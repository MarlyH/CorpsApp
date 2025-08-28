// lib/models/booking_model.dart

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
    required this.canBeLeftAlone,
    required this.qrCodeData,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final raw = json['status'];
    BookingStatus status;
    if (raw is int && raw >= 0 && raw < BookingStatus.values.length) {
      status = BookingStatus.values[raw];
    } else {
      status = BookingStatus.values.firstWhere(
        (e) => e.toString().split('.').last == raw.toString(),
        orElse: () => BookingStatus.Booked,
      );
    }

    return Booking(
      bookingId:      json['bookingId']    as int,
      eventId:        json['eventId']      as int,
      eventName:      json['eventName']    as String,
      attendeeName:   (json['attendeeName'] as String?) ?? '',
      eventDate:      DateTime.parse(json['eventDate'] as String),
      seatNumber:     json['seatNumber']   as int?,
      status:         status,
      canBeLeftAlone: json['canBeLeftAlone'] as bool? ?? false,
      qrCodeData:     json['qrCodeData']    as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'bookingId':      bookingId,
        'eventId':        eventId,
        'eventName':      eventName,
        'attendeeName':   attendeeName,
        'eventDate':      eventDate.toIso8601String(),
        'seatNumber':     seatNumber,
        'status':         status.index,
        'canBeLeftAlone': canBeLeftAlone,
        'qrCodeData':     qrCodeData,
      };
}
