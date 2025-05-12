import 'package:flutter/material.dart';
import 'dart:math';
import 'package:image_meter/models/arrow_model.dart';

// Helper methods for the HomeView
// This file contains utility methods that were previously causing reference errors

// Check if touch position is near an arrow endpoint
bool isNearEndpoint(Offset touchPoint, Offset endpoint, double radius) {
  return (touchPoint - endpoint).distance < radius;
}

// Calculate distance from point to line segment
double distanceToLineSegment(Offset point, Offset start, Offset end) {
  // Vector from start to end
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  
  // Square of length of line segment
  final l2 = dx * dx + dy * dy;
  
  // If line segment is actually a point, just return distance to the point
  if (l2 == 0) return (point - start).distance;
  
  // Calculate projection scalar
  final t = max(0, min(1, ((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) / l2));
  
  // Calculate projection point
  final p = Offset(
    start.dx + t * (end.dx - start.dx),
    start.dy + t * (end.dy - start.dy),
  );
  
  // Return distance to the nearest point
  return (point - p).distance;
}

// Get the arrow at the position, if any
int? getArrowAtPosition(Offset position, List<ArrowModel> arrows) {
  // Check in reverse order to find the top-most arrow first
  for (int i = arrows.length - 1; i >= 0; i--) {
    final arrow = arrows[i];
    
    // Calculate distance from point to line segment
    final distance = distanceToLineSegment(position, arrow.start, arrow.end);
    
    // Adjust tap precision based on arrow width - increased for easier selection
    final tapPrecision = max(20.0, arrow.arrowWidth * 5);
    
    if (distance < tapPrecision) {
      return i;
    }
  }
  
  return null;
}
