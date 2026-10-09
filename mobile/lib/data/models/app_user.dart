import '../../core/constants.dart';
import 'profile.dart';

/// Utilisateur connecte (objet renvoye par le backend).
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.phone = '',
    required this.role,
    this.isActive = true,
    this.dateJoined,
    this.profile = const Profile(),
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phone;

  /// Role attribue par le backend ; JAMAIS choisi par le client.
  final String role;
  final bool isActive;
  final String? dateJoined;
  final Profile profile;

  bool get isAdmin => role == AppConstants.roleAdmin;
  bool get isAgent => role == AppConstants.roleAgent;
  bool get isWorker => role == AppConstants.roleWorker;

  /// Un agent (ou administrateur) peut gerer les vols et les annonces.
  /// Le backend reste toutefois l'autorite en matiere de permissions.
  bool get canManage => isAdmin || isAgent;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num).toInt(),
      email: (json['email'] ?? '') as String,
      firstName: (json['first_name'] ?? '') as String,
      lastName: (json['last_name'] ?? '') as String,
      fullName: (json['full_name'] ?? json['email'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      role: (json['role'] ?? AppConstants.roleWorker) as String,
      isActive: (json['is_active'] ?? true) as bool,
      dateJoined: json['date_joined'] as String?,
      profile: Profile.fromJson(json['profile'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'full_name': fullName,
        'phone': phone,
        'role': role,
        'is_active': isActive,
        'date_joined': dateJoined,
        'profile': profile.toJson(),
      };

  String get roleLabel => AppConstants.roleLabel(role);

  AppUser copyWith({Profile? profile}) => AppUser(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        fullName: fullName,
        phone: phone,
        role: role,
        isActive: isActive,
        dateJoined: dateJoined,
        profile: profile ?? this.profile,
      );
}
