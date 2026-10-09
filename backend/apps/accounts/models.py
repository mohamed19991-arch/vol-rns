from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from django.utils import timezone

from apps.core.models import TimeStampedModel

from .managers import UserManager


class User(AbstractBaseUser, PermissionsMixin):
    """Utilisateur de l'application (travailleur, agent ou administrateur)."""

    class Role(models.TextChoices):
        ADMIN = "admin", "Administrateur"
        AGENT = "agent", "Agent du bureau de voyage"
        WORKER = "worker", "Travailleur"

    email = models.EmailField("Adresse e-mail", unique=True)
    first_name = models.CharField("Prenom", max_length=150, blank=True)
    last_name = models.CharField("Nom", max_length=150, blank=True)
    phone = models.CharField("Telephone", max_length=32, blank=True)
    role = models.CharField(
        "Role", max_length=16, choices=Role.choices, default=Role.WORKER
    )
    is_active = models.BooleanField("Actif", default=True)
    is_staff = models.BooleanField("Acces admin Django", default=False)
    date_joined = models.DateTimeField("Inscription", default=timezone.now)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    class Meta:
        verbose_name = "Utilisateur"
        verbose_name_plural = "Utilisateurs"
        ordering = ["last_name", "first_name", "email"]
        indexes = [
            models.Index(fields=["role"]),
            models.Index(fields=["is_active"]),
        ]

    def __str__(self) -> str:
        return self.email

    def save(self, *args, **kwargs):
        self.email = self.email.lower().strip()
        super().save(*args, **kwargs)

    @property
    def full_name(self) -> str:
        name = f"{self.first_name} {self.last_name}".strip()
        return name or self.email

    @property
    def is_admin(self) -> bool:
        return self.is_superuser or self.role == self.Role.ADMIN

    @property
    def is_agent(self) -> bool:
        return self.role == self.Role.AGENT

    @property
    def is_worker(self) -> bool:
        return self.role == self.Role.WORKER


class Profile(TimeStampedModel):
    """Profil et preferences de l'utilisateur."""

    class Language(models.TextChoices):
        FR = "fr", "Francais"
        AR = "ar", "Arabe"
        EN = "en", "Anglais"

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="profile", verbose_name="Utilisateur"
    )
    matricule = models.CharField("Matricule", max_length=32, blank=True)
    position = models.CharField("Poste", max_length=128, blank=True)
    language = models.CharField(
        "Langue", max_length=5, choices=Language.choices, default=Language.FR
    )
    phone = models.CharField("Telephone de contact", max_length=32, blank=True)
    receive_push = models.BooleanField("Recevoir les notifications push", default=True)
    receive_email = models.BooleanField("Recevoir les e-mails", default=False)

    class Meta:
        verbose_name = "Profil"
        verbose_name_plural = "Profils"

    def __str__(self) -> str:
        return f"Profil de {self.user.email}"
