from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    DestinationViewSet,
    FavoriteViewSet,
    FlightStatsView,
    FlightViewSet,
    WeeklyScheduleViewSet,
)

router = DefaultRouter()
router.register("destinations", DestinationViewSet, basename="destination")
router.register("weekly-schedules", WeeklyScheduleViewSet, basename="weekly-schedule")
router.register("flights", FlightViewSet, basename="flight")
router.register("favorites", FavoriteViewSet, basename="favorite")

urlpatterns = [
    path("stats/flights/", FlightStatsView.as_view(), name="flight-stats"),
    path("", include(router.urls)),
]
