import 'package:intl/intl.dart';

/// Formatage des dates et heures.
///
/// Regle metier : format de date JJ/MM/AAAA et heures sur 24 heures (HH:mm).
/// Le fuseau horaire est Africa/Algiers cote serveur ; l'application affiche
/// les valeurs telles qu'envoyees par le backend (aucun calcul de fuseau cote
/// client).
class Formatters {
  Formatters._();

  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  /// Formate une date ISO (`2026-03-14` ou ISO 8601 complet).
  static String formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parsed = _tryParse(iso);
    if (parsed == null) return iso;
    return _date.format(parsed);
  }

  /// Formate un couple date/heure ISO 8601.
  static String formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parsed = _tryParse(iso);
    if (parsed == null) return iso;
    return _dateTime.format(parsed);
  }

  /// Normalise une heure backend (`08:30:00` ou `08:30`) en `HH:mm`.
  static String formatTime(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.length >= 5 && value.contains(':')) {
      return value.substring(0, 5);
    }
    return value;
  }

  static String formatDateObj(DateTime? date) {
    if (date == null) return '';
    return _date.format(date);
  }

  /// Convertit un `DateTime` en chaine `AAAA-MM-JJ` (parametre API).
  static String toApiDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Convertit une heure `HH:mm` (saisie utilisateur).
  static String toApiTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static DateTime? _tryParse(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
}
