"""Utilitaires transverses (journalisation, IP client)."""
import logging

from .models import AuditLog

logger = logging.getLogger("apps.core")


def get_client_ip(request) -> str | None:
    if request is None:
        return None
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")


def log_action(request, action, instance=None, description="", **metadata) -> AuditLog:
    """Enregistre une action dans le journal d'audit."""
    user = getattr(request, "user", None)
    if user is not None and not getattr(user, "is_authenticated", False):
        user = None
    return AuditLog.objects.create(
        user=user,
        action=action,
        entity_type=instance.__class__.__name__ if instance is not None else "",
        entity_id=str(getattr(instance, "pk", "")) if instance is not None else "",
        description=description,
        metadata=metadata or {},
        ip_address=get_client_ip(request),
    )
