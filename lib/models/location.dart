class Location {
  final int id;
  final String name;

  Location({required this.id, required this.name});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id:   json['locationId'] as int,
      name: json['name']       as String,
    );
  }
}