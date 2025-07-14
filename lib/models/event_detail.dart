class EventDetail {
  final int eventId;
  final String description;
  final String address;
  final String locationName;
  final int totalSeats;
  final List<int> availableSeats;
  final String seatingMapImgSrc;

  EventDetail({
    required this.eventId,
    required this.description,
    required this.address,
    required this.locationName,
    required this.totalSeats,
    required this.availableSeats,
    required this.seatingMapImgSrc,
  });

  factory EventDetail.fromJson(Map<String, dynamic> json) {
    return EventDetail(
      eventId: json['eventId'] as int,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      totalSeats: json['totalSeatsCount'] as int? ?? 0,
      availableSeats: (json['availableSeats'] as List<dynamic>?)
              ?.cast<int>()
              .toList() ??
          [],
      seatingMapImgSrc: json['seatingMapImgSrc'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'description': description,
        'address': address,
        'locationName': locationName,
        'totalSeatsCount': totalSeats,
        'availableSeats': availableSeats,
        'seatingMapImgSrc': seatingMapImgSrc,
      };
}
