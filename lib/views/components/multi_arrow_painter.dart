import 'package:flutter/material.dart';
import '../../models/arrow_model.dart';
import 'dart:math' as math ;

class MultiArrowPainter extends CustomPainter {
  final List<ArrowModel> arrows;
  final ArrowModel? currentArrow;
  final int? selectedArrowIndex;

  MultiArrowPainter({
    required this.arrows,
    this.currentArrow,
    this.selectedArrowIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all existing arrows
    for (int i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];
      final isSelected = selectedArrowIndex == i;
      
      _drawArrow(
        canvas: canvas,
        arrow: arrow,
        isSelected: isSelected,
      );
    }
    
    // Draw the currently being drawn arrow (if any)
    if (currentArrow != null) {
      _drawArrow(
        canvas: canvas,
        arrow: currentArrow!,
        isSelected: false,
      );
    }
  }

  void _drawArrow({
    required Canvas canvas,
    required ArrowModel arrow,
    required bool isSelected,
  }) {
    // Create main paint style for the arrow
    final paint = Paint()
      ..color = arrow.arrowColor
      ..strokeWidth = arrow.arrowWidth
      ..strokeCap = StrokeCap.round;
    
    // Draw the main line
    if (arrow.isDashed) {
      _drawDashedLine(canvas, paint, arrow.start, arrow.end);
    } else {
      canvas.drawLine(arrow.start, arrow.end, paint);
    }
    
    // Draw arrow heads at the ends of the line if showArrowStyle is true
    if (arrow.showArrowStyle) {
      // Left arrow point
      _drawArrowHead(canvas, paint, arrow.start, arrow.end);
      // Right arrow point
      _drawArrowHead(canvas, paint, arrow.end, arrow.start);
    }
    
    // Draw endpoint indicators for easier manipulation
    if (isSelected) {
      // Endpoint indicator paint
      final endpointPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
        
      final fillPaint = Paint()
        ..color = arrow.arrowColor
        ..style = PaintingStyle.fill;
        
      // Draw start point indicator
      canvas.drawCircle(arrow.start, 12, fillPaint);
      canvas.drawCircle(arrow.start, 12, endpointPaint);
      
      // Draw end point indicator
      canvas.drawCircle(arrow.end, 12, fillPaint);
      canvas.drawCircle(arrow.end, 12, endpointPaint);
    }
    
    // Draw the measurement text directly on the line
    _drawLabel(canvas, arrow);
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    final dashWidth = 8;
    final dashSpace = 5;
    
    double dx = end.dx - start.dx;
    double dy = end.dy - start.dy;
    double distance = math.sqrt(dx * dx + dy * dy);
    
    int dashCount = (distance / (dashWidth + dashSpace)).floor();
    if (dashCount <= 0) dashCount = 1;
    
    double ddx = dx / dashCount;
    double ddy = dy / dashCount;
    
    Offset startPoint = start;
    for (int i = 0; i < dashCount; i++) {
      Offset endPoint = Offset(
        startPoint.dx + ddx * dashWidth / (dashWidth + dashSpace),
        startPoint.dy + ddy * dashWidth / (dashWidth + dashSpace),
      );
      canvas.drawLine(startPoint, endPoint, paint);
      startPoint = Offset(
        startPoint.dx + ddx,
        startPoint.dy + ddy,
      );
    }
  }

  void _drawArrowHead(Canvas canvas, Paint paint, Offset from, Offset to) {
    // Calculate the direction and angle
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    
    if (distance < 1) return;
    
    final dirX = dx / distance;
    final dirY = dy / distance;
    
    // Offset from the end to avoid overlapping with line
    final offset = 3.0;
    final headLength = 15.0;
    final headWidth = 9.0;
    
    final tipX = from.dx + dirX * offset;
    final tipY = from.dy + dirY * offset;
    final tip = Offset(tipX, tipY);
    
    // Calculate perpendicular direction
    final perpX = -dirY;
    final perpY = dirX;
    
    // Draw the left side of the arrowhead
    final leftX = tipX + headLength * dirX + headWidth * perpX;
    final leftY = tipY + headLength * dirY + headWidth * perpY;
    final left = Offset(leftX, leftY);
    
    // Draw the right side of the arrowhead
    final rightX = tipX + headLength * dirX - headWidth * perpX;
    final rightY = tipY + headLength * dirY - headWidth * perpY;
    final right = Offset(rightX, rightY);
    
    // Draw the arrowhead
    canvas.drawLine(tip, left, paint);
    canvas.drawLine(tip, right, paint);
  }

  void _drawLabel(Canvas canvas, ArrowModel arrow) {
    if (arrow.label == null || arrow.label!.isEmpty) return;
    
    // Just show the measurement text without additional formatting
    final formattedLabel = '${arrow.label} ${arrow.unit}';
        
    final textSpan = TextSpan(
      text: formattedLabel,
      style: TextStyle(
        color: arrow.textColor, 
        fontSize: arrow.fontSize, // Use the arrow's font size property
        fontWeight: FontWeight.bold,
        backgroundColor: const Color.fromARGB(180, 255, 255, 255), // More visible background
        letterSpacing: 1.0,
        height: 1.2,
        shadows: const [
          Shadow(
            offset: Offset(1.0, 1.0),
            blurRadius: 2.0,
            color: Color.fromARGB(120, 0, 0, 0),
          ),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Calculate the angle of the line to rotate the text if needed
    final dx = arrow.end.dx - arrow.start.dx;
    final dy = arrow.end.dy - arrow.start.dy;
    final angle =math. atan2(dy, dx);
    
    // Calculate the middle point of the line
    final middleX = (arrow.start.dx + arrow.end.dx) / 2;
    final middleY = (arrow.start.dy + arrow.end.dy) / 2;
    
    canvas.save();
    
    // Only rotate if the line is not almost horizontal
    bool shouldRotate = angle.abs() >math.pi/4 && angle.abs() < 3*math.pi/4;
    
    if (shouldRotate) {
      // Center the rotation around the middle point
      canvas.translate(middleX, middleY);
      canvas.rotate(angle);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
    } else {
      // Just center the text on the line without rotation
      final middle = Offset(
        middleX - textPainter.width / 2,
        middleY - textPainter.height / 2,
      );
      textPainter.paint(canvas, middle);
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(MultiArrowPainter oldDelegate) {
    // Always repaint when something changes
    return true;
  }
}

class Vector {
  final double x;
  final double y;
  
  Vector(this.x, this.y);
  
  factory Vector.fromOffset(Offset offset) {
    return Vector(offset.dx, offset.dy);
  }
  
  double get length => math.sqrt(x * x + y * y);
  
  Vector normalized() {
    if (length == 0) return Vector(0, 0);
    return Vector(x / length, y / length);
  }
  
  Vector operator *(double scalar) {
    return Vector(x * scalar, y * scalar);
  }
  
  Vector rotate(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Vector(x * cos - y * sin, x * sin + y * cos);
  }
  
  Offset toOffset() {
    return Offset(x, y);
  }
}
