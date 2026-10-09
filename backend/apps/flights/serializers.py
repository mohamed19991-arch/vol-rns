from rest_framework import serializers

from .constants import DayOfWeek, FlightStatus
from .models import Destination, Favorite, Flight, FlightChangeLog, WeeklySchedule


class DestinationBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Destination
        fields = ("id", "code", "name", "city")


class DestinationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Destination
        fields = (
            "id",
            "code",
            "name",
            "city",
            "airport_name",
            "country",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def validate_code(self, value):
        return value.upper().strip()


class WeeklyScheduleSerializer(serializers.ModelSerializer):
    origin_detail = DestinationBriefSerializer(source="origin", read_only=True)
    destination_detail = DestinationBriefSerializer(source="destination", read_only=True)
    day_label = serializers.CharField(source="get_day_of_week_display", read_only=True)

    class Meta:
        model = WeeklySchedule
        fields = (
            "id",
            "day_of_week",
            "day_label",
            "origin",
            "destination",
            "origin_detail",
            "destination_detail",
            "flight_code",
            "registration_time",
            "departure_time",
            "arrival_time",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def validate(self, attrs):
        instance = WeeklySchedule(
            day_of_week=attrs.get("day_of_week", getattr(self.instance, "day_of_week", None)),
            origin=attrs.get("origin", getattr(self.instance, "origin", None)),
            destination=attrs.get("destination", getattr(self.instance, "destination", None)),
            registration_time=attrs.get(
                "registration_time", getattr(self.instance, "registration_time", None)
            ),
            departure_time=attrs.get(
                "departure_time", getattr(self.instance, "departure_time", None)
            ),
            arrival_time=attrs.get("arrival_time", getattr(self.instance, "arrival_time", None)),
        )
        instance.clean()
        return attrs


class FlightSerializer(serializers.ModelSerializer):
    origin_detail = DestinationBriefSerializer(source="origin", read_only=True)
    destination_detail = DestinationBriefSerializer(source="destination", read_only=True)
    day_label = serializers.CharField(source="get_day_of_week_display", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    updated_by_email = serializers.EmailField(source="updated_by.email", read_only=True, default="")
    created_by_email = serializers.EmailField(
        source="created_by.email", read_only=True, default=""
    )
    previous_departure_time_display = serializers.CharField(
        source="previous_departure_label", read_only=True
    )
    route = serializers.SerializerMethodField()

    class Meta:
        model = Flight
        fields = (
            "id",
            "schedule",
            "flight_date",
            "day_of_week",
            "day_label",
            "origin",
            "destination",
            "origin_detail",
            "destination_detail",
            "route",
            "flight_code",
            "registration_time",
            "departure_time",
            "arrival_time",
            "previous_registration_time",
            "previous_departure_time",
            "previous_arrival_time",
            "previous_departure_time_display",
            "status",
            "status_label",
            "observation",
            "is_exceptional",
            "is_active",
            "created_by",
            "created_by_email",
            "updated_by",
            "updated_by_email",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "day_of_week",
            "previous_registration_time",
            "previous_departure_time",
            "previous_arrival_time",
            "created_by",
            "updated_by",
            "created_at",
            "updated_at",
        )

    def get_route(self, obj: Flight) -> str:
        return f"{obj.origin.code} -> {obj.destination.code}"

    def validate(self, attrs):
        instance = self.instance
        candidate = Flight(
            flight_date=attrs.get("flight_date", getattr(instance, "flight_date", None)),
            origin=attrs.get("origin", getattr(instance, "origin", None)),
            destination=attrs.get("destination", getattr(instance, "destination", None)),
            registration_time=attrs.get(
                "registration_time", getattr(instance, "registration_time", None)
            ),
            departure_time=attrs.get(
                "departure_time", getattr(instance, "departure_time", None)
            ),
            arrival_time=attrs.get("arrival_time", getattr(instance, "arrival_time", None)),
        )
        if candidate.flight_date is None:
            raise serializers.ValidationError({"flight_date": "La date du vol est obligatoire."})
        candidate.clean()
        return attrs


class FlightListSerializer(serializers.ModelSerializer):
    origin_detail = DestinationBriefSerializer(source="origin", read_only=True)
    destination_detail = DestinationBriefSerializer(source="destination", read_only=True)
    day_label = serializers.CharField(source="get_day_of_week_display", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    route = serializers.SerializerMethodField()

    class Meta:
        model = Flight
        fields = (
            "id",
            "flight_date",
            "day_of_week",
            "day_label",
            "origin_detail",
            "destination_detail",
            "route",
            "flight_code",
            "registration_time",
            "departure_time",
            "arrival_time",
            "status",
            "status_label",
            "observation",
            "is_exceptional",
        )

    def get_route(self, obj: Flight) -> str:
        return f"{obj.origin.code} -> {obj.destination.code}"


class FlightChangeLogSerializer(serializers.ModelSerializer):
    changed_by_email = serializers.EmailField(
        source="changed_by.email", read_only=True, default=""
    )
    change_type_label = serializers.CharField(source="get_change_type_display", read_only=True)

    class Meta:
        model = FlightChangeLog
        fields = (
            "id",
            "flight",
            "changed_by",
            "changed_by_email",
            "change_type",
            "change_type_label",
            "field_name",
            "old_value",
            "new_value",
            "note",
            "created_at",
        )
        read_only_fields = fields


class FavoriteSerializer(serializers.ModelSerializer):
    destination_detail = DestinationBriefSerializer(source="destination", read_only=True)
    route_origin_detail = DestinationBriefSerializer(source="route_origin", read_only=True)
    route_destination_detail = DestinationBriefSerializer(
        source="route_destination", read_only=True
    )
    flight_detail = FlightListSerializer(source="flight", read_only=True)
    label = serializers.SerializerMethodField()

    class Meta:
        model = Favorite
        fields = (
            "id",
            "favorite_type",
            "destination",
            "destination_detail",
            "route_origin",
            "route_destination",
            "route_origin_detail",
            "route_destination_detail",
            "flight",
            "flight_detail",
            "notifications_enabled",
            "label",
            "created_at",
        )
        read_only_fields = ("id", "created_at")

    def get_label(self, obj: Favorite) -> str:
        if obj.favorite_type == Favorite.FavoriteType.DESTINATION and obj.destination:
            return obj.destination.code
        if obj.favorite_type == Favorite.FavoriteType.ROUTE and obj.route_origin and obj.route_destination:
            return f"{obj.route_origin.code} -> {obj.route_destination.code}"
        if obj.favorite_type == Favorite.FavoriteType.FLIGHT and obj.flight:
            return f"{obj.flight.origin.code} -> {obj.flight.destination.code} " \
                   f"({obj.flight.flight_date:%d/%m/%Y})"
        return ""

    def validate(self, attrs):
        instance = Favorite(
            favorite_type=attrs.get("favorite_type", getattr(self.instance, "favorite_type", None)),
            destination=attrs.get("destination", getattr(self.instance, "destination", None)),
            route_origin=attrs.get("route_origin", getattr(self.instance, "route_origin", None)),
            route_destination=attrs.get(
                "route_destination", getattr(self.instance, "route_destination", None)
            ),
            flight=attrs.get("flight", getattr(self.instance, "flight", None)),
        )
        instance.clean()
        return attrs


class StatusChangeSerializer(serializers.Serializer):
    """Entree pour les actions metier (retard, report, annulation...)."""

    status = serializers.ChoiceField(choices=FlightStatus.choices)
    observation = serializers.CharField(required=False, allow_blank=True)
    new_departure_time = serializers.TimeField(required=False)
    new_registration_time = serializers.TimeField(required=False)
    new_arrival_time = serializers.TimeField(required=False)
    new_flight_date = serializers.DateField(required=False)

    def validate(self, attrs):
        needs_time = attrs["status"] in {
            FlightStatus.DELAYED,
            FlightStatus.POSTPONED,
            FlightStatus.RESCHEDULED,
        }
        has_time = any(
            attrs.get(k)
            for k in ("new_departure_time", "new_registration_time", "new_arrival_time")
        )
        if needs_time and not has_time and attrs["status"] != FlightStatus.POSTPONED:
            raise serializers.ValidationError(
                {"new_departure_time": "Un nouvel horaire est requis pour ce statut."}
            )
        return attrs


class DayScheduleSerializer(serializers.Serializer):
    """Sortie du programme hebdomadaire groupe par jour."""

    day_of_week = serializers.IntegerField()
    day_label = serializers.CharField()
    flights = WeeklyScheduleSerializer(many=True)


DAY_LABELS = dict(DayOfWeek.choices)
