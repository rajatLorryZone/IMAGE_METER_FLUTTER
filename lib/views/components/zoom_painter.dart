import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../models/arrow_model.dart';

class ZoomPainter extends CustomPainter {
  final List<ArrowModel> arrows;
  final int? selectedArrowIndex;
  final ArrowModel? currentArrow;
  final Color backgroundColor;
  final Offset currentPoint;
  final double zoomFactor;
  final ui.Image? imageObject;
  final Rect? imageRect;
  final Offset panOffset; // New parameter for gesture panning

  ZoomPainter({
    required this.arrows,
    this.selectedArrowIndex,
    this.currentArrow,
    required this.backgroundColor,
    required this.currentPoint,
    required this.zoomFactor,
    this.imageObject,
    this.imageRect,
    this.panOffset = Offset.zero, // Default to no panning
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Start by filling the background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Save the canvas state before transformations
    canvas.save();
    
    // Calculate the viewport dimensions (the area we want to magnify)
    final viewportWidth = size.width / zoomFactor;
    final viewportHeight = size.height / zoomFactor;
    
    // Calculate the viewport rectangle centered at the current point
    final viewportRect = Rect.fromCenter(
      center: currentPoint,
      width: viewportWidth,
      height: viewportHeight
    );
    
    // Set up the transformation for the zoom view
    
    // 1. First translate to the center of our zoom window
    canvas.translate(size.width / 2, size.height / 2);
    
    // 2. Apply the zoom factor
    canvas.scale(zoomFactor);
    
    // 3. Translate to position the current point at the center, adjusted by pan offset
    canvas.translate(-currentPoint.dx + panOffset.dx, -currentPoint.dy + panOffset.dy);
    
    // Now paint the content within the viewport
    
    // If we have an image, paint it in its exact position
    if (imageObject != null && imageRect != null) {
      // Calculate the source rectangle - the part of the image to display
      _paintImage(canvas, imageObject!, imageRect!);
    } else {
      // If no image, draw a grid background
      _paintNoImageBackground(canvas, viewportRect);
    }
    
    // Draw the reference grid on top
    _drawGrid(canvas, currentPoint, size, zoomFactor);
    
    // Draw all arrows
    for (int i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];
      final isSelected = selectedArrowIndex == i;
      
      final paint = Paint()
        ..color = arrow.arrowColor
        ..strokeWidth = arrow.arrowWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      if (arrow.isDashed) {
        _drawDashedLine(canvas, arrow.start, arrow.end, paint);
      } else {
        canvas.drawLine(arrow.start, arrow.end, paint);
      }
      
      // Draw arrowhead
      _drawArrowhead(canvas, arrow.start, arrow.end, arrow.arrowColor, arrow.arrowWidth);
      
      // Highlight the endpoints
      final startPointPaint = Paint()..color = Colors.blue;
      canvas.drawCircle(arrow.start, 5.0 / zoomFactor, startPointPaint);
      
      final endPointPaint = Paint()..color = Colors.red;
      canvas.drawCircle(arrow.end, 5.0 / zoomFactor, endPointPaint);
      
      // Add special highlighting for selected arrows
      if (isSelected) {
        final highlightPaint = Paint()
          ..color = Colors.yellow.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = arrow.arrowWidth + 4;
          
        canvas.drawLine(arrow.start, arrow.end, highlightPaint);
      }
    }
    
    // Draw the current arrow being created
    if (currentArrow != null) {
      final paint = Paint()
        ..color = currentArrow!.arrowColor
        ..strokeWidth = currentArrow!.arrowWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      if (currentArrow!.isDashed) {
        _drawDashedLine(canvas, currentArrow!.start, currentArrow!.end, paint);
      } else {
        canvas.drawLine(currentArrow!.start, currentArrow!.end, paint);
      }
      
      // Only draw arrowhead if the arrow is long enough
      if ((currentArrow!.end - currentArrow!.start).distance > 10) {
        _drawArrowhead(canvas, currentArrow!.start, currentArrow!.end, 
            currentArrow!.arrowColor, currentArrow!.arrowWidth);
      }
      
      // Highlight current arrow endpoints with larger, more visible circles
      final startPointPaint = Paint()..color = Colors.blue.withOpacity(0.8);
      canvas.drawCircle(currentArrow!.start, 6.0 / zoomFactor, startPointPaint);
      
      final endPointPaint = Paint()..color = Colors.red.withOpacity(0.8);
      canvas.drawCircle(currentArrow!.end, 6.0 / zoomFactor, endPointPaint);
    }
    
    // Restore the canvas state
    canvas.restore();
  }
  
  void _paintImage(Canvas canvas, ui.Image image, Rect imageRect) {
    final imagePaint = Paint();
    
    // Draw the image in its exact position on screen
    // The canvas transformation will handle showing only the zoomed portion
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      imageRect,
      imagePaint,
    );
  }
  
  void _paintNoImageBackground(Canvas canvas, Rect viewportRect) {
    // Draw a light grid pattern as background when there's no image
    final bgGridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    // Draw a more spaced out background grid (every 50 pixels)
    const bgGridSpacing = 50.0;
    
    // Calculate grid bounds to cover the viewport
    final startX = (viewportRect.left ~/ bgGridSpacing) * bgGridSpacing - bgGridSpacing;
    final endX = (viewportRect.right ~/ bgGridSpacing + 2) * bgGridSpacing;
    final startY = (viewportRect.top ~/ bgGridSpacing) * bgGridSpacing - bgGridSpacing;
    final endY = (viewportRect.bottom ~/ bgGridSpacing + 2) * bgGridSpacing;
    
    // Draw vertical background grid lines
    for (double x = startX; x <= endX; x += bgGridSpacing) {
      canvas.drawLine(
        Offset(x, viewportRect.top - bgGridSpacing),
        Offset(x, viewportRect.bottom + bgGridSpacing),
        bgGridPaint,
      );
    }
    
    // Draw horizontal background grid lines
    for (double y = startY; y <= endY; y += bgGridSpacing) {
      canvas.drawLine(
        Offset(viewportRect.left - bgGridSpacing, y),
        Offset(viewportRect.right + bgGridSpacing, y),
        bgGridPaint,
      );
    }
  }

  void _drawGrid(Canvas canvas, Offset point, Size size, double zoom) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.4) // Slightly more visible
      ..strokeWidth = 0.5 / zoom;
    
    // Calculate the visible area in the zoom view
    final visibleRect = Rect.fromCenter(
      center: point,
      width: size.width / zoom,
      height: size.height / zoom,
    );
    
    // Use a 10-pixel grid spacing
    const gridSpacing = 10.0;
    
    // Calculate grid bounds
    final startX = (visibleRect.left ~/ gridSpacing - 1) * gridSpacing;
    final endX = (visibleRect.right ~/ gridSpacing + 2) * gridSpacing;
    final startY = (visibleRect.top ~/ gridSpacing - 1) * gridSpacing;
    final endY = (visibleRect.bottom ~/ gridSpacing + 2) * gridSpacing;
    
    // Draw vertical grid lines
    for (double x = startX; x <= endX; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, visibleRect.top - gridSpacing),
        Offset(x, visibleRect.bottom + gridSpacing),
        gridPaint,
      );
    }
    
    // Draw horizontal grid lines
    for (double y = startY; y <= endY; y += gridSpacing) {
      canvas.drawLine(
        Offset(visibleRect.left - gridSpacing, y),
        Offset(visibleRect.right + gridSpacing, y),
        gridPaint,
      );
    }
    
    // Draw axes with different color at x=0 and y=0 if they're in view
    if (startX <= 0 && 0 <= endX) {
      final axisPaint = Paint()
        ..color = Colors.blue.withOpacity(0.6)
        ..strokeWidth = 1.0 / zoom;
      
      canvas.drawLine(
        Offset(0, visibleRect.top - gridSpacing), 
        Offset(0, visibleRect.bottom + gridSpacing),
        axisPaint,
      );
    }
    
    if (startY <= 0 && 0 <= endY) {
      final axisPaint = Paint()
        ..color = Colors.red.withOpacity(0.6)
        ..strokeWidth = 1.0 / zoom;
      
      canvas.drawLine(
        Offset(visibleRect.left - gridSpacing, 0),
        Offset(visibleRect.right + gridSpacing, 0),
        axisPaint,
      );
    }
  }
  
  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Color color, double width) {
    if ((end - start).distance < 10) return; // Don't draw arrowhead for very short lines
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.fill;
    
    // Calculate the angle of the line
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    
    // Calculate the points for the arrowhead
    final arrowSize = math.max(8, width * 3);
    
    final path = Path();
    path.moveTo(end.dx, end.dy);
    path.lineTo(
      end.dx - arrowSize * math.cos(angle - math.pi / 6),
      end.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    path.lineTo(
      end.dx - arrowSize * math.cos(angle + math.pi / 6),
      end.dy - arrowSize * math.sin(angle + math.pi / 6),
    );
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final path = Path();
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    
    // Calculate the total distance
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    
    // Calculate the number of dashes
    final steps = distance / (dashWidth + dashSpace);
    final stepX = dx / steps;
    final stepY = dy / steps;
    
    path.moveTo(start.dx, start.dy);
    
    for (int i = 0; i < steps.floor(); i++) {
      path.lineTo(
        start.dx + (i + 1) * stepX,
        start.dy + (i + 1) * stepY,
      );
      if (i < steps.floor() - 1) {
        path.moveTo(
          start.dx + (i + 1) * stepX + dashSpace * stepX / (dashWidth + dashSpace),
          start.dy + (i + 1) * stepY + dashSpace * stepY / (dashWidth + dashSpace),
        );
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ZoomPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
           oldDelegate.selectedArrowIndex != selectedArrowIndex ||
           oldDelegate.currentArrow != currentArrow ||
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.currentPoint != currentPoint ||
           oldDelegate.zoomFactor != zoomFactor ||
           oldDelegate.imageObject != imageObject ||
           oldDelegate.imageRect != imageRect ||
           oldDelegate.panOffset != panOffset; // Also repaint when pan offset changes
  }
}
