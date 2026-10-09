from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models

from apps.core.models import TimeStampedModel

from .constants import DayOfWeek, FlightStatus


class Destination(TimeStampedModel):
    """Ville / aeroport desservi."""

    code = models.CharField("Code", max_length=8, unique=True)
    name = models.CharField("Nom", max_length=128)
    city = models.CharField("Ville", max_length=128, blank=True)
    airport_name = models.CharField("Aeroport", max_length=160, blank=True)
    country = models.CharField("Pays", max_length=64, default="Algerie")
    is_active = models.BooleanField("Actif", default=True)

    class Meta:
        verbose_name = "Destination"
        verbose_name_plural = "Destinations"
        ordering = ["code"]
        indexes = [models.Index(fields=["is_active"])]

    def __str__(self) -> str:
        return f"{self.code} - {self.name}"

    def save(self, *args, **kwargs):
        self.code = self.code.upper().strip()
        super().save(*args, **kwargs)


class WeeklySchedule(TimeStampedModel):
    """Programme hebdomadaire habituel (recurrent, sans date precise)."""

    day_of_week = models.IntegerField("Jour de la semaine", choices=DayOfWeek.choices)
    origin = models.ForeignKey(
        Destination,
        on_delete=models.PROTECT,
        related_name="weekly_departures",
        verbose_name="Depart",
    )
    destination = models.ForeignKey(
        Destination,
        on_delete=models.PROTECT,
        related_name="weekly_arrivals",
        verbose_name="Destination",
    )
    flight_code = models.CharField("Code du vol", max_length=16, blank=True)
    registration_time = models.TimeField("Heure d'enregistrement")
    departure_time = models.TimeField("Heure de decollage")
    arrival_time = models.TimeField("Heure d'arrivee", null=True, blank=True)
    is_active = models.BooleanField("Actif", default=True)

    class Meta:
        verbose_name = "Programme hebdomadaire"
        verbose_name_plural = "Programmes hebdomadaires"
        ordering = ["day_of_week", "departure_time"]
        constraints = [
            models.UniqueConstraint(
                fields=["day_of_week", "origin", "destination", "departure_time"],
                name="uniq_weekly_slot",
            ),
            models.CheckConstraint(
                condition=~models.Q(origin=models.F("destination")),
                name="weekly_origin_diff_destination",
            ),
        ]
        indexes = [
            models.Index(fields=["day_of_week", "is_active"]),
        ]

    def __str__(self) -> str:
        return (
            f"{self.get_day_of_week_display()} {self.origin.code}->"
            f"{self.destination.code} {self.departure_time:%H:%M}"
        )

    def clean(self):
        if self.origin_id and self.destination_id and self.origin_id == self.destination_id:
            raise ValidationError("Le depart et la destination doivent etre differents.")
        if (
            self.arrival_time
            and self.departure_time
            and self.arrival_time < self.departure_time
        ):
            raise ValidationError(
                "L'heure d'arrivee ne peut pas etre anterieure a l'heure de decollage."
            )


class Flight(TimeStampedModel):
    """Vol associe a une date precise."""

    schedule = models.ForeignKey(
        WeeklySchedule,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="flights",
        verbose_name="Programme d'origine",
    )
    flight_date = models.DateField("Date du vol")
    day_of_week = models.IntegerField(
        "Jour de la semaine", choices=DayOfWeek.choices, editable=False
    )
    origin = models.ForeignKey(
        Destination,
        on_delete=models.PROTECT,
        related_name="departures",
        verbose_name="Depart",
    )
    destination = models.ForeignKey(
        Destination,
        on_delete=models.PROTECT,
        related_name="arrivals",
        verbose_name="Destination",
    )
    flight_code = models.CharField("Code du vol", max_length=16, blank=True)
    registration_time = models.TimeField("Heure d'enregistrement")
    departure_time = models.TimeField("Heure de decollage")
    arrival_time = models.TimeField("Heure d'arrivee", null=True, blank=True)

    # Horaires precedents (conserves pour tracabilite en cas de modification).
    previous_registration_time = models.TimeField(
        "Ancienne heure d'enregistrement", null=True, blank=True
    )
    previous_departure_time = models.TimeField(
        "Ancienne heure de decollage", null=True, blank=True
    )
    previous_arrival_time = models.TimeField(
        "Ancienne heure d'arrivee", null=True, blank=True
    )

    status = models.CharField(
        "Statut", max_length=16, choices=FlightStatus.choices, default=FlightStatus.SCHEDULED
    )
    observation = models.TextField("Observation", blank=True)
    is_exceptional = models.BooleanField(
        "Vol exceptionnel", default=False,
        help_text="Vol ajoute pour une date precise, hors programme habituel.",
    )
    is_active = models.BooleanField("Actif", default=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="flights_created",
        verbose_name="Cree par",
    )
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="flights_updated",
        verbose_name="Modifie par",
    )

    class Meta:
        verbose_name = "Vol"
        verbose_name_plural = "Vols"
        ordering = ["flight_date", "departure_time"]
        constraints = [
            models.UniqueConstraint(
                fields=["flight_date", "origin", "destination", "departure_time"],
                name="uniq_flight_slot",
            ),
            models.CheckConstraint(
                condition=~models.Q(origin=models.F("destination")),
                name="flight_origin_diff_destination",
            ),
        ]
        indexes = [
            models.Index(fields=["flight_date", "status"]),
            models.Index(fields=["origin", "destination"]),
            models.Index(fields=["-updated_at"]),
        ]

    def __str__(self) -> str:
        return (
            f"{self.flight_code or 'VOL'} {self.origin.code}->{self.destination.code} "
            f"le {self.flight_date:%d/%m/%Y} {self.departure_time:%H:%M}"
        )

    def save(self, *args, **kwargs):
        # Le jour de la semaine est toujours deduit de la date reelle,
        # ce qui evite toute incoherence entre le jour et la date.
        if self.flight_date:
            self.day_of_week = self.flight_date.weekday()
        super().save(*args, **kwargs)

    def clean(self):
        errors = {}
        if self.origin_id and self.destination_id and self.origin_id == self.destination_id:
            errors["destination"] = "Le depart et la destination doivent etre differents."
        if (
            self.arrival_time
            and self.departure_time
            and self.arrival_time < self.departure_time
        ):
            errors["arrival_time"] = (
                "L'heure d'arrivee ne peut pas etre anterieure a l'heure de decollage."
            )
        if (
            self.registration_time
            and self.departure_time
            and self.registration_time > self.departure_time
        ):
            errors["registration_time"] = (
                "L'heure d'enregistrement ne peut pas etre posterieure au decollage."
            )
        if errors:
            raise ValidationError(errors)

    @property
    def previous_departure_label(self) -> str:
        if self.previous_departure_time:
            return self.previous_departure_time.strftime("%H:%M")
        return ""


class FlightChangeLog(models.Model):
    """Historique des modifications d'un vol (tracabilite obligatoire)."""

    class ChangeType(models.TextChoices):
        CREATED = "created", "Creation"
        TIME_CHANGED = "time_changed", "Modification d'horaire"
        STATUS_CHANGED = "status_changed", "Changement de statut"
        DELAYED = "delayed", "Retard"
        POSTPONED = "postponed", "Report"
        CANCELLED = "cancelled", "Annulation"
        OBSERVATION = "observation", "Observation"
        UPDATED = "updated", "Mise a jour"

    flight = models.ForeignKey(
        Flight, on_delete=models.CASCADE, related_name="change_logs", verbose_name="Vol"
    )
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="flight_changes",
        verbose_name="Auteur",
    )
    change_type = models.CharField("Type", max_length=16, choices=ChangeType.choices)
    field_name = models.CharField("Champ", max_length=64, blank=True)
    old_value = models.CharField("Ancienne valeur", max_length=255, blank=True)
    new_value = models.CharField("Nouvelle valeur", max_length=255, blank=True)
    note = models.TextField("Note", blank=True)
    created_at = models.DateTimeField("Date", auto_now_add=True)

    class Meta:
        verbose_name = "Historique de vol"
        verbose_name_plural = "Historique des vols"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["flight", "-created_at"]),
            models.Index(fields=["change_type"]),
        ]

    def __str__(self) -> str:
        return f"{self.get_change_type_display()} - {self.flight_id}"


class Favorite(TimeStampedModel):
    """Favori d'un travailleur : destination, trajet ou vol date."""

    class FavoriteType(models.TextChoices):
        DESTINATION = "destination", "Destination"
        ROUTE = "route", "Trajet"
        FLIGHT = "flight", "Vol date"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="favorites",
        verbose_name="Utilisateur",
    )
    favorite_type = models.CharField("Type", max_length=16, choices=FavoriteType.choices)
    destination = models.ForeignKey(
        Destination,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="favorited_by",
        verbose_name="Destination",
    )
    route_origin = models.ForeignKey(
        Destination,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="favorite_routes_from",
        verbose_name="Depart du trajet",
    )
    route_destination = models.ForeignKey(
        Destination,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="favorite_routes_to",
        verbose_name="Arrivee du trajet",
    )
    flight = models.ForeignKey(
        Flight,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="favorited_by",
        verbose_name="Vol",
    )
    notifications_enabled = models.BooleanField("Notifications actives", default=True)

    class Meta:
        verbose_name = "Favori"
        verbose_name_plural = "Favoris"
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "destination"],
                condition=models.Q(favorite_type="destination"),
                name="uniq_favorite_destination",
            ),
            models.UniqueConstraint(
                fields=["user", "route_origin", "route_destination"],
                condition=models.Q(favorite_type="route"),
                name="uniq_favorite_route",
            ),
            models.UniqueConstraint(
                fields=["user", "flight"],
                condition=models.Q(favorite_type="flight"),
                name="uniq_favorite_flight",
            ),
        ]
        indexes = [models.Index(fields=["user", "favorite_type"])]

    def __str__(self) -> str:
        return f"{self.user_id} - {self.favorite_type}"

    def clean(self):
        if self.favorite_type == self.FavoriteType.DESTINATION and not self.destination_id:
            raise ValidationError({"destination": "Une destination est requise."})
        if self.favorite_type == self.FavoriteType.ROUTE and not (
            self.route_origin_id and self.route_destination_id
        ):
            raise ValidationError({"route_origin": "Le trajet depart/arrivee est requis."})
        if self.favorite_type == self.FavoriteType.FLIGHT and not self.flight_id:
            raise ValidationError({"flight": "Un vol est requis."})
