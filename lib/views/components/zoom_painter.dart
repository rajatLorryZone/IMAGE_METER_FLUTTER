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
  final ImageProvider? image;
  final ui.Image? imageObject;
  final Rect? imageRect;

  ZoomPainter({
    required this.arrows,
    this.selectedArrowIndex,
    this.currentArrow,
    required this.backgroundColor,
    required this.currentPoint,
    required this.zoomFactor,
    this.image,
    this.imageObject,
    this.imageRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Start by filling the background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Save the canvas state before transformations
    canvas.save();
    
    // VIEWPORT APPROACH: We treat the zoom view as a viewport
    // that shows a small portion of the main canvas but magnified
    
    // Step 1: Define the viewport size in the original coordinate system
    // This is the area around the current point that we want to magnify
    final viewportWidth = size.width / zoomFactor;
    final viewportHeight = size.height / zoomFactor;
    
    // Step 2: Calculate the viewport rectangle centered at the current point
    final viewportRect = Rect.fromCenter(
      center: currentPoint,
      width: viewportWidth,
      height: viewportHeight
    );
    
    // Step 3: Set up the transformation that maps the viewport to the zoom window
    // This transformation centers the current point and applies the zoom factor
    
    // First, center the zoom view (translate to the center of our window)
    canvas.translate(size.width / 2, size.height / 2);
    
    // Next, apply the zoom factor to magnify
    canvas.scale(zoomFactor);
    
    // Finally, translate so that currentPoint is at the center
    canvas.translate(-currentPoint.dx, -currentPoint.dy);
    
    // Step 4: Now paint the content within the viewport
    
    // 4a. If we have an image, paint it exactly where it appears in the main view
    if (imageObject != null) {
      // Paint the image first (as background)
      _paintDirectImageViewport(canvas, imageObject!, viewportRect);
    } else if (image != null) {
      // Fallback for placeholder when only image provider is available
      _paintImagePlaceholder(canvas);
    }
    
    // Draw grid for reference (positioned above the image)
    _drawGrid(canvas, currentPoint, size, zoomFactor);
    
    // Draw completed arrows
    for (int i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];
      final isSelected = selectedArrowIndex == i;
      
      final paint = Paint()
        ..color = arrow.arrowColor
        ..strokeWidth = arrow.arrowWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      if (arrow.isDashed) {
        // Draw a dashed line
        _drawDashedLine(canvas, arrow.start, arrow.end, paint);
      } else {
        // Draw a straight line
        canvas.drawLine(arrow.start, arrow.end, paint);
      }
      
      // Draw arrowhead
      _drawArrowhead(canvas, arrow.start, arrow.end, arrow.arrowColor, arrow.arrowWidth);
      
      // Draw the endpoints with different colors for clarity
      final startPointPaint = Paint()..color = Colors.blue;
      canvas.drawCircle(arrow.start, 5.0 / zoomFactor, startPointPaint);
      
      final endPointPaint = Paint()..color = Colors.red;
      canvas.drawCircle(arrow.end, 5.0 / zoomFactor, endPointPaint);
      
      // If selected, draw with a halo
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
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(currentArrow!.start, currentArrow!.end, paint);
      
      // Draw the current arrow endpoints
      final startPointPaint = Paint()..color = Colors.blue;
      canvas.drawCircle(currentArrow!.start, 5.0 / zoomFactor, startPointPaint);
      
      final endPointPaint = Paint()..color = Colors.red;
      canvas.drawCircle(currentArrow!.end, 5.0 / zoomFactor, endPointPaint);
      
      // Draw arrowhead for current arrow
      _drawArrowhead(canvas, currentArrow!.start, currentArrow!.end, currentArrow!.arrowColor, currentArrow!.arrowWidth);
    }
    
    // Restore the canvas state
    canvas.restore();
  }
  
  // Paint the actual image when we have a direct ui.Image object
  // This method is now replaced by _paintDirectImageViewport
  
  // Direct viewport-based approach for painting the image
  void _paintDirectImageViewport(Canvas canvas, ui.Image image, Rect viewportRect) {
    // Get the original image dimensions
    final double srcWidth = image.width.toDouble();
    final double srcHeight = image.height.toDouble();
    
    // Use high quality paint
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
    
    // The key insight: We need to render the image exactly as it appears in the main view
    // and let the canvas transformations handle the zooming and positioning
    
    if (imageRect == null) {
      // If we don't have image rect info, just center the image
      final srcRect = Rect.fromLTWH(0, 0, srcWidth, srcHeight);
      canvas.drawImageRect(
        image, 
        srcRect, 
        Rect.fromLTWH(-srcWidth/2, -srcHeight/2, srcWidth, srcHeight),
        paint
      );
      return;
    }
    
    // Source rectangle - the entire original image
    final srcRect = Rect.fromLTWH(0, 0, srcWidth, srcHeight);
    
    // CRITICAL CHANGE: Draw the image at exactly the same position as in the main view
    // This ensures perfect synchronization because we're using the same coordinate system
    // Our canvas transformations will ensure the correct part is visible and zoomed
    canvas.drawImageRect(image, srcRect, imageRect!, paint);
  }
  
  // This method is now replaced by _paintDirectImageViewport
  
  // Paint a placeholder when we only have an ImageProvider but no loaded image yet
  void _paintImagePlaceholder(Canvas canvas) {
    // For a zoom preview with an image background, we'll draw a rectangular area
    // that represents where the image would be
    final imageRectSize = Size(300, 300); // A reasonable default size
    
    // Create a Paint object for the image placeholder
    final imagePlaceholderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.fill;
      
    // Draw a rectangle to represent the image area
    final imageRect = Rect.fromCenter(
      center: Offset.zero, // Center of our zoomed view
      width: imageRectSize.width,
      height: imageRectSize.height,
    );
    
    canvas.drawRect(imageRect, imagePlaceholderPaint);
    
    // Draw a border around the image area
    final imageBorderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomFactor;
      
    canvas.drawRect(imageRect, imageBorderPaint);
    
    // Optional: draw some image-like pattern or icon
    final iconPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomFactor;
      
    // Draw a simple image icon
    final iconPath = Path();
    final iconSize = 40.0;
    iconPath.moveTo(-iconSize/2, -iconSize/2);
    iconPath.lineTo(iconSize/2, -iconSize/2);
    iconPath.lineTo(iconSize/2, iconSize/2);
    iconPath.lineTo(-iconSize/2, iconSize/2);
    iconPath.close();
    
    // Add a mountain-like shape to indicate an image
    iconPath.moveTo(-iconSize/2, iconSize/2);
    iconPath.lineTo(-iconSize/4, 0);
    iconPath.lineTo(0, iconSize/4);
    iconPath.lineTo(iconSize/4, -iconSize/4);
    iconPath.lineTo(iconSize/2, iconSize/2);
    
    canvas.drawPath(iconPath, iconPaint);
  }

  void _drawGrid(Canvas canvas, Offset point, Size size, double zoom) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5 / zoom;
    
    // Calculate the visible area
    final visibleRect = Rect.fromCenter(
      center: point,
      width: size.width / zoom,
      height: size.height / zoom,
    );
    
    // Calculate grid spacing (10 pixels in the normal view)
    const gridSpacing = 10.0;
    
    // Calculate the starting and ending grid lines
    final startX = (visibleRect.left ~/ gridSpacing) * gridSpacing;
    final endX = (visibleRect.right ~/ gridSpacing + 1) * gridSpacing;
    final startY = (visibleRect.top ~/ gridSpacing) * gridSpacing;
    final endY = (visibleRect.bottom ~/ gridSpacing + 1) * gridSpacing;
    
    // Draw vertical grid lines
    for (double x = startX; x <= endX; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, visibleRect.top),
        Offset(x, visibleRect.bottom),
        gridPaint,
      );
    }
    
    // Draw horizontal grid lines
    for (double y = startY; y <= endY; y += gridSpacing) {
      canvas.drawLine(
        Offset(visibleRect.left, y),
        Offset(visibleRect.right, y),
        gridPaint,
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
           oldDelegate.zoomFactor != zoomFactor;
  }
}
