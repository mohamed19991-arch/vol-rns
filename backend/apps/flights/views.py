"""API des destinations, programmes hebdomadaires, vols, favoris et statistiques."""
import datetime as dt
import logging

from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from django.db.models import Count, Q
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.exceptions import error_response
from apps.core.models import AuditLog
from apps.core.permissions import IsAdmin, IsAgent, IsAgentOrReadOnly
from apps.core.utils import log_action

from .constants import CRITICAL_STATUSES, WEEK_DISPLAY_ORDER, DayOfWeek, FlightStatus
from .filters import FlightFilter
from .models import Destination, Favorite, Flight, FlightChangeLog, WeeklySchedule
from .serializers import (
    DAY_LABELS,
    DestinationSerializer,
    FavoriteSerializer,
    FlightChangeLogSerializer,
    FlightListSerializer,
    FlightSerializer,
    StatusChangeSerializer,
    WeeklyScheduleSerializer,
)
from .services import (
    log_flight_change,
    notify_flight_status,
    notify_flight_times,
    notify_new_flight,
)

logger = logging.getLogger("apps.flights")


def _fmt_time(value) -> str:
    return value.strftime("%H:%M") if value else ""


@extend_schema_view(list=extend_schema(tags=["Destinations"]))
class DestinationViewSet(viewsets.ModelViewSet):
    queryset = Destination.objects.all()
    serializer_class = DestinationSerializer
    permission_classes = [IsAgentOrReadOnly]
    filterset_fields = ["is_active"]
    search_fields = ["code", "name", "city", "airport_name"]
    ordering_fields = ["code", "name"]

    def perform_create(self, serializer):
        destination = serializer.save()
        log_action(self.request, AuditLog.Action.CREATE, instance=destination,
                   description=f"Creation de la destination {destination.code}")

    def perform_update(self, serializer):
        destination = serializer.save()
        log_action(self.request, AuditLog.Action.UPDATE, instance=destination,
                   description=f"Modification de la destination {destination.code}")

    def perform_destroy(self, instance):
        if instance.departures.exists() or instance.arrivals.exists():
            raise ValidationError(
                "Cette destination est utilisee par des vols : desactivation recommandee."
            )
        log_action(self.request, AuditLog.Action.DELETE, instance=instance,
                   description=f"Suppression de la destination {instance.code}")
        instance.delete()


@extend_schema_view(list=extend_schema(tags=["Programme hebdomadaire"]))
class WeeklyScheduleViewSet(viewsets.ModelViewSet):
    """Programme hebdomadaire habituel (recurrent)."""

    queryset = WeeklySchedule.objects.select_related("origin", "destination").all()
    serializer_class = WeeklyScheduleSerializer
    permission_classes = [IsAgentOrReadOnly]
    filterset_fields = ["day_of_week", "origin", "destination", "is_active"]
    search_fields = ["flight_code", "origin__code", "destination__code"]

    def perform_create(self, serializer):
        schedule = serializer.save()
        log_action(self.request, AuditLog.Action.CREATE, instance=schedule,
                   description=f"Ajout au programme: {schedule}")

    def perform_update(self, serializer):
        schedule = serializer.save()
        log_action(self.request, AuditLog.Action.UPDATE, instance=schedule,
                   description=f"Modification du programme: {schedule}")

    def perform_destroy(self, instance):
        log_action(self.request, AuditLog.Action.DELETE, instance=instance,
                   description=f"Suppression du programme: {instance}")
        instance.delete()

    @extend_schema(tags=["Programme hebdomadaire"])
    @action(detail=False, methods=["get"])
    def week(self, request):
        """Programme complet de la semaine, groupe par jour (ordre: samedi -> vendredi)."""
        schedules = self.get_queryset().filter(is_active=True)
        grouped = {day.value: [] for day in WEEK_DISPLAY_ORDER}
        for schedule in schedules:
            grouped.setdefault(schedule.day_of_week, []).append(schedule)
        data = [
            {
                "day_of_week": day.value,
                "day_label": DAY_LABELS[day.value],
                "flights": WeeklyScheduleSerializer(grouped.get(day.value, []), many=True).data,
            }
            for day in WEEK_DISPLAY_ORDER
        ]
        return Response(data)

    @extend_schema(tags=["Programme hebdomadaire"], request=None)
    @action(detail=False, methods=["post"], permission_classes=[IsAgent])
    def generate(self, request):
        """Genere les vols dates d'une semaine a partir du programme habituel.

        Parametre ``week_start`` (AAAA-MM-JJ, un samedi). Par defaut la semaine
        courante. Les vols exceptionnels existants ne sont pas modifies.
        """
        week_start_raw = request.data.get("week_start")
        if week_start_raw:
            try:
                week_start = dt.date.fromisoformat(week_start_raw)
            except ValueError:
                return error_response("Format de date invalide (attendu AAAA-MM-JJ).")
        else:
            today = timezone.localdate()
            # La semaine metier commence le samedi.
            offset = (today.weekday() - DayOfWeek.SATURDAY) % 7
            week_start = today - dt.timedelta(days=offset)

        schedules = self.get_queryset().filter(is_active=True)
        created = 0
        skipped = 0
        with transaction.atomic():
            for schedule in schedules:
                # Debut de semaine = samedi ; on calcule la date du jour vise.
                delta = (schedule.day_of_week - DayOfWeek.SATURDAY) % 7
                flight_date = week_start + dt.timedelta(days=delta)
                _, was_created = Flight.objects.get_or_create(
                    flight_date=flight_date,
                    origin=schedule.origin,
                    destination=schedule.destination,
                    departure_time=schedule.departure_time,
                    defaults={
                        "schedule": schedule,
                        "flight_code": schedule.flight_code,
                        "registration_time": schedule.registration_time,
                        "arrival_time": schedule.arrival_time,
                        "status": FlightStatus.SCHEDULED,
                        "created_by": request.user,
                        "updated_by": request.user,
                    },
                )
                created += int(was_created)
                skipped += int(not was_created)
        log_action(request, AuditLog.Action.CREATE, description=(
            f"Generation de {created} vol(s) pour la semaine du {week_start:%d/%m/%Y}"
        ))
        return Response(
            {"week_start": week_start, "created": created, "skipped": skipped},
            status=status.HTTP_201_CREATED,
        )


@extend_schema_view(list=extend_schema(tags=["Vols"]))
class FlightViewSet(viewsets.ModelViewSet):
    """Vols associes a des dates precises."""

    queryset = Flight.objects.select_related(
        "origin", "destination", "created_by", "updated_by", "schedule"
    ).all()
    permission_classes = [IsAgentOrReadOnly]
    filterset_class = FlightFilter
    search_fields = ["flight_code", "origin__code", "destination__code", "observation"]
    ordering_fields = ["flight_date", "departure_time", "status", "updated_at"]
    ordering = ["flight_date", "departure_time"]

    def get_serializer_class(self):
        if self.action == "list":
            return FlightListSerializer
        return FlightSerializer

    # ------------------------------------------------------------------
    # Creation / modification
    # ------------------------------------------------------------------
    def perform_create(self, serializer):
        try:
            flight = serializer.save(created_by=self.request.user, updated_by=self.request.user)
        except IntegrityError:
            raise ValidationError(
                {"detail": "Un vol identique existe deja pour cette date et cet horaire."}
            )
        log_flight_change(flight, self.request.user, FlightChangeLog.ChangeType.CREATED,
                          note="Creation du vol")
        log_action(self.request, AuditLog.Action.CREATE, instance=flight,
                   description=f"Creation du vol {flight}")
        if str(self.request.query_params.get("notify", "true")).lower() != "false":
            notify_new_flight(flight)

    def perform_update(self, serializer):
        instance = self.get_object()
        user = self.request.user
        old_times = {
            field: getattr(instance, field)
            for field in ("registration_time", "departure_time", "arrival_time")
        }
        old_status = instance.status
        old_observation = instance.observation

        try:
            flight = serializer.save(updated_by=user)
        except IntegrityError:
            raise ValidationError(
                {"detail": "Un vol identique existe deja pour cette date et cet horaire."}
            )

        changed_time_fields = [
            field for field, old in old_times.items() if getattr(flight, field) != old
        ]
        if changed_time_fields:
            for field in changed_time_fields:
                setattr(flight, f"previous_{field}", old_times[field])
            update_fields = [f"previous_{f}" for f in changed_time_fields] + ["updated_at"]
            flight.save(update_fields=update_fields)
            for field in changed_time_fields:
                log_flight_change(
                    flight, user, FlightChangeLog.ChangeType.TIME_CHANGED,
                    field_name=field,
                    old_value=_fmt_time(old_times[field]),
                    new_value=_fmt_time(getattr(flight, field)),
                )
            notify_flight_times(flight, changed_time_fields)

        if flight.status != old_status:
            log_flight_change(
                flight, user, FlightChangeLog.ChangeType.STATUS_CHANGED,
                old_value=old_status, new_value=flight.status,
            )
            notify_flight_status(flight)

        if flight.observation != old_observation:
            log_flight_change(
                flight, user, FlightChangeLog.ChangeType.OBSERVATION,
                old_value=old_observation, new_value=flight.observation,
            )

        log_action(self.request, AuditLog.Action.UPDATE, instance=flight,
                   description=f"Modification du vol {flight}")

    def perform_destroy(self, instance):
        # Suppression logique : la tracabilite est conservee.
        instance.is_active = False
        instance.save(update_fields=["is_active", "updated_at"])
        log_flight_change(instance, self.request.user, FlightChangeLog.ChangeType.CANCELLED,
                          note="Vol desactive")
        log_action(self.request, AuditLog.Action.DELETE, instance=instance,
                   description=f"Desactivation du vol {instance}")

    # ------------------------------------------------------------------
    # Lectures specifiques
    # ------------------------------------------------------------------
    @extend_schema(tags=["Vols"])
    @action(detail=False, methods=["get"], permission_classes=[IsAuthenticated])
    def today(self, request):
        today = timezone.localdate()
        queryset = self.filter_queryset(self.get_queryset().filter(flight_date=today))
        page = self.paginate_queryset(queryset)
        serializer = FlightListSerializer(page or queryset, many=True)
        if page is not None:
            return self.get_paginated_response(serializer.data)
        return Response(serializer.data)

    @extend_schema(tags=["Vols"])
    @action(detail=False, methods=["get"], permission_classes=[IsAuthenticated])
    def upcoming(self, request):
        """Prochains vols a partir de maintenant (limite configurable)."""
        try:
            limit = int(request.query_params.get("limit", 10))
        except (TypeError, ValueError):
            limit = 10
        now = timezone.localtime()
        queryset = (
            self.get_queryset()
            .filter(is_active=True)
            .filter(
                Q(flight_date__gt=now.date())
                | Q(flight_date=now.date(), departure_time__gte=now.time())
            )
            .filter(~Q(status__in=[FlightStatus.CANCELLED, FlightStatus.ARRIVED]))
            .order_by("flight_date", "departure_time")[: max(1, min(limit, 50))]
        )
        return Response(FlightListSerializer(queryset, many=True).data)

    @extend_schema(tags=["Vols"])
    @action(detail=True, methods=["get"], permission_classes=[IsAuthenticated])
    def history(self, request, pk=None):
        flight = self.get_object()
        logs = flight.change_logs.select_related("changed_by").all()
        return Response(FlightChangeLogSerializer(logs, many=True).data)

    # ------------------------------------------------------------------
    # Actions metier (agent / administrateur)
    # ------------------------------------------------------------------
    def _apply_status_change(self, request, flight, new_status, *, observation="", times=None):
        times = times or {}
        user = request.user
        old_status = flight.status
        old_times = {f: getattr(flight, f) for f in ("registration_time", "departure_time", "arrival_time")}

        if times.get("new_flight_date"):
            flight.flight_date = times["new_flight_date"]
        for field, value in (
            ("registration_time", times.get("new_registration_time")),
            ("departure_time", times.get("new_departure_time")),
            ("arrival_time", times.get("new_arrival_time")),
        ):
            if value:
                setattr(flight, field, value)
        if observation:
            flight.observation = observation
        flight.status = new_status
        try:
            flight.clean()
        except DjangoValidationError as exc:
            raise ValidationError(getattr(exc, "message_dict", str(exc)))
        flight.updated_by = user

        changed_time_fields = [f for f, old in old_times.items() if getattr(flight, f) != old]
        for field in changed_time_fields:
            setattr(flight, f"previous_{field}", old_times[field])
        try:
            flight.save()
        except IntegrityError:
            raise ValidationError(
                {"detail": "Un vol identique existe deja pour cette date et cet horaire."}
            )

        change_type = {
            FlightStatus.DELAYED: FlightChangeLog.ChangeType.DELAYED,
            FlightStatus.POSTPONED: FlightChangeLog.ChangeType.POSTPONED,
            FlightStatus.CANCELLED: FlightChangeLog.ChangeType.CANCELLED,
            FlightStatus.RESCHEDULED: FlightChangeLog.ChangeType.TIME_CHANGED,
        }.get(new_status, FlightChangeLog.ChangeType.STATUS_CHANGED)
        log_flight_change(
            flight, user, change_type,
            old_value=old_status, new_value=new_status, note=observation,
        )
        for field in changed_time_fields:
            log_flight_change(
                flight, user, FlightChangeLog.ChangeType.TIME_CHANGED,
                field_name=field,
                old_value=_fmt_time(old_times[field]),
                new_value=_fmt_time(getattr(flight, field)),
            )
        if new_status in CRITICAL_STATUSES:
            notify_flight_status(flight, dedup_suffix=f"{_fmt_time(flight.departure_time)}")
        log_action(request, AuditLog.Action.UPDATE, instance=flight,
                   description=f"Statut du vol change vers {new_status}")
        return flight

    @extend_schema(request=StatusChangeSerializer, tags=["Vols"])
    @action(detail=True, methods=["post"], permission_classes=[IsAgent])
    def change_status(self, request, pk=None):
        flight = self.get_object()
        serializer = StatusChangeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        times = {
            key: data.get(key)
            for key in ("new_departure_time", "new_registration_time", "new_arrival_time", "new_flight_date")
        }
        flight = self._apply_status_change(
            request, flight, data["status"],
            observation=data.get("observation", ""), times=times,
        )
        return Response(FlightSerializer(flight).data)

    @extend_schema(request=StatusChangeSerializer, tags=["Vols"])
    @action(detail=True, methods=["post"], permission_classes=[IsAgent])
    def delay(self, request, pk=None):
        flight = self.get_object()
        serializer = StatusChangeSerializer(data={**request.data, "status": FlightStatus.DELAYED})
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        flight = self._apply_status_change(
            request, flight, FlightStatus.DELAYED,
            observation=data.get("observation", ""),
            times={"new_departure_time": data.get("new_departure_time")},
        )
        return Response(FlightSerializer(flight).data)

    @extend_schema(request=StatusChangeSerializer, tags=["Vols"])
    @action(detail=True, methods=["post"], permission_classes=[IsAgent])
    def postpone(self, request, pk=None):
        flight = self.get_object()
        serializer = StatusChangeSerializer(data={**request.data, "status": FlightStatus.POSTPONED})
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        flight = self._apply_status_change(
            request, flight, FlightStatus.POSTPONED,
            observation=data.get("observation", ""),
            times={
                "new_departure_time": data.get("new_departure_time"),
                "new_flight_date": data.get("new_flight_date"),
            },
        )
        return Response(FlightSerializer(flight).data)

    @extend_schema(request=StatusChangeSerializer, tags=["Vols"])
    @action(detail=True, methods=["post"], permission_classes=[IsAgent])
    def cancel(self, request, pk=None):
        flight = self.get_object()
        serializer = StatusChangeSerializer(data={**request.data, "status": FlightStatus.CANCELLED})
        serializer.is_valid(raise_exception=True)
        flight = self._apply_status_change(
            request, flight, FlightStatus.CANCELLED,
            observation=serializer.validated_data.get("observation", ""),
        )
        return Response(FlightSerializer(flight).data)

    @extend_schema(request=None, tags=["Vols"])
    @action(detail=True, methods=["post"], permission_classes=[IsAgent])
    def observe(self, request, pk=None):
        flight = self.get_object()
        observation = (request.data.get("observation") or "").strip()
        if not observation:
            return error_response("L'observation ne peut pas etre vide.")
        old = flight.observation
        flight.observation = observation
        flight.updated_by = request.user
        flight.save(update_fields=["observation", "updated_by", "updated_at"])
        log_flight_change(flight, request.user, FlightChangeLog.ChangeType.OBSERVATION,
                          old_value=old, new_value=observation)
        log_action(request, AuditLog.Action.UPDATE, instance=flight,
                   description="Ajout d'une observation")
        return Response(FlightSerializer(flight).data)


@extend_schema_view(list=extend_schema(tags=["Favoris"]))
class FavoriteViewSet(viewsets.ModelViewSet):
    """Favoris du travailleur connecte (persistes en base)."""

    serializer_class = FavoriteSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ["favorite_type", "notifications_enabled"]
    ordering_fields = ["created_at"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Favorite.objects.none()
        return (
            Favorite.objects.filter(user=self.request.user)
            .select_related(
                "destination", "route_origin", "route_destination", "flight",
                "flight__origin", "flight__destination",
            )
        )

    def perform_create(self, serializer):
        try:
            favorite = serializer.save(user=self.request.user)
        except IntegrityError:
            raise ValidationError({"detail": "Ce favori existe deja."})
        log_action(self.request, AuditLog.Action.CREATE, instance=favorite,
                   description=f"Ajout du favori {favorite}")

    def perform_destroy(self, instance):
        log_action(self.request, AuditLog.Action.DELETE, instance=instance,
                   description=f"Suppression du favori {instance}")
        instance.delete()

    @extend_schema(tags=["Favoris"])
    @action(detail=True, methods=["post"])
    def toggle_notifications(self, request, pk=None):
        favorite = self.get_object()
        favorite.notifications_enabled = not favorite.notifications_enabled
        favorite.save(update_fields=["notifications_enabled", "updated_at"])
        return Response(FavoriteSerializer(favorite).data)


class FlightStatsView(APIView):
    """Statistiques sur les vols (administrateur / agent)."""

    permission_classes = [IsAgent]

    @extend_schema(tags=["Statistiques"], responses={200: OpenApiTypes.OBJECT})
    def get(self, request):
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")
        queryset = Flight.objects.filter(is_active=True)
        if date_from:
            queryset = queryset.filter(flight_date__gte=date_from)
        if date_to:
            queryset = queryset.filter(flight_date__lte=date_to)

        by_status = {
            row["status"]: row["total"]
            for row in queryset.values("status").annotate(total=Count("id"))
        }
        by_destination = list(
            queryset.values("destination__code", "destination__name")
            .annotate(total=Count("id"))
            .order_by("-total")
        )
        total = queryset.count()
        return Response(
            {
                "total_flights": total,
                "by_status": by_status,
                "scheduled": by_status.get(FlightStatus.SCHEDULED, 0),
                "delayed": by_status.get(FlightStatus.DELAYED, 0),
                "postponed": by_status.get(FlightStatus.POSTPONED, 0),
                "cancelled": by_status.get(FlightStatus.CANCELLED, 0),
                "by_destination": by_destination,
            }
        )
