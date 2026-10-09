"""API des notifications, des appareils (jetons FCM) et des annonces."""
import logging

from django.db.models import BooleanField, OuterRef, Q, Subquery
from django.utils import timezone
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.core.exceptions import error_response
from apps.core.models import AuditLog
from apps.core.permissions import IsAgent, IsAgentOrReadOnly
from apps.core.utils import log_action

from .models import (
    Announcement,
    FCMDevice,
    Notification,
    NotificationRecipient,
    TargetType,
)
from .serializers import (
    AnnouncementSerializer,
    FCMDeviceSerializer,
    NotificationCreateSerializer,
    NotificationRecipientSerializer,
    NotificationSerializer,
)
from .services import (
    create_notification,
    notify_announcement,
    send_push_to_users,
    visible_announcements_for,
)

logger = logging.getLogger("apps.notifications")


def _read_state_annotation(user):
    """Sous-requete renvoyant l'etat de lecture de la notification pour l'utilisateur."""
    return Subquery(
        NotificationRecipient.objects.filter(
            notification=OuterRef("pk"), user=user
        ).values("is_read")[:1],
        output_field=BooleanField(),
    )


@extend_schema_view(list=extend_schema(tags=["Notifications"]))
class NotificationInboxViewSet(viewsets.ReadOnlyModelViewSet):
    """Boite de reception des notifications du travailleur connecte."""

    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ["category"]
    search_fields = ["title", "message"]
    ordering_fields = ["created_at"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Notification.objects.none()
        user = self.request.user
        return (
            Notification.objects.filter(recipients__user=user)
            .select_related("flight", "flight__origin", "flight__destination")
            .annotate(is_read_state=_read_state_annotation(user))
        )

    @extend_schema(tags=["Notifications"])
    @action(detail=False, methods=["get"])
    def unread_count(self, request):
        count = NotificationRecipient.objects.filter(
            user=request.user, is_read=False
        ).count()
        return Response({"unread": count})

    @extend_schema(tags=["Notifications"])
    @action(detail=True, methods=["post"])
    def mark_read(self, request, pk=None):
        updated = NotificationRecipient.objects.filter(
            notification_id=pk, user=request.user
        ).update(is_read=True, read_at=timezone.now())
        if not updated:
            return error_response("Notification introuvable.", status.HTTP_404_NOT_FOUND)
        return Response({"detail": "Notification marquee comme lue."})

    @extend_schema(tags=["Notifications"])
    @action(detail=False, methods=["post"])
    def mark_all_read(self, request):
        updated = NotificationRecipient.objects.filter(
            user=request.user, is_read=False
        ).update(is_read=True, read_at=timezone.now())
        return Response({"updated": updated})


@extend_schema_view(list=extend_schema(tags=["Notifications"]))
class NotificationManageViewSet(viewsets.ModelViewSet):
    """Gestion et envoi de notifications (agent / administrateur)."""

    queryset = Notification.objects.select_related("created_by", "flight").all()
    permission_classes = [IsAgent]
    filterset_fields = ["category", "target_type", "is_urgent"]
    search_fields = ["title", "message"]
    ordering_fields = ["created_at"]

    def get_serializer_class(self):
        if self.action == "create":
            return NotificationCreateSerializer
        return NotificationSerializer

    def create(self, request, *args, **kwargs):
        serializer = NotificationCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        notification = create_notification(
            title=data["title"],
            message=data["message"],
            category=data["category"],
            target_type=data.get("target_type", TargetType.ALL_WORKERS),
            flight=data.get("flight"),
            destination=data.get("destination"),
            route_origin=data.get("route_origin"),
            route_destination=data.get("route_destination"),
            created_by=request.user,
            is_urgent=data.get("is_urgent", False),
            dedup_key=data.get("dedup_key", ""),
        )
        log_action(request, AuditLog.Action.NOTIFY, instance=notification,
                   description=f"Envoi de la notification '{notification.title}' "
                               f"a {notification.total_recipients} destinataire(s)")
        return Response(NotificationSerializer(notification).data, status=status.HTTP_201_CREATED)

    @extend_schema(tags=["Notifications"])
    @action(detail=True, methods=["get"])
    def recipients(self, request, pk=None):
        notification = self.get_object()
        recipients = notification.recipients.select_related("user").all()
        return Response(NotificationRecipientSerializer(recipients, many=True).data)

    @extend_schema(tags=["Notifications"], request=None)
    @action(detail=True, methods=["post"])
    def resend(self, request, pk=None):
        """Rejoue l'envoi push (utile en cas d'echec temporaire)."""
        notification = self.get_object()
        users = [r.user for r in notification.recipients.select_related("user").all()]
        success, failure = send_push_to_users(
            users,
            title=notification.title,
            body=notification.message,
            data={"category": notification.category, "notification_id": notification.pk},
        )
        Notification.objects.filter(pk=notification.pk).update(
            success_count=notification.success_count + success,
            failure_count=notification.failure_count + failure,
        )
        log_action(request, AuditLog.Action.NOTIFY, instance=notification,
                   description=f"Reenvoi: {success} succes / {failure} echec(s)")
        return Response({"success": success, "failure": failure})


@extend_schema_view(list=extend_schema(tags=["Appareils"]))
class FCMDeviceViewSet(viewsets.ModelViewSet):
    """Enregistrement et gestion des jetons FCM des appareils."""

    serializer_class = FCMDeviceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return FCMDevice.objects.none()
        return FCMDevice.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save()

    def perform_destroy(self, instance):
        instance.delete()

    @extend_schema(tags=["Appareils"], request=None)
    @action(detail=False, methods=["post"])
    def unregister(self, request):
        token = request.data.get("token")
        if not token:
            return error_response("Le jeton est obligatoire.")
        deleted, _ = FCMDevice.objects.filter(user=request.user, token=token).delete()
        return Response({"deleted": deleted})


@extend_schema_view(list=extend_schema(tags=["Annonces"]))
class AnnouncementViewSet(viewsets.ModelViewSet):
    """Annonces generales ou ciblees."""

    serializer_class = AnnouncementSerializer
    permission_classes = [IsAgentOrReadOnly]
    filterset_fields = ["category", "priority", "status", "target_type"]
    search_fields = ["title", "content"]
    ordering_fields = ["published_at", "created_at", "priority"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Announcement.objects.none()
        user = self.request.user
        queryset = Announcement.objects.select_related("author").all()
        if user.is_authenticated and (user.is_admin or user.is_agent):
            return queryset
        return visible_announcements_for(user)

    def perform_create(self, serializer):
        announcement = serializer.save(author=self.request.user)
        log_action(self.request, AuditLog.Action.CREATE, instance=announcement,
                   description=f"Creation de l'annonce '{announcement.title}'")

    def perform_update(self, serializer):
        announcement = serializer.save()
        log_action(self.request, AuditLog.Action.UPDATE, instance=announcement,
                   description=f"Modification de l'annonce '{announcement.title}'")

    def perform_destroy(self, instance):
        log_action(self.request, AuditLog.Action.DELETE, instance=instance,
                   description=f"Suppression de l'annonce '{instance.title}'")
        instance.delete()

    @extend_schema(tags=["Annonces"], request=None)
    @action(detail=True, methods=["post"])
    def publish(self, request, pk=None):
        announcement = self.get_object()
        announcement.status = Announcement.Status.PUBLISHED
        announcement.published_at = timezone.now()
        announcement.save(update_fields=["status", "published_at", "updated_at"])
        log_action(request, AuditLog.Action.PUBLISH, instance=announcement,
                   description=f"Publication de l'annonce '{announcement.title}'")
        if announcement.send_push:
            notify_announcement(announcement)
        return Response(AnnouncementSerializer(announcement).data)

    @extend_schema(tags=["Annonces"], request=None)
    @action(detail=True, methods=["post"])
    def unpublish(self, request, pk=None):
        announcement = self.get_object()
        announcement.status = Announcement.Status.DRAFT
        announcement.save(update_fields=["status", "updated_at"])
        log_action(request, AuditLog.Action.UPDATE, instance=announcement,
                   description=f"Annonce repassee en brouillon '{announcement.title}'")
        return Response(AnnouncementSerializer(announcement).data)
