import 'package:corpsapp/models/medical_condition.dart';
import 'package:flutter/material.dart';
import 'package:corpsapp/theme/colors.dart'; 

class MedicalTile extends StatelessWidget {
  final MedicalCondition medicalCondition;
  final bool useWhiteBackground;

  const MedicalTile(this.medicalCondition, {super.key, this.useWhiteBackground = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: useWhiteBackground ? Colors.black12 : Colors.white54),
        color: useWhiteBackground ? Color(0xFFF7F7F7) : Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: medicalCondition.isAllergy ? 8 : 0,
              right: medicalCondition.isAllergy ? 8 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicalCondition.name,
                  style: TextStyle(
                    color: useWhiteBackground ? AppColors.normalText : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if ((medicalCondition.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    medicalCondition.notes!,
                    style: TextStyle(color: useWhiteBackground ? AppColors.normalText : Colors.white),
                  ),
                ],
              ],
            ),
          ),

          if (medicalCondition.isAllergy)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x33FF5252),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.errorColor),
                ),
                child: const Text(
                  'ALLERGY',
                  style: TextStyle(
                    color: AppColors.errorColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
