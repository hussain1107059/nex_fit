import 'package:flutter/material.dart';

extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  String toSentenceCase() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }

  bool get isBlank => trim().isEmpty;

  bool get isNotBlank => !isBlank;

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

extension WidgetExtensions on Widget {
  Widget paddingAll(double value) => Padding(padding: EdgeInsets.all(value));

  Widget paddingSymmetric({double horizontal = 0, double vertical = 0}) =>
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        ),
      );

  Widget center() => Center(child: this);
}
