import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../models/event_summary.dart' show EventSummary, friendlySession;
import '../models/event_detail.dart' show EventDetail;
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
      // ignore errors
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
          backgroundColor: Color.fromARGB(255, 255, 255, 255),
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
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Always show the details header, even on Terms which is step 0
              _buildHeader(),

            // Step title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _needsFullFlow
                    ? ['Terms', 'Seat', 'Attendee', 'Confirm'][_step]
                    : ['Seat', 'Confirm'][_step],
                style:
                    const TextStyle(color: Colors.white70, fontSize: 16),
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

            // Back/Next buttons which are hidden on Terms
            if (showNav)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF9E9E9E),
                          side: BorderSide.none,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('BACK',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            (_step == 1 && _selectedSeat == null) ? null : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C85D0),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          (_step == totalSteps - 1)
                              ? 'COMPLETE'
                              : 'NEXT',
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

  
  // Dynamic, full-width header with full date on one line
  
    Widget _buildHeader() {
    final e = widget.event;
    return Container(
      width: double.infinity,
      color: Colors.black,
      // extra top padding so you never collide with the notch/status bar
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // back arrow
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: _back,
              ),

              // logo
              Expanded(
                flex: 2,
                child: Center(
                  child: Image.asset(
                    e.locationAssetPath,
                    height: 56,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // text details
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // full weekday & day & month in one line
                    Text(
                      _headerDate(e.startDate),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,    // smaller
                      ),
                    ),

                    const SizedBox(height: 6),

                    // session title
                    Text(
                      friendlySession(e.sessionType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,   // smaller
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // time & location on same row
                    Row(
                      children: [
                        Text(
                          e.startTime,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          ' • ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.locationName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white54, height: 1),
        ],
      ),
    );
  }

  /// Helper for date format
  String _headerDate(DateTime d) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    const weekdays = [
      'Monday','Tuesday','Wednesday',
      'Thursday','Friday','Saturday','Sunday'
    ];
    final wd = weekdays[d.weekday - 1];
    final mo = months[d.month - 1];
    return '$wd ${d.day} $mo';
  }
 
  // TERMS PAGE

  Widget _termsView({
    required VoidCallback onCancel,
    required VoidCallback onAgree,
  }) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'TERMS AND CONDITIONS',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Registering Multiple People: You may register more than one person for a single-session, however you will have to repeat the process from the start for each person. (This prevents people abusing the FREE registration process, and signing up for all the tickets for a laugh.)',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• Kids Aged 8 to 11 years will only be allowed to play G and PG rated Games. We are unable to provide tailored experiences for individual kids if you do not approve of your child playing “Recommended Classifications” such as PG rated games, as it will mean your children will not be able to participate in the same experience as everyone else in the room. If you have an issue with this, then we apologize for the inconvenience, and recommend you do not attend.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• Teens Ages 12 to 15 years will be allowed to play M rated games, which is an Unrestricted Rated Classification, and is not enforced by law. If you have an issue with this, then we apologize for the inconvenience, and recommend you do not attend.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '• By participating in our events, you understand and accept that you and/or your child participate at your own risk and release the event organizers and venue from any liability.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF9E9E9E),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('CANCEL',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAgree,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4C85D0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('AGREE & CONTINUE',
                          style: TextStyle(color: Colors.white)),
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

  // SEAT SELECTION
  
  Widget _seatView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: (widget.event.seatingMapImgSrc?.isNotEmpty ?? false)
                  ? Image.network(widget.event.seatingMapImgSrc!,
                      fit: BoxFit.contain)
                  : const Text('No seating map available',
                      style: TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<EventDetail>(
            future: _detailFut,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(color: Colors.white);
              }
              if (snap.hasError) {
                return const Text('Error loading seats',
                    style: TextStyle(color: Colors.redAccent));
              }
              final seats = snap.data!.availableSeats;
              if (seats.isEmpty) {
                return const Text('No seats available',
                    style: TextStyle(color: Colors.white70));
              }
              return DropdownButtonFormField<int>(
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Seat Number',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: Colors.black),
                value: _selectedSeat,
                items: seats
                    .map((n) =>
                        DropdownMenuItem(value: n, child: Text(n.toString())))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSeat = v),
              );
            },
          ),
        ],
      ),
    );
  }


  // ATTENDEE DETAILS

  Widget _attendeeView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Attendee Details',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              dropdownColor: Colors.white,
              decoration: InputDecoration(
                labelText: 'Select Child',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
              style: const TextStyle(color: Colors.black),
              value: _selectedChildId,
              items: [
                ..._children.map((c) => DropdownMenuItem(
                      value: c.childId.toString(),
                      child: Text('${c.firstName} ${c.lastName}'),
                    )),
                const DropdownMenuItem(
                    value: 'ADD',
                    child:
                        Text('Add Child', style: TextStyle(color: Colors.blue))),
              ],
              onChanged: (v) {
                if (v == 'ADD') {
                  _showAddChildDialog();
                } else {
                  setState(() => _selectedChildId = v);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('Allow child to leave on their own?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _allowAlone,
                  activeColor: Colors.white,
                  onChanged: (v) => setState(() => _allowAlone = v!),
                ),
                const Text('Yes', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 12),
                Radio<bool>(
                  value: false,
                  groupValue: _allowAlone,
                  activeColor: Colors.white,
                  onChanged: (v) => setState(() => _allowAlone = v!),
                ),
                const Text('No', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // CONFIRM

  Widget _confirmView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'About to book seat #$_selectedSeat\nfor ${widget.event.locationName}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }

  // ADD CHILD DIALOG

  Future<void> _showAddChildDialog() async {
    final fn = TextEditingController();
    final ln = TextEditingController();
    final emName = TextEditingController();
    final emPhone = TextEditingController();
    DateTime? dob;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setSb) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration:
                    BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogCtx).pop(),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Add New Child', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // First Name
                    TextField(
                      controller: fn,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        hintText: 'e.g. Jane',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Last Name
                    TextField(
                      controller: ln,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        hintText: 'e.g. Doe',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // DOB
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: sbCtx,
                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 8)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        child: Text(
                          dob == null
                              ? 'Tap to select date'
                              : '${dob!.year}-${dob!.month.toString().padLeft(2,'0')}-${dob!.day.toString().padLeft(2,'0')}',
                          style: TextStyle(color: dob == null ? Colors.black38 : Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Emergency Name
                    TextField(
                      controller: emName,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Emergency Contact Name',
                        hintText: 'e.g. John Doe',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Emergency Phone
                    TextField(
                      controller: emPhone,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Emergency Contact Phone',
                        hintText: '(555) 123-4567',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (fn.text.trim().isEmpty ||
                                  ln.text.trim().isEmpty ||
                                  dob == null ||
                                  emName.text.trim().isEmpty ||
                                  emPhone.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill out all fields'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              setSb(() => isSubmitting = true);
                              try {
                                await AuthHttpClient.post(
                                  '/api/child',
                                  body: {  
                                    'firstName': fn.text.trim(),
                                    'lastName': ln.text.trim(),
                                    'dateOfBirth': dob!.toIso8601String().split('T').first,
                                    'emergencyContactName': emName.text.trim(),
                                    'emergencyContactPhone': emPhone.text.trim(),
                                  },
                                );
                                await _loadChildren();
                                Navigator.of(dialogCtx).pop(); // only pop dialog
                              } catch (e) {
                                setSb(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not add child: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('ADD CHILD', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _weekdayFull(DateTime d) {
    const week = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return week[d.weekday - 1];
  }
}
