class MedicalCondition {
  final int id;
  final String name;
  final String? notes;
  final bool isAllergy;

  MedicalCondition({
    required this.id,
    required this.name,
    required this.notes,
    required this.isAllergy,
  });

  factory MedicalCondition.fromJson(Map<String, dynamic> j) => MedicalCondition(
        id: (j['id'] ?? j['Id'] ?? 0) as int,
        name: (j['name'] ?? j['Name'] ?? '').toString(),
        notes: (j['notes'] ?? j['Notes'])?.toString(),
        isAllergy: j['isAllergy'] == true,
      );
}