"""Tests des annonces, des appareils FCM, du ciblage et de la gestion des erreurs."""
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from apps.flights.models import Destination, Favorite

from .models import Announcement, FCMDevice, Notification, NotificationCategory, TargetType
from .services import resolve_recipients

User = get_user_model()


class NotificationsBaseTestCase(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.admin = User.objects.create_user(
            email="admin@notif.local", password="Pass!12345", role=User.Role.ADMIN
        )
        cls.agent = User.objects.create_user(
            email="agent@notif.local", password="Pass!12345", role=User.Role.AGENT
        )
        cls.worker = User.objects.create_user(
            email="worker@notif.local", password="Pass!12345", role=User.Role.WORKER
        )
        cls.other_worker = User.objects.create_user(
            email="other@notif.local", password="Pass!12345", role=User.Role.WORKER
        )
        cls.rns = Destination.objects.create(code="RNS", name="RENNES")
        cls.oran = Destination.objects.create(code="ORAN", name="ORAN")

    def setUp(self):
        cache.clear()

    def auth(self, user):
        token = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")


class AnnouncementTests(NotificationsBaseTestCase):
    def test_agent_creates_draft_and_worker_cannot_see_it(self):
        self.auth(self.agent)
        created = self.client.post(
            "/api/announcements/",
            {"title": "Brouillon", "content": "Contenu", "category": "general",
             "priority": "normal"},
            format="json",
        )
        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        self.assertEqual(created.data["status"], Announcement.Status.DRAFT)

        self.auth(self.worker)
        listing = self.client.get("/api/announcements/")
        self.assertEqual(listing.data["count"], 0)

    def test_publish_makes_announcement_visible_to_workers(self):
        self.auth(self.agent)
        created = self.client.post(
            "/api/announcements/",
            {"title": "Info generale", "content": "Contenu", "category": "general"},
            format="json",
        )
        announcement_id = created.data["id"]
        publish = self.client.post(f"/api/announcements/{announcement_id}/publish/")
        self.assertEqual(publish.status_code, status.HTTP_200_OK)

        self.auth(self.worker)
        listing = self.client.get("/api/announcements/")
        self.assertEqual(listing.data["count"], 1)

    def test_targeted_announcement_only_for_interested_worker(self):
        Favorite.objects.create(
            user=self.worker, favorite_type=Favorite.FavoriteType.DESTINATION,
            destination=self.oran,
        )
        self.auth(self.agent)
        created = self.client.post(
            "/api/announcements/",
            {"title": "Oran", "content": "Contenu ORAN", "category": "operation",
             "target_type": TargetType.DESTINATION, "target_destination": self.oran.pk},
            format="json",
        )
        self.client.post(f"/api/announcements/{created.data['id']}/publish/")

        self.auth(self.worker)
        self.assertEqual(self.client.get("/api/announcements/").data["count"], 1)
        self.auth(self.other_worker)
        self.assertEqual(self.client.get("/api/announcements/").data["count"], 0)

    def test_urgent_published_announcement_creates_notification(self):
        self.auth(self.agent)
        created = self.client.post(
            "/api/announcements/",
            {"title": "Urgence", "content": "Message urgent", "category": "security",
             "priority": "urgent", "send_push": True},
            format="json",
        )
        self.client.post(f"/api/announcements/{created.data['id']}/publish/")
        self.assertTrue(
            Notification.objects.filter(
                category=NotificationCategory.URGENT, is_urgent=True
            ).exists()
        )

    def test_expired_announcement_not_visible(self):
        import datetime as dt

        announcement = Announcement.objects.create(
            title="Expiree",
            content="...",
            status=Announcement.Status.PUBLISHED,
            published_at=timezone.now(),
            expires_at=timezone.now() - dt.timedelta(hours=1),
        )
        self.assertTrue(announcement.is_expired)
        self.auth(self.worker)
        listing = self.client.get("/api/announcements/")
        self.assertNotIn(announcement.pk, [a["id"] for a in listing.data["results"]])

    def test_worker_cannot_create_announcement(self):
        self.auth(self.worker)
        response = self.client.post(
            "/api/announcements/", {"title": "x", "content": "y"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class FCMDeviceTests(NotificationsBaseTestCase):
    def test_register_and_list_device(self):
        self.auth(self.worker)
        response = self.client.post(
            "/api/devices/",
            {"token": "token-abc-123", "platform": "android", "device_id": "dev-1"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        listing = self.client.get("/api/devices/")
        self.assertEqual(listing.data["count"], 1)

    def test_re_registering_same_token_does_not_duplicate(self):
        self.auth(self.worker)
        payload = {"token": "token-abc-123", "platform": "android"}
        self.client.post("/api/devices/", payload, format="json")
        self.client.post("/api/devices/", payload, format="json")
        self.assertEqual(FCMDevice.objects.filter(token="token-abc-123").count(), 1)

    def test_unregister_device(self):
        FCMDevice.objects.create(user=self.worker, token="token-abc-123")
        self.auth(self.worker)
        response = self.client.post(
            "/api/devices/unregister/", {"token": "token-abc-123"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(FCMDevice.objects.filter(token="token-abc-123").exists())

    def test_devices_isolated_by_user(self):
        FCMDevice.objects.create(user=self.worker, token="token-worker")
        FCMDevice.objects.create(user=self.other_worker, token="token-other")
        self.auth(self.worker)
        listing = self.client.get("/api/devices/")
        self.assertEqual(listing.data["count"], 1)


class TargetingServiceTests(NotificationsBaseTestCase):
    def test_all_workers_targeting_excludes_agents(self):
        recipients = resolve_recipients(TargetType.ALL_WORKERS)
        ids = set(recipients.values_list("id", flat=True))
        self.assertIn(self.worker.pk, ids)
        self.assertIn(self.other_worker.pk, ids)
        self.assertNotIn(self.agent.pk, ids)
        self.assertNotIn(self.admin.pk, ids)

    def test_route_targeting_matches_favorites(self):
        Favorite.objects.create(
            user=self.worker, favorite_type=Favorite.FavoriteType.ROUTE,
            route_origin=self.rns, route_destination=self.oran,
        )
        recipients = resolve_recipients(
            TargetType.ROUTE, route_origin=self.rns, route_destination=self.oran
        )
        ids = set(recipients.values_list("id", flat=True))
        self.assertEqual(ids, {self.worker.pk})


class ErrorHandlingTests(NotificationsBaseTestCase):
    def test_unauthenticated_request_returns_consistent_error(self):
        response = self.client.get("/api/flights/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertIn("error", response.data)
        self.assertEqual(response.data["error"]["code"], "authentication_failed")

    def test_not_found_returns_consistent_error(self):
        self.auth(self.worker)
        response = self.client.get("/api/announcements/999999/")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertIn("error", response.data)
        self.assertEqual(response.data["error"]["code"], "not_found")

    def test_method_not_allowed_returns_consistent_error(self):
        self.auth(self.agent)
        response = self.client.delete("/api/stats/flights/")
        self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)
        self.assertIn("error", response.data)
