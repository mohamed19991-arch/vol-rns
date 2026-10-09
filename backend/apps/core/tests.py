"""Tests de la configuration (base de donnees, fuseau horaire, erreurs)."""
import dj_database_url
from django.conf import settings
from django.test import SimpleTestCase, TestCase

from .exceptions import error_response


class SettingsTests(SimpleTestCase):
    def test_timezone_and_locale(self):
        self.assertEqual(settings.TIME_ZONE, "Africa/Algiers")
        self.assertTrue(settings.USE_TZ)
        self.assertTrue(settings.USE_I18N)
        self.assertEqual(settings.LANGUAGE_CODE, "fr-fr")

    def test_development_uses_sqlite_when_no_database_url(self):
        # Sans DATABASE_URL (environnement de test local), on ne doit pas
        # dependre d'un serveur PostgreSQL.
        if not settings.DATABASE_URL:
            self.assertEqual(
                settings.DATABASES["default"]["ENGINE"], "django.db.backends.sqlite3"
            )

    def test_production_forces_postgresql(self):
        self.assertEqual(
            dj_database_url.parse(
                "postgresql://user:pass@ep-test.eu-central-1.aws.neon.tech/neondb",
                ssl_require=True,
            )["ENGINE"],
            "django.db.backends.postgresql",
        )

    def test_neon_requires_ssl(self):
        parsed = dj_database_url.parse(
            "postgresql://user:pass@ep-test.aws.neon.tech/neondb?sslmode=require",
            ssl_require=True,
        )
        self.assertEqual(parsed["OPTIONS"]["sslmode"], "require")

    def test_production_settings_reject_missing_database_url(self):
        from .config_checks import validate_production_config

        with self.assertRaises(RuntimeError):
            validate_production_config("", "cle-secrete-robuste", False)

    def test_production_settings_reject_default_secret(self):
        from .config_checks import validate_production_config

        with self.assertRaises(RuntimeError):
            validate_production_config(
                "postgresql://u:p@ep.neon.tech/db", "dev-insecure-secret-key-change-me", False
            )

    def test_production_settings_accept_valid_config(self):
        from .config_checks import validate_production_config

        # Ne doit pas lever d'exception.
        validate_production_config(
            "postgresql://u:p@ep.neon.tech/db?sslmode=require", "cle-secrete-robuste", False
        )

    def test_rest_framework_defaults_require_authentication(self):
        self.assertIn(
            "rest_framework.permissions.IsAuthenticated",
            settings.REST_FRAMEWORK["DEFAULT_PERMISSION_CLASSES"],
        )

    def test_login_throttling_configured(self):
        rates = settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]
        self.assertIn("login", rates)
        self.assertIn("password_reset", rates)

    def test_password_hashers_use_django_defaults(self):
        self.assertIn("django.contrib.auth.hashers.PBKDF2PasswordHasher", settings.PASSWORD_HASHERS)


class ErrorFormatTests(TestCase):
    def test_error_response_structure(self):
        response = error_response("Message d'erreur", status_code=400)
        self.assertEqual(response.status_code, 400)
        self.assertFalse(response.data["error"]["code"] is None)
        self.assertEqual(response.data["error"]["message"], "Message d'erreur")
        self.assertEqual(response.data["error"]["status"], 400)
        self.assertIn("fields", response.data["error"])
