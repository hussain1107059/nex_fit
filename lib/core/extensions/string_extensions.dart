import 'package:flutter/material.dart';

extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  String toBanglaDigits() {
    const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return codeUnits.map((unit) {
      if (unit >= 0x30 && unit <= 0x39) return bangla[unit - 0x30];
      return String.fromCharCode(unit);
    }).join();
  }
}

extension SizedBoxExtensions on num {
  SizedBox get widthSpace => SizedBox(width: toDouble());

  SizedBox get heightSpace => SizedBox(height: toDouble());
}
