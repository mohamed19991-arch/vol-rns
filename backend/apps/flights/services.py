"""Logique metier des vols : tracabilite et declenchement des notifications."""
import logging

from apps.notifications.models import NotificationCategory, TargetType
from apps.notifications.services import create_notification

from .constants import FlightStatus
from .models import Flight, FlightChangeLog

logger = logging.getLogger("apps.flights")


def log_flight_change(
    flight: Flight,
    user,
    change_type: str,
    *,
    field_name: str = "",
    old_value: str = "",
    new_value: str = "",
    note: str = "",
) -> FlightChangeLog:
    """Enregistre une entree d'historique pour un vol."""
    return FlightChangeLog.objects.create(
        flight=flight,
        changed_by=user if getattr(user, "is_authenticated", False) else None,
        change_type=change_type,
        field_name=field_name,
        old_value=str(old_value)[:255],
        new_value=str(new_value)[:255],
        note=note,
    )


def _fmt_time(value) -> str:
    return value.strftime("%H:%M") if value else "-"


def _fmt_date(value) -> str:
    return value.strftime("%d/%m/%Y") if value else "-"


def flight_label(flight: Flight) -> str:
    code = f" {flight.flight_code}" if flight.flight_code else ""
    return (
        f"{flight.origin.code} -> {flight.destination.code}{code} "
        f"du {_fmt_date(flight.flight_date)}"
    )


# Messages et categories associes aux evenements critiques.
_STATUS_NOTIFICATIONS = {
    FlightStatus.DELAYED: (
        NotificationCategory.DELAY,
        "Vol retarde",
        "Le vol {label} est retarde. Nouvel horaire de decollage : {departure}.",
    ),
    FlightStatus.POSTPONED: (
        NotificationCategory.POSTPONE,
        "Vol reporte",
        "Le vol {label} est reporte. Nouvel horaire de decollage : {departure}.",
    ),
    FlightStatus.CANCELLED: (
        NotificationCategory.CANCELLATION,
        "Vol annule",
        "Le vol {label} est annule. {observation}",
    ),
    FlightStatus.BOARDING: (
        NotificationCategory.BOARDING,
        "Embarquement en cours",
        "L'embarquement du vol {label} est en cours. Decollage prevu a {departure}.",
    ),
    FlightStatus.ARRIVED: (
        NotificationCategory.ARRIVAL,
        "Vol arrive",
        "Le vol {label} est arrive a destination.",
    ),
    FlightStatus.RESCHEDULED: (
        NotificationCategory.SCHEDULE_CHANGE,
        "Horaire modifie",
        "L'horaire du vol {label} a ete modifie. Nouveau decollage : {departure}.",
    ),
}


def notify_flight_status(flight: Flight, *, dedup_suffix: str = "") -> None:
    """Declenche une notification ciblee sur le vol pour un statut critique."""
    entry = _STATUS_NOTIFICATIONS.get(flight.status)
    if entry is None:
        return
    category, title, template = entry
    message = template.format(
        label=flight_label(flight),
        departure=_fmt_time(flight.departure_time),
        observation=flight.observation or "",
    ).strip()
    dedup_key = f"flight-{flight.pk}-status-{flight.status}-{dedup_suffix}".rstrip("-")
    try:
        create_notification(
            title=title,
            message=message,
            category=category,
            target_type=TargetType.FLIGHT,
            flight=flight,
            dedup_key=dedup_key,
            is_urgent=flight.status in {FlightStatus.CANCELLED, FlightStatus.POSTPONED},
        )
    except Exception as exc:  # pragma: no cover - ne doit jamais bloquer le flux metier
        logger.error("Echec de la notification de statut du vol %s : %s", flight.pk, exc)


def notify_flight_times(flight: Flight, changed_fields: list[str]) -> None:
    """Notifie les modifications d'horaires d'enregistrement / decollage."""
    try:
        if "registration_time" in changed_fields:
            create_notification(
                title="Modification de l'enregistrement",
                message=(
                    f"L'heure d'enregistrement du vol {flight_label(flight)} "
                    f"est desormais {_fmt_time(flight.registration_time)}."
                ),
                category=NotificationCategory.REGISTRATION_TIME_CHANGED,
                target_type=TargetType.FLIGHT,
                flight=flight,
                dedup_key=f"flight-{flight.pk}-reg-{flight.registration_time}",
            )
        if "departure_time" in changed_fields:
            create_notification(
                title="Modification du decollage",
                message=(
                    f"L'heure de decollage du vol {flight_label(flight)} "
                    f"est desormais {_fmt_time(flight.departure_time)}."
                ),
                category=NotificationCategory.DEPARTURE_TIME_CHANGED,
                target_type=TargetType.FLIGHT,
                flight=flight,
                dedup_key=f"flight-{flight.pk}-dep-{flight.departure_time}",
            )
    except Exception as exc:  # pragma: no cover - ne doit pas bloquer l'operation
        logger.error("Echec de la notification d'horaire du vol %s : %s", flight.pk, exc)


def notify_new_flight(flight: Flight) -> None:
    """Notifie la publication d'un nouveau vol."""
    try:
        create_notification(
            title="Nouveau vol publie",
            message=(
                f"Un nouveau vol {flight_label(flight)} est disponible. "
                f"Enregistrement a {_fmt_time(flight.registration_time)}, "
                f"decollage a {_fmt_time(flight.departure_time)}."
            ),
            category=NotificationCategory.NEW_FLIGHT,
            target_type=TargetType.FLIGHT,
            flight=flight,
            dedup_key=f"flight-{flight.pk}-created",
        )
    except Exception as exc:  # pragma: no cover - ne doit pas bloquer l'operation
        logger.error("Echec de la notification de creation du vol %s : %s", flight.pk, exc)
