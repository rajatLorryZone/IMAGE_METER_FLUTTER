import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(MaterialApp(home: ArrowDrawPage()));

class ArrowDrawPage extends StatefulWidget {
  @override
  _ArrowDrawPageState createState() => _ArrowDrawPageState();
}

class ArrowModel {
  Offset start;
  Offset end;
  String? label;
  String unit;
  Color arrowColor;
  Color textColor;
  double arrowWidth;
  bool isDashed;
  bool showArrowStyle; // Whether to show <--> or -----

  ArrowModel({
    required this.start,
    required this.end,
    this.label,
    this.unit = "cm",
    this.arrowColor = Colors.blue,
    this.textColor = Colors.black,
    this.arrowWidth = 3.0,
    this.isDashed = false,
    this.showArrowStyle = true,
  });
}

class _ArrowDrawPageState extends State<ArrowDrawPage> {
  List<ArrowModel> arrows = [];
  ArrowModel? currentArrow;
  int? selectedArrowIndex;
  Offset? dragOffset;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _screenshotKey = GlobalKey();
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }
  
  // Request all necessary permissions
  Future<void> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.storage,
        Permission.photos,
      ].request();
      
      // Log permission statuses
      statuses.forEach((permission, status) {
        print('$permission: $status');
      });
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }
  
  // Method to pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing gallery: $e'))
      );
    }
  }
  
  // Method to capture image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      await Permission.camera.request();
      final status = await Permission.camera.status;
      
      if (status.isGranted) {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 85,
        );
        if (photo != null) {
          setState(() {
            _imageFile = File(photo.path);
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera permission is required'))
        );
      }
    } catch (e) {
      print('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing camera: $e'))
      );
    }
  }
  
  // Method to capture screenshot
  Future<Uint8List?> _captureScreenshot() async {
    try {
      if (_screenshotKey.currentContext == null) return null;
      
      RenderRepaintBoundary boundary = _screenshotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
      return null;
    } catch (e) {
      print('Error capturing screenshot: $e');
      return null;
    }
  }
  
  // Method to save image
  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage permission is required'))
        );
        setState(() => _isSaving = false);
        return;
      }
      
      final imageBytes = await _captureScreenshot();
      if (imageBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image'))
        );
        setState(() => _isSaving = false);
        return;
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory.path}/measurement_$timestamp.png';
      
      File(imagePath).writeAsBytesSync(imageBytes);
      
      // Share the saved image
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: 'Measurement Image',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image saved and shared successfully'))
      );
    } catch (e) {
      print('Error saving image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e'))
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
  
  // Method to export as PDF
  Future<void> _exportAsPDF() async {
    setState(() => _isSaving = true);
    try {
      final imageBytes = await _captureScreenshot();
      if (imageBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image'))
        );
        setState(() => _isSaving = false);
        return;
      }
      
      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image),
            );
          },
        ),
      );
      
      // Display PDF preview
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Measurement_Document',
      );
      
    } catch (e) {
      print('Error creating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating PDF: $e'))
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Image Meter', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        actions: [
          // Save Image button
          IconButton(
            icon: Icon(Icons.save_alt),
            tooltip: 'Save Image',
            onPressed: _isSaving ? null : _saveImage,
          ),
          // Export as PDF button
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            tooltip: 'Export as PDF',
            onPressed: _isSaving ? null : _exportAsPDF,
          ),
          // Clear All button
          IconButton(
            icon: Icon(Icons.delete_sweep),
            tooltip: 'Clear All',
            onPressed: () {
              setState(() {
                arrows.clear();
              });
            },
          ),
          // Help button
          IconButton(
            icon: Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('How to Use'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• Drag to create measurement lines'),
                      Text('• Tap a line to edit its properties'),
                      Text('• Drag existing lines to move them'),
                      Text('• Use camera or gallery for background images'),
                      Text('• Save as image or export as PDF'),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      // Show loading indicator when saving
      body: _isSaving ? 
        Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing...', style: TextStyle(fontSize: 16)),
          ],
        )) : Stack(
        children: [
          // Main drawing area wrapped with RepaintBoundary for screenshots
          RepaintBoundary(
            key: _screenshotKey,
            child: GestureDetector(
              onPanStart: (details) {
                final pos = details.localPosition;
                final index = _getArrowAtPosition(pos);

                if (index != null) {
                  selectedArrowIndex = index;
                  dragOffset = pos;
                } else {
                  currentArrow = ArrowModel(start: pos, end: pos);
                  arrows.add(currentArrow!);
                  selectedArrowIndex = null;
                }
                setState(() {});
              },
              onPanUpdate: (details) {
                final pos = details.localPosition;

                if (selectedArrowIndex != null) {
                  final delta = pos - dragOffset!;
                  final arrow = arrows[selectedArrowIndex!];
                  setState(() {
                    arrow.start += delta;
                    arrow.end += delta;
                    dragOffset = pos;
                  });
                } else if (currentArrow != null) {
                  setState(() {
                    currentArrow!.end = pos;
                  });
                }
              },
              onPanEnd: (_) {
                currentArrow = null;
                selectedArrowIndex = null;
                dragOffset = null;
              },
              onTapUp: (details) {
                final index = _getArrowAtPosition(details.localPosition);
                if (index != null) {
                  _openLabelEditor(index);
                }
              },
              child: Container(
                color: Colors.white,
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    // Background image if available
                    if (_imageFile != null)
                      Positioned.fill(
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    // Arrow painter on top
                    CustomPaint(
                      size: Size.infinite,
                      painter: MultiArrowPainter(arrows: arrows),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Camera and gallery buttons
          Positioned(
            right: 16, 
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Camera button
                FloatingActionButton(
                  mini: true,
                  heroTag: 'camera',
                  backgroundColor: Colors.indigo.shade700,
                  child: Icon(Icons.camera_alt),
                  onPressed: _pickImageFromCamera,
                ),
                SizedBox(height: 12),
                // Gallery button
                FloatingActionButton(
                  mini: true,
                  heroTag: 'gallery',
                  backgroundColor: Colors.indigo.shade700,
                  child: Icon(Icons.photo_library),
                  onPressed: _pickImageFromGallery,
                ),
                SizedBox(height: 12),
                // Clear image button
                FloatingActionButton(
                  heroTag: 'clear',
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      _imageFile = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int? _getArrowAtPosition(Offset pos) {
    const threshold = 20.0;
    for (int i = arrows.length - 1; i >= 0; i--) {
      final arrow = arrows[i];
      final rect = Rect.fromPoints(arrow.start, arrow.end).inflate(threshold);
      if (rect.contains(pos)) return i;
    }
    return null;
  }

  void _openLabelEditor(int index) {
    final arrow = arrows[index];
    TextEditingController controller =
        TextEditingController(text: arrow.label ?? '');
    String unit = arrow.unit;
    Color selectedArrowColor = arrow.arrowColor;
    Color selectedTextColor = arrow.textColor;
    double arrowWidth = arrow.arrowWidth;
    bool isDashed = arrow.isDashed;
    bool showArrowStyle = arrow.showArrowStyle;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Measurement Properties', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Enter measurement',
                      border: OutlineInputBorder(),
                      filled: true,
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text('Unit', style: TextStyle(fontSize: 16)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: unit,
                              items: ['cm', 'm', 'mm', 'inch', 'ft', 'px']
                                  .map((u) => DropdownMenuItem(
                                        child: Text(u),
                                        value: u,
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setModalState(() {
                                  unit = val!;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text('Line Width', style: TextStyle(fontSize: 16)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Slider(
                          value: arrowWidth,
                          min: 1.0,
                          max: 8.0,
                          divisions: 7,
                          label: arrowWidth.toStringAsFixed(1),
                          onChanged: (val) {
                            setModalState(() {
                              arrowWidth = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          title: Text('Dashed Line'),
                          value: isDashed,
                          onChanged: (val) {
                            setModalState(() {
                              isDashed = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          title: Text('Show Arrow Style <---->'),
                          value: showArrowStyle,
                          onChanged: (val) {
                            setModalState(() {
                              showArrowStyle = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Divider(),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.arrow_forward),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedArrowColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.symmetric(vertical: 12)
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) {
                                return AlertDialog(
                                  title: Text('Pick Arrow Color'),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: selectedArrowColor,
                                      onColorChanged: (color) {
                                        setModalState(() => selectedArrowColor = color);
                                      },
                                      pickerAreaHeightPercent: 0.8,
                                      displayThumbColor: true,
                                      enableAlpha: false,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: Text('OK'),
                                      onPressed: () => Navigator.of(context).pop(),
                                    )
                                  ],
                                );
                              },
                            );
                          },
                          label: Text("Arrow Color"),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.text_fields),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedTextColor,
                            foregroundColor: selectedTextColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.symmetric(vertical: 12)
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) {
                                return AlertDialog(
                                  title: Text('Pick Text Color'),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: selectedTextColor,
                                      onColorChanged: (color) {
                                        setModalState(() => selectedTextColor = color);
                                      },
                                      pickerAreaHeightPercent: 0.8,
                                      displayThumbColor: true,
                                      enableAlpha: false,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: Text('OK'),
                                      onPressed: () => Navigator.of(context).pop(),
                                    )
                                  ],
                                );
                              },
                            );
                          },
                          label: Text("Text Color"),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade800, Colors.indigo.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 16)
                      ),
                      onPressed: () {
                        setState(() {
                          arrow.label = controller.text;
                          arrow.unit = unit;
                          arrow.arrowColor = selectedArrowColor;
                          arrow.textColor = selectedTextColor;
                          arrow.arrowWidth = arrowWidth;
                          arrow.isDashed = isDashed;
                          arrow.showArrowStyle = showArrowStyle;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Text('APPLY CHANGES', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class MultiArrowPainter extends CustomPainter {
  final List<ArrowModel> arrows;

  MultiArrowPainter({required this.arrows});

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in arrows) {
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
      
      // Draw the measurement text directly on the line
      _drawLabel(canvas, arrow);
    }
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    final dashWidth = 8;
    final dashSpace = 5;
    
    double dx = end.dx - start.dx;
    double dy = end.dy - start.dy;
    double distance = sqrt(dx * dx + dy * dy);
    
    int dashCount = (distance / (dashWidth + dashSpace)).floor();
    
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
    final distance = sqrt(dx * dx + dy * dy);
    
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
        fontSize: 16, 
        fontWeight: FontWeight.bold,
        backgroundColor: Color.fromARGB(180, 255, 255, 255), // More visible background
        letterSpacing: 1.0,
        height: 1.2,
        shadows: [
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
    final angle = atan2(dy, dx);
    
    // Calculate the middle point of the line
    final middleX = (arrow.start.dx + arrow.end.dx) / 2;
    final middleY = (arrow.start.dy + arrow.end.dy) / 2;
    
    canvas.save();
    
    // Only rotate if the line is not almost horizontal
    bool shouldRotate = angle.abs() > pi/4 && angle.abs() < 3*pi/4;
    
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
  bool shouldRepaint(covariant MultiArrowPainter oldDelegate) => true;
}
