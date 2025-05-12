import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'settings_model.g.dart';

@HiveType(typeId: 1)
class AppSettings {
  @HiveField(0)
  final Color defaultArrowColor;
  
  @HiveField(1)
  final Color defaultTextColor;
  
  @HiveField(2)
  final double defaultFontSize;
  
  @HiveField(3)
  final double defaultArrowWidth;
  
  @HiveField(4)
  final bool defaultDashedLine;

  @HiveField(5)
  final bool defaultShowArrowStyle;
  
  @HiveField(6)
  final String defaultUnit;
  
  @HiveField(7)
  final Color defaultBackgroundColor;

  const AppSettings({
    this.defaultArrowColor = Colors.blue,
    this.defaultTextColor = Colors.black,
    this.defaultFontSize = 16.0,
    this.defaultArrowWidth = 3.0,
    this.defaultDashedLine = false,
    this.defaultShowArrowStyle = true,
    this.defaultUnit = 'cm',
    this.defaultBackgroundColor = Colors.black,
  });

  // Create a copy with updated values
  AppSettings copyWith({
    Color? defaultArrowColor,
    Color? defaultTextColor,
    double? defaultFontSize,
    double? defaultArrowWidth,
    bool? defaultDashedLine,
    bool? defaultShowArrowStyle,
    String? defaultUnit,
    Color? defaultBackgroundColor,
  }) {
    return AppSettings(
      defaultArrowColor: defaultArrowColor ?? this.defaultArrowColor,
      defaultTextColor: defaultTextColor ?? this.defaultTextColor,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      defaultArrowWidth: defaultArrowWidth ?? this.defaultArrowWidth,
      defaultDashedLine: defaultDashedLine ?? this.defaultDashedLine,
      defaultShowArrowStyle: defaultShowArrowStyle ?? this.defaultShowArrowStyle,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      defaultBackgroundColor: defaultBackgroundColor ?? this.defaultBackgroundColor,
    );
  }
}
