import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/material.dart';
import 'package:corpsapp/models/medical_item.dart';

class MedicalEditor extends StatefulWidget {
  const MedicalEditor({super.key, this.initial});
  final MedicalItem? initial;

  @override
  State<MedicalEditor> createState() => _MedicalEditorState();
}

class _MedicalEditorState extends State<MedicalEditor> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  bool _isAllergy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _notes = TextEditingController(text: widget.initial?.notes ?? '');
    _isAllergy = widget.initial?.isAllergy ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.screen,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [ 
          const SizedBox(height: 8),

          Text(
            'Medical Condition or Allergy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'WinnerSans',
            ),
            textAlign: TextAlign.center,
          ),  

          const SizedBox(height: 20),

          InputField(hintText: 'Name', controller: _name),

          const SizedBox(height: 8),

          InputField(
            hintText: 'Notes or Description (Optional)', 
            controller: _notes,
            maxLines: 3,
          ),

          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            value: _isAllergy,
            onChanged: (v) => setState(() => _isAllergy = v),
            activeColor: AppColors.primaryColor,
            title: const Text('Is this an allergy?', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Enable if this item is an allergy (e.g., peanuts, bee stings).',
                style: TextStyle(color: Colors.white70)),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 16),
          
          Row(
              children: [
                Expanded(
                  child: Button(
                    label: 'Cancel', 
                    onPressed: () => Navigator.pop(context),
                    borderColor: Colors.white,
                    buttonColor: AppColors.background,)
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Button(
                    label: 'Save', 
                    onPressed: () {
                      if (_name.text.trim().isEmpty) return;
                      Navigator.pop(
                        context,
                        MedicalItem(
                          name: _name.text.trim(),
                          notes: _notes.text.trim(),
                          isAllergy: _isAllergy,
                        ),
                      );
                    },                   
                  )                 
                ),
              ],
            ),
            const SizedBox(height: 16),
          ]
        ),     
      );
  }
}