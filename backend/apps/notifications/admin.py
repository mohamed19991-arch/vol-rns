from django.contrib import admin

from .models import Announcement, FCMDevice, Notification, NotificationRecipient


@admin.register(FCMDevice)
class FCMDeviceAdmin(admin.ModelAdmin):
    list_display = ("user", "platform", "is_active", "last_used_at")
    list_filter = ("platform", "is_active")
    search_fields = ("user__email", "token", "device_id")


class NotificationRecipientInline(admin.TabularInline):
    model = NotificationRecipient
    extra = 0
    readonly_fields = ("user", "is_read", "read_at", "delivered", "created_at")
    fields = readonly_fields

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = (
        "title", "category", "target_type", "is_urgent",
        "total_recipients", "success_count", "failure_count", "sent_at",
    )
    list_filter = ("category", "target_type", "is_urgent")
    search_fields = ("title", "message")
    readonly_fields = ("total_recipients", "success_count", "failure_count", "sent_at")
    inlines = [NotificationRecipientInline]


@admin.register(Announcement)
class AnnouncementAdmin(admin.ModelAdmin):
    list_display = ("title", "category", "priority", "status", "author", "published_at", "expires_at")
    list_filter = ("category", "priority", "status", "target_type")
    search_fields = ("title", "content")
    date_hierarchy = "created_at"
