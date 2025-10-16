import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:flutter/material.dart';

class SingleFieldDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String hint;
  const SingleFieldDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.hint,
  });

  @override
  __SingleFieldDialogState createState() => __SingleFieldDialogState();
}

class __SingleFieldDialogState extends State<SingleFieldDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),

              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.text,
                style: TextStyle(fontSize: 16, color: AppColors.normalText, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: Colors.black26),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Button(label: 'Save', onPressed: () => Navigator.pop(context, _ctrl.text.trim())),
            ],
          ),
        ),
      )
    );
  }
}