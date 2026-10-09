"""Configuration de developpement local."""
from .base import *  # noqa: F401,F403

DEBUG = True

ALLOWED_HOSTS = ["*"]

# En developpement, un jeton d'acces plus long evite les deconnexions.
SIMPLE_JWT = {**SIMPLE_JWT, "ACCESS_TOKEN_LIFETIME": timedelta(days=1)}  # noqa: F405

# Emails affiches dans la console lors de la reinitialisation de mot de passe.
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# En developpement, l'uid et le token de reinitialisation sont renvoyes dans la
# reponse pour permettre les tests sans serveur SMTP.
PASSWORD_RESET_RETURN_TOKEN = env_bool("PASSWORD_RESET_RETURN_TOKEN", True)  # noqa: F405

# Journalisation detaillee des requetes API en local.
LOGGING["loggers"]["apps"]["level"] = "DEBUG"  # noqa: F405
