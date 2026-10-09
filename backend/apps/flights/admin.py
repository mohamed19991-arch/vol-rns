from django.contrib import admin

from .models import Destination, Favorite, Flight, FlightChangeLog, WeeklySchedule


@admin.register(Destination)
class DestinationAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "city", "country", "is_active")
    list_filter = ("is_active", "country")
    search_fields = ("code", "name", "city")
    ordering = ("code",)


@admin.register(WeeklySchedule)
class WeeklyScheduleAdmin(admin.ModelAdmin):
    list_display = (
        "day_of_week", "origin", "destination", "flight_code",
        "registration_time", "departure_time", "arrival_time", "is_active",
    )
    list_filter = ("day_of_week", "is_active")
    search_fields = ("origin__code", "destination__code", "flight_code")
    autocomplete_fields = ("origin", "destination")


class FlightChangeLogInline(admin.TabularInline):
    model = FlightChangeLog
    extra = 0
    can_delete = False
    readonly_fields = (
        "changed_by", "change_type", "field_name", "old_value", "new_value", "note", "created_at",
    )
    fields = readonly_fields

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Flight)
class FlightAdmin(admin.ModelAdmin):
    list_display = (
        "flight_date", "day_of_week", "origin", "destination", "flight_code",
        "registration_time", "departure_time", "status", "is_exceptional", "is_active",
    )
    list_filter = ("status", "is_active", "is_exceptional", "flight_date", "origin", "destination")
    search_fields = ("flight_code", "origin__code", "destination__code", "observation")
    date_hierarchy = "flight_date"
    autocomplete_fields = ("origin", "destination")
    inlines = [FlightChangeLogInline]


@admin.register(FlightChangeLog)
class FlightChangeLogAdmin(admin.ModelAdmin):
    list_display = ("created_at", "flight", "change_type", "field_name", "old_value", "new_value")
    list_filter = ("change_type", "created_at")
    search_fields = ("flight__flight_code", "note")
    readonly_fields = (
        "flight", "changed_by", "change_type", "field_name", "old_value", "new_value", "note",
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ("user", "favorite_type", "destination", "route_origin", "route_destination", "flight", "notifications_enabled")
    list_filter = ("favorite_type", "notifications_enabled")
    search_fields = ("user__email",)
