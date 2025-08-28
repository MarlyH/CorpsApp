enum BookingStatus {
  Booked,
  CheckedIn,
  CheckedOut,
  Cancelled,
  Striked,
}

class Booking {
  final int bookingId;
  final int eventId;
  final String eventName;
  final String attendeeName;
  final DateTime eventDate;
  final int? seatNumber;
  final BookingStatus status;
  final bool isForChild;
  final bool canBeLeftAlone;
  final String qrCodeData;

  Booking({
    required this.bookingId,
    required this.eventId,
    required this.eventName,
    required this.attendeeName,
    required this.eventDate,
    required this.seatNumber,
    required this.status,
    required this.isForChild,
    required this.canBeLeftAlone,
    required this.qrCodeData,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // status: accept int or string
    final raw = json['status'];
    final status = (raw is int && raw >= 0 && raw < BookingStatus.values.length)
        ? BookingStatus.values[raw]
        : BookingStatus.values.firstWhere(
            (e) => e.toString().split('.').last == raw.toString(),
            orElse: () => BookingStatus.Booked,
          );

    // isForChild with safe default (false)
    final isForChild = json['isForChild'] as bool? ?? false;

    // canBeLeftAlone rules:
    // - For child bookings, use value (default false if missing).
    // - For self (non-child) bookings, default to true unless explicitly overridden.
    final rawLeftAlone = json['canBeLeftAlone'] as bool?;
    final canBeLeftAlone = isForChild ? (rawLeftAlone ?? false) : (rawLeftAlone ?? true);

    return Booking(
      bookingId: json['bookingId'] as int,
      eventId: json['eventId'] as int,
      eventName: json['eventName'] as String,
      attendeeName: (json['attendeeName'] as String?) ?? '',
      eventDate: DateTime.parse(json['eventDate'] as String),
      seatNumber: json['seatNumber'] as int?,
      status: status,
      isForChild: isForChild,
      canBeLeftAlone: canBeLeftAlone,
      qrCodeData: json['qrCodeData'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'bookingId': bookingId,
        'eventId': eventId,
        'eventName':eventName,
        'attendeeName':attendeeName,
        'eventDate':eventDate.toIso8601String(),
        'seatNumber': seatNumber,
        'status': status.index,
        'isForChild': isForChild,
        'canBeLeftAlone': canBeLeftAlone,
        'qrCodeData': qrCodeData,
      };
}
