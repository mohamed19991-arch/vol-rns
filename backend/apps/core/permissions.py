"""Permissions basees sur les roles, verifiees cote serveur.

Le role est toujours determine par le backend a partir du compte
authentifie : le role envoye par Flutter n'est jamais utilise.
"""
from rest_framework.permissions import SAFE_METHODS, BasePermission

ROLE_ADMIN = "admin"
ROLE_AGENT = "agent"
ROLE_WORKER = "worker"


class _BaseRolePermission(BasePermission):
    allowed_roles: tuple[str, ...] = ()
    message = "Vous n'avez pas les autorisations necessaires pour cette action."

    def has_permission(self, request, view) -> bool:
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if not user.is_active:
            return False
        if user.is_superuser:
            return True
        return user.role in self.allowed_roles

    def has_object_permission(self, request, view, obj) -> bool:
        return self.has_permission(request, view)


class IsAdmin(_BaseRolePermission):
    allowed_roles = (ROLE_ADMIN,)


class IsAgent(_BaseRolePermission):
    """Agent du bureau de voyage (et administrateur)."""

    allowed_roles = (ROLE_ADMIN, ROLE_AGENT)


class IsWorker(_BaseRolePermission):
    allowed_roles = (ROLE_WORKER,)


class IsAdminOrReadOnly(_BaseRolePermission):
    """Lecture pour tout utilisateur authentifie, ecriture pour l'admin."""

    allowed_roles = (ROLE_ADMIN, ROLE_AGENT, ROLE_WORKER)

    def has_permission(self, request, view) -> bool:
        if request.method in SAFE_METHODS:
            return super().has_permission(request, view)
        user = request.user
        return bool(
            user and user.is_authenticated and (user.is_superuser or user.role == ROLE_ADMIN)
        )


class IsAgentOrReadOnly(_BaseRolePermission):
    """Lecture pour tous, ecriture pour les agents et administrateurs."""

    allowed_roles = (ROLE_ADMIN, ROLE_AGENT, ROLE_WORKER)

    def has_permission(self, request, view) -> bool:
        if request.method in SAFE_METHODS:
            return super().has_permission(request, view)
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and (user.is_superuser or user.role in (ROLE_ADMIN, ROLE_AGENT))
        )
