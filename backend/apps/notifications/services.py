"""Services de notifications : ciblage des destinataires et envoi FCM.

Principes :
  * la notification est TOUJOURS enregistree en base avant l'envoi push ;
  * l'envoi est declenche immediatement apres la validation cote serveur ;
  * les envois sont dedupliques (cle ``dedup_key``) et rejoues en cas d'echec ;
  * les jetons FCM invalides sont desactives automatiquement.
"""
import base64
import json
import logging
import time

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import User
from apps.flights.models import Favorite

from .models import (
    FCMDevice,
    Notification,
    NotificationRecipient,
    TargetType,
)

logger = logging.getLogger("apps.notifications")

# ----------------------------------------------------------------------
# Firebase Admin SDK (chargement tolerant : l'application doit demarrer
# meme si Firebase n'est pas encore configure).
# ----------------------------------------------------------------------
_firebase_messaging = None
_firebase_initialized = False


def _load_firebase():
    global _firebase_messaging, _firebase_initialized
    if _firebase_initialized:
        return _firebase_messaging
    _firebase_initialized = True
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging
    except ImportError:  # pragma: no cover
        logger.warning("firebase-admin n'est pas installe : envoi push desactive.")
        return None

    if firebase_admin._apps:  # deja initialise
        _firebase_messaging = messaging
        return _firebase_messaging

    try:
        if settings.FIREBASE_CREDENTIALS_FILE:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_FILE)
        elif settings.FIREBASE_CREDENTIALS_BASE64:
            raw = base64.b64decode(settings.FIREBASE_CREDENTIALS_BASE64)
            cred = credentials.Certificate(json.loads(raw.decode("utf-8")))
        else:
            logger.warning("Aucune credentials Firebase : envoi push desactive.")
            return None
        firebase_admin.initialize_app(cred)
        _firebase_messaging = messaging
    except Exception as exc:  # pragma: no cover
        logger.error("Initialisation Firebase impossible : %s", exc)
        return None
    return _firebase_messaging


# ----------------------------------------------------------------------
# Ciblage des destinataires
# ----------------------------------------------------------------------
def resolve_recipients(
    target_type: str,
    *,
    destination=None,
    route_origin=None,
    route_destination=None,
    flight=None,
    user=None,
    role=None,
):
    """Retourne le queryset des utilisateurs cibles (actifs).

    Les travailleurs interesses sont determines a partir de leurs favoris
    (destination, trajet ou vol), conformement aux regles de ciblage.
    """
    from django.db.models import Q

    workers = User.objects.filter(is_active=True)

    if target_type == TargetType.USER and user is not None:
        return workers.filter(pk=user.pk)

    if target_type == TargetType.ROLE and role:
        return workers.filter(role=role)

    favorites = Favorite.objects.all()

    if target_type == TargetType.FLIGHT and flight is not None:
        favorites = favorites.filter(
            Q(favorite_type=Favorite.FavoriteType.FLIGHT, flight=flight)
            | Q(
                favorite_type=Favorite.FavoriteType.ROUTE,
                route_origin=flight.origin,
                route_destination=flight.destination,
            )
            | Q(
                favorite_type=Favorite.FavoriteType.DESTINATION,
                destination=flight.destination,
            )
        )

    elif target_type == TargetType.ROUTE and route_origin and route_destination:
        favorites = favorites.filter(
            Q(
                favorite_type=Favorite.FavoriteType.ROUTE,
                route_origin=route_origin,
                route_destination=route_destination,
            )
            | Q(
                favorite_type=Favorite.FavoriteType.DESTINATION,
                destination=route_destination,
            )
        )

    elif target_type == TargetType.DESTINATION and destination is not None:
        favorites = favorites.filter(
            Q(favorite_type=Favorite.FavoriteType.DESTINATION, destination=destination)
            | Q(
                favorite_type=Favorite.FavoriteType.ROUTE,
                route_origin=destination,
            )
            | Q(
                favorite_type=Favorite.FavoriteType.ROUTE,
                route_destination=destination,
            )
        )

    else:
        # Par defaut : tous les travailleurs.
        return workers.filter(role=User.Role.WORKER)

    user_ids = favorites.values_list("user_id", flat=True)
    return workers.filter(pk__in=user_ids)


def _recipients_with_push_enabled(users):
    """Filtre les utilisateurs ayant active les notifications push."""
    return users.filter(profile__receive_push=True, devices__is_active=True).distinct()


# ----------------------------------------------------------------------
# Envoi FCM
# ----------------------------------------------------------------------
def send_push_to_users(users, *, title: str, body: str, data: dict | None = None):
    """Envoie un message push a tous les appareils actifs des utilisateurs.

    Retourne (success_count, failure_count). Ne leve jamais d'exception :
    les jetons invalides sont desactives, les erreurs sont journalisees.
    """
    messaging = _load_firebase()
    tokens = list(
        FCMDevice.objects.filter(user__in=users, is_active=True).values_list(
            "token", flat=True
        )
    )
    tokens = list(dict.fromkeys(tokens))  # deduplication
    if not tokens:
        return 0, 0
    if messaging is None:
        logger.warning(
            "Firebase non configure : %s jeton(s) non notifie(s) (titre=%s)", len(tokens), title
        )
        return 0, len(tokens)

    data = {k: str(v) for k, v in (data or {}).items()}
    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data=data,
        tokens=tokens,
        android=messaging.AndroidConfig(
            priority="high",
            # Cible le canal cree par l'application : importance haute + son.
            notification=messaging.AndroidNotification(
                channel_id="vol_rns_default",
                default_sound=True,
                default_vibrate_timings=True,
            ),
        ),
    )

    success = 0
    failure = 0
    invalid_tokens: list[str] = []
    max_attempts = 3
    pending = tokens

    for attempt in range(1, max_attempts + 1):
        try:
            response = messaging.send_each_for_multicast(message)
        except Exception as exc:  # pragma: no cover - erreur reseau/transitoire
            logger.error("Echec de l'envoi FCM (tentative %s) : %s", attempt, exc)
            if attempt == max_attempts:
                failure += len(pending)
                break
            time.sleep(2 ** attempt)
            continue

        retry_tokens: list[str] = []
        for idx, resp in enumerate(response.responses):
            token = pending[idx]
            if resp.success:
                success += 1
                continue
            exc = resp.exception
            if exc is not None and exc.__class__.__name__ in {
                "UnregisteredError",
                "SenderIdMismatchError",
                "InvalidArgumentError",
            }:
                invalid_tokens.append(token)
            else:
                retry_tokens.append(token)

        pending = retry_tokens
        if not pending:
            break
        if attempt == max_attempts:
            failure += len(pending)
            break
        time.sleep(2 ** attempt)

    if invalid_tokens:
        FCMDevice.objects.filter(token__in=invalid_tokens).update(is_active=False)
        logger.info("%s jeton(s) FCM invalide(s) desactive(s).", len(invalid_tokens))

    return success, failure


# ----------------------------------------------------------------------
# Creation et distribution
# ----------------------------------------------------------------------
def create_notification(
    *,
    title: str,
    message: str,
    category: str,
    target_type: str = TargetType.ALL_WORKERS,
    flight=None,
    announcement=None,
    created_by=None,
    dedup_key: str = "",
    is_urgent: bool = False,
    destination=None,
    route_origin=None,
    route_destination=None,
    user=None,
    send_push: bool = True,
) -> Notification:
    """Enregistre la notification en base puis la distribue immediatement."""
    if dedup_key:
        existing = Notification.objects.filter(dedup_key=dedup_key).first()
        if existing is not None:
            logger.info("Notification dedupliquee (cle=%s)", dedup_key)
            return existing

    notification = Notification.objects.create(
        title=title,
        message=message,
        category=category,
        target_type=target_type,
        flight=flight,
        announcement=announcement,
        created_by=created_by,
        dedup_key=dedup_key,
        is_urgent=is_urgent,
        target_destination=destination,
        target_route_origin=route_origin,
        target_route_destination=route_destination,
        target_user=user,
    )
    dispatch_notification(notification, send_push=send_push)
    return notification


@transaction.atomic
def _register_recipients(notification: Notification, users) -> list[NotificationRecipient]:
    recipients = [
        NotificationRecipient(notification=notification, user=u) for u in users
    ]
    NotificationRecipient.objects.bulk_create(recipients, ignore_conflicts=True)
    return recipients


def dispatch_notification(notification: Notification, *, send_push: bool = True) -> Notification:
    """Resout les destinataires, cree les etats de lecture et envoie le push."""
    users = resolve_recipients(
        notification.target_type,
        destination=notification.target_destination,
        route_origin=notification.target_route_origin,
        route_destination=notification.target_route_destination,
        flight=notification.flight,
        user=notification.target_user,
    )
    users = list(users)
    _register_recipients(notification, users)

    notification.total_recipients = len(users)
    if send_push and users:
        push_users = _recipients_with_push_enabled(User.objects.filter(pk__in=[u.pk for u in users]))
        success, failure = send_push_to_users(
            push_users,
            title=notification.title,
            body=notification.message,
            data={
                "category": notification.category,
                "flight_id": notification.flight_id or "",
                "notification_id": notification.pk,
            },
        )
        notification.success_count = success
        notification.failure_count = failure
    notification.sent_at = timezone.now()
    notification.save(
        update_fields=[
            "total_recipients",
            "success_count",
            "failure_count",
            "sent_at",
            "updated_at",
        ]
    )
    return notification


# ----------------------------------------------------------------------
# Annonces
# ----------------------------------------------------------------------
def visible_announcements_for(user):
    """Retourne les annonces visibles par un utilisateur selon son role et ses favoris."""
    from django.db.models import Q

    from .models import Announcement

    queryset = Announcement.objects.filter(status=Announcement.Status.PUBLISHED).filter(
        Q(expires_at__isnull=True) | Q(expires_at__gt=timezone.now())
    )
    if user.is_admin or user.is_agent:
        return queryset

    favorite_filter = Q()
    destinations = set(
        Favorite.objects.filter(user=user, favorite_type=Favorite.FavoriteType.DESTINATION)
        .values_list("destination_id", flat=True)
    )
    routes = list(
        Favorite.objects.filter(user=user, favorite_type=Favorite.FavoriteType.ROUTE)
        .values_list("route_origin_id", "route_destination_id")
    )
    for origin_id, destination_id in routes:
        destinations.add(destination_id)
        favorite_filter |= Q(
            target_type=TargetType.ROUTE,
            target_route_origin_id=origin_id,
            target_route_destination_id=destination_id,
        )

    base = Q(target_type__in=[TargetType.ALL_WORKERS, TargetType.ROLE])
    if destinations:
        base |= Q(target_type=TargetType.DESTINATION, target_destination_id__in=destinations)
    if favorite_filter:
        base |= favorite_filter
    return queryset.filter(base).distinct()


def notify_announcement(announcement) -> Notification:
    """Publie une annonce et declenche la notification push associee."""
    from .models import Announcement, NotificationCategory

    is_urgent = announcement.priority == Announcement.Priority.URGENT
    category = NotificationCategory.URGENT if is_urgent else NotificationCategory.ANNOUNCEMENT
    return create_notification(
        title=announcement.title,
        message=announcement.content,
        category=category,
        target_type=announcement.target_type,
        announcement=announcement,
        created_by=announcement.author,
        dedup_key=f"announcement-{announcement.pk}",
        is_urgent=is_urgent,
        destination=announcement.target_destination,
        route_origin=announcement.target_route_origin,
        route_destination=announcement.target_route_destination,
    )
