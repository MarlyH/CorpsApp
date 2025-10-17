class EventReport {
  final int totalEvents;
  final int totalUsers;
  final int totalBookings;
  final int totalTurnout;
  final int uniqueAttendees;
  final int recurringAttendees;
  final double averageAttendeesPerEvent;
  final double attendanceRateOverall;
  final List<EventsPerLocation> eventsPerLocation;

  EventReport({
    required this.totalEvents,
    required this.totalUsers,
    required this.totalBookings,
    required this.totalTurnout,
    required this.uniqueAttendees,
    required this.recurringAttendees,
    required this.averageAttendeesPerEvent,
    required this.attendanceRateOverall,
    required this.eventsPerLocation,
  });

  factory EventReport.fromJson(Map<String, dynamic> json) {
    return EventReport(
      totalEvents: json['totalEvents'] ?? 0,
      totalUsers: json['totalUsers'] ?? 0,
      totalBookings: json['totalBookings'] ?? 0,
      totalTurnout: json['totalTurnout'] ?? 0,
      uniqueAttendees: json['uniqueAttendees'] ?? 0,
      recurringAttendees: json['recurringAttendees'] ?? 0,
      averageAttendeesPerEvent: (json['averageAttendeesPerEvent'] ?? 0).toDouble(),
      attendanceRateOverall: (json['attendanceRateOverall'] ?? 0).toDouble(),
      eventsPerLocation: (json['eventsPerLocation'] as List)
          .map((e) => EventsPerLocation.fromJson(e))
          .toList(),
    );
  }
}

class EventsPerLocation {
  final String location;
  final int count;

  EventsPerLocation({required this.location, required this.count});

  factory EventsPerLocation.fromJson(Map<String, dynamic> json) {
    return EventsPerLocation(
      location: json['location'] ?? 'Unknown',
      count: json['count'] ?? 0,
    );
  }
}
