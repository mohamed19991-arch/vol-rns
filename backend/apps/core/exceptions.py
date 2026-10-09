"""Gestion centralisee et coherente des erreurs API."""
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError
from django.http import Http404
from rest_framework import status
from rest_framework.exceptions import (
    APIException,
    AuthenticationFailed,
    NotAuthenticated,
    PermissionDenied,
    Throttled,
    ValidationError,
)
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler


def _code_from_status(status_code: int) -> str:
    return {
        400: "validation_error",
        401: "authentication_failed",
        403: "permission_denied",
        404: "not_found",
        405: "method_not_allowed",
        409: "conflict",
        429: "too_many_requests",
    }.get(status_code, "error")


def api_exception_handler(exc, context):
    """Retourne une structure d'erreur homogene pour toute l'API.

    Format:
        {"error": {"status": 400, "code": "...", "message": "...", "fields": {...}}}
    """
    # Conversion des exceptions Django natives non gerees par le DRF.
    if isinstance(exc, DjangoValidationError):
        exc = ValidationError(getattr(exc, "message_dict", None) or exc.messages)
    elif isinstance(exc, IntegrityError):
        exc = ValidationError(
            {"detail": "Conflit de donnees : la ressource viole une contrainte d'integrite."}
        )

    response = drf_exception_handler(exc, context)
    if response is None:
        return None

    status_code = response.status_code
    fields = {}
    message = ""

    if isinstance(exc, ValidationError):
        detail = response.data
        if isinstance(detail, dict):
            fields = detail
        else:
            fields = {"non_field_errors": detail}
        message = "Les donnees transmises sont invalides."
    elif isinstance(exc, Http404):
        message = "Ressource introuvable."
    elif isinstance(exc, (NotAuthenticated, AuthenticationFailed)):
        message = "Authentification requise ou invalide."
    elif isinstance(exc, PermissionDenied):
        message = "Vous n'avez pas les autorisations necessaires pour cette action."
    elif isinstance(exc, Throttled):
        message = f"Trop de requetes. Reessayez dans {exc.wait} seconde(s)."
    elif isinstance(exc, APIException):
        message = str(exc.detail)
    else:  # pragma: no cover
        message = "Une erreur est survenue."

    response.data = {
        "error": {
            "status": status_code,
            "code": _code_from_status(status_code),
            "message": message,
            "fields": fields,
        }
    }
    return response


def error_response(message: str, status_code: int = status.HTTP_400_BAD_REQUEST, fields=None):
    """Construit une reponse d'erreur manuelle au meme format."""
    return Response(
        {
            "error": {
                "status": status_code,
                "code": _code_from_status(status_code),
                "message": message,
                "fields": fields or {},
            }
        },
        status=status_code,
    )
