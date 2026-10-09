/// Profil et preferences d'un utilisateur.
class Profile {
  const Profile({
    this.matricule = '',
    this.position = '',
    this.language = 'fr',
    this.phone = '',
    this.receivePush = true,
    this.receiveEmail = false,
  });

  final String matricule;
  final String position;
  final String language;
  final String phone;
  final bool receivePush;
  final bool receiveEmail;

  factory Profile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Profile();
    return Profile(
      matricule: (json['matricule'] ?? '') as String,
      position: (json['position'] ?? '') as String,
      language: (json['language'] ?? 'fr') as String,
      phone: (json['phone'] ?? '') as String,
      receivePush: (json['receive_push'] ?? true) as bool,
      receiveEmail: (json['receive_email'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'matricule': matricule,
        'position': position,
        'language': language,
        'phone': phone,
        'receive_push': receivePush,
        'receive_email': receiveEmail,
      };

  Profile copyWith({
    String? matricule,
    String? position,
    String? language,
    String? phone,
    bool? receivePush,
    bool? receiveEmail,
  }) {
    return Profile(
      matricule: matricule ?? this.matricule,
      position: position ?? this.position,
      language: language ?? this.language,
      phone: phone ?? this.phone,
      receivePush: receivePush ?? this.receivePush,
      receiveEmail: receiveEmail ?? this.receiveEmail,
    );
  }
}
