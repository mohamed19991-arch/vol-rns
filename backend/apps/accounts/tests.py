"""Tests de l'authentification, des profils, des roles et des permissions."""
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.core.models import AuditLog

User = get_user_model()


class BaseAuthTestCase(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.admin = User.objects.create_user(
            email="admin@test.local", password="AdminPass!123", role=User.Role.ADMIN
        )
        cls.agent = User.objects.create_user(
            email="agent@test.local", password="AgentPass!123", role=User.Role.AGENT
        )
        cls.worker = User.objects.create_user(
            email="worker@test.local", password="WorkerPass!123", role=User.Role.WORKER
        )

    def setUp(self):
        # Reinitialise les compteurs de limitation de debit entre les tests.
        cache.clear()

    def auth(self, user):
        from rest_framework_simplejwt.tokens import RefreshToken

        token = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")


class LoginTests(BaseAuthTestCase):
    url = "/api/auth/login/"

    def test_login_success_returns_tokens_and_user(self):
        response = self.client.post(
            self.url, {"email": "admin@test.local", "password": "AdminPass!123"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("tokens", response.data)
        self.assertIn("access", response.data["tokens"])
        self.assertIn("refresh", response.data["tokens"])
        self.assertEqual(response.data["user"]["role"], User.Role.ADMIN)

    def test_login_case_insensitive_email(self):
        response = self.client.post(
            self.url, {"email": "ADMIN@test.local", "password": "AdminPass!123"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_login_wrong_password_uses_consistent_error_format(self):
        response = self.client.post(
            self.url, {"email": "admin@test.local", "password": "wrong"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("error", response.data)
        self.assertEqual(response.data["error"]["code"], "validation_error")

    def test_login_inactive_account_refused(self):
        self.worker.is_active = False
        self.worker.save(update_fields=["is_active"])
        response = self.client.post(
            self.url, {"email": "worker@test.local", "password": "WorkerPass!123"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_login_is_audited(self):
        self.client.post(
            self.url, {"email": "agent@test.local", "password": "AgentPass!123"}, format="json"
        )
        self.assertTrue(AuditLog.objects.filter(action=AuditLog.Action.LOGIN).exists())

    def test_failed_login_is_audited(self):
        self.client.post(
            self.url, {"email": "agent@test.local", "password": "bad"}, format="json"
        )
        self.assertTrue(AuditLog.objects.filter(action=AuditLog.Action.LOGIN_FAILED).exists())


class PasswordResetTests(BaseAuthTestCase):
    def test_password_reset_full_flow(self):
        response = self.client.post(
            "/api/auth/password-reset/", {"email": "worker@test.local"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # En DEBUG (tests), l'uid et le token sont renvoyes pour permettre le test.
        self.assertIn("uid", response.data)
        self.assertIn("token", response.data)

        confirm = self.client.post(
            "/api/auth/password-reset/confirm/",
            {
                "uid": response.data["uid"],
                "token": response.data["token"],
                "new_password": "NouveauPass!456",
            },
            format="json",
        )
        self.assertEqual(confirm.status_code, status.HTTP_200_OK)

        login = self.client.post(
            "/api/auth/login/",
            {"email": "worker@test.local", "password": "NouveauPass!456"},
            format="json",
        )
        self.assertEqual(login.status_code, status.HTTP_200_OK)

    def test_password_reset_unknown_email_is_neutral(self):
        response = self.client.post(
            "/api/auth/password-reset/", {"email": "inconnu@test.local"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertNotIn("uid", response.data)

    def test_password_reset_invalid_token_refused(self):
        response = self.client.post(
            "/api/auth/password-reset/confirm/",
            {"uid": "invalid", "token": "invalid", "new_password": "NouveauPass!456"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class ProfileTests(BaseAuthTestCase):
    def test_me_requires_authentication(self):
        response = self.client.get("/api/me/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_me_returns_authenticated_user(self):
        self.auth(self.worker)
        response = self.client.get("/api/me/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["email"], "worker@test.local")

    def test_update_profile_and_preferences(self):
        self.auth(self.worker)
        response = self.client.patch(
            "/api/me/",
            {"first_name": "Ali", "profile": {"receive_push": False, "language": "fr"}},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.worker.refresh_from_db()
        self.assertEqual(self.worker.first_name, "Ali")
        self.assertFalse(self.worker.profile.receive_push)

    def test_role_cannot_be_modified_via_me(self):
        self.auth(self.worker)
        self.client.patch("/api/me/", {"role": "admin"}, format="json")
        self.worker.refresh_from_db()
        self.assertEqual(self.worker.role, User.Role.WORKER)

    def test_change_password(self):
        self.auth(self.worker)
        response = self.client.post(
            "/api/me/change-password/",
            {"old_password": "WorkerPass!123", "new_password": "AutrePass!789"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.worker.refresh_from_db()
        self.assertTrue(self.worker.check_password("AutrePass!789"))


class RolePermissionTests(BaseAuthTestCase):
    def test_worker_cannot_list_users(self):
        self.auth(self.worker)
        response = self.client.get("/api/users/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_agent_cannot_list_users(self):
        self.auth(self.agent)
        response = self.client.get("/api/users/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_list_users(self):
        self.auth(self.admin)
        response = self.client.get("/api/users/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 3)

    def test_admin_can_create_agent(self):
        self.auth(self.admin)
        response = self.client.post(
            "/api/users/",
            {"email": "nouvel.agent@test.local", "password": "AgentNew!123",
             "role": User.Role.AGENT, "first_name": "Nadia"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_agent_cannot_create_admin(self):
        self.auth(self.agent)
        response = self.client.post(
            "/api/users/",
            {"email": "faux.admin@test.local", "password": "AdminNew!123", "role": User.Role.ADMIN},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_cannot_create_admin_via_agent_serializer_rule(self):
        # Un agent (non-admin) ne peut pas s'octroyer le role administrateur.
        self.auth(self.agent)
        response = self.client.patch(
            f"/api/users/{self.worker.pk}/", {"role": User.Role.ADMIN}, format="json"
        )
        self.assertIn(response.status_code, (status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND))

    def test_user_deletion_is_logical(self):
        self.auth(self.admin)
        response = self.client.delete(f"/api/users/{self.worker.pk}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.worker.refresh_from_db()
        self.assertFalse(self.worker.is_active)
        self.assertTrue(User.objects.filter(pk=self.worker.pk).exists())

    def test_audit_logs_restricted_to_admin(self):
        self.auth(self.agent)
        self.assertEqual(self.client.get("/api/audit-logs/").status_code, status.HTTP_403_FORBIDDEN)
        self.auth(self.admin)
        self.assertEqual(self.client.get("/api/audit-logs/").status_code, status.HTTP_200_OK)
