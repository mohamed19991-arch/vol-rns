"""Configuration de production (deploiement)."""
import os

from apps.core.config_checks import validate_production_config

from .base import *  # noqa: F401,F403

DEBUG = False

# ------------------------------------------------------------------
# Verification : Neon PostgreSQL et secret obligatoires en production
# ------------------------------------------------------------------
validate_production_config(DATABASE_URL, SECRET_KEY, DEBUG)  # noqa: F405

# ------------------------------------------------------------------
# Hebergeurs (Render, Railway, Koyeb...) : domaine public fourni par la plateforme
# ------------------------------------------------------------------
_external_host = os.environ.get("RENDER_EXTERNAL_HOSTNAME") or os.environ.get(
    "PUBLIC_HOSTNAME"
)
if _external_host:
    if _external_host not in ALLOWED_HOSTS:  # noqa: F405
        ALLOWED_HOSTS.append(_external_host)  # noqa: F405
    _origin = f"https://{_external_host}"
    if _origin not in CSRF_TRUSTED_ORIGINS:  # noqa: F405
        CSRF_TRUSTED_ORIGINS.append(_origin)  # noqa: F405

# ------------------------------------------------------------------
# Securite renforcee (HTTPS obligatoire derriere un reverse proxy)
# ------------------------------------------------------------------
SECURE_SSL_REDIRECT = env_bool("DJANGO_SECURE_SSL_REDIRECT", True)  # noqa: F405
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
