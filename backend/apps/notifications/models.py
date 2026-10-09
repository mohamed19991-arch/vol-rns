from django.conf import settings
from django.db import models

from apps.core.models import TimeStampedModel


class TargetType(models.TextChoices):
    ALL_WORKERS = "all_workers", "Tous les travailleurs"
    DESTINATION = "destination", "Interesses par une destination"
    ROUTE = "route", "Interesses par un trajet"
    FLIGHT = "flight", "Concernes par un vol precis"
    USER = "user", "Utilisateur precis"
    ROLE = "role", "Par role"


class NotificationCategory(models.TextChoices):
    NEW_FLIGHT = "new_flight", "Nouveau vol publie"
    REGISTRATION_TIME_CHANGED = "registration_time_changed", "Modification de l'enregistrement"
    DEPARTURE_TIME_CHANGED = "departure_time_changed", "Modification du decollage"
    DELAY = "delay", "Retard"
    POSTPONE = "postpone", "Report"
    CANCELLATION = "cancellation", "Annulation"
    BOARDING = "boarding", "Embarquement en cours"
    ARRIVAL = "arrival", "Information d'arrivee"
    ANNOUNCEMENT = "announcement", "Annonce administrative"
    URGENT = "urgent", "Information urgente"
    SCHEDULE_CHANGE = "schedule_change", "Changement de programme"


class FCMDevice(TimeStampedModel):
    """Jeton FCM d'un appareil (gestion des renouvellements et jetons invalides)."""

    class Platform(models.TextChoices):
        ANDROID = "android", "Android"
        IOS = "ios", "iOS"
        WEB = "web", "Web"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="devices",
        verbose_name="Utilisateur",
    )
    token = models.CharField("Jeton FCM", max_length=255, unique=True)
    platform = models.CharField(
        "Plateforme", max_length=16, choices=Platform.choices, default=Platform.ANDROID
    )
    device_id = models.CharField("Identifiant appareil", max_length=128, blank=True)
    is_active = models.BooleanField("Actif", default=True)
    last_used_at = models.DateTimeField("Derniere utilisation", auto_now=True)

    class Meta:
        verbose_name = "Appareil (jeton FCM)"
        verbose_name_plural = "Appareils (jetons FCM)"
        ordering = ["-last_used_at"]
        indexes = [
            models.Index(fields=["user", "is_active"]),
        ]

    def __str__(self) -> str:
        return f"{self.user_id} - {self.platform} - {self.token[:12]}..."


class Notification(TimeStampedModel):
    """Notification enregistree en base AVANT sa distribution push."""

    title = models.CharField("Titre", max_length=180)
    message = models.TextField("Message")
    category = models.CharField(
        "Categorie", max_length=40, choices=NotificationCategory.choices
    )
    flight = models.ForeignKey(
        "flights.Flight",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="notifications",
        verbose_name="Vol associe",
    )
    announcement = models.ForeignKey(
        "notifications.Announcement",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="notifications",
        verbose_name="Annonce associee",
    )
    target_type = models.CharField(
        "Cible", max_length=16, choices=TargetType.choices, default=TargetType.ALL_WORKERS
    )
    target_destination = models.ForeignKey(
        "flights.Destination",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="notifications",
        verbose_name="Destination ciblee",
    )
    target_route_origin = models.ForeignKey(
        "flights.Destination",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="notifications_route_from",
        verbose_name="Depart du trajet cible",
    )
    target_route_destination = models.ForeignKey(
        "flights.Destination",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="notifications_route_to",
        verbose_name="Arrivee du trajet cible",
    )
    target_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="targeted_notifications",
        verbose_name="Utilisateur cible",
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="notifications_created",
        verbose_name="Emetteur",
    )
    # Cle de deduplication pour eviter les envois multiples.
    dedup_key = models.CharField("Cle anti-doublon", max_length=128, blank=True, db_index=True)
    total_recipients = models.PositiveIntegerField("Destinataires", default=0)
    success_count = models.PositiveIntegerField("Envois reussis", default=0)
    failure_count = models.PositiveIntegerField("Envois echoues", default=0)
    is_urgent = models.BooleanField("Urgente", default=False)
    sent_at = models.DateTimeField("Envoyee le", null=True, blank=True)

    class Meta:
        verbose_name = "Notification"
        verbose_name_plural = "Notifications"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["-created_at"]),
            models.Index(fields=["category"]),
            models.Index(fields=["flight"]),
        ]

    def __str__(self) -> str:
        return self.title


class NotificationRecipient(models.Model):
    """Etat de lecture d'une notification pour un destinataire donne."""

    notification = models.ForeignKey(
        Notification,
        on_delete=models.CASCADE,
        related_name="recipients",
        verbose_name="Notification",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notification_states",
        verbose_name="Utilisateur",
    )
    is_read = models.BooleanField("Lue", default=False)
    read_at = models.DateTimeField("Lue le", null=True, blank=True)
    delivered = models.BooleanField("Distribuee", default=False)
    created_at = models.DateTimeField("Recue le", auto_now_add=True)

    class Meta:
        verbose_name = "Destinataire de notification"
        verbose_name_plural = "Destinataires de notification"
        constraints = [
            models.UniqueConstraint(
                fields=["notification", "user"], name="uniq_notification_recipient"
            )
        ]
        indexes = [
            models.Index(fields=["user", "is_read"]),
            models.Index(fields=["-created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.notification_id} -> {self.user_id}"


class Announcement(TimeStampedModel):
    """Annonce administrative generale ou ciblee."""

    class Category(models.TextChoices):
        GENERAL = "general", "General"
        OPERATION = "operation", "Operationnel"
        MAINTENANCE = "maintenance", "Maintenance"
        SECURITY = "security", "Securite"
        HR = "hr", "Ressources humaines"
        OTHER = "other", "Autre"

    class Priority(models.TextChoices):
        LOW = "low", "Basse"
        NORMAL = "normal", "Normale"
        HIGH = "high", "Haute"
        URGENT = "urgent", "Urgente"

    class Status(models.TextChoices):
        DRAFT = "draft", "Brouillon"
        PUBLISHED = "published", "Publiee"

    title = models.CharField("Titre", max_length=200)
    content = models.TextField("Contenu")
    category = models.CharField(
        "Categorie", max_length=16, choices=Category.choices, default=Category.GENERAL
    )
    priority = models.CharField(
        "Priorite", max_length=16, choices=Priority.choices, default=Priority.NORMAL
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="announcements",
        verbose_name="Auteur",
    )
    published_at = models.DateTimeField("Publiee le", null=True, blank=True)
    expires_at = models.DateTimeField("Expire le", null=True, blank=True)
    target_type = models.CharField(
        "Public cible", max_length=16, choices=TargetType.choices, default=TargetType.ALL_WORKERS
    )
    target_destination = models.ForeignKey(
        "flights.Destination",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="announcements",
        verbose_name="Destination ciblee",
    )
    target_route_origin = models.ForeignKey(
        "flights.Destination",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="announcements_route_from",
        verbose_name="Depart du trajet cible",
    )
    target_route_destination = models.ForeignKey(
        "flights.Destination",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="announcements_route_to",
        verbose_name="Arrivee du trajet cible",
    )
    status = models.CharField(
        "Statut", max_length=16, choices=Status.choices, default=Status.DRAFT
    )
    send_push = models.BooleanField(
        "Declencher une notification push", default=False
    )

    class Meta:
        verbose_name = "Annonce"
        verbose_name_plural = "Annonces"
        ordering = ["-published_at", "-created_at"]
        indexes = [
            models.Index(fields=["status", "-published_at"]),
            models.Index(fields=["priority"]),
        ]

    def __str__(self) -> str:
        return self.title

    @property
    def is_expired(self) -> bool:
        from django.utils import timezone

        return bool(self.expires_at and self.expires_at < timezone.now())

    @property
    def is_visible(self) -> bool:
        return self.status == self.Status.PUBLISHED and not self.is_expired
