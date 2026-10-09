from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    AnnouncementViewSet,
    FCMDeviceViewSet,
    NotificationInboxViewSet,
    NotificationManageViewSet,
)

router = DefaultRouter()
router.register("notifications", NotificationInboxViewSet, basename="notification")
router.register("notification-management", NotificationManageViewSet, basename="notification-manage")
router.register("devices", FCMDeviceViewSet, basename="device")
router.register("announcements", AnnouncementViewSet, basename="announcement")

urlpatterns = [
    path("", include(router.urls)),
]
