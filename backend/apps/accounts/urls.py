from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import AuditLogViewSet, ChangePasswordView, MeView, UserViewSet

router = DefaultRouter()
router.register("users", UserViewSet, basename="user")
router.register("audit-logs", AuditLogViewSet, basename="audit-log")

urlpatterns = [
    path("me/", MeView.as_view(), name="me"),
    path("me/change-password/", ChangePasswordView.as_view(), name="me-change-password"),
    path("", include(router.urls)),
]
