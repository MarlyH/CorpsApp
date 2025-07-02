class ChildModel {
  final int childId;
  final String firstName;
  final String lastName;
  final String dateOfBirth; // Expected format: YYYY-MM-DD
  final String emergencyContactName;
  final String emergencyContactPhone;
  final int age;
  final String ageGroup;
  final String ageGroupLabel;

  const ChildModel({
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.age,
    required this.ageGroup,
    required this.ageGroupLabel,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      childId: json['childId'] as int,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      dateOfBirth: json['dateOfBirth'] ?? '',
      emergencyContactName: json['emergencyContactName'] ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] ?? '',
      age: json['age'] ?? 0,
      ageGroup: json['ageGroup'] ?? '',
      ageGroupLabel: json['ageGroupLabel'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'childId': childId,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'age': age,
      'ageGroup': ageGroup,
      'ageGroupLabel': ageGroupLabel,
    };
  }

  ChildModel copyWith({
    int? childId,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? emergencyContactName,
    String? emergencyContactPhone,
    int? age,
    String? ageGroup,
    String? ageGroupLabel,
  }) {
    return ChildModel(
      childId: childId ?? this.childId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      emergencyContactName:
          emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      age: age ?? this.age,
      ageGroup: ageGroup ?? this.ageGroup,
      ageGroupLabel: ageGroupLabel ?? this.ageGroupLabel,
    );
  }
}
