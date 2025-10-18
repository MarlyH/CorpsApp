import 'dart:convert';
import 'package:corpsapp/models/medical_item.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:corpsapp/widgets/medical_editor.dart';
import 'package:flutter/material.dart';
import '/models/child_model.dart';
import '/services/auth_http_client.dart';


class EditChildView extends StatefulWidget {
  final ChildModel child;
  const EditChildView({super.key, required this.child});

  @override
  State<EditChildView> createState() => _EditChildViewState();
}

class _EditChildViewState extends State<EditChildView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _dob;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _hasMedical = false;
  final List<MedicalItem> _medicalItems = [];

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.child.firstName);
    _lastName = TextEditingController(text: widget.child.lastName);
    _dob = TextEditingController(text: widget.child.dateOfBirth);
    _contactName = TextEditingController(text: widget.child.emergencyContactName);
    _contactPhone = TextEditingController(text: widget.child.emergencyContactPhone);
    _loadChildDetails();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _dob.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  String _cap(String s) =>
      s.split(RegExp(r'\s+')).map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');

  Future<void> _loadChildDetails() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await AuthHttpClient.get('/api/child/${widget.child.childId}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;

      // basics
      _firstName.text = (j['firstName'] ?? '').toString();
      _lastName.text  = (j['lastName'] ?? '').toString();
      _dob.text       = (j['dateOfBirth'] ?? '').toString();
      _contactName.text  = (j['emergencyContactName'] ?? '').toString();
      _contactPhone.text = (j['emergencyContactPhone'] ?? '').toString();

      // medical
      final has = (j['hasMedicalConditions'] as bool?) ?? false;
      final list = (j['medicalConditions'] as List?) ?? const [];
      _medicalItems
        ..clear()
        ..addAll(list.whereType<Map<String, dynamic>>().map(MedicalItem.fromJson));
      _hasMedical = has;
    } catch (e) {
      _error = 'Failed to load details. You can still edit the basics.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hasMedical && _medicalItems.isEmpty) {
      _snack('Please add at least one condition/allergy or turn the toggle OFF.', err: true);
      return;
    }

    setState(() => _saving = true);

    final body = {
      'firstName': _cap(_firstName.text.trim()),
      'lastName': _cap(_lastName.text.trim()),
      'dateOfBirth': _dob.text.trim(), 
      'emergencyContactName': _cap(_contactName.text.trim()),
      'emergencyContactPhone': _contactPhone.text.trim(),
      'hasMedicalConditions': _hasMedical,
      if (_hasMedical)
        'medicalConditions': _medicalItems
            .where((m) => m.name.trim().isNotEmpty)
            .map((m) => m.toJson())
            .toList(),
    };

    try {
      final res = await AuthHttpClient.put('/api/child/${widget.child.childId}', body: body);
      if (res.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        final msg = _extractMsg(res.body) ?? 'Failed to update child.';
        _snack(msg, err: true);
      }
    } catch (e) {
      _snack('Network error: $e', err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomAlertDialog(
        title: 'Delete Child', 
        info: 'Are you sure you want to remove this child from your account? This action cannot be undone.',
        cancel: true,
        buttonLabel: 'Delete',
        buttonAction: () => Navigator.pop(context, true),
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final res = await AuthHttpClient.delete('/api/child/${widget.child.childId}');
      if (res.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        final msg = _extractMsg(res.body) ?? 'Failed to delete child.';
        _snack(msg, err: true);
      }
    } catch (e) {
      _snack('Network error: $e', err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _extractMsg(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['message'] != null) return j['message'].toString();
    } catch (_) {}
    return null;
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: err ? AppColors.errorColor : Colors.green),
    );
  }

  Future<void> _addMedicalItem() async {
    final item = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, // shifts up when keyboard appears
        ),
        child: MedicalEditor(),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
    if (item != null && mounted) setState(() => _medicalItems.add(item));
  }

  Future<void> _editMedicalItem(int index) async {
    final updated = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, // shifts up when keyboard appears
        ),
        child: MedicalEditor(initial: _medicalItems[index],),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
    if (updated != null && mounted) setState(() => _medicalItems[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(
        title: 'Edit Child',
        actionButton: Icon(Icons.delete_outline, color: AppColors.errorColor),
        actionOnTap: _saving ? null : _delete,
      ),
      
      body: SafeArea(
        bottom: true,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: AppPadding.screen,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(_error!, style: const TextStyle(color: Colors.white70)),
                        ),
                      ],
                      InputField(
                        label: 'First Name', 
                        hintText: 'e.g. Jane', 
                        controller: _firstName,
                        prefixIcon: Icon(Icons.person_outline, color: Colors.black54),
                        textCapitalization: TextCapitalization.words,
                      ),    

                      const SizedBox(height: 16),

                      InputField(
                        label: 'Last Name', 
                        hintText: 'e.g. Doe', 
                        controller: _lastName,
                        prefixIcon: Icon(Icons.person_outline, color: Colors.black54),
                        textCapitalization: TextCapitalization.words,
                      ),

                      const SizedBox(height: 16),

                      InputField(
                        label: 'Date of Birth', 
                        hintText: 'Select date of birth',
                        controller: _dob,
                        prefixIcon: Icon(Icons.calendar_today, color: Colors.black54),    
                        isReadOnly: true,
                        isDisabled: true,                  
                      ),
                      
                      const SizedBox(height: 16),

                      InputField(
                        label: 'Emergency Contact Full Name', 
                        hintText: 'e.g. John doe', 
                        controller: _contactName,
                        prefixIcon: Icon(Icons.contact_phone_outlined, color: Colors.black54),
                        textCapitalization: TextCapitalization.words,
                      ),
                    
                      const SizedBox(height: 16),

                      InputField(
                        label: 'Emergency Contact Phone Number', 
                        hintText: '021-555-1234', 
                        controller: _contactPhone,
                        prefixIcon: Icon(Icons.phone_outlined, color: Colors.black54),
                        keyboardType: TextInputType.phone,
                      ),
                    
                      const SizedBox(height: 16),

                      SwitchListTile.adaptive(
                        value: _hasMedical,
                        onChanged: (v) => setState(() => _hasMedical = v),
                        activeColor: AppColors.primaryColor,
                        title: const Text('Has medical conditions or allergies?',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)
                        ),       
                        contentPadding: EdgeInsets.zero,            
                      ),

                      const SizedBox(height: 4),              

                      if (_hasMedical) ...[
                        const SizedBox(height: 4),

                        Button(
                          label: 'Add condition / allergy', 
                          onPressed: _addMedicalItem,
                          buttonColor: Colors.transparent,
                          borderColor: Colors.white24,
                        ),
                        
                        const SizedBox(height: 16), 
                      
                        _medicalItems.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Text(
                                  'No medical conditions or allergies yet. Tap button above to add one.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _medicalItems.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final it = _medicalItems[i];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),                                  
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (it.isAllergy)
                                                    const Padding(
                                                      padding: EdgeInsets.only(right: 4),
                                                      child: Icon(Icons.warning_amber_rounded,
                                                          size: 16, color: Colors.amber),
                                                    ),
                                                  Flexible(
                                                    child: Text(it.name,
                                                        style: const TextStyle(
                                                            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                                                  ),
                                                ],
                                              ),
                                              if (it.notes.trim().isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(it.notes, style: const TextStyle(color: Colors.white70)),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _editMedicalItem(i),
                                          icon: const Icon(Icons.edit, color: Colors.white),
                                        ),
                                        IconButton(
                                          onPressed: () => setState(() => _medicalItems.removeAt(i)),
                                          icon: const Icon(Icons.delete_outline, color: AppColors.errorColor),
                                        ),
                                      ],
                                    )
                                  );                                
                                },
                              ),

                        const SizedBox(height: 16),

                        Button(
                          label: 'Update', 
                          onPressed: _update,
                          loading: _saving,
                        ),                          
                      ],                     
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

