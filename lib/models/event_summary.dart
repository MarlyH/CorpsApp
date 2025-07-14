// lib/models/event_summary.dart

import 'package:flutter/foundation.dart';

extension TakeIfExtension<T> on T {
  T? takeIf(bool Function(T) test) => test(this) ? this : null;
}

enum SessionType { Ages8to11, Ages12to15 }
SessionType sessionTypeFromRaw(dynamic raw) {
  if (raw is int) {
    return SessionType.values[raw.clamp(0, SessionType.values.length - 1)];
  } else if (raw is String) {
    return SessionType.values.firstWhere(
      (e) => describeEnum(e).toLowerCase() == raw.toLowerCase(),
      orElse: () => SessionType.Ages8to11,
    );
  }
  return SessionType.Ages8to11;
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
  final int         eventId;          // ← guaranteed non-null
  final SessionType sessionType;
  final DateTime    startDate;        // ← guaranteed non-null
  final String      startTime;
  final String      endTime;
  final String      locationName;
  final int         totalSeats;
  final int         availableSeats;
  final EventStatus status;
  final String?     seatingMapImgSrc; // optional

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

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    int _intOrZero(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return EventSummary(
      eventId:        _intOrZero(json['eventId']),
      sessionType:    sessionTypeFromRaw(json['sessionType']),
      startDate:      DateTime.parse(json['startDate'] as String),
      startTime:      json['startTime'] as String? ?? '',
      endTime:        json['endTime']   as String? ?? '',
      locationName:   json['locationName'] as String? ?? '',
      totalSeats:     _intOrZero(json['totalSeatsCount'] ?? json['totalSeats']),
      availableSeats: _intOrZero(json['availbleSeatsCount']),
      status:         statusFromRaw(_intOrZero(json['status'])),
      seatingMapImgSrc:
        (json['seatingMapImgSrc'] as String?)
          ?.takeIf((s) => s.isNotEmpty),
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId':            eventId,
        'sessionType':        describeEnum(sessionType),
        'startDate':          startDate.toIso8601String(),
        'startTime':          startTime,
        'endTime':            endTime,
        'locationName':       locationName,
        'totalSeatsCount':    totalSeats,
        'availbleSeatsCount': availableSeats,
        'status':             EventStatus.values.indexOf(status),
        'seatingMapImgSrc':   seatingMapImgSrc,
      };
}
