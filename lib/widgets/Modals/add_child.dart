import 'dart:convert';
import 'package:corpsapp/models/medical_item.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/date_picker.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:corpsapp/widgets/medical_editor.dart';
import 'package:flutter/material.dart';
import '/services/auth_http_client.dart';

class AddChildModal extends StatefulWidget {
  final void Function(String? newChildId)? onChildAdded;

  const AddChildModal({super.key, this.onChildAdded});

  @override
  State<AddChildModal> createState() => _AddChildModalState();
}

class _AddChildModalState extends State<AddChildModal> {
  final fn = TextEditingController();
  final ln = TextEditingController();
  final emName = TextEditingController();
  final emPhone = TextEditingController();
  final dobController = TextEditingController();

  String? errorMessage;
  DateTime? dob;
  bool hasMedical = false;
final List<MedicalItem> medicalItems = [];
  bool isSubmitting = false;
  String _cap(String s) =>
    s.split(RegExp(r'\s+'))
     .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
     .join(' ');

  Future<void> _addMedical() async {
    final item = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, // shifts up when keyboard appears
        ),
        child: MedicalEditor(),
      ),
    );
    if (item != null) setState(() => medicalItems.add(item));
  }

  Future<void> _editMedical(int i) async {
    final updated = await showModalBottomSheet<MedicalItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, // shifts up when keyboard appears
        ),
        child: MedicalEditor(initial: medicalItems[i]),
      ),
    );
    if (updated != null) setState(() => medicalItems[i] = updated);
  }

  Future<void> _submit() async {
    if (fn.text.trim().isEmpty ||
        ln.text.trim().isEmpty ||
        dob == null ||
        emName.text.trim().isEmpty ||
        emPhone.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please fill out all required fields.';
      });
      return;
    }
    if (hasMedical && medicalItems.isEmpty) {
      setState(() {
        errorMessage = 'Please add at least one medical condition or allergy.';
      });
      return;
    }

  setState(() {
    isSubmitting = true;
    errorMessage = null; // clear previous errors
  });

    try {
      final body = {
        'firstName': _cap(fn.text.trim()),
        'lastName': _cap(ln.text.trim()),
        'dateOfBirth': dob!.toIso8601String().split('T').first,
        'emergencyContactName': _cap(emName.text.trim()),
        'emergencyContactPhone': emPhone.text.trim(),
        'hasMedicalConditions': hasMedical,
        if (hasMedical)
          'medicalConditions': medicalItems.map((m) => m.toJson()).toList(),
      };

      final res = await AuthHttpClient.post('/api/child', body: body);

      int? newId;
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['childId'] != null) {
          newId = (j['childId'] as num).toInt();
        }
      } catch (_) {}

      widget.onChildAdded?.call(newId?.toString());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        isSubmitting = false;
        errorMessage = 'Could not add child: $e';
      });    
      }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: AppPadding.screen.copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Add New Child',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'WinnerSans',
                ),
                textAlign: TextAlign.center,
              ),      

              const SizedBox(height: 12),

              InputField(
                label: 'First Name', 
                hintText: 'e.g. Jane', 
                controller: fn,
                prefixIcon: Icon(Icons.person_outline, color: Colors.black54),
              ),

              const SizedBox(height: 16),

              InputField(
                label: 'Last Name', 
                hintText: 'e.g. Doe', 
                controller: ln,
                prefixIcon: Icon(Icons.person_outline, color: Colors.black54),
              ),

              const SizedBox(height: 16),

              InputField(
                label: 'Date of Birth', 
                hintText: 'Select date of birth',
                controller: dobController,
                onTap: () async {
                  final dt = await DatePickerUtil.pickDate(context);
                  if (dt != null) {
                    setState(() {
                      dob = dt; 
                      dobController.text = dt.toIso8601String().split('T').first;
                    });
                  }
                },
                prefixIcon: Icon(Icons.calendar_today, color: Colors.black54),
              ),
              
              const SizedBox(height: 16),

              InputField(
                label: 'Emergency Contact Full Name', 
                hintText: 'e.g. John doe', 
                controller: emName,
                prefixIcon: Icon(Icons.contact_phone_outlined, color: Colors.black54),
              ),
            
              const SizedBox(height: 16),

              InputField(
                label: 'Emergency Contact Phone Number', 
                hintText: '021-555-1234', 
                controller: emPhone,
                prefixIcon: Icon(Icons.phone_outlined, color: Colors.black54),
              ),
            
              const SizedBox(height: 16),            

              // medical toggle
              SwitchListTile.adaptive(
                value: hasMedical,
                onChanged: (v) => setState(() => hasMedical = v),
                activeColor: AppColors.primaryColor,
                title: const Text(
                  'Does child have any medical conditions or allergies?',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),       
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 4),              
          
              if (hasMedical) ...[
                const SizedBox(height: 4),
                Button(
                  label: 'Add condition / allergy', 
                  onPressed: _addMedical,
                  buttonColor: Colors.transparent,
                  borderColor: Colors.white24,
                ),
                
                const SizedBox(height: 16),

                medicalItems.isEmpty
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
                      itemCount: medicalItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final it = medicalItems[i];
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
                                            child: Icon(
                                              Icons.warning_amber_rounded,
                                              size: 16,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        Flexible(
                                          child: Text(
                                            it.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    //description
                                    if (it.notes.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(it.notes,
                                        style: const TextStyle(color: Colors.white70)
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _editMedical(i),
                                icon: const Icon(Icons.edit,
                                    color: Colors.white),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => medicalItems.removeAt(i)),
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.errorColor),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ],

              // error message
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                Button(
                  label: 'Add Child', 
                  onPressed: _submit,
                  loading: isSubmitting,
                ),         
            ],
          ),
        ),
      );
  }
}