/// Libelles francais des valeurs de l'API (statuts, roles, cibles...).
class AppConstants {
  AppConstants._();

  // -------------------------------------------------------------------------
  // Roles
  // -------------------------------------------------------------------------
  static const String roleAdmin = 'admin';
  static const String roleAgent = 'agent';
  static const String roleWorker = 'worker';

  static const Map<String, String> roleLabels = {
    'admin': 'Administrateur',
    'agent': 'Agent',
    'worker': 'Travailleur',
  };

  static String roleLabel(String? role) => roleLabels[role] ?? (role ?? '');

  // -------------------------------------------------------------------------
  // Statuts de vol
  // -------------------------------------------------------------------------
  static const String statusScheduled = 'scheduled';
  static const String statusCheckinOpen = 'checkin_open';
  static const String statusDelayed = 'delayed';
  static const String statusRescheduled = 'rescheduled';
  static const String statusPostponed = 'postponed';
  static const String statusCancelled = 'cancelled';
  static const String statusBoarding = 'boarding';
  static const String statusDeparted = 'departed';
  static const String statusArrived = 'arrived';

  static const Map<String, String> flightStatusLabels = {
    'scheduled': 'Programmé',
    'checkin_open': 'Enregistrement ouvert',
    'delayed': 'Retardé',
    'rescheduled': 'Horaire modifié',
    'postponed': 'Reporté',
    'cancelled': 'Annulé',
    'boarding': 'Embarquement en cours',
    'departed': 'Décollé',
    'arrived': 'Arrivé',
  };

  static String flightStatusLabel(String? status) {
    if (status == null) return '';
    return flightStatusLabels[status] ?? status;
  }

  static const List<String> flightStatuses = [
    'scheduled',
    'checkin_open',
    'delayed',
    'rescheduled',
    'postponed',
    'cancelled',
    'boarding',
    'departed',
    'arrived',
  ];

  // -------------------------------------------------------------------------
  // Jours de la semaine (convention backend : lundi = 0, dimanche = 6)
  // Ordre d'affichage metier : samedi -> vendredi.
  // -------------------------------------------------------------------------
  static const Map<int, String> dayLabels = {
    0: 'Lundi',
    1: 'Mardi',
    2: 'Mercredi',
    3: 'Jeudi',
    4: 'Vendredi',
    5: 'Samedi',
    6: 'Dimanche',
  };

  static const List<int> weekDisplayOrder = [5, 6, 0, 1, 2, 3, 4];

  static String dayLabel(int? day) => dayLabels[day] ?? '';

  // -------------------------------------------------------------------------
  // Categories d'annonce
  // -------------------------------------------------------------------------
  static const Map<String, String> announcementCategoryLabels = {
    'general': 'Général',
    'operation': 'Opérationnel',
    'maintenance': 'Maintenance',
    'security': 'Sécurité',
    'hr': 'Ressources humaines',
    'other': 'Autre',
  };

  static const Map<String, String> announcementPriorityLabels = {
    'low': 'Basse',
    'normal': 'Normale',
    'high': 'Haute',
    'urgent': 'Urgente',
  };

  static const Map<String, String> announcementStatusLabels = {
    'draft': 'Brouillon',
    'published': 'Publiée',
  };

  // -------------------------------------------------------------------------
  // Categories de notification
  // -------------------------------------------------------------------------
  static const Map<String, String> notificationCategoryLabels = {
    'new_flight': 'Nouveau vol publié',
    'registration_time_changed': 'Modification de l\'enregistrement',
    'departure_time_changed': 'Modification du décollage',
    'delay': 'Retard',
    'postpone': 'Report',
    'cancellation': 'Annulation',
    'boarding': 'Embarquement en cours',
    'arrival': 'Information d\'arrivée',
    'announcement': 'Annonce administrative',
    'urgent': 'Information urgente',
    'schedule_change': 'Changement de programme',
  };

  // -------------------------------------------------------------------------
  // Types de cible (notifications & annonces)
  // -------------------------------------------------------------------------
  static const Map<String, String> targetTypeLabels = {
    'all_workers': 'Tous les travailleurs',
    'destination': 'Intéressés par une destination',
    'route': 'Intéressés par un trajet',
    'flight': 'Concernés par un vol précis',
    'user': 'Utilisateur précis',
    'role': 'Par rôle',
  };

  // -------------------------------------------------------------------------
  // Types de favori
  // -------------------------------------------------------------------------
  static const Map<String, String> favoriteTypeLabels = {
    'destination': 'Destination',
    'route': 'Trajet',
    'flight': 'Vol',
  };

  // -------------------------------------------------------------------------
  // Types de changement (historique de vol)
  // -------------------------------------------------------------------------
  static const Map<String, String> changeTypeLabels = {
    'created': 'Création',
    'time_changed': 'Horaire modifié',
    'status_changed': 'Statut modifié',
    'delayed': 'Retard',
    'postponed': 'Report',
    'cancelled': 'Annulation',
    'observation': 'Observation',
  };

  // -------------------------------------------------------------------------
  // Libelles de champs (historique)
  // -------------------------------------------------------------------------
  static const Map<String, String> fieldLabels = {
    'registration_time': 'Heure d\'enregistrement',
    'departure_time': 'Heure de décollage',
    'arrival_time': 'Heure d\'arrivée',
    'status': 'Statut',
    'observation': 'Observation',
    'flight_date': 'Date du vol',
  };

  static String labelFromMap(Map<String, String> map, String? key) {
    if (key == null) return '';
    return map[key] ?? key;
  }
}
