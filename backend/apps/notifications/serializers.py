from rest_framework import serializers

from apps.flights.models import Destination, Flight

from .models import (
    Announcement,
    FCMDevice,
    Notification,
    NotificationRecipient,
    TargetType,
)


class FCMDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = FCMDevice
        fields = ("id", "token", "platform", "device_id", "is_active", "last_used_at")
        read_only_fields = ("id", "last_used_at")

    def create(self, validated_data):
        user = self.context["request"].user
        token = validated_data["token"]
        device, _ = FCMDevice.objects.update_or_create(
            token=token,
            defaults={
                "user": user,
                "platform": validated_data.get("platform", FCMDevice.Platform.ANDROID),
                "device_id": validated_data.get("device_id", ""),
                "is_active": True,
            },
        )
        return device


class NotificationRecipientSerializer(serializers.ModelSerializer):
    user_email = serializers.EmailField(source="user.email", read_only=True)

    class Meta:
        model = NotificationRecipient
        fields = ("id", "user", "user_email", "is_read", "read_at", "delivered", "created_at")
        read_only_fields = fields


class NotificationSerializer(serializers.ModelSerializer):
    category_label = serializers.CharField(source="get_category_display", read_only=True)
    is_read = serializers.SerializerMethodField()
    flight_route = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = (
            "id",
            "title",
            "message",
            "category",
            "category_label",
            "flight",
            "flight_route",
            "is_urgent",
            "is_read",
            "sent_at",
            "created_at",
        )
        read_only_fields = fields

    def get_is_read(self, obj: Notification) -> bool:
        return bool(getattr(obj, "is_read_state", False))

    def get_flight_route(self, obj: Notification) -> str:
        if obj.flight_id and obj.flight:
            return f"{obj.flight.origin.code} -> {obj.flight.destination.code}"
        return ""


class NotificationCreateSerializer(serializers.Serializer):
    """Creation manuelle d'une notification ciblee (agent / administrateur)."""

    title = serializers.CharField(max_length=180)
    message = serializers.CharField()
    category = serializers.ChoiceField(choices=Notification.category.field.choices)
    target_type = serializers.ChoiceField(
        choices=TargetType.choices, default=TargetType.ALL_WORKERS
    )
    destination = serializers.PrimaryKeyRelatedField(
        queryset=Destination.objects.all(), required=False, allow_null=True
    )
    route_origin = serializers.PrimaryKeyRelatedField(
        queryset=Destination.objects.all(), required=False, allow_null=True
    )
    route_destination = serializers.PrimaryKeyRelatedField(
        queryset=Destination.objects.all(), required=False, allow_null=True
    )
    flight = serializers.PrimaryKeyRelatedField(
        queryset=Flight.objects.all(), required=False, allow_null=True
    )
    is_urgent = serializers.BooleanField(required=False, default=False)
    dedup_key = serializers.CharField(required=False, allow_blank=True, max_length=128)

    def validate(self, attrs):
        target_type = attrs.get("target_type")
        if target_type == TargetType.DESTINATION and not attrs.get("destination"):
            raise serializers.ValidationError(
                {"destination": "Une destination est requise pour ce ciblage."}
            )
        if target_type == TargetType.ROUTE and not (
            attrs.get("route_origin") and attrs.get("route_destination")
        ):
            raise serializers.ValidationError(
                {"route_origin": "Le trajet depart/arrivee est requis pour ce ciblage."}
            )
        if target_type == TargetType.FLIGHT and not attrs.get("flight"):
            raise serializers.ValidationError(
                {"flight": "Un vol est requis pour ce ciblage."}
            )
        return attrs


class AnnouncementSerializer(serializers.ModelSerializer):
    author_email = serializers.EmailField(source="author.email", read_only=True, default="")
    category_label = serializers.CharField(source="get_category_display", read_only=True)
    priority_label = serializers.CharField(source="get_priority_display", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)

    class Meta:
        model = Announcement
        fields = (
            "id",
            "title",
            "content",
            "category",
            "category_label",
            "priority",
            "priority_label",
            "author",
            "author_email",
            "published_at",
            "expires_at",
            "target_type",
            "target_destination",
            "target_route_origin",
            "target_route_destination",
            "status",
            "status_label",
            "send_push",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "author", "published_at", "created_at", "updated_at")

    def validate(self, attrs):
        expires_at = attrs.get("expires_at", getattr(self.instance, "expires_at", None))
        published_at = attrs.get("published_at", getattr(self.instance, "published_at", None))
        if expires_at and published_at and expires_at <= published_at:
            raise serializers.ValidationError(
                {"expires_at": "La date d'expiration doit etre posterieure a la publication."}
            )
        return attrs
