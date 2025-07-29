import 'package:flutter/foundation.dart';

enum SessionType { Ages8to11, Ages12to15, Adults }
enum EventStatus  { Available, Unavailable, Cancelled, Concluded }

SessionType sessionTypeFromRaw(dynamic raw) {
  if (raw is int && raw >= 0 && raw < SessionType.values.length) {
    return SessionType.values[raw];
  }
  if (raw is String) {
    return SessionType.values.firstWhere(
      (e) => describeEnum(e).toLowerCase() == raw.toLowerCase(),
      orElse: () => SessionType.Ages8to11,
    );
  }
  return SessionType.Ages8to11;
}

EventStatus statusFromRaw(int raw) {
  switch (raw) {
    case 1: return EventStatus.Unavailable;
    case 2: return EventStatus.Cancelled;
    case 3: return EventStatus.Concluded;
    case 0:
    default: return EventStatus.Available;
  }
}

String friendlySession(SessionType s) {
  switch (s) {
    case SessionType.Ages8to11: return 'Ages 8 to 11';
    case SessionType.Ages12to15: return 'Ages 12 to 15';
    case SessionType.Adults:     return 'Ages 16+';
  }
}

class EventSummary {
  final int          eventId;
  final int          locationId;
  final String       locationName;
  final SessionType  sessionType;
  final DateTime     startDate;
  final String       startTime;
  final String       endTime;
  final int          totalSeats;
  final int          availableSeatsCount;
  final List<int>    availableSeats;
  final EventStatus  status;
  final String?      seatingMapImgSrc;
  final String?      mascotImgSrc;

  EventSummary({
    required this.eventId,
    required this.locationId,
    required this.locationName,
    required this.sessionType,
    required this.startDate,
    required this.startTime,
    required this.endTime,
    required this.totalSeats,
    required this.availableSeatsCount,
    required this.availableSeats,
    required this.status,
    this.seatingMapImgSrc,
    this.mascotImgSrc,
  });

  /// handy for `Image.network(mascotUrl)` or placeholder fallback
  String? get mascotUrl => mascotImgSrc;

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final rawSeats = (json['availableSeats'] as List<dynamic>?) ?? [];

    return EventSummary(
      eventId             : toInt(json['eventId']),
      locationId          : toInt(json['locationId']),
      locationName        : json['locationName'] as String? ?? '',
      sessionType         : sessionTypeFromRaw(json['sessionType']),
      startDate           : DateTime.parse(json['startDate'] as String),
      startTime           : json['startTime'] as String? ?? '',
      endTime             : json['endTime']   as String? ?? '',
      totalSeats          : toInt(json['totalSeatsCount'] ?? json['totalSeats']),
      availableSeatsCount : toInt(json['availableSeatsCount'] ?? json['availbleSeatsCount']),
      availableSeats      : rawSeats.map((e) => toInt(e)).toList(),
      status              : statusFromRaw(toInt(json['status'])),
      seatingMapImgSrc    : (json['seatingMapImgSrc'] as String?)?.takeIf((s) => s.isNotEmpty),
      mascotImgSrc        : (json['mascotImgSrc']    as String?)?.takeIf((s) => s.isNotEmpty),
    );
  }

  Map<String, dynamic> toJson() => {
    'eventId'             : eventId,
    'locationId'          : locationId,
    'locationName'        : locationName,
    'sessionType'         : describeEnum(sessionType),
    'startDate'           : startDate.toIso8601String(),
    'startTime'           : startTime,
    'endTime'             : endTime,
    'totalSeatsCount'     : totalSeats,
    'availableSeatsCount' : availableSeatsCount,
    'availableSeats'      : availableSeats,
    'status'              : EventStatus.values.indexOf(status),
    'seatingMapImgSrc'    : seatingMapImgSrc,
    'mascotImgSrc'        : mascotImgSrc,
  };
}

extension _TakeIf<T> on T {
  T? takeIf(bool Function(T) test) => test(this) ? this : null;
}
