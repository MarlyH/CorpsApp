import 'dart:convert';
import 'dart:io';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/utils/date_picker.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../services/auth_http_client.dart';
import '../services/token_service.dart';

enum SessionType { Ages8to11, Ages12to15, Adults }
const _sessionTypeValues = {
  SessionType.Ages8to11: 0,
  SessionType.Ages12to15: 1,
  SessionType.Adults: 2
};

class CreateEventView extends StatefulWidget {
  const CreateEventView({super.key});
  @override
  State<CreateEventView> createState() => _CreateEventViewState();
}

class _CreateEventViewState extends State<CreateEventView> {
  final _formKey    = GlobalKey<FormState>();
  final _addressCtl = TextEditingController();
  final _descCtl    = TextEditingController();
  final _seatsCtl   = TextEditingController();

  SessionType? _sessionType;
  Location?    _location;
  DateTime?    _eventDate;
  TimeOfDay?   _startTime;
  TimeOfDay?   _endTime;
  DateTime?    _availableDate;

  bool _isLoading = false;
  List<Location> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final locs = await AuthHttpClient.fetchLocations();
      setState(() => _locations = locs);
    } catch (_) {
      // Optionally show an error
    }
  }

  Future<void> _pickDate({ required bool eventDate }) async {
    final now = DateTime.now();
    final d = await DatePickerUtil.pickDate(
      context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate:  now.add(const Duration(days: 365 * 5)),
    );
    if (d != null) {
      setState(() {
        if (eventDate) {
          _eventDate = d;
        } else {
          _availableDate = d;
        }
      });
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final now = TimeOfDay.now();

    if (Platform.isIOS) {
      // Cupertino-style picker
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
                    initialDateTime: DateTime(
                      0, 0, 0, now.hour, now.minute,
                    ),
                    use24hFormat: false,
                    onDateTimeChanged: (DateTime dt) {
                      tempDate = dt;
                    },
                  ),
                ),
                CupertinoButton(
                  child: const Text('Done',style: TextStyle(
                      color: CupertinoColors.activeBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),),
                  onPressed: () {
                    Navigator.of(context).pop(
                      TimeOfDay(hour: tempDate.hour, minute: tempDate.minute)
                    );
                  },
                ),
              ],
            ),
          );
        },
      );

      if (selectedTime != null) {
        setState(() {
          if (start) {
            _startTime = selectedTime;
          } else {
            _endTime = selectedTime;
          }
        });
      }

    } else {
      final t = await showTimePicker(context: context, initialTime: now);
      if (t != null) {
        setState(() {
          if (start) {
            _startTime = t;
          } else {
            _endTime = t;
          }
        });
      }
    }
  }


  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';

  InputDecoration _inputDecoration({
    String? labelText,
    String? hintText,
    Widget? suffixIcon,
  }) =>
    InputDecoration(
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

    if (_sessionType == null ||
        _location == null ||
        _eventDate == null ||
        _startTime == null ||
        _endTime == null ||
        _availableDate == null
    ) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.'))
      );
      return;
    }

    if (_availableDate!.isAfter(_eventDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking date must be on or before event date.'))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
      final uri  = Uri.parse('$base/api/events');
      final req  = http.MultipartRequest('POST', uri);

      final token = await TokenService.getAccessToken();
      if (token != null) req.headers['Authorization'] = 'Bearer $token';

      req.fields
        ..['locationId']      = _location!.id.toString()
        ..['sessionType']     = _sessionTypeValues[_sessionType]!.toString()
        ..['startDate']       = _fmtDate(_eventDate!)
        ..['startTime']       = _fmtTime(_startTime!)
        ..['endTime']         = _fmtTime(_endTime!)
        ..['availableDate']   = _fmtDate(_availableDate!)
        ..['totalSeats']      = _seatsCtl.text.trim()
        ..['address']         = _addressCtl.text.trim()
        ..['description']     = _descCtl.text.trim();

      final streamed = await req.send();
      final resp     = await http.Response.fromStream(streamed);
      final data     = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
      final msg      = data?['message']
          ?? (resp.statusCode == 200 ? 'Event created!' : 'Error ${resp.statusCode}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.black)),
          backgroundColor: resp.statusCode == 200 ? Colors.white : AppColors.errorColor
        ),
      );
      if (resp.statusCode == 200) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.errorColor)
      );
    } finally {
      setState(() => _isLoading = false);
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
                  label: 'Session Type',
                  hintText: '',
                  customContent: Row(children: [
                  Expanded(child: RadioListTile<SessionType>(
                    contentPadding: EdgeInsets.all(0),
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4), 
                    title: const Text('Ages 8 – 11', style: TextStyle(color: Colors.white)),
                    value: SessionType.Ages8to11,
                    groupValue: _sessionType,
                    activeColor: AppColors.primaryColor,
                    onChanged: (v) => setState(() => _sessionType = v),
                  )),
                  Expanded(child: RadioListTile<SessionType>(
                    contentPadding: EdgeInsets.all(0),
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4), 
                    title: const Text('Ages 12 – 15', style: TextStyle(color: Colors.white)),
                    value: SessionType.Ages12to15,
                    groupValue: _sessionType,
                    activeColor: AppColors.primaryColor,
                    onChanged: (v) => setState(() => _sessionType = v),
                  )),
                ]),
                ),

                const SizedBox(height: 16),

                // Location
                InputField(
                  label: 'Location',
                  hintText: 'Select city or town',
                  customContent: DropdownButtonFormField<Location>(
                    hint: Text('Select city or town', style: TextStyle(color: AppColors.disabled, fontWeight: FontWeight.bold)),
                    decoration: _inputDecoration(),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.black87),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: AppColors.normalText),
                    items: _locations.map((loc) => DropdownMenuItem<Location>(
                      value: loc,
                      child: Text(loc.name, style: const TextStyle(color: AppColors.normalText)),
                    )).toList(),
                    value: _location,
                    onChanged: (v) => setState(() => _location = v),
                    validator: (v) => v == null ? 'Please select a location' : null,
                  ),
                ),            

                const SizedBox(height: 16),

                // Address
                InputField(
                  label: 'Address',
                  hintText: 'Enter venue address',
                  controller: _addressCtl,
                ),

                const SizedBox(height: 16),

                // Date & Time section
                InputField(
                  label: 'Date & Time',
                  hintText: 'When will the event happen?',
                  controller: TextEditingController(
                    text: _eventDate == null ? '' : _fmtDate(_eventDate!)
                  ),
                  onTap: () => _pickDate(eventDate: true),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SvgPicture.asset(
                      'assets/icons/calendar.svg',
                      width: 12,
                      height: 12,
                      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Time range
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: InputField(
                        hintText: 'Start',
                        onTap: () => _pickTime(start: true),
                        controller: TextEditingController(
                          text: _startTime == null ? '' : _startTime!.format(context),
                        ),
                        suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.black54),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Text('to'),

                    const SizedBox(width: 16),
                   
                    Expanded(
                      child: InputField(
                        hintText: 'End',
                        onTap: () => _pickTime(start: false),
                        controller: TextEditingController(
                          text: _endTime == null ? '' : _endTime!.format(context),
                        ),
                        suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.black54),
                      ),
                    )                   
                  ],
                ),
              
                const SizedBox(height: 16),

                // Booking Opens On
                InputField(
                  label: 'Booking Available Date',
                  hintText: 'When should the booking be made available?',
                  controller: TextEditingController(
                    text: _availableDate == null ? '' : _fmtDate(_availableDate!)
                  ),
                  onTap: () => _pickDate(eventDate: false),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SvgPicture.asset(
                      'assets/icons/calendar.svg',
                      width: 12,
                      height: 12,
                      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                    ),
                  ),
                ),
            
                const SizedBox(height: 16),
                           
                Row(children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Total number of seats',
                      style: TextStyle(
                        fontFamily: 'WinnerSans',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ),
                  
                  Expanded(
                    flex: 1,
                    child: InputField(
                      hintText: '',
                      controller: _seatsCtl,
                      keyboardType: TextInputType.number,
                      suffixIcon: Icon(Icons.event_seat, color: AppColors.normalText),
                    )                   
                  ),
                ]),

                const SizedBox(height: 16),

                // Description
                InputField(
                  label: 'Description',
                  hintText: 'Enter a description, additional notes, or requirements for the event.',
                  controller: _descCtl,
                  maxLines: 5,
                ),         

                const SizedBox(height: 24),

                // Create Event Button
                Button(
                  label: 'Create Event', 
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
