import 'package:flutter/material.dart';

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({Key? key}) : super(key: key);

  @override
  _DrawingScreenState createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<Line> lines = [];
  Offset? startPoint;
  Offset? endPoint;
  bool isDrawing = false;
  
  // For zoom preview
  final double zoomFactor = 4.0;
  final double zoomSize = 80.0;
  
  // For dynamic positioning of zoom container
  bool isZoomContainerAtTop = true;
  final double zoomContainerHeight = 100.0;
  final double zoomContainerTopMargin = 10.0;
  final double zoomContainerBottomMargin = 10.0;
  final double pointerPositionThreshold = 150.0; // Distance threshold to trigger repositioning

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Line Drawing with Zoom Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                lines.clear();
                startPoint = null;
                endPoint = null;
                isDrawing = false;
              });
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Get the screen height for accurate position calculation
          final screenHeight = constraints.maxHeight;
          
          return GestureDetector(
            onPanStart: (details) {
              setState(() {
                startPoint = details.localPosition;
                endPoint = details.localPosition;
                isDrawing = true;
                
                // Check if we need to reposition the zoom container
                // If finger is in the top part of the screen where the zoom preview would be
                if (details.localPosition.dy < zoomContainerHeight + zoomContainerTopMargin + pointerPositionThreshold) {
                  isZoomContainerAtTop = false; // Move it to bottom
                } else {
                  isZoomContainerAtTop = true; // Keep it at top
                }
              });
            },
            onPanUpdate: (details) {
              setState(() {
                endPoint = details.localPosition;
                
                // Update container position based on the current drawing position
                // If drawing near top and container is at top, move to bottom
                if (isZoomContainerAtTop && 
                    details.localPosition.dy < zoomContainerHeight + zoomContainerTopMargin + pointerPositionThreshold) {
                  isZoomContainerAtTop = false;
                } 
                // If drawing near bottom and container is at bottom, move to top
                else if (!isZoomContainerAtTop && 
                         details.localPosition.dy > screenHeight - (zoomContainerHeight + zoomContainerBottomMargin + pointerPositionThreshold)) {
                  isZoomContainerAtTop = true;
                }
              });
            },
            onPanEnd: (details) {
              setState(() {
                if (startPoint != null && endPoint != null) {
                  lines.add(Line(startPoint!, endPoint!, Colors.black, 2.0));
                }
                isDrawing = false;
                startPoint = null;
                endPoint = null;
                
                // Reset zoom container to top position when drawing is complete
                isZoomContainerAtTop = true;
              });
            },
            child: Stack(
              children: [
                // Main drawing area
                CustomPaint(
                  painter: LinePainter(lines, startPoint, endPoint, isDrawing),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                
                // Dynamically positioned zoom preview container
                if (endPoint != null && isDrawing)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300), // Smooth transition
                    curve: Curves.easeOut,
                    top: isZoomContainerAtTop ? zoomContainerTopMargin : null,
                    bottom: !isZoomContainerAtTop ? zoomContainerBottomMargin : null,
                    left: 0,
                    right: 0,
                    height: zoomContainerHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildZoomPreview(endPoint!, false),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // No longer needed since we handle positioning directly in the onPanStart/onPanUpdate methods

  Widget _buildZoomPreview(Offset point, bool isStart) {
    return Container(
      width: 300,
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: isStart ? Colors.blue : Colors.red, width: 2),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(zoomSize, zoomSize),
            painter: ZoomPainter(
              lines: lines,
              currentPoint: point,
              isStart: isStart,
              zoomFactor: zoomFactor,
              currentStartPoint: startPoint,
              currentEndPoint: endPoint,
              isDrawing: isDrawing,
            ),
          ),
          Positioned(
            bottom: 5,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                isStart ? "Start" : "End",
                style: TextStyle(
                  color: isStart ? Colors.blue : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Line {
  final Offset start;
  final Offset end;
  final Color color;
  final double width;

  Line(this.start, this.end, this.color, this.width);
}

class LinePainter extends CustomPainter {
  final List<Line> lines;
  final Offset? startPoint;
  final Offset? endPoint;
  final bool isDrawing;

  LinePainter(this.lines, this.startPoint, this.endPoint, this.isDrawing);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed lines
    for (var line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.width
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(line.start, line.end, paint);
      
      // Draw endpoints for completed lines
      _drawEndpoint(canvas, line.start, Colors.blue);
      _drawEndpoint(canvas, line.end, Colors.red);
    }

    // Draw the line being currently drawn
    if (isDrawing && startPoint != null && endPoint != null) {
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(startPoint!, endPoint!, paint);
      
      // Draw endpoints for the current line
      _drawEndpoint(canvas, startPoint!, Colors.blue);
      _drawEndpoint(canvas, endPoint!, Colors.red);
    }
  }

  void _drawEndpoint(Canvas canvas, Offset point, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(point, 5.0, paint);
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) {
    return true;
  }
}

class ZoomPainter extends CustomPainter {
  final List<Line> lines;
  final Offset currentPoint;
  final bool isStart;
  final double zoomFactor;
  final Offset? currentStartPoint;
  final Offset? currentEndPoint;
  final bool isDrawing;

  ZoomPainter({
    required this.lines,
    required this.currentPoint,
    required this.isStart,
    required this.zoomFactor,
    required this.currentStartPoint,
    required this.currentEndPoint,
    required this.isDrawing,
  });
  
  // Helper method to check if a point is visible on screen
  bool _isPointVisible(Offset point) {
    // Assuming standard screen bounds
    final screenBounds = Rect.fromLTWH(0, 0, 1000, 2000); // Large enough estimate
    return screenBounds.contains(point);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the center of the zoom preview
    final center = Offset(size.width / 2, size.height / 2);
    
    // Save the canvas state
    canvas.save();
    
    // Draw a background for the zoomed area
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      bgPaint,
    );
    
    // Keep track of whether the point is visible on the screen
    bool isPointVisible = _isPointVisible(currentPoint);
    
    // Translate to the center and scale
    canvas.translate(center.dx, center.dy);
    canvas.scale(zoomFactor);
    canvas.translate(-currentPoint.dx, -currentPoint.dy);
    
    // Draw a grid for better visual reference
    _drawGrid(canvas, currentPoint, size, zoomFactor);
    
    // Draw completed lines
    for (var line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.width
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(line.start, line.end, paint);
    }
    
    // Draw the current line being drawn
    if (isDrawing && currentStartPoint != null && currentEndPoint != null) {
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(currentStartPoint!, currentEndPoint!, paint);
    }
    
    // Draw the point with emphasis
    final pointPaint = Paint()
      ..color = isStart ? Colors.blue : Colors.red
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(currentPoint, 3.0 / zoomFactor, pointPaint);
    
    // Restore the canvas state
    canvas.restore();
    
    // Draw a crosshair in the center for precise positioning
    final crosshairPaint = Paint()
      ..color = isStart ? Colors.blue : Colors.red
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      Offset(center.dx - 10, center.dy),
      Offset(center.dx + 10, center.dy),
      crosshairPaint,
    );
    
    canvas.drawLine(
      Offset(center.dx, center.dy - 10),
      Offset(center.dx, center.dy + 10),
      crosshairPaint,
    );
    
    // Draw "Off Screen" indicator if the point is not visible
    if (!isPointVisible) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: "Point is off screen",
          style: TextStyle(
            color: Colors.red,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: size.width - 10);
      textPainter.paint(canvas, Offset(5, 5));
    }
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

  @override
  bool shouldRepaint(ZoomPainter oldDelegate) => true;
}
