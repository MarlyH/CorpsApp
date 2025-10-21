import 'package:corpsapp/models/session_type_helper.dart';
import 'package:flutter/foundation.dart';

enum EventStatus  { available, unavailable, cancelled, concluded }

SessionType sessionTypeFromRaw(dynamic raw) {
  if (raw is int && raw >= 0 && raw < SessionType.values.length) {
    return SessionType.values[raw];
  }
  if (raw is String) {
    return SessionType.values.firstWhere(
      (e) => describeEnum(e).toLowerCase() == raw.toLowerCase(),
      orElse: () => SessionType.ages8to11,
    );
  }
  return SessionType.ages8to11;
}

EventStatus statusFromRaw(int raw) {
  switch (raw) {
    case 1: return EventStatus.unavailable;
    case 2: return EventStatus.cancelled;
    case 3: return EventStatus.concluded;
    case 0:
    default: return EventStatus.available;
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
  final String?      locationMascotImgSrc;

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
    this.locationMascotImgSrc,
  });

  /// handy for `Image.network(mascotUrl)` or placeholder fallback
  String? get mascotUrl => locationMascotImgSrc;

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
      locationMascotImgSrc        : (json['locationMascotImgSrc']    as String?)?.takeIf((s) => s.isNotEmpty),
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
    'locationMascotImgSrc'        : locationMascotImgSrc,
  };
}

extension _TakeIf<T> on T {
  T? takeIf(bool Function(T) test) => test(this) ? this : null;
}
