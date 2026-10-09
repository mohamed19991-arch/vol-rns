"""Vues d'authentification, de profil et de gestion des utilisateurs."""
import logging

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import generics, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from apps.core.models import AuditLog
from apps.core.permissions import IsAdmin
from apps.core.utils import log_action

from .serializers import (
    AuditLogSerializer,
    ChangePasswordSerializer,
    LoginSerializer,
    MeSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    UserCreateSerializer,
    UserSerializer,
    UserUpdateSerializer,
)

logger = logging.getLogger("apps.accounts")
User = get_user_model()


def _tokens_for_user(user) -> dict:
    refresh = RefreshToken.for_user(user)
    # Le role est injecte cote serveur : il n'est jamais fourni par le client.
    refresh["role"] = user.role
    refresh["email"] = user.email
    return {"refresh": str(refresh), "access": str(refresh.access_token)}


class LoginView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "login"

    @extend_schema(
        request=LoginSerializer,
        responses={200: OpenApiTypes.OBJECT},
        tags=["Authentification"],
    )
    def post(self, request):
        serializer = LoginSerializer(data=request.data, context={"request": request})
        if not serializer.is_valid():
            log_action(
                request,
                AuditLog.Action.LOGIN_FAILED,
                description=f"Echec de connexion: {request.data.get('email', '')}",
            )
            raise ValidationError(serializer.errors)
        user = serializer.validated_data["user"]
        log_action(request, AuditLog.Action.LOGIN, instance=user, description="Connexion reussie")
        return Response(
            {"tokens": _tokens_for_user(user), "user": MeSerializer(user).data},
            status=status.HTTP_200_OK,
        )


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(request=None, responses={205: None}, tags=["Authentification"])
    def post(self, request):
        refresh = request.data.get("refresh")
        if refresh:
            try:
                RefreshToken(refresh).blacklist()
            except TokenError:
                pass
        log_action(request, AuditLog.Action.LOGOUT, description="Deconnexion")
        return Response(status=status.HTTP_205_RESET_CONTENT)


class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    @extend_schema(
        request=PasswordResetRequestSerializer,
        responses={200: OpenApiTypes.OBJECT},
        tags=["Authentification"],
    )
    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"].lower().strip()
        user = User.objects.filter(email=email, is_active=True).first()
        payload = {}
        if user is not None:
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            send_mail(
                subject="Reinitialisation de votre mot de passe - VOL-RNS",
                message=(
                    "Vous avez demande la reinitialisation de votre mot de passe.\n\n"
                    f"Identifiant: {uid}\nCode: {token}\n\n"
                    "Si vous n'etes pas a l'origine de cette demande, ignorez cet e-mail."
                ),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                fail_silently=True,
            )
            if settings.PASSWORD_RESET_RETURN_TOKEN:
                # Pratique en developpement : permet de tester le flux sans SMTP.
                payload = {"uid": uid, "token": token}
        # Reponse constante pour ne pas reveler l'existence du compte.
        return Response(
            {"detail": "Si un compte correspond a cette adresse, un e-mail a ete envoye.", **payload}
        )


class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    @extend_schema(
        request=PasswordResetConfirmSerializer,
        responses={200: OpenApiTypes.OBJECT},
        tags=["Authentification"],
    )
    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            user_id = force_str(urlsafe_base64_decode(data["uid"]))
            user = User.objects.get(pk=user_id, is_active=True)
        except (User.DoesNotExist, ValueError, TypeError, OverflowError):
            return Response(
                {"error": {"status": 400, "code": "validation_error",
                           "message": "Lien de reinitialisation invalide.", "fields": {}}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not default_token_generator.check_token(user, data["token"]):
            return Response(
                {"error": {"status": 400, "code": "validation_error",
                           "message": "Le code de reinitialisation est invalide ou expire.",
                           "fields": {}}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(data["new_password"])
        user.save(update_fields=["password"])
        log_action(request, AuditLog.Action.UPDATE, instance=user,
                   description="Reinitialisation du mot de passe")
        return Response({"detail": "Mot de passe reinitialise avec succes."})


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = MeSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["Utilisateurs"])
    def get_object(self):
        return self.request.user

    def perform_update(self, serializer):
        serializer.save()
        log_action(self.request, AuditLog.Action.UPDATE, instance=self.request.user,
                   description="Mise a jour du profil")


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=ChangePasswordSerializer,
        responses={200: OpenApiTypes.OBJECT},
        tags=["Utilisateurs"],
    )
    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        log_action(request, AuditLog.Action.UPDATE, instance=request.user,
                   description="Changement de mot de passe")
        return Response({"detail": "Mot de passe modifie avec succes."})


class UserViewSet(viewsets.ModelViewSet):
    """Gestion des utilisateurs et des roles (administrateur uniquement)."""

    queryset = User.objects.select_related("profile").all()
    permission_classes = [IsAdmin]
    filterset_fields = ["role", "is_active"]
    search_fields = ["email", "first_name", "last_name", "phone"]
    ordering_fields = ["date_joined", "email", "last_name"]

    def get_serializer_class(self):
        if self.action == "create":
            return UserCreateSerializer
        if self.action in {"update", "partial_update"}:
            return UserUpdateSerializer
        return UserSerializer

    def perform_create(self, serializer):
        user = serializer.save()
        log_action(self.request, AuditLog.Action.CREATE, instance=user,
                   description=f"Creation de l'utilisateur {user.email} (role={user.role})")

    def perform_update(self, serializer):
        target = self.get_object()
        old_role = target.role
        user = serializer.save()
        if old_role != user.role:
            log_action(self.request, AuditLog.Action.PERMISSION, instance=user,
                       description=f"Role modifie: {old_role} -> {user.role}")
        log_action(self.request, AuditLog.Action.UPDATE, instance=user,
                   description=f"Mise a jour de l'utilisateur {user.email}")

    def perform_destroy(self, instance):
        # Desactivation logique plutot que suppression physique (tracabilite).
        instance.is_active = False
        instance.save(update_fields=["is_active"])
        log_action(self.request, AuditLog.Action.DELETE, instance=instance,
                   description=f"Desactivation de l'utilisateur {instance.email}")

    @extend_schema(tags=["Utilisateurs"])
    @action(detail=True, methods=["post"])
    def set_password(self, request, pk=None):
        user = self.get_object()
        password = request.data.get("password")
        if not password:
            return Response(
                {"error": {"status": 400, "code": "validation_error",
                           "message": "Le mot de passe est obligatoire.", "fields": {}}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        from django.contrib.auth.password_validation import validate_password

        validate_password(password, user)
        user.set_password(password)
        user.save(update_fields=["password"])
        log_action(request, AuditLog.Action.PERMISSION, instance=user,
                   description="Mot de passe reinitialise par un administrateur")
        return Response({"detail": "Mot de passe mis a jour."})


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    """Consultation de l'historique des actions (administrateur)."""

    queryset = AuditLog.objects.select_related("user").all()
    serializer_class = AuditLogSerializer
    permission_classes = [IsAdmin]
    filterset_fields = ["action", "entity_type", "user"]
    search_fields = ["description", "entity_id"]
    ordering_fields = ["created_at"]
