import 'package:flutter/material.dart';

// Central color definitions
const Color primaryColor = Colors.indigo;
const Color accentColor = Colors.indigoAccent;

// Measurement units with display names and symbols
class MeasurementUnit {
  final String name;
  final String symbol;
  
  const MeasurementUnit({required this.name, required this.symbol});
}

// Central list of commonly used measurement units
const List<MeasurementUnit> measurementUnits = [
  MeasurementUnit(name: 'Centimeters', symbol: 'cm'),
  MeasurementUnit(name: 'Millimeters', symbol: 'mm'),
  MeasurementUnit(name: 'Meters', symbol: 'm'),
  MeasurementUnit(name: 'Inches', symbol: 'in'),
  MeasurementUnit(name: 'Feet', symbol: 'ft'),
  MeasurementUnit(name: 'Yards', symbol: 'yd'),
  MeasurementUnit(name: 'Pixels', symbol: 'px'),
  MeasurementUnit(name: 'Points', symbol: 'pt'),
];

// Function to get unit symbols only (for dropdowns)
List<String> getUnitSymbols() {
  return measurementUnits.map((unit) => unit.symbol).toList();
}

// Get default unit
String getDefaultUnit() {
  return 'cm'; // Default to centimeters
}
