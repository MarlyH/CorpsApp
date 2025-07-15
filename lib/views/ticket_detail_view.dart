import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/booking_model.dart';
import '../services/auth_http_client.dart';

// Matches server‐side EventSessionType enum
enum SessionType { Kids, Teens, Adults }

SessionType sessionTypeFromRaw(dynamic raw) {
  if (raw is int && raw >= 0 && raw < SessionType.values.length) {
    return SessionType.values[raw];
  }
  if (raw is String) {
    return SessionType.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == raw.toLowerCase(),
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

// Mirrors your GET /api/events/{id} response
class EventDetail {
  final String description;
  final String address;
  final String? seatingMapImgSrc;
  final SessionType sessionType;
  final DateTime startDate;
  final String startTime; // "HH:mm:ss"
  final String endTime;   // "HH:mm:ss"

  EventDetail({
    required this.description,
    required this.address,
    this.seatingMapImgSrc,
    required this.sessionType,
    required this.startDate,
    required this.startTime,
    required this.endTime,
  });

  factory EventDetail.fromJson(Map<String, dynamic> json) {
    return EventDetail(
      description : json['description'] as String? ?? '',
      address : json['address'] as String? ?? '',
      seatingMapImgSrc : json['seatingMapImgSrc'] as String?,
      // parse raw enum field:
      sessionType : sessionTypeFromRaw(json['sessionType']),
      startDate : DateTime.parse(json['startDate'] as String),
      startTime : json['startTime'] as String? ?? '',
      endTime : json['endTime'] as String? ?? '',
    );
  }
}

class TicketDetailView extends StatefulWidget {
  final Booking booking;
  final bool    allowCancel;

  const TicketDetailView({
    Key? key,
    required this.booking,
    required this.allowCancel,
  }) : super(key: key);

  @override
  State<TicketDetailView> createState() => _TicketDetailViewState();
}

class _TicketDetailViewState extends State<TicketDetailView> {
  late Future<EventDetail> _eventDetailFut;

  @override
  void initState() {
    super.initState();
    _eventDetailFut = _fetchEventDetail();
  }

  Future<EventDetail> _fetchEventDetail() async {
    final resp = await AuthHttpClient.get(
      '/api/events/${widget.booking.eventId}'
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load event');
    }
    final Map<String, dynamic> j = jsonDecode(resp.body);
    return EventDetail.fromJson(j);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('d MMM, yyyy').format(widget.booking.eventDate);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<EventDetail>(
          future: _eventDetailFut,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white)
              );
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  'Error loading event',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            }
            final detail = snap.data!;

            // Only allow cancel if before event start
            final parts = detail.startTime.split(':').map(int.parse).toList();
            final eventStart = DateTime(
              detail.startDate.year,
              detail.startDate.month,
              detail.startDate.day,
              parts[0],
              parts[1],
            );
            final now = DateTime.now();
            final canCancelNow =
                widget.allowCancel && now.isBefore(eventStart);

            return Column(
              children: [
                const SizedBox(height: 16),

                // Attendee & Session
                Center(
                  child: Text(
                    widget.booking.attendeeName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    friendlySession(detail.sessionType),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // White info card
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _detailRow('Location', detail.address),
                          _detailRow('Date', dateLabel),
                          _detailRow(
                            'Time',
                            '${detail.startTime} – ${detail.endTime}',
                          ),
                          _detailRow(
                            'Seat',
                            widget.booking.seatNumber
                                .toString()
                                .padLeft(2, '0'),
                          ),
                          _detailRow(
                            'Pick Up',
                            widget.booking.canBeLeftAlone ? 'Yes' : 'No',
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.black26),
                          const SizedBox(height: 8),
                          const Text(
                            'Description',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detail.description,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.black26),
                          const SizedBox(height: 16),

                          // QR Code
                          Center(
                            child: QrImageView(
                              data: widget.booking.qrCodeData,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                // Cancel link
                if (canCancelNow)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () async {
                        await AuthHttpClient.delete(
                          '/api/booking/${widget.booking.bookingId}'
                        );
                        Navigator.pop(context, widget.booking);
                      },
                      child: const Text(
                        'Cancel Booking',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Back button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)
                      ),
                    ),
                    child: const Text(
                      'VIEW ALL TICKETS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
