from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from apps.core.models import AuditLog

from .models import Profile

User = get_user_model()


class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Profile
        fields = (
            "matricule",
            "position",
            "language",
            "phone",
            "receive_push",
            "receive_email",
        )


class UserSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)
    profile = ProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "first_name",
            "last_name",
            "full_name",
            "phone",
            "role",
            "is_active",
            "is_staff",
            "date_joined",
            "profile",
        )
        read_only_fields = ("id", "date_joined", "is_staff")


class UserCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, style={"input_type": "password"})
    profile = ProfileSerializer(required=False)

    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "first_name",
            "last_name",
            "phone",
            "role",
            "is_active",
            "password",
            "profile",
        )
        read_only_fields = ("id",)

    def validate_password(self, value):
        validate_password(value)
        return value

    def validate_role(self, value):
        request = self.context.get("request")
        actor = getattr(request, "user", None)
        # Un agent ne peut pas creer d'administrateur.
        if actor is not None and not actor.is_admin and value == User.Role.ADMIN:
            raise serializers.ValidationError(
                "Seul un administrateur peut creer un compte administrateur."
            )
        return value

    def create(self, validated_data):
        profile_data = validated_data.pop("profile", {})
        password = validated_data.pop("password")
        user = User.objects.create_user(password=password, **validated_data)
        Profile.objects.update_or_create(user=user, defaults=profile_data)
        return user


class UserUpdateSerializer(serializers.ModelSerializer):
    profile = ProfileSerializer(required=False)

    class Meta:
        model = User
        fields = (
            "first_name",
            "last_name",
            "phone",
            "role",
            "is_active",
            "profile",
        )

    def update(self, instance, validated_data):
        profile_data = validated_data.pop("profile", None)
        request = self.context.get("request")
        actor = getattr(request, "user", None)

        # Un agent ne peut pas s'octroyer le role administrateur.
        if "role" in validated_data and actor is not None:
            if not actor.is_admin and validated_data["role"] == User.Role.ADMIN:
                raise serializers.ValidationError(
                    {"role": "Seul un administrateur peut attribuer ce role."}
                )

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if profile_data is not None:
            Profile.objects.update_or_create(user=instance, defaults=profile_data)
        return instance


class MeSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)
    profile = ProfileSerializer()

    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "first_name",
            "last_name",
            "full_name",
            "phone",
            "role",
            "date_joined",
            "profile",
        )
        read_only_fields = ("id", "email", "role", "date_joined")

    def update(self, instance, validated_data):
        profile_data = validated_data.pop("profile", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if profile_data is not None:
            Profile.objects.update_or_create(user=instance, defaults=profile_data)
        return instance


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, style={"input_type": "password"})

    def validate(self, attrs):
        email = attrs.get("email", "").lower().strip()
        password = attrs.get("password")
        user = authenticate(request=self.context.get("request"), username=email, password=password)
        if user is None:
            # Message volontairement generique pour ne pas divulguer
            # l'existence d'un compte.
            raise serializers.ValidationError(
                {"detail": "Adresse e-mail ou mot de passe incorrect."}
            )
        if not user.is_active:
            raise serializers.ValidationError({"detail": "Ce compte est desactive."})
        attrs["user"] = user
        return attrs


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True)

    def validate_old_password(self, value):
        user = self.context["request"].user
        if not user.check_password(value):
            raise serializers.ValidationError("L'ancien mot de passe est incorrect.")
        return value

    def validate_new_password(self, value):
        validate_password(value, self.context["request"].user)
        return value

    def save(self, **kwargs):
        user = self.context["request"].user
        user.set_password(self.validated_data["new_password"])
        user.save(update_fields=["password"])
        return user


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()
    new_password = serializers.CharField(write_only=True)

    def validate_new_password(self, value):
        validate_password(value)
        return value


class AuditLogSerializer(serializers.ModelSerializer):
    user_email = serializers.EmailField(source="user.email", read_only=True, default="")

    class Meta:
        model = AuditLog
        fields = (
            "id",
            "user",
            "user_email",
            "action",
            "entity_type",
            "entity_id",
            "description",
            "metadata",
            "ip_address",
            "created_at",
        )
        read_only_fields = fields
