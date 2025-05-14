import 'package:flutter/material.dart';
import 'dart:math' as math;

class GestureZoomWrapper extends StatefulWidget {
  final Widget child;
  final Function(double scale, Offset focalPoint)? onScaleUpdate;
  final Function()? onScaleEnd;
  final bool enableZoom;

  const GestureZoomWrapper({
    Key? key,
    required this.child,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.enableZoom = true,
  }) : super(key: key);

  @override
  _GestureZoomWrapperState createState() => _GestureZoomWrapperState();
}

class _GestureZoomWrapperState extends State<GestureZoomWrapper> {
  double _currentScale = 1.0;
  Offset _focalPoint = Offset.zero;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: widget.enableZoom 
          ? (details) {
              setState(() {
                _focalPoint = details.focalPoint;
              });
            }
          : null,
      onScaleUpdate: widget.enableZoom 
          ? (details) {
              // Limit scale to reasonable bounds (0.5 to 5.0)
              final newScale = math.max(0.5, math.min(5.0, details.scale));
              
              setState(() {
                _currentScale = newScale;
                _focalPoint = details.focalPoint;
              });
              
              if (widget.onScaleUpdate != null) {
                widget.onScaleUpdate!(_currentScale, _focalPoint);
              }
            }
          : null,
      onScaleEnd: widget.enableZoom 
          ? (details) {
              if (widget.onScaleEnd != null) {
                widget.onScaleEnd!();
              }
            }
          : null,
      child: widget.child,
    );
  }
}
