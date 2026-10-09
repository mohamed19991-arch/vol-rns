from django.conf import settings
from django.db import models


class TimeStampedModel(models.Model):
    """Modele abstrait ajoutant les horodatages de creation et modification."""

    created_at = models.DateTimeField("Cree le", auto_now_add=True)
    updated_at = models.DateTimeField("Modifie le", auto_now=True)

    class Meta:
        abstract = True


class AuditLog(models.Model):
    """Historique des actions sensibles / administratives."""

    class Action(models.TextChoices):
        CREATE = "create", "Creation"
        UPDATE = "update", "Modification"
        DELETE = "delete", "Suppression"
        LOGIN = "login", "Connexion"
        LOGIN_FAILED = "login_failed", "Echec de connexion"
        LOGOUT = "logout", "Deconnexion"
        PUBLISH = "publish", "Publication"
        NOTIFY = "notify", "Notification"
        PERMISSION = "permission", "Changement d'autorisations"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="audit_logs",
        verbose_name="Utilisateur",
    )
    action = models.CharField("Action", max_length=32, choices=Action.choices)
    entity_type = models.CharField("Type d'entite", max_length=64, blank=True)
    entity_id = models.CharField("Identifiant entite", max_length=64, blank=True)
    description = models.TextField("Description", blank=True)
    metadata = models.JSONField("Metadonnees", default=dict, blank=True)
    ip_address = models.GenericIPAddressField("Adresse IP", null=True, blank=True)
    created_at = models.DateTimeField("Date", auto_now_add=True)

    class Meta:
        verbose_name = "Journal d'audit"
        verbose_name_plural = "Journal d'audit"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["-created_at"]),
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["action"]),
        ]

    def __str__(self) -> str:
        return f"{self.get_action_display()} - {self.entity_type}#{self.entity_id}"
