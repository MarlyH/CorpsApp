import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../models/event_summary.dart';
import '../models/event_detail.dart';
import '../models/child_model.dart';

class BookingFlow extends StatefulWidget {
  final EventSummary event;

  const BookingFlow({super.key, required this.event});

  @override
  _BookingFlowState createState() => _BookingFlowState();
}

class _BookingFlowState extends State<BookingFlow> {
  int _step = 0;
  int? _selectedSeat;
  String? _selectedChildId;
  bool _allowAlone = false;

  List<ChildModel> _children = [];
  late Future<EventDetail> _detailFut;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _detailFut = _loadEventDetail();
  }

  Future<void> _loadChildren() async {
    try {
      final resp = await AuthHttpClient.fetchChildren();
      final data = jsonDecode(resp.body) as List<dynamic>;
      setState(() {
        _children = data
            .cast<Map<String, dynamic>>()
            .map(ChildModel.fromJson)
            .toList();
      });
    } catch (_) {
      // optionally show an error
    }
  }

  Future<EventDetail> _loadEventDetail() async {
    final resp =
        await AuthHttpClient.get('/api/events/${widget.event.eventId}');
    return EventDetail.fromJson(jsonDecode(resp.body));
  }

  bool get _needsFullFlow {
    final age =
        context.read<AuthProvider>().userProfile?['age'] as int? ?? 0;
    return age >= 16;
  }

  void _next() {
    final last = _needsFullFlow ? 3 : 1;
    if (_step < last) {
      setState(() => _step++);
    } else {
      _submitBooking();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitBooking() async {
    final isForChild = _selectedChildId != null;
    final dto = {
      'eventId': widget.event.eventId,
      'seatNumber': _selectedSeat,
      'isForChild': isForChild,
      'childId': isForChild ? int.parse(_selectedChildId!) : null,
      'canBeLeftAlone': _allowAlone,
    };

    try {
      await AuthHttpClient.post('/api/booking', body: dto);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking successful'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = _needsFullFlow ? 4 : 2;
    final showNav = !(_needsFullFlow && _step == 0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Book ${widget.event.locationName}'),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Step title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _needsFullFlow
                    ? ['Terms', 'Seat', 'Attendee', 'Confirm'][_step]
                    : ['Seat', 'Confirm'][_step],
                style: const TextStyle(
                    color: Colors.white70, fontSize: 16),
              ),
            ),

            // Step content
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  if (_needsFullFlow)
                    _termsView(onCancel: _back, onAgree: _next),
                  _seatView(),
                  if (_needsFullFlow) _attendeeView(),
                  _confirmView(),
                ],
              ),
            ),

            // Shared BACK/NEXT row—hidden on Terms step
            if (showNav)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          side: const BorderSide(color: Colors.grey),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'BACK',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            (_step == 1 && _selectedSeat == null)
                                ? null
                                : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          (_step == totalSteps - 1)
                              ? 'COMPLETE'
                              : (_needsFullFlow && _step == 0
                                  ? 'AGREE & CONTINUE'
                                  : 'NEXT'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _termsView({
    required VoidCallback onCancel,
    required VoidCallback onAgree,
  }) {
    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'TERMS AND CONDITIONS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Scrollable T&C body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Registering Multiple People: You may register more than one person for a single-session, however you will have to repeat the process from the start for each person. (This prevents people abusing the FREE registration process, and signing up for all the tickets for a laugh.)',
                        style: TextStyle(
                            color: Colors.white70,
                            height: 1.4),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• Kids Aged 8–11 years will only be allowed to play G and PG rated Games. We are unable to provide tailored experiences for individual kids if you do not approve of your child playing “Recommended Classifications” such as PG rated games, as it will mean your children will not be able to participate in the same experience as everyone else in the room. If you have an issue with this, then we apologize for the inconvenience, and recommend you do not attend.',
                        style: TextStyle(
                            color: Colors.white70,
                            height: 1.4),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• Teens Ages 12–15 years will be allowed to play M rated games, which is an Unrestricted Rated Classification, and is not enforced by law. If you have an issue with this, then we apologize for the inconvenience, and recommend you do not attend.',
                        style: TextStyle(
                            color: Colors.white70,
                            height: 1.4),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• By participating in our events, you understand and accept that you and/or your child participate at your own risk and release the event organizers and venue from any liability.',
                        style: TextStyle(
                            color: Colors.white70,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Terms-specific Cancel / Agree row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            Colors.grey.shade700,
                        side: BorderSide(
                            color: Colors.grey.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAgree,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      child: const Text(
                        'AGREE & CONTINUE',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seatView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: (widget.event.seatingMapImgSrc
                          ?.isNotEmpty ??
                      false)
                  ? Image.network(
                      widget.event.seatingMapImgSrc!,
                      fit: BoxFit.contain,
                    )
                  : const Text(
                      'No seating map available',
                      style: TextStyle(
                          color: Colors.white70),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<EventDetail>(
            future: _detailFut,
            builder: (ctx, snap) {
              if (snap.connectionState ==
                  ConnectionState.waiting) {
                return const CircularProgressIndicator(
                    color: Colors.white);
              }
              if (snap.hasError) {
                return const Text('Error loading seats',
                    style: TextStyle(
                        color: Colors.redAccent));
              }
              final seats = snap.data!.availableSeats;
              if (seats.isEmpty) {
                return const Text('No seats available',
                    style: TextStyle(
                        color:
                            Colors.white70));
              }
              return DropdownButtonFormField<int>(
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Seat Number',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(
                    color: Colors.black),
                value: _selectedSeat,
                items: seats
                    .map((n) => DropdownMenuItem(
                          value: n,
                          child: Text(n.toString()),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedSeat = v),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _attendeeView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Attendee Details',
              style: TextStyle(
                  color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              dropdownColor: Colors.white,
              decoration: InputDecoration(
                labelText: 'Select Child',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style:
                  const TextStyle(color: Colors.black),
              value: _selectedChildId,
              items: [
                ..._children.map((c) =>
                    DropdownMenuItem(
                      value: c.childId.toString(),
                      child: Text(
                          '${c.firstName} ${c.lastName}'),
                    )),
                const DropdownMenuItem(
                  value: 'ADD',
                  child: Text('Add Child',
                      style: TextStyle(
                          color: Colors.blue)),
                ),
              ],
              onChanged: (v) {
                if (v == 'ADD') {
                  _showAddChildDialog();
                } else {
                  setState(
                      () => _selectedChildId = v);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Allow child to leave on their own?',
              style:
                  TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _allowAlone,
                  activeColor: Colors.blue,
                  onChanged: (v) =>
                      setState(() => _allowAlone = v!),
                ),
                const Text('Yes',
                    style: TextStyle(
                        color: Colors.white70)),
                const SizedBox(width: 12),
                Radio<bool>(
                  value: false,
                  groupValue: _allowAlone,
                  activeColor: Colors.blue,
                  onChanged: (v) =>
                      setState(() => _allowAlone = v!),
                ),
                const Text('No',
                    style: TextStyle(
                        color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'About to book seat #$_selectedSeat\nfor ${widget.event.locationName}',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _showAddChildDialog() async {
    final fn = TextEditingController();
    final ln = TextEditingController();
    final emName = TextEditingController();
    final emPhone = TextEditingController();
    DateTime? dob;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSb) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Add New Child',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold)),
                  const SizedBox(height: 12),

                  // First Name
                  TextField(
                    controller: fn,
                    style: const TextStyle(
                        color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      hintText: 'e.g. Jane',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Last Name
                  TextField(
                    controller: ln,
                    style: const TextStyle(
                        color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      hintText: 'e.g. Doe',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // DOB
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: c,
                        initialDate: DateTime.now()
                            .subtract(
                                const Duration(days: 365 * 8)),
                        firstDate: DateTime(2005),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setSb(() => dob = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      child: Text(
                        dob == null
                            ? 'Tap to select date'
                            : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            color: dob == null
                                ? Colors.black38
                                : Colors.black87),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Emergency Contact Name
                  TextField(
                    controller: emName,
                    style: const TextStyle(
                        color: Colors.black),
                    decoration: InputDecoration(
                      labelText:
                          'Emergency Contact Name',
                      hintText: 'e.g. John Doe',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Emergency Contact Phone
                  TextField(
                    controller: emPhone,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                        color: Colors.black),
                    decoration: InputDecoration(
                      labelText:
                          'Emergency Contact Phone',
                      hintText: '(555) 123-4567',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (fn.text.trim().isEmpty ||
                          ln.text.trim().isEmpty ||
                          dob == null ||
                          emName.text.trim().isEmpty ||
                          emPhone.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please fill out all fields'),
                            backgroundColor:
                                Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      await AuthHttpClient.post(
                        '/api/child',
                        body: {
                          'firstName':
                              fn.text.trim(),
                          'lastName': ln.text.trim(),
                          'dateOfBirth': dob!
                              .toIso8601String()
                              .split('T')
                              .first,
                          'emergencyContactName':
                              emName.text.trim(),
                          'emergencyContactPhone':
                              emPhone.text.trim(),
                        },
                      );
                      await _loadChildren();
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('ADD CHILD',
                        style: TextStyle(
                            color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
