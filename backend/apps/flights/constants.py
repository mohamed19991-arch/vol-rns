"""Constantes metier des vols (jours, statuts).

Le numerotage des jours suit la convention Python ``date.weekday()``
(lundi = 0 ... dimanche = 6) afin de faciliter les calculs de dates.
"""
from django.db import models


class DayOfWeek(models.IntegerChoices):
    MONDAY = 0, "Lundi"
    TUESDAY = 1, "Mardi"
    WEDNESDAY = 2, "Mercredi"
    THURSDAY = 3, "Jeudi"
    FRIDAY = 4, "Vendredi"
    SATURDAY = 5, "Samedi"
    SUNDAY = 6, "Dimanche"


# Ordre d'affichage de la semaine tel que souhaite par le metier
# (la semaine commence le samedi).
WEEK_DISPLAY_ORDER = [
    DayOfWeek.SATURDAY,
    DayOfWeek.SUNDAY,
    DayOfWeek.MONDAY,
    DayOfWeek.TUESDAY,
    DayOfWeek.WEDNESDAY,
    DayOfWeek.THURSDAY,
    DayOfWeek.FRIDAY,
]


class FlightStatus(models.TextChoices):
    SCHEDULED = "scheduled", "Programme"
    CHECKIN_OPEN = "checkin_open", "Enregistrement ouvert"
    DELAYED = "delayed", "Retarde"
    RESCHEDULED = "rescheduled", "Horaire modifie"
    POSTPONED = "postponed", "Reporte"
    CANCELLED = "cancelled", "Annule"
    BOARDING = "boarding", "Embarquement en cours"
    DEPARTED = "departed", "Decolle"
    ARRIVED = "arrived", "Arrive"


# Statuts consideres comme critiques (notification immediate obligatoire).
CRITICAL_STATUSES = {
    FlightStatus.DELAYED,
    FlightStatus.RESCHEDULED,
    FlightStatus.POSTPONED,
    FlightStatus.CANCELLED,
    FlightStatus.BOARDING,
    FlightStatus.ARRIVED,
}
