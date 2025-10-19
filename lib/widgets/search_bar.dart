import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final String hintText;

  const CustomSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onClear,
    required this.hintText
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.normalText),

          const SizedBox(width: 8),

          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.normalText),
              cursorColor: Colors.black,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.black54),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
            ),
          ),

          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, color: Colors.black54),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}
