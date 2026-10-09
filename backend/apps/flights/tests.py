"""Tests des destinations, programmes, vols, favoris et statistiques."""
import datetime as dt

from django.contrib.auth import get_user_model
from django.core.cache import cache
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from apps.notifications.models import (
    Notification,
    NotificationCategory,
    TargetType,
)

from .constants import DayOfWeek, FlightStatus
from .models import Destination, Favorite, Flight, FlightChangeLog, WeeklySchedule

User = get_user_model()


class FlightsBaseTestCase(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.admin = User.objects.create_user(
            email="admin@flights.local", password="Pass!12345", role=User.Role.ADMIN
        )
        cls.agent = User.objects.create_user(
            email="agent@flights.local", password="Pass!12345", role=User.Role.AGENT
        )
        cls.worker = User.objects.create_user(
            email="worker@flights.local", password="Pass!12345", role=User.Role.WORKER
        )
        cls.rns = Destination.objects.create(code="RNS", name="RENNES")
        cls.oran = Destination.objects.create(code="ORAN", name="ORAN")
        cls.adrar = Destination.objects.create(code="ADRAR", name="ADRAR")

    def setUp(self):
        cache.clear()

    def auth(self, user):
        token = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")

    def make_schedule(self, **overrides):
        data = {
            "day_of_week": DayOfWeek.SATURDAY,
            "origin": self.rns,
            "destination": self.oran,
            "registration_time": dt.time(8, 0),
            "departure_time": dt.time(10, 0),
            "arrival_time": dt.time(12, 0),
        }
        data.update(overrides)
        return WeeklySchedule.objects.create(**data)

    def make_flight(self, **overrides):
        data = {
            "flight_date": dt.date(2026, 3, 14),  # un samedi
            "origin": self.rns,
            "destination": self.oran,
            "registration_time": dt.time(8, 0),
            "departure_time": dt.time(10, 0),
            "arrival_time": dt.time(12, 0),
        }
        data.update(overrides)
        return Flight.objects.create(**data)


class DestinationTests(FlightsBaseTestCase):
    def test_authenticated_worker_can_read_destinations(self):
        self.auth(self.worker)
        response = self.client.get("/api/destinations/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 3)

    def test_worker_cannot_create_destination(self):
        self.auth(self.worker)
        response = self.client.post(
            "/api/destinations/", {"code": "BEJAIA", "name": "BEJAIA"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_agent_can_create_destination(self):
        self.auth(self.agent)
        response = self.client.post(
            "/api/destinations/", {"code": "biskra", "name": "BISKRA"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["code"], "BISKRA")


class WeeklyScheduleTests(FlightsBaseTestCase):
    def test_agent_creates_schedule_and_week_is_grouped(self):
        self.auth(self.agent)
        response = self.client.post(
            "/api/weekly-schedules/",
            {
                "day_of_week": DayOfWeek.SATURDAY,
                "origin": self.rns.pk,
                "destination": self.oran.pk,
                "registration_time": "08:00",
                "departure_time": "10:00",
                "arrival_time": "12:00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        week = self.client.get("/api/weekly-schedules/week/")
        self.assertEqual(week.status_code, status.HTTP_200_OK)
        self.assertEqual(len(week.data), 7)  # samedi -> vendredi
        saturday = next(d for d in week.data if d["day_of_week"] == DayOfWeek.SATURDAY)
        self.assertEqual(len(saturday["flights"]), 1)

    def test_worker_cannot_create_schedule(self):
        self.auth(self.worker)
        response = self.client.post(
            "/api/weekly-schedules/",
            {
                "day_of_week": DayOfWeek.SATURDAY,
                "origin": self.rns.pk,
                "destination": self.oran.pk,
                "registration_time": "08:00",
                "departure_time": "10:00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_duplicate_schedule_slot_rejected(self):
        self.make_schedule()
        self.auth(self.agent)
        response = self.client.post(
            "/api/weekly-schedules/",
            {
                "day_of_week": DayOfWeek.SATURDAY,
                "origin": self.rns.pk,
                "destination": self.oran.pk,
                "registration_time": "08:00",
                "departure_time": "10:00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_generate_flights_from_schedule(self):
        self.make_schedule()
        self.auth(self.agent)
        response = self.client.post(
            "/api/weekly-schedules/generate/", {"week_start": "2026-03-14"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["created"], 1)
        self.assertTrue(
            Flight.objects.filter(flight_date=dt.date(2026, 3, 14), origin=self.rns).exists()
        )
        # Une seconde generation ne cree pas de doublon.
        second = self.client.post(
            "/api/weekly-schedules/generate/", {"week_start": "2026-03-14"}, format="json"
        )
        self.assertEqual(second.data["created"], 0)
        self.assertEqual(second.data["skipped"], 1)


class FlightCrudTests(FlightsBaseTestCase):
    def test_agent_creates_flight_and_notification_is_recorded(self):
        self.auth(self.agent)
        response = self.client.post(
            "/api/flights/",
            {
                "flight_date": "2026-03-14",
                "origin": self.rns.pk,
                "destination": self.oran.pk,
                "flight_code": "AH1000",
                "registration_time": "08:00",
                "departure_time": "10:00",
                "arrival_time": "12:00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        flight = Flight.objects.get(pk=response.data["id"])
        self.assertEqual(flight.day_of_week, DayOfWeek.SATURDAY)
        self.assertEqual(flight.created_by, self.agent)
        self.assertTrue(
            Notification.objects.filter(
                category=NotificationCategory.NEW_FLIGHT, flight=flight
            ).exists()
        )
        self.assertTrue(
            FlightChangeLog.objects.filter(
                flight=flight, change_type=FlightChangeLog.ChangeType.CREATED
            ).exists()
        )

    def test_worker_cannot_create_flight(self):
        self.auth(self.worker)
        response = self.client.post(
            "/api/flights/",
            {
                "flight_date": "2026-03-14",
                "origin": self.rns.pk,
                "destination": self.oran.pk,
                "registration_time": "08:00",
                "departure_time": "10:00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_duplicate_flight_slot_rejected(self):
        self.make_flight()
        self.auth(self.agent)
        response = self.client.post(
            "/api/flights/",
            {
                "flight_date": "2026-03-14",
                "origin": self.rns.pk,
                "destination": self.oran.pk,
                "registration_time": "08:00",
                "departure_time": "10:00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_arrival_before_departure_is_rejected(self):
        self.auth(self.agent)
        response = self.client.post(
            "/api/flights/",
            {
                "flight_date": "2026-03-14",
                "origin": self.rns.pk,
                "destination": self.oran.pk,
                "registration_time": "08:00",
                "departure_time": "10:00",
                "arrival_time": "09:00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_registration_after_departure_is_rejected(self):
        self.auth(self.agent)
        response = self.client.post(
            "/api/flights/",
            {
                "flight_date": "2026-03-14",
                "origin": self.rns.pk,
                "destination": self.oran.pk,
                "registration_time": "11:00",
                "departure_time": "10:00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_same_origin_and_destination_rejected(self):
        self.auth(self.agent)
        response = self.client.post(
            "/api/flights/",
            {
                "flight_date": "2026-03-14",
                "origin": self.rns.pk,
                "destination": self.rns.pk,
                "registration_time": "08:00",
                "departure_time": "10:00",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_flight_is_deactivated_not_deleted(self):
        flight = self.make_flight()
        self.auth(self.agent)
        response = self.client.delete(f"/api/flights/{flight.pk}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        flight.refresh_from_db()
        self.assertFalse(flight.is_active)
        self.assertTrue(Flight.objects.filter(pk=flight.pk).exists())

    def test_update_departure_time_keeps_previous_time_and_logs(self):
        flight = self.make_flight()
        self.auth(self.agent)
        response = self.client.patch(
            f"/api/flights/{flight.pk}/", {"departure_time": "11:30"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        flight.refresh_from_db()
        self.assertEqual(flight.departure_time, dt.time(11, 30))
        self.assertEqual(flight.previous_departure_time, dt.time(10, 0))
        self.assertTrue(
            FlightChangeLog.objects.filter(
                flight=flight, change_type=FlightChangeLog.ChangeType.TIME_CHANGED
            ).exists()
        )
        self.assertTrue(
            Notification.objects.filter(
                flight=flight, category=NotificationCategory.DEPARTURE_TIME_CHANGED
            ).exists()
        )


class FlightBusinessActionTests(FlightsBaseTestCase):
    def test_delay_sets_status_time_and_notifies(self):
        flight = self.make_flight()
        self.auth(self.agent)
        response = self.client.post(
            f"/api/flights/{flight.pk}/delay/",
            {"new_departure_time": "11:30", "observation": "Conditions meteo"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        flight.refresh_from_db()
        self.assertEqual(flight.status, FlightStatus.DELAYED)
        self.assertEqual(flight.departure_time, dt.time(11, 30))
        self.assertEqual(flight.previous_departure_time, dt.time(10, 0))
        self.assertTrue(
            FlightChangeLog.objects.filter(
                flight=flight, change_type=FlightChangeLog.ChangeType.DELAYED
            ).exists()
        )
        self.assertTrue(
            Notification.objects.filter(flight=flight, category=NotificationCategory.DELAY).exists()
        )

    def test_delay_requires_new_time(self):
        flight = self.make_flight()
        self.auth(self.agent)
        response = self.client.post(f"/api/flights/{flight.pk}/delay/", {}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_postpone_changes_date_and_keeps_schedule_untouched(self):
        schedule = self.make_schedule()
        flight = self.make_flight(schedule=schedule)
        self.auth(self.agent)
        response = self.client.post(
            f"/api/flights/{flight.pk}/postpone/",
            {"new_flight_date": "2026-03-15", "observation": "Report au dimanche"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        flight.refresh_from_db()
        schedule.refresh_from_db()
        self.assertEqual(flight.flight_date, dt.date(2026, 3, 15))
        self.assertEqual(flight.status, FlightStatus.POSTPONED)
        # Le programme hebdomadaire (recurrent) ne doit pas changer.
        self.assertEqual(schedule.day_of_week, DayOfWeek.SATURDAY)
        self.assertEqual(schedule.departure_time, dt.time(10, 0))

    def test_cancel_flight(self):
        flight = self.make_flight()
        self.auth(self.agent)
        response = self.client.post(
            f"/api/flights/{flight.pk}/cancel/", {"observation": "Vol annule"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        flight.refresh_from_db()
        self.assertEqual(flight.status, FlightStatus.CANCELLED)
        self.assertTrue(
            Notification.objects.filter(
                flight=flight, category=NotificationCategory.CANCELLATION
            ).exists()
        )

    def test_observe_requires_content(self):
        flight = self.make_flight()
        self.auth(self.agent)
        self.assertEqual(
            self.client.post(f"/api/flights/{flight.pk}/observe/", {}, format="json").status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        response = self.client.post(
            f"/api/flights/{flight.pk}/observe/", {"observation": "Retard possible"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        flight.refresh_from_db()
        self.assertEqual(flight.observation, "Retard possible")

    def test_history_endpoint_returns_logs(self):
        flight = self.make_flight()
        self.auth(self.agent)
        self.client.post(f"/api/flights/{flight.pk}/cancel/", {}, format="json")
        response = self.client.get(f"/api/flights/{flight.pk}/history/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(response.data), 1)

    def test_today_and_upcoming(self):
        today = dt.date(2026, 3, 14)
        self.make_flight(flight_date=today)
        self.auth(self.worker)
        self.assertEqual(self.client.get("/api/flights/today/").status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.get("/api/flights/upcoming/").status_code, status.HTTP_200_OK)

    def test_worker_cannot_access_stats(self):
        self.auth(self.worker)
        self.assertEqual(
            self.client.get("/api/stats/flights/").status_code, status.HTTP_403_FORBIDDEN
        )

    def test_agent_can_access_stats(self):
        self.make_flight()
        self.auth(self.agent)
        response = self.client.get("/api/stats/flights/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["total_flights"], 1)


class FlightFilterTests(FlightsBaseTestCase):
    def test_filter_by_date_status_and_route(self):
        self.make_flight(flight_date=dt.date(2026, 3, 14), status=FlightStatus.SCHEDULED)
        self.make_flight(
            flight_date=dt.date(2026, 3, 15),
            origin=self.rns,
            destination=self.adrar,
            departure_time=dt.time(14, 0),
            status=FlightStatus.CANCELLED,
        )
        self.auth(self.worker)
        response = self.client.get("/api/flights/?date=2026-03-14")
        self.assertEqual(response.data["count"], 1)
        response = self.client.get("/api/flights/?status=cancelled")
        self.assertEqual(response.data["count"], 1)
        response = self.client.get("/api/flights/?route=RNS-ADRAR")
        self.assertEqual(response.data["count"], 1)
        response = self.client.get("/api/flights/?date_from=2026-03-14&date_to=2026-03-14")
        self.assertEqual(response.data["count"], 1)


class FavoriteTests(FlightsBaseTestCase):
    def test_worker_can_add_and_list_favorites(self):
        self.auth(self.worker)
        response = self.client.post(
            "/api/favorites/", {"favorite_type": "destination", "destination": self.oran.pk},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["label"], "ORAN")
        listing = self.client.get("/api/favorites/")
        self.assertEqual(listing.data["count"], 1)

    def test_duplicate_favorite_rejected(self):
        self.auth(self.worker)
        payload = {"favorite_type": "destination", "destination": self.oran.pk}
        self.client.post("/api/favorites/", payload, format="json")
        response = self.client.post("/api/favorites/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_route_favorite_requires_both_destinations(self):
        self.auth(self.worker)
        response = self.client.post(
            "/api/favorites/",
            {"favorite_type": "route", "route_origin": self.rns.pk},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_favorites_are_isolated_between_users(self):
        Favorite.objects.create(
            user=self.worker, favorite_type=Favorite.FavoriteType.DESTINATION,
            destination=self.oran,
        )
        Favorite.objects.create(
            user=self.agent, favorite_type=Favorite.FavoriteType.DESTINATION,
            destination=self.adrar,
        )
        self.auth(self.worker)
        response = self.client.get("/api/favorites/")
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["destination_detail"]["code"], "ORAN")

    def test_toggle_favorite_notifications(self):
        favorite = Favorite.objects.create(
            user=self.worker, favorite_type=Favorite.FavoriteType.DESTINATION,
            destination=self.oran,
        )
        self.auth(self.worker)
        response = self.client.post(f"/api/favorites/{favorite.pk}/toggle_notifications/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        favorite.refresh_from_db()
        self.assertFalse(favorite.notifications_enabled)


class NotificationTargetingTests(FlightsBaseTestCase):
    def test_destination_favorite_targets_only_interested_users(self):
        Favorite.objects.create(
            user=self.worker, favorite_type=Favorite.FavoriteType.DESTINATION,
            destination=self.oran,
        )
        other = User.objects.create_user(
            email="autre@flights.local", password="Pass!12345", role=User.Role.WORKER
        )
        # Cible les utilisateurs interesses par ORAN.
        self.auth(self.agent)
        response = self.client.post(
            "/api/notification-management/",
            {
                "title": "Info ORAN",
                "message": "Retard sur la ligne ORAN",
                "category": "delay",
                "target_type": TargetType.DESTINATION,
                "destination": self.oran.pk,
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        notification = Notification.objects.get(pk=response.data["id"])
        recipients = set(notification.recipients.values_list("user_id", flat=True))
        self.assertIn(self.worker.pk, recipients)
        self.assertNotIn(other.pk, recipients)
        self.assertNotIn(self.agent.pk, recipients)

    def test_notification_deduplication(self):
        self.auth(self.agent)
        payload = {
            "title": "Annonce urgente",
            "message": "Message identique",
            "category": "urgent",
            "target_type": TargetType.ALL_WORKERS,
            "dedup_key": "clef-unique-001",
        }
        first = self.client.post("/api/notification-management/", payload, format="json")
        second = self.client.post("/api/notification-management/", payload, format="json")
        self.assertEqual(first.data["id"], second.data["id"])
        self.assertEqual(Notification.objects.filter(dedup_key="clef-unique-001").count(), 1)

    def test_worker_cannot_send_notifications(self):
        self.auth(self.worker)
        response = self.client.post(
            "/api/notification-management/",
            {"title": "x", "message": "y", "category": "urgent"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_inbox_lists_notifications_for_user(self):
        Favorite.objects.create(
            user=self.worker, favorite_type=Favorite.FavoriteType.DESTINATION,
            destination=self.oran,
        )
        self.auth(self.agent)
        self.client.post(
            "/api/notification-management/",
            {
                "title": "Info",
                "message": "Message",
                "category": "delay",
                "target_type": TargetType.DESTINATION,
                "destination": self.oran.pk,
            },
            format="json",
        )
        self.auth(self.worker)
        inbox = self.client.get("/api/notifications/")
        self.assertEqual(inbox.data["count"], 1)
        notification_id = inbox.data["results"][0]["id"]
        read = self.client.post(f"/api/notifications/{notification_id}/mark_read/")
        self.assertEqual(read.status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.get("/api/notifications/unread_count/").data["unread"], 0)
