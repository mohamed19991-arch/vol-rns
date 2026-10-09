import django_filters as filters
from django.db.models import Q

from .models import Flight


class FlightFilter(filters.FilterSet):
    """Filtres de recherche de vols (date, destination, statut, jour, trajet)."""

    date = filters.DateFilter(field_name="flight_date", lookup_expr="exact")
    date_from = filters.DateFilter(field_name="flight_date", lookup_expr="gte")
    date_to = filters.DateFilter(field_name="flight_date", lookup_expr="lte")
    day = filters.NumberFilter(field_name="day_of_week")
    origin = filters.NumberFilter(field_name="origin_id")
    destination = filters.NumberFilter(field_name="destination_id")
    origin_code = filters.CharFilter(field_name="origin__code", lookup_expr="iexact")
    destination_code = filters.CharFilter(field_name="destination__code", lookup_expr="iexact")
    route = filters.CharFilter(method="filter_route")
    status = filters.CharFilter(field_name="status")
    status_in = filters.BaseInFilter(field_name="status")

    class Meta:
        model = Flight
        fields = ["date", "date_from", "date_to", "day", "origin", "destination", "status"]

    def filter_route(self, queryset, name, value):
        """Filtre par trajet au format ``RNS-ORAN``."""
        if "-" not in value:
            return queryset.none()
        origin_code, destination_code = value.split("-", 1)
        return queryset.filter(
            Q(origin__code__iexact=origin_code.strip())
            & Q(destination__code__iexact=destination_code.strip())
        )
