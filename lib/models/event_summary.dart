import 'package:flutter/foundation.dart';
import '../utils/location_assets.dart';  // ← import your asset map

extension TakeIfExtension<T> on T {
  T? takeIf(bool Function(T) test) => test(this) ? this : null;
}

enum SessionType { Ages8to11, Ages12to15, Adults }

/// Turn a raw (int or String) into our enum.
SessionType sessionTypeFromRaw(dynamic raw) {
  if (raw is int && raw >= 0 && raw < SessionType.values.length) {
    return SessionType.values[raw];
  } else if (raw is String) {
    // fallback if ever you get the literal name
    return SessionType.values.firstWhere(
      (e) => describeEnum(e).toLowerCase() == raw.toLowerCase(),
      orElse: () => SessionType.Ages8to11,
    );
  }
  // default
  return SessionType.Ages8to11;
}

/// Make a human label out of it:
String friendlySession(SessionType s) {
  switch (s) {
    case SessionType.Ages8to11:
      return 'Ages 8 to 11';
    case SessionType.Ages12to15:
      return 'Ages 12 to 15';
    case SessionType.Adults:
      return 'Ages 16+';
  }
}

enum EventStatus { Available, Unavailable, Cancelled, Concluded }

EventStatus statusFromRaw(int raw) {
  switch (raw) {
    case 1:
      return EventStatus.Unavailable;
    case 2:
      return EventStatus.Cancelled;
    case 3:
      return EventStatus.Concluded;
    case 0:
    default:
      return EventStatus.Available;
  }
}

class EventSummary {
  final int eventId;
  final SessionType sessionType;
  final DateTime startDate;
  final String startTime;
  final String endTime;
  final String locationName;
  final int totalSeats;
  final int availableSeats;
  final EventStatus status;
  final String? seatingMapImgSrc; // optional image URL for seating map

  EventSummary({
    required this.eventId,
    required this.sessionType,
    required this.startDate,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    required this.totalSeats,
    required this.availableSeats,
    required this.status,
    this.seatingMapImgSrc,
  });

  /// The Flutter‐asset path for this summary’s location icon
  String get locationAssetPath =>
      locationAssetMap[locationName] ?? defaultLocationAsset;

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    int intOrZero(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return EventSummary(
      eventId: intOrZero(json['eventId']),
      sessionType: sessionTypeFromRaw(json['sessionType']),
      startDate: DateTime.parse(json['startDate'] as String),
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      totalSeats: intOrZero(json['totalSeatsCount'] ?? json['totalSeats']),
      availableSeats: intOrZero(json['availbleSeatsCount']),
      status: statusFromRaw(intOrZero(json['status'])),
      seatingMapImgSrc:
          (json['seatingMapImgSrc'] as String?)?.takeIf((s) => s.isNotEmpty),
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'sessionType': describeEnum(sessionType),
        'startDate': startDate.toIso8601String(),
        'startTime': startTime,
        'endTime': endTime,
        'locationName': locationName,
        'totalSeatsCount': totalSeats,
        'availableSeatsCount': availableSeats,
        'status': EventStatus.values.indexOf(status),
        'seatingMapImgSrc': seatingMapImgSrc,
      };
}
