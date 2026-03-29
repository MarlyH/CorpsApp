import 'dart:convert';
import 'dart:io';

import 'package:corpsapp/models/session_type_helper.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/utils/date_picker.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

import '../models/location.dart';
import '../services/auth_http_client.dart';

const _sessionTypeValues = {
  SessionType.ages8to11: 0,
  SessionType.ages12to15: 1,
  SessionType.adults: 2,
};

enum EventCategory { bookable, announcement, promotional }

extension _EventCategoryX on EventCategory {
  String get label {
    switch (this) {
      case EventCategory.bookable:
        return 'Bookable Event';
      case EventCategory.announcement:
        return 'Announcement';
      case EventCategory.promotional:
        return 'Promotional Event';
    }
  }

  String get apiValue {
    switch (this) {
      case EventCategory.bookable:
        return 'bookable';
      case EventCategory.announcement:
        return 'announcement';
      case EventCategory.promotional:
        return 'promotional';
    }
  }

  bool get requiresBooking => this == EventCategory.bookable;
}

class CreateEventView extends StatefulWidget {
  const CreateEventView({super.key});

  @override
  State<CreateEventView> createState() => _CreateEventViewState();
}

class _CreateEventViewState extends State<CreateEventView> {
  static const int _maxEventImageBytes = 4 * 1024 * 1024;
  final _formKey = GlobalKey<FormState>();
  final _titleCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _seatsCtl = TextEditingController();

  EventCategory _category = EventCategory.bookable;
  SessionType? _sessionType;
  Location? _location;
  DateTime? _eventDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _availableDate;
  DateTime? _contentFromDate;
  DateTime? _contentToDate;
  List<File> _eventImages = [];

  bool _isLoading = false;
  List<Location> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _addressCtl.dispose();
    _descCtl.dispose();
    _seatsCtl.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final locs = await AuthHttpClient.fetchLocations();
      if (!mounted) return;
      setState(() => _locations = locs);
    } catch (_) {}
  }

  void _onCategoryChanged(EventCategory? value) {
    if (value == null || value == _category) return;
    setState(() {
      _category = value;
      if (!_category.requiresBooking) {
        _sessionType = null;
        _location = null;
        _eventDate = null;
        _startTime = null;
        _endTime = null;
        _availableDate = null;
        _seatsCtl.clear();
        _addressCtl.clear();
      } else {
        _eventImages = [];
        _contentFromDate = null;
        _contentToDate = null;
      }
    });
  }

  Future<void> _pickDate({required bool eventDate}) async {
    final now = DateTime.now();
    final d = await DatePickerUtil.pickDate(
      context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    setState(() {
      if (eventDate) {
        _eventDate = d;
      } else {
        _availableDate = d;
      }
    });
  }

  Future<void> _pickContentDate({required bool from}) async {
    final now = DateTime.now();
    final d = await DatePickerUtil.pickDate(
      context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    setState(() {
      if (from) {
        _contentFromDate = d;
      } else {
        _contentToDate = d;
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final now = TimeOfDay.now();

    if (Platform.isIOS) {
      TimeOfDay? selectedTime = await showCupertinoModalPopup<TimeOfDay>(
        context: context,
        builder: (_) {
          DateTime tempDate = DateTime.now();
          return Container(
            height: 300,
            color: AppColors.background,
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime(0, 0, 0, now.hour, now.minute),
                    use24hFormat: false,
                    onDateTimeChanged: (DateTime dt) {
                      tempDate = dt;
                    },
                  ),
                ),
                CupertinoButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      TimeOfDay(hour: tempDate.hour, minute: tempDate.minute),
                    );
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: CupertinoColors.activeBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (selectedTime == null) return;
      setState(() {
        if (start) {
          _startTime = selectedTime;
        } else {
          _endTime = selectedTime;
        }
      });
      return;
    }

    final t = await showTimePicker(context: context, initialTime: now);
    if (t == null) return;
    setState(() {
      if (start) {
        _startTime = t;
      } else {
        _endTime = t;
      }
    });
  }

  Future<void> _pickEventImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 92);
    if (picked.isEmpty) return;

    final validFiles = <File>[];
    int skippedCount = 0;

    for (final image in picked) {
      final file = File(image.path);
      final sizeBytes = await file.length();
      if (sizeBytes > _maxEventImageBytes) {
        skippedCount++;
        continue;
      }
      validFiles.add(file);
    }

    if (!mounted) return;

    if (validFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All selected images were above 4MB. Please pick smaller files.'),
        ),
      );
      return;
    }

    setState(() => _eventImages = [..._eventImages, ...validFiles]);

    if (skippedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$skippedCount image(s) were skipped because they exceeded 4MB.'),
        ),
      );
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  InputDecoration _inputDecoration({
    String? labelText,
    String? hintText,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(color: Colors.black),
    hintText: hintText,
    hintStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.circular(8),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_category.requiresBooking) {
      if (_sessionType == null ||
          _location == null ||
          _eventDate == null ||
          _startTime == null ||
          _endTime == null ||
          _availableDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete all required fields.')),
        );
        return;
      }

      if (_availableDate!.isAfter(_eventDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking date must be on or before event date.'),
          ),
        );
        return;
      }
    } else {
      if (_contentFromDate == null || _contentToDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select From and To dates for this event.'),
          ),
        );
        return;
      }
      if (_contentToDate!.isBefore(_contentFromDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('To date must be on or after From date.'),
          ),
        );
        return;
      }
      for (final image in _eventImages) {
        if (await image.length() > _maxEventImageBytes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Each image must be 4MB or smaller.'),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      final resp = await AuthHttpClient.createEvent(
        category: _category.apiValue,
        requiresBooking: _category.requiresBooking,
        locationId: _category.requiresBooking ? _location!.id : null,
        sessionType:
            _category.requiresBooking
                ? _sessionTypeValues[_sessionType]!.toString()
                : null,
        startDate:
            _category.requiresBooking
                ? _fmtDate(_eventDate!)
                : _fmtDate(_contentFromDate!),
        endDate: _category.requiresBooking ? null : _fmtDate(_contentToDate!),
        startTime: _category.requiresBooking ? _fmtTime(_startTime!) : null,
        endTime: _category.requiresBooking ? _fmtTime(_endTime!) : null,
        availableDate:
            _category.requiresBooking ? _fmtDate(_availableDate!) : null,
        totalSeats:
            _category.requiresBooking
                ? int.tryParse(_seatsCtl.text.trim())
                : null,
        title: _titleCtl.text.trim().isEmpty ? null : _titleCtl.text.trim(),
        description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
        address:
            _category.requiresBooking
                ? _addressCtl.text.trim()
                : null,
        promotionalImages:
            _category.requiresBooking ? null : _eventImages,
      );

      String msg = 'Event created!';
      final bodyText = resp.body.trim();
      if (bodyText.isNotEmpty) {
        try {
          final parsed = jsonDecode(bodyText);
          if (parsed is Map && parsed['message'] != null) {
            msg = parsed['message'].toString();
          }
        } catch (_) {
          // Some endpoints can return plain text/empty bodies.
        }
      }

      final ok = resp.statusCode == 200 || resp.statusCode == 201;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.black)),
          backgroundColor: ok ? Colors.white : AppColors.errorColor,
        ),
      );
      if (ok) Navigator.of(context).pop();
    } catch (e) {
      final raw = e.toString();
      final bool customCategory = !_category.requiresBooking;
      final String friendly =
          customCategory &&
                  (raw.toLowerCase().contains('location') ||
                      raw.toLowerCase().contains('session') ||
                      raw.toLowerCase().contains('totalseats') ||
                      raw.toLowerCase().contains('starttime') ||
                      raw.toLowerCase().contains('endtime'))
              ? 'Backend is still expecting bookable-event fields. Please update the backend DTO/validator to accept non-bookable categories.'
              : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $friendly'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Create an Event'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppPadding.screen,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InputField(
                  label: 'Event Category',
                  hintText: 'Select what type of event to create',
                  customContent: DropdownButtonFormField<EventCategory>(
                    value: _category,
                    hint: const Text(
                      'Select a category',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    decoration: _inputDecoration(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: AppColors.normalText),
                    items:
                        EventCategory.values
                            .map(
                              (category) => DropdownMenuItem<EventCategory>(
                                value: category,
                                child: Text(
                                  category.label,
                                  style: const TextStyle(
                                    color: AppColors.normalText,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: _onCategoryChanged,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _category.requiresBooking
                        ? 'Bookable Event: this includes booking windows, session type, seats, and full scheduling.'
                        : 'Non-bookable content event: use title, description, and optional image for promotions/announcements without booking seats.',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),

                const SizedBox(height: 16),

                InputField(
                  label: 'Title',
                  hintText: 'Enter event title',
                  controller: _titleCtl,
                  isRequired: false,
                  validator: (value) {
                    if (_category.requiresBooking) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required for this category';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                if (_category.requiresBooking) ...[
                  InputField(
                    label: 'Session Type',
                    hintText: 'Select session type',
                    customContent: DropdownButtonFormField<SessionType>(
                      value: _sessionType,
                      hint: const Text(
                        'Select session type',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      decoration: _inputDecoration(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: AppColors.normalText),
                      items:
                          SessionType.values
                              .where((session) => session != SessionType.all)
                              .map(
                                (session) => DropdownMenuItem<SessionType>(
                                  value: session,
                                  child: Text(
                                    SessionTypeHelper.format(session),
                                    style: const TextStyle(
                                      color: AppColors.normalText,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => setState(() => _sessionType = value),
                      validator:
                          (value) =>
                              value == null
                                  ? 'Please select a session type'
                                  : null,
                    ),
                  ),

                  const SizedBox(height: 16),

                  InputField(
                    label: 'Location',
                    hintText: 'Select city or town',
                    customContent: DropdownButtonFormField<Location>(
                      value: _location,
                      hint: const Text(
                        'Select city or town',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      decoration: _inputDecoration(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: AppColors.normalText),
                      items:
                          _locations
                              .map(
                                (loc) => DropdownMenuItem<Location>(
                                  value: loc,
                                  child: Text(
                                    loc.name,
                                    style: const TextStyle(
                                      color: AppColors.normalText,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => setState(() => _location = value),
                      validator:
                          (value) =>
                              value == null ? 'Please select a location' : null,
                    ),
                  ),

                  const SizedBox(height: 16),

                  InputField(
                    label: 'Address',
                    hintText: 'Enter venue address',
                    controller: _addressCtl,
                  ),

                  const SizedBox(height: 16),

                  InputField(
                    label: 'Date & Time',
                    hintText: 'When will the event happen?',
                    controller: TextEditingController(
                      text: _eventDate == null ? '' : _fmtDate(_eventDate!),
                    ),
                    onTap: () => _pickDate(eventDate: true),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SvgPicture.asset(
                        'assets/icons/calendar.svg',
                        width: 12,
                        height: 12,
                        colorFilter: const ColorFilter.mode(
                          Colors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: InputField(
                          hintText: 'Start',
                          onTap: () => _pickTime(start: true),
                          controller: TextEditingController(
                            text:
                                _startTime == null
                                    ? ''
                                    : _startTime!.format(context),
                          ),
                          suffixIcon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('to'),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InputField(
                          hintText: 'End',
                          onTap: () => _pickTime(start: false),
                          controller: TextEditingController(
                            text:
                                _endTime == null ? '' : _endTime!.format(context),
                          ),
                          suffixIcon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  InputField(
                    label: 'Booking Available Date',
                    hintText: 'When should bookings open?',
                    controller: TextEditingController(
                      text: _availableDate == null ? '' : _fmtDate(_availableDate!),
                    ),
                    onTap: () => _pickDate(eventDate: false),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SvgPicture.asset(
                        'assets/icons/calendar.svg',
                        width: 12,
                        height: 12,
                        colorFilter: const ColorFilter.mode(
                          Colors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'TOTAL NUMBER OF SEATS',
                          style: TextStyle(
                            fontFamily: 'WinnerSans',
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: InputField(
                          hintText: '',
                          controller: _seatsCtl,
                          keyboardType: TextInputType.number,
                          isRequired: false,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            final parsed = int.tryParse(value.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Invalid';
                            }
                            return null;
                          },
                          suffixIcon: const Icon(
                            Icons.event_seat,
                            color: AppColors.normalText,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ] else ...[
                  InputField(
                    label: 'From Date',
                    hintText: 'When should this appear from?',
                    controller: TextEditingController(
                      text:
                          _contentFromDate == null
                              ? ''
                              : _fmtDate(_contentFromDate!),
                    ),
                    onTap: () => _pickContentDate(from: true),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SvgPicture.asset(
                        'assets/icons/calendar.svg',
                        width: 12,
                        height: 12,
                        colorFilter: const ColorFilter.mode(
                          Colors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  InputField(
                    label: 'To Date',
                    hintText: 'When should this end?',
                    controller: TextEditingController(
                      text:
                          _contentToDate == null
                              ? ''
                              : _fmtDate(_contentToDate!),
                    ),
                    onTap: () => _pickContentDate(from: false),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SvgPicture.asset(
                        'assets/icons/calendar.svg',
                        width: 12,
                        height: 12,
                        colorFilter: const ColorFilter.mode(
                          Colors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'EVENT IMAGE (OPTIONAL)',
                    style: const TextStyle(
                      fontFamily: 'WinnerSans',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickEventImages,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                _eventImages.isEmpty ? 'Pick Images' : 'Add Images',
                              ),
                            ),
                            if (_eventImages.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => setState(() => _eventImages = []),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remove All'),
                              ),
                          ],
                        ),
                        if (_eventImages.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_eventImages.length} image(s) selected',
                            style: const TextStyle(
                              color: AppColors.normalText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 96,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _eventImages.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final file = _eventImages[index];
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        file,
                                        width: 120,
                                        height: 96,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _eventImages.removeAt(index));
                                        },
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                InputField(
                  label: 'Description',
                  hintText:
                      'Enter a description, additional notes, or requirements for the event.',
                  controller: _descCtl,
                  maxLines: 5,
                  isRequired: false,
                  textInputAction: TextInputAction.newline,
                  validator: (value) {
                    if (_category.requiresBooking) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required for this category';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                Button(
                  label:
                      _category.requiresBooking
                          ? 'Create Event'
                          : 'Create Content Event',
                  onPressed: _submit,
                  loading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
