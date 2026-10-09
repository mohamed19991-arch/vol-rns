/// Version courte d'une destination (imbriquee dans les vols).
class DestinationBrief {
  const DestinationBrief({
    required this.id,
    required this.code,
    required this.name,
    this.city = '',
  });

  final int id;
  final String code;
  final String name;
  final String city;

  factory DestinationBrief.fromJson(Map<String, dynamic> json) {
    return DestinationBrief(
      id: (json['id'] as num).toInt(),
      code: (json['code'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      city: (json['city'] ?? '') as String,
    );
  }

  String get display => city.isNotEmpty ? '$code — $city' : '$code — $name';
}

/// Destination (aéroport / ville) complète.
class Destination {
  const Destination({
    required this.id,
    required this.code,
    required this.name,
    this.city = '',
    this.airportName = '',
    this.country = '',
    this.isActive = true,
  });

  final int id;
  final String code;
  final String name;
  final String city;
  final String airportName;
  final String country;
  final bool isActive;

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: (json['id'] as num).toInt(),
      code: (json['code'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      airportName: (json['airport_name'] ?? '') as String,
      country: (json['country'] ?? '') as String,
      isActive: (json['is_active'] ?? true) as bool,
    );
  }

  DestinationBrief get brief =>
      DestinationBrief(id: id, code: code, name: name, city: city);

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'city': city,
        'airport_name': airportName,
        'country': country,
        'is_active': isActive,
      };
}
