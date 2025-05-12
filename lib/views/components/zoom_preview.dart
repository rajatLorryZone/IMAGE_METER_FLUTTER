import 'package:flutter/material.dart';

class ZoomPreview extends StatelessWidget {
  final Offset position;
  final double radius;
  final double zoom;
  final Widget child;
  final Color borderColor;

  const ZoomPreview({
    Key? key,
    required this.position,
    this.radius = 80.0,
    this.zoom = 3.0,
    required this.child,
    this.borderColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: OverflowBox(
          alignment: Alignment.center,
          maxWidth: radius * 2 * zoom,
          maxHeight: radius * 2 * zoom,
          child: Transform.translate(
            offset: Offset(
              -position.dx * zoom + radius,
              -position.dy * zoom + radius,
            ),
            child: Transform.scale(
              scale: zoom,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class ZoomPreviewContainer extends StatelessWidget {
  final Offset? startPosition;
  final Offset? endPosition;
  final Widget child;
  final double radius;
  final double zoom;

  const ZoomPreviewContainer({
    Key? key,
    this.startPosition,
    this.endPosition,
    required this.child,
    this.radius = 80.0,
    this.zoom = 3.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        
        // Display zoom previews if positions are available
        if (startPosition != null || endPosition != null)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (startPosition != null)
                  ZoomPreview(
                    position: startPosition!,
                    child: child,
                    radius: radius,
                    zoom: zoom,
                    borderColor: Colors.green,
                  ),
                  
                const SizedBox(width: 20),
                
                if (endPosition != null)
                  ZoomPreview(
                    position: endPosition!,
                    child: child,
                    radius: radius,
                    zoom: zoom,
                    borderColor: Colors.red,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}