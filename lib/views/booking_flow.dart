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
  String? _mascotUrl; // ← URL from GET /api/locations/{id}

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _detailFut = _loadEventDetail();
    _fetchMascotImage();
  }

  Future<void> _fetchMascotImage() async {
    try {
      final resp = await AuthHttpClient.getLocation(widget.event.locationId);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final url = data['mascotImgSrc'] as String?;
        if (url != null && url.isNotEmpty) {
          setState(() => _mascotUrl = url);
        }
      }
    } catch (_) {
      // ignore errors
    }
  }

  Future<void> _loadChildren() async {
    try {
      final resp = await AuthHttpClient.fetchChildren();
      final list = jsonDecode(resp.body) as List<dynamic>;
      setState(() {
        _children =
            list.cast<Map<String, dynamic>>().map(ChildModel.fromJson).toList();
      });
    } catch (_) {}
  }

  Future<EventDetail> _loadEventDetail() async {
    final resp = await AuthHttpClient.get(
      '/api/events/${widget.event.eventId}',
    );
    return EventDetail.fromJson(jsonDecode(resp.body));
  }

  bool get _needsFullFlow {
    final age = context.read<AuthProvider>().userProfile?['age'] as int? ?? 0;
    return age >= 16;
  }

  // opens a dedicated seat picker modal
  // returns the selected seat number or null if cancelled
  Future<void> _openSeatPicker() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.9, // ~90% height, scrollable inside
          child: _SeatPickerSheet(
            futureDetail: _detailFut,
            initialSelected: _selectedSeat,
            eventTotalSeats: widget.event.totalSeats, // non-nullable in your model
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedSeat = picked);
    }
  }


  void _next() {
    // now under-16 goes up to index 2 (Terms=0, Seat=1, Confirm=2)
    final last = _needsFullFlow ? 3 : 2;
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
    final isChild = _selectedChildId != null;
    final dto = {
      'eventId': widget.event.eventId,
      'seatNumber': _selectedSeat,
      'isForChild': isChild,
      'childId': isChild ? int.parse(_selectedChildId!) : null,
      'canBeLeftAlone': _allowAlone,
    };

    try {
      await AuthHttpClient.post('/api/booking', body: dto);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking successful'),
          backgroundColor: Colors.white,
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
    // fullFlow has 4 pages, under16 has 3
    final totalSteps = _needsFullFlow ? 4 : 3;
    // only hide nav on Terms (step 0)
    final showNav = _step > 0;

    // labels per step
    final labels =
        _needsFullFlow
            ? ['Terms', 'Seat', 'Attendee', 'Confirm']
            : ['Terms', 'Seat', 'Confirm'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),

            // step title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                labels[_step],
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),

            // content
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  // always Terms first
                  _termsView(onCancel: _back, onAgree: _next),
                  _seatView(),
                  if (_needsFullFlow) _attendeeView(),
                  _confirmView(),
                ],
              ),
            ),

            // BACK / NEXT bar
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
                    // Back
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF9E9E9E),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'BACK',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Next / Complete
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            (_step == 1 && _selectedSeat == null)
                                ? null
                                : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C85D0),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          (_step == totalSteps - 1) ? 'COMPLETE' : 'NEXT',
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

  Widget _buildHeader() {
    final e = widget.event;
    final hasMascot = e.mascotUrl != null && e.mascotUrl!.isNotEmpty;

    // Build the avatar: either the mascot URL or a generic icon.
    final avatar =
        hasMascot
            ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                e.mascotUrl!,
                height: 56,
                width: 56,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => const Icon(
                      Icons.location_on,
                      size: 56,
                      color: Colors.white30,
                    ),
              ),
            )
            : const Icon(Icons.location_on, size: 56, color: Colors.white30);

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _back,
              ),
              const SizedBox(width: 8),
              avatar,
              const SizedBox(width: 12),
              // Event info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headerDate(e.startDate),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      friendlySession(e.sessionType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Expanded(
                          child: Text(
                            e.locationName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
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

  // ... make sure you still have this helper below in the same file:

  String _headerDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
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
                  fontWeight: FontWeight.bold,
                ),
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
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: Colors.white),
                      ),
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
                      child: const Text(
                        'AGREE & CONTINUE',
                        style: TextStyle(color: Colors.white),
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

  // SEAT SELECTION

  Widget _seatView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Seating map preview (more room by default)
          Expanded(
            child: Center(
              child: (widget.event.seatingMapImgSrc?.isNotEmpty ?? false)
                  ? Image.network(
                      widget.event.seatingMapImgSrc!,
                      fit: BoxFit.contain,
                    )
                  : const Text(
                      'No seating map available',
                      style: TextStyle(color: Colors.white70),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Button that opens the overlay seat picker
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C85D0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.event_seat, color: Colors.white),
              label: Text(
                _selectedSeat == null
                    ? 'Choose Seat'
                    : 'Change Seat (Seat #$_selectedSeat)',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              onPressed: _openSeatPicker,
            ),
          ),

          const SizedBox(height: 8),

          // Tiny hint showing the current choice
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _selectedSeat == null
                  ? 'No seat selected yet.'
                  : 'Selected seat: $_selectedSeat',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }



  // ATTENDEE DETAILS

  Widget _attendeeView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Who is attending?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'WinnerSans',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'Select Child',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                DropdownButtonFormField<String>(
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Colors.black54,
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                  value: _selectedChildId,
                  items: [
                    ..._children.map(
                      (c) => DropdownMenuItem(
                        value: c.childId.toString(),
                        child: Text('${c.firstName} ${c.lastName}'),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'ADD',
                      child: Text(
                        'Add New Child',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == 'ADD') {
                      _showAddChildDialog();
                    } else {
                      setState(() => _selectedChildId = v);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permission to Leave',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Allow child to leave on their own after the event?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: _allowAlone,
                        activeColor: Colors.blue,
                        onChanged: (v) => setState(() => _allowAlone = v!),
                      ),
                      const Text('Yes', style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 24),
                      Radio<bool>(
                        value: false,
                        groupValue: _allowAlone,
                        activeColor: Colors.blue,
                        onChanged: (v) => setState(() => _allowAlone = v!),
                      ),
                      const Text('No', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Container(
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add New Child',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'WinnerSans',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // First Name
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              'First Name',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextField(
                            controller: fn,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'e.g. Jane',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              'Last Name',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextField(
                            controller: ln,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'e.g. Doe',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // DOB
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              'Date of Birth',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: sbCtx,
                                initialDate: DateTime.now().subtract(
                                  const Duration(days: 365 * 8),
                                ),
                                firstDate: DateTime(2005),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) setSb(() => dob = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    dob == null
                                        ? 'Tap to select date'
                                        : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color:
                                          dob == null
                                              ? Colors.black38
                                              : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Emergency Name
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              'Emergency Contact Name',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextField(
                            controller: emName,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'e.g. John Doe',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              prefixIcon: const Icon(
                                Icons.contact_phone_outlined,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Emergency Phone
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              'Emergency Contact Phone',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextField(
                            controller: emPhone,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: '(555) 123-4567',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed:
                            isSubmitting
                                ? null
                                : () async {
                                  if (fn.text.trim().isEmpty ||
                                      ln.text.trim().isEmpty ||
                                      dob == null ||
                                      emName.text.trim().isEmpty ||
                                      emPhone.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please fill out all fields',
                                          style: TextStyle(color: Colors.black),
                                        ),
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
                                        'dateOfBirth':
                                            dob!
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
                                    Navigator.of(dialogCtx).pop();
                                  } catch (e) {
                                    setSb(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not add child: $e',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                        ),
                        child:
                            isSubmitting
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text(
                                  'ADD CHILD',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      },
    );
  }
}


class _SeatPickerSheet extends StatefulWidget {
  final Future<EventDetail> futureDetail;
  final int? initialSelected;
  final int eventTotalSeats; // from EventSummary (non-nullable)

  const _SeatPickerSheet({
    required this.futureDetail,
    required this.initialSelected,
    required this.eventTotalSeats,
  });

  @override
  State<_SeatPickerSheet> createState() => _SeatPickerSheetState();
}

class _SeatPickerSheetState extends State<_SeatPickerSheet> {
  int? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialSelected;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select a Seat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),

            // Content
            Expanded(
              child: FutureBuilder<EventDetail>(
                future: widget.futureDetail,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return const Center(
                      child: Text('Error loading seats',
                          style: TextStyle(color: Colors.redAccent)),
                    );
                  }

                  final detail = snap.data!;
                  final availableSeats = detail.availableSeats.toSet();

                  // Determine total seats:
                  // Prefer EventDetail.totalSeats (if present) → EventSummary.totalSeats (passed in) → highest available seat number
                  int totalSeats = 0;
                  final int? detailTotal = detail.totalSeats; // make sure your model includes this (int?)
                  if (detailTotal != null && detailTotal > 0) {
                    totalSeats = detailTotal;
                  } else if (widget.eventTotalSeats > 0) {
                    totalSeats = widget.eventTotalSeats;
                  } else {
                    totalSeats = availableSeats.isNotEmpty
                        ? availableSeats.reduce((a, b) => a > b ? a : b)
                        : 0;
                  }

                  if (totalSeats <= 0) {
                    return const Center(
                      child: Text('No seats available',
                          style: TextStyle(color: Colors.white70)),
                    );
                  }

                  final takenCount =
                      totalSeats - availableSeats.length.clamp(0, totalSeats);

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Little summary
                        Text(
                          '${availableSeats.length} of $totalSeats seats available'
                          '${_picked != null ? ' • selected: #$_picked' : ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        // Grid (scrolls independently)
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.4,
                            ),
                            itemCount: totalSeats,
                            itemBuilder: (_, idx) {
                              final seat = idx + 1;
                              final available = availableSeats.contains(seat);
                              final selected = _picked == seat;

                              return _SeatTile(
                                seat: seat,
                                available: available,
                                selected: selected,
                                onTap: available
                                    ? () => setState(() => _picked = seat)
                                    : null,
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Legend
                        Row(
                          children: const [
                            _LegendSwatch(color: Colors.white, border: Colors.white24),
                            SizedBox(width: 6),
                            Text('Available', style: TextStyle(color: Colors.white70)),
                            SizedBox(width: 16),
                            _LegendSwatch(color: Colors.white10, border: Colors.white24),
                            SizedBox(width: 6),
                            Text('Taken', style: TextStyle(color: Colors.white70)),
                            SizedBox(width: 16),
                            _LegendSwatch(color: Color(0xFF4C85D0), border: Colors.transparent),
                            SizedBox(width: 6),
                            Text('Selected', style: TextStyle(color: Colors.white70)),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9E9E9E),
                                  side: BorderSide.none,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('CANCEL',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4C85D0),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _picked == null
                                    ? null
                                    : () => Navigator.of(context).pop(_picked),
                                child: Text(
                                  _picked == null
                                      ? 'USE SELECTED'
                                      : 'USE SEAT #$_picked',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// widgets used inside the sheet for the seat tiles and legend

class _SeatTile extends StatelessWidget {
  final int seat;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;

  const _SeatTile({
    required this.seat,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = !available
        ? Colors.white10
        : (selected ? const Color(0xFF4C85D0) : Colors.white);
    final fg = !available
        ? Colors.white38
        : (selected ? Colors.white : Colors.black87);
    final border = selected ? const Color(0xFF4C85D0) : Colors.white24;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!available)
                const Icon(Icons.event_seat, size: 14, color: Colors.white38),
              if (!available) const SizedBox(width: 6),
              Text(
                seat.toString(),
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  final Color border;
  const _LegendSwatch({required this.color, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 1),
      ),
    );
  }
}

