import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/booking_model.dart';
import '../services/auth_http_client.dart';

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

class EventDetail {
  final String description;
  final String address;
  final SessionType sessionType;
  final DateTime startDate;
  final String startTime;
  final String endTime;

  EventDetail({
    required this.description,
    required this.address,
    required this.sessionType,
    required this.startDate,
    required this.startTime,
    required this.endTime,
  });

  factory EventDetail.fromJson(Map<String, dynamic> json) {
    return EventDetail(
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      sessionType: sessionTypeFromRaw(json['sessionType']),
      startDate: DateTime.parse(json['startDate'] as String),
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }
}

class TicketDetailView extends StatefulWidget {
  final Booking booking;
  final bool allowCancel;

  const TicketDetailView({
    super.key,
    required this.booking,
    required this.allowCancel,
  });

  @override
  State<TicketDetailView> createState() => _TicketDetailViewState();
}

class _TicketDetailViewState extends State<TicketDetailView> {
  late Future<EventDetail> _detailFuture;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<EventDetail> _loadDetail() async {
    final resp = await AuthHttpClient.get(
      '/api/events/${widget.booking.eventId}',
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load event');
    }
    return EventDetail.fromJson(jsonDecode(resp.body));
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Booking'),
            content: const Text(
              'Are you sure you want to cancel this booking?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('NO', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('YES', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    final resp = await AuthHttpClient.put(
      '/api/booking/cancel/${widget.booking.bookingId}',
    );

    setState(() => _isCancelling = false);

    if (resp.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking successfully cancelled.')),
      );
      // Return `true` to indicate cancellation
      Navigator.of(context).pop<bool>(true);
    } else {
      String msg = 'Cancellation failed.';
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        msg = data['message'] ?? msg;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'd MMM, yyyy',
    ).format(widget.booking.eventDate);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<EventDetail>(
          future: _detailFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
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
            final parts = detail.startTime.split(':').map(int.parse).toList();
            final eventStart = DateTime(
              detail.startDate.year,
              detail.startDate.month,
              detail.startDate.day,
              parts[0],
              parts[1],
            );
            final canCancel =
                widget.allowCancel && DateTime.now().isBefore(eventStart);

            return Column(
              children: [
                const SizedBox(height: 16),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 16),
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
                            widget.booking.seatNumber.toString().padLeft(
                              2,
                              '0',
                            ),
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
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detail.description,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.black26),
                          const SizedBox(height: 16),
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
                if (canCancel)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child:
                        _isCancelling
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : GestureDetector(
                              onTap: _cancelBooking,
                              child: const Text(
                                'Cancel Booking',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontSize: 14,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop<bool>(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: const Text(
                        'VIEW ALL TICKETS',
                        style: TextStyle(
                          fontFamily: 'WinnerSans',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
