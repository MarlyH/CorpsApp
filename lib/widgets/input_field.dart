import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';

class InputField extends StatefulWidget {
  final String? label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onTap;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final bool isPassword;

  const InputField({
    super.key,
    this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.isPassword = false,
  });

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.onTap != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontFamily: 'WinnerSans',
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
        ],
        TextFormField(
          controller: widget.controller,
          textCapitalization: widget.textCapitalization,
          keyboardType: widget.isPassword
              ? TextInputType.visiblePassword
              : widget.keyboardType,
          obscureText: _obscure,
          onTap: widget.onTap,
          readOnly: readOnly,
          maxLines: widget.maxLines,
          style: const TextStyle(color: Colors.black),
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      setState(() => _obscure = !_obscure);
                    },
                  )
                : widget.suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
            errorStyle: TextStyle(color: AppColors.errorColor),
          ),
          validator: widget.validator ??
              (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }
}
