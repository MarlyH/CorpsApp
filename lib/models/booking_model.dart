// Mirrors the server-side BookingStatus enum:
enum BookingStatus {
  Booked,     // 0
  CheckedIn,  // 1
  CheckedOut, // 2
}

// Front-end model for a booking record.
class Booking {
  final int bookingId;
  final int eventId;
  final String eventName;
  final DateTime eventDate;
  final int seatNumber;
  final BookingStatus status;
  final bool canBeLeftAlone;
  final String qrCodeData;

  Booking({
    required this.bookingId,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.seatNumber,
    required this.status,
    required this.canBeLeftAlone,
    required this.qrCodeData,
  });

  // Convert JSON from `/api/Booking/my` into a Booking.
  factory Booking.fromJson(Map<String, dynamic> json) {
    // The API may return status as a number or string.
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
      bookingId: json['bookingId'] as int,
      eventId: json['eventId'] as int,
      eventName: json['eventName'] as String,
      eventDate: DateTime.parse(json['eventDate'] as String),
      seatNumber: json['seatNumber'] as int,
      status: status,
      canBeLeftAlone: json['canBeLeftAlone'] as bool? ?? false,
      qrCodeData: json['qrCodeData'] as String? ?? '',
    );
  }

  // Turn this booking back into JSON (if ever needed).
  Map<String, dynamic> toJson() => {
        'bookingId': bookingId,
        'eventId': eventId,
        'eventName': eventName,
        'eventDate': eventDate.toIso8601String(),
        'seatNumber': seatNumber,
        'status': status.index,
        'canBeLeftAlone': canBeLeftAlone,
        'qrCodeData': qrCodeData,
      };
}
