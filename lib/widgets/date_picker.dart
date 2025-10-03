import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:corpsapp/theme/colors.dart';

class DatePickerUtil {
  static Future<DateTime?> pickDate(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final init = initialDate ?? DateTime(2008, 1, 1);
    final first = firstDate ?? DateTime(1900);
    final last = lastDate ?? now;

    if (Platform.isAndroid) {
      return showDatePicker(
        context: context,
        initialDate: init,
        firstDate: first,
        lastDate: last,
      );
    } else if (Platform.isIOS) {
      return showModalBottomSheet<DateTime>(
        context: context,
        builder: (BuildContext builder) {
          DateTime tempPickedDate = init;
          return Container(
            height: 300,
            color: AppColors.background,
            child: Column(
              children: [
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: init,
                    minimumDate: first,
                    maximumDate: last,
                    onDateTimeChanged: (DateTime picked) {
                      tempPickedDate = picked;
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(tempPickedDate),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: CupertinoColors.activeBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(builder).padding.bottom),
              ],
            ),
          );
        },
      );
    }
    return null;
  }
}
