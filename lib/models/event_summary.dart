import 'dart:convert';

import 'package:corpsapp/models/session_type_helper.dart';
import 'package:flutter/foundation.dart';

enum EventStatus { available, unavailable, cancelled, concluded }

enum EventCategory { bookable, announcement, promotional }

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
    case 1:
      return EventStatus.unavailable;
    case 2:
      return EventStatus.cancelled;
    case 3:
      return EventStatus.concluded;
    case 0:
    default:
      return EventStatus.available;
  }
}

EventCategory categoryFromRaw(dynamic raw) {
  if (raw is int) {
    switch (raw) {
      case 1:
        return EventCategory.announcement;
      case 2:
        return EventCategory.promotional;
      case 0:
      default:
        return EventCategory.bookable;
    }
  }
  if (raw is String) {
    final normalized =
        raw
            .trim()
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('_', '')
            .replaceAll('-', '');
    if (normalized.contains('promo')) return EventCategory.promotional;
    if (normalized.contains('announce') ||
        normalized.contains('content') ||
        normalized.contains('custom')) {
      return EventCategory.announcement;
    }
    return EventCategory.bookable;
  }
  return EventCategory.bookable;
}

bool? _boolFromRaw(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final v = raw.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return null;
}

DateTime? _dateFromRaw(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

class EventSummary {
  final int eventId;
  final int locationId;
  final String locationName;
  final String title;
  final EventCategory category;
  final bool requiresBooking;
  final SessionType sessionType;
  final DateTime startDate;
  final DateTime? endDate;
  final String startTime;
  final String endTime;
  final int totalSeats;
  final int availableSeatsCount;
  final List<int> availableSeats;
  final EventStatus status;
  final String? seatingMapImgSrc;
  final String? locationMascotImgSrc;
  final String? eventImageImgSrc;
  final List<String> eventImageImgSrcs;
  final int? createdByUserId;
  final String? createdByEmail;

  EventSummary({
    required this.eventId,
    required this.locationId,
    required this.locationName,
    required this.title,
    required this.category,
    required this.requiresBooking,
    required this.sessionType,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.totalSeats,
    required this.availableSeatsCount,
    required this.availableSeats,
    required this.status,
    this.seatingMapImgSrc,
    this.locationMascotImgSrc,
    this.eventImageImgSrc,
    this.eventImageImgSrcs = const [],
    this.createdByUserId,
    this.createdByEmail,
  });

  String? get mascotUrl => locationMascotImgSrc;
  String? get eventImageUrl => eventImageImgSrc;
  List<String> get eventImageUrls =>
      eventImageImgSrcs.isNotEmpty
          ? eventImageImgSrcs
          : (eventImageImgSrc == null ? const [] : [eventImageImgSrc!]);
  bool get isPromotional => category == EventCategory.promotional;
  bool get isAnnouncement => category == EventCategory.announcement;
  DateTime get toDate => endDate ?? startDate;
  String get displayTitle => title.trim().isEmpty ? locationName : title.trim();

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final rawSeats = (json['availableSeats'] as List<dynamic>?) ?? [];
    final eventImageUrls = _stringListFromRaw(json['eventImageImgSrcs']);
    final legacyEventImage =
        (json['eventImageImgSrc'] as String?)?.takeIf((s) => s.isNotEmpty);
    if (eventImageUrls.isEmpty && legacyEventImage != null) {
      eventImageUrls.add(legacyEventImage);
    }
    final category = categoryFromRaw(json['eventCategory'] ?? json['category']);
    final requiresBooking =
        _boolFromRaw(json['requiresBooking']) ??
        (category == EventCategory.bookable);

    final startDate =
        _dateFromRaw(json['startDate']) ??
        _dateFromRaw(json['fromDate']) ??
        DateTime.now();
    final endDate =
        _dateFromRaw(json['endDate']) ?? _dateFromRaw(json['toDate']);

    final sessionTypeRaw = json['sessionType'];
    final sessionType =
        sessionTypeRaw == null && !requiresBooking
            ? SessionType.all
            : sessionTypeFromRaw(sessionTypeRaw);

    return EventSummary(
      eventId: toInt(json['eventId']),
      locationId: toInt(json['locationId']),
      locationName: json['locationName'] as String? ?? '',
      title:
          (json['title'] as String?) ??
          (json['eventTitle'] as String?) ??
          '',
      category: category,
      requiresBooking: requiresBooking,
      sessionType: sessionType,
      startDate: startDate,
      endDate: endDate,
      startTime:
          (json['startTime'] as String?) ??
          (json['fromTime'] as String?) ??
          '',
      endTime: (json['endTime'] as String?) ?? (json['toTime'] as String?) ?? '',
      totalSeats: toInt(json['totalSeatsCount'] ?? json['totalSeats']),
      availableSeatsCount: toInt(
        json['availableSeatsCount'] ?? json['availbleSeatsCount'],
      ),
      availableSeats: rawSeats.map((e) => toInt(e)).toList(),
      status: statusFromRaw(toInt(json['status'])),
      seatingMapImgSrc:
          (json['seatingMapImgSrc'] as String?)?.takeIf((s) => s.isNotEmpty),
      locationMascotImgSrc:
          (json['locationMascotImgSrc'] as String?)?.takeIf((s) => s.isNotEmpty),
      eventImageImgSrc: eventImageUrls.isNotEmpty ? eventImageUrls.first : null,
      eventImageImgSrcs: eventImageUrls,
      createdByUserId: _intOrNull(
        json['createdByUserId'] ?? json['createdById'] ?? json['creatorUserId'],
      ),
      createdByEmail:
          (json['createdByEmail'] as String?) ??
          (json['createdBy'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'locationId': locationId,
    'locationName': locationName,
    'title': title,
    'eventCategory': describeEnum(category),
    'requiresBooking': requiresBooking,
    'sessionType': describeEnum(sessionType),
    'startDate': startDate.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    'startTime': startTime,
    'endTime': endTime,
    'totalSeatsCount': totalSeats,
    'availableSeatsCount': availableSeatsCount,
    'availableSeats': availableSeats,
    'status': EventStatus.values.indexOf(status),
    'seatingMapImgSrc': seatingMapImgSrc,
    'locationMascotImgSrc': locationMascotImgSrc,
    'eventImageImgSrc': eventImageImgSrc,
    'eventImageImgSrcs': eventImageUrls,
    'createdByUserId': createdByUserId,
    'createdByEmail': createdByEmail,
  };
}

extension _TakeIf<T> on T {
  T? takeIf(bool Function(T) test) => test(this) ? this : null;
}

int? _intOrNull(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

List<String> _stringListFromRaw(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];

    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return [trimmed];
      }
    }

    return [trimmed];
  }

  return [];
}
