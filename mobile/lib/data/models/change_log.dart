/// Entree de l'historique des modifications d'un vol.
class ChangeLog {
  const ChangeLog({
    required this.id,
    required this.changeType,
    required this.changeTypeLabel,
    this.fieldName = '',
    this.oldValue = '',
    this.newValue = '',
    this.note = '',
    this.changedByEmail = '',
    this.createdAt,
  });

  final int id;
  final String changeType;
  final String changeTypeLabel;
  final String fieldName;
  final String oldValue;
  final String newValue;
  final String note;
  final String changedByEmail;
  final String? createdAt;

  factory ChangeLog.fromJson(Map<String, dynamic> json) {
    return ChangeLog(
      id: (json['id'] as num).toInt(),
      changeType: (json['change_type'] ?? '') as String,
      changeTypeLabel: (json['change_type_label'] ?? '') as String,
      fieldName: (json['field_name'] ?? '') as String,
      oldValue: (json['old_value'] ?? '') as String,
      newValue: (json['new_value'] ?? '') as String,
      note: (json['note'] ?? '') as String,
      changedByEmail: (json['changed_by_email'] ?? '') as String,
      createdAt: json['created_at'] as String?,
    );
  }
}
