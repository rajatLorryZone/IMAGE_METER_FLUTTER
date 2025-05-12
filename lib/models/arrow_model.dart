import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'arrow_model.g.dart';

@HiveType(typeId: 0)
class ArrowModel {
  @HiveField(0)
  Offset start;

  @HiveField(1)
  Offset end;

  @HiveField(2)
  String? label;

  @HiveField(3)
  String unit;

  @HiveField(4)
  Color arrowColor;

  @HiveField(5)
  Color textColor;

  @HiveField(6)
  double fontSize;

  @HiveField(7)
  double arrowWidth;

  @HiveField(8)
  Offset middlePoint = Offset.zero;

  @HiveField(9)
  bool isDashed;

  @HiveField(10)
  bool showArrowStyle; // Whether to show <--> or -----

  @HiveField(11, defaultValue: false)
  bool isSelected = false;

  ArrowModel({
    required this.start,
    required this.end,
    this.label,
    this.unit = "cm",
    this.arrowColor = Colors.blue,
    this.textColor = Colors.black,
    this.fontSize = 16.0,
    this.arrowWidth = 3.0,
    this.isDashed = false,
    this.showArrowStyle = true,
  });

  ArrowModel copyWith({
    Offset? start,
    Offset? end,
    String? label,
    String? unit,
    Color? arrowColor,
    Color? textColor,
    double? fontSize,
    double? arrowWidth,
    bool? isDashed,
    bool? showArrowStyle,
    bool? isSelected,
  }) {
    return ArrowModel(
      start: start ?? this.start,
      end: end ?? this.end,
      label: label ?? this.label,
      unit: unit ?? this.unit,
      arrowColor: arrowColor ?? this.arrowColor,
      textColor: textColor ?? this.textColor,
      fontSize: fontSize ?? this.fontSize,
      arrowWidth: arrowWidth ?? this.arrowWidth,
      isDashed: isDashed ?? this.isDashed,
      showArrowStyle: showArrowStyle ?? this.showArrowStyle,
    )..isSelected = isSelected ?? this.isSelected;
  }
}
