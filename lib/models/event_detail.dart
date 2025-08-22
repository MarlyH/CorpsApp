import 'package:flutter/foundation.dart';

// Mirrors server‐side enum EventSessionType
enum SessionType { Kids, Teens, Adults }

SessionType sessionTypeFromRaw(dynamic raw) {
  if (raw is int && raw >= 0 && raw < SessionType.values.length) {
    return SessionType.values[raw];
  }
  if (raw is String) {
    return SessionType.values.firstWhere(
      (e) => describeEnum(e).toLowerCase() == raw.toLowerCase(),
      orElse: () => SessionType.Kids,
    );
  }
  return SessionType.Kids;
}

String friendlySession(SessionType s) {
  switch (s) {
    case SessionType.Kids:
      return 'Ages 8 to 11';
    case SessionType.Teens:
      return 'Ages 12 to 15';
    case SessionType.Adults:
      return 'Ages 16+';
  }
}

// Full detail for GET /api/events/{id}
class EventDetail {
  final String description;
  final String address;
  final String? seatingMapImgSrc;
  final SessionType sessionType;
  final DateTime startDate;
  final String startTime; // "HH:mm:ss"
  final String endTime;   // "HH:mm:ss"
  final List<int> availableSeats;

  // NEW: total seats (nullable to be safe if backend omits it)
  final int? totalSeats;

  EventDetail({
    required this.description,
    required this.address,
    this.seatingMapImgSrc,
    required this.sessionType,
    required this.startDate,
    required this.startTime,
    required this.endTime,
    required this.availableSeats,
    this.totalSeats,
  });

  factory EventDetail.fromJson(Map<String, dynamic> json) {
    final seatsJson = (json['availableSeats'] as List<dynamic>?) ?? const <dynamic>[];
    final seats = seatsJson.cast<int>();

    return EventDetail(
      description : json['description'] as String? ?? '',
      address     : json['address'] as String? ?? '',
      seatingMapImgSrc : json['seatingMapImgSrc'] as String?,
      sessionType : sessionTypeFromRaw(json['sessionType']),
      startDate   : DateTime.parse(json['startDate'] as String),
      startTime   : json['startTime'] as String? ?? '',
      endTime     : json['endTime'] as String? ?? '',
      availableSeats : seats,

      // parse totalSeats if present
      totalSeats  : (json['totalSeats'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description' : description,
      'address'     : address,
      if (seatingMapImgSrc != null) 'seatingMapImgSrc': seatingMapImgSrc,
      'sessionType' : SessionType.values.indexOf(sessionType),
      'startDate'   : startDate.toIso8601String(),
      'startTime'   : startTime,
      'endTime'     : endTime,
      'availableSeats': availableSeats,
      if (totalSeats != null) 'totalSeats': totalSeats,
    };
  }
}
