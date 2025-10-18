class MedicalItem {
  MedicalItem({required this.name, this.notes = '', this.isAllergy = false});
  String name;
  String notes;
  bool isAllergy;

  factory MedicalItem.fromJson(Map<String, dynamic> j) => MedicalItem(
      name: (j['name'] ?? '').toString(),
      notes: (j['notes'] ?? '').toString(),
      isAllergy: (j['isAllergy'] as bool?) ?? false,
    );

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'notes': notes.trim(),
        'isAllergy': isAllergy,
      };
}