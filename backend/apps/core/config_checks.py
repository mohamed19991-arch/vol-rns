"""Verifications de coherence de la configuration (notamment en production)."""

DEV_SECRET_PREFIX = "dev-insecure"


def validate_production_config(database_url: str, secret_key: str, debug: bool) -> None:
    """Echoue rapidement si la configuration de production est incomplete.

    Args:
        database_url: chaine de connexion Neon PostgreSQL.
        secret_key: cle secrete Django.
        debug: indicateur du mode debug.

    Raises:
        RuntimeError: si une variable critique est manquante ou invalide.
    """
    if not database_url:
        raise RuntimeError(
            "DATABASE_URL est obligatoire en production (Neon PostgreSQL). "
            "Renseignez cette variable dans le fichier .env."
        )
    if not database_url.startswith(("postgres://", "postgresql://")):
        raise RuntimeError(
            "En production, DATABASE_URL doit pointer vers PostgreSQL (Neon)."
        )
    if not secret_key or secret_key.startswith(DEV_SECRET_PREFIX):
        raise RuntimeError(
            "DJANGO_SECRET_KEY doit etre defini en production avec une valeur robuste."
        )
    if debug:
        raise RuntimeError("DJANGO_DEBUG doit valoir False en production.")
