import 'dart:developer';

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'components/zoom_painter.dart';
import 'package:image_meter/models/arrow_model.dart';
import 'package:image_meter/models/project_model.dart';
import 'package:image_meter/models/settings_model.dart';
import 'package:image_meter/services/settings_service.dart';
import 'package:image_meter/services/project_service.dart';
import 'package:image_meter/utils/constants.dart'; // Import constants file
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'components/multi_arrow_painter.dart';
// custom_toolbar.dart no longer needed
import 'home_view_helpers.dart';
import 'home_view_save.dart';

// Loading indicator widget
void showLoading(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryColor),
                const SizedBox(height: 16),
                const Text('Processing...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void hideLoading(BuildContext context) {
  Navigator.of(context).pop();
}

class ArrowDrawPage extends StatefulWidget {
  final Project? existingProject;
  final String projectName;
  final Color backgroundColor;
  final String? siteId; // Add site ID parameter

  const ArrowDrawPage({
    Key? key,
    this.existingProject,
    this.projectName = 'Untitled Project',
    this.backgroundColor = Colors.black,
    this.siteId, // Add site ID parameter
  }) : super(key: key);

  @override
  _ArrowDrawPageState createState() => _ArrowDrawPageState();
}

class _ArrowDrawPageState extends State<ArrowDrawPage> {
  final ProjectService _projectService = ProjectService();
  final SettingsService _settingsService = SettingsService();
  final GlobalKey _screenshotKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  // For arrows and projects
  List<ArrowModel> arrows = [];
  ArrowModel? currentArrow;
  int? selectedArrowIndex;
  File? _imageFile;
  ui.Image? _uiImage; // UI image for zoom view
  String _projectName = '';
  String? _projectId;
  Color _backgroundColor = Colors.black;
  AppSettings _settings = const AppSettings();
  bool _isSettingsLoaded = false;
  bool _isSaving = false;
  bool _isEndPointDrag = false;
  bool _isStartPointDrag = false;
  bool _isMiddlePointDrag = false;
  Offset? dragOffset;

  // For image area drawing restriction
  Rect? _imageRect; // Track the actual image boundaries on screen
  double _endpointTouchRadius =
      35.0; // Increased touch detection radius for easier endpoint manipulation
  double _middlePointTouchRadius =
      15.0; // Touch radius for detecting middle point drag

  // For zoom preview
  final double zoomFactor = 3.0; // Default zoom factor
  Offset zoomPoint = Offset.zero;
  Offset zoomContainerPosition = const Offset(
    20,
    80,
  ); // Default top-left position
  Size zoomContainerSize = const Size(300, 300);
  bool _showZoomPreview = false;
  bool _isZoomContainerAtTop = true;
  Offset _zoomPanOffset = Offset.zero; // Pan offset for zoom view dragging
  final double zoomContainerHeight = 100.0;
  final double zoomContainerTopMargin = 10.0;
  final double zoomContainerBottomMargin = 80.0;
  final double pointerPositionThreshold =
      150.0; // Distance threshold to trigger repositioning

  // For image zooming and panning
  Matrix4 _transformMatrix = Matrix4.identity();
  double _currentScale = 1.0;
  Offset _currentTranslation = Offset.zero;
  
  // For gesture handling
  double _baseScale = 1.0;
  Offset _baseTranslation = Offset.zero;
  Offset _normalizedFocalPoint = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;
  bool _isZooming = false;
  Offset _focalPoint = Offset.zero;
  
  // For preserving state between modes
  Matrix4 _savedTransformMatrix = Matrix4.identity();
  
  // For compatibility with existing code
  Offset _imageTranslation = Offset.zero;
  
  // Toggle between drawing and zoom mode
  void _toggleDrawingMode() {
    setState(() {
      if (_isDrawingModeEnabled) {
        // Save current transform before switching to zoom mode
        _savedTransformMatrix = Matrix4.identity()
          ..translate(_currentTranslation.dx, _currentTranslation.dy)
          ..scale(_currentScale);
      } else {
        // Restore the saved transform when entering drawing mode
        final translation = _savedTransformMatrix.getTranslation();
        _currentTranslation = Offset(translation.x, translation.y);
        _currentScale = _savedTransformMatrix.getMaxScaleOnAxis();
      }
      _isDrawingModeEnabled = !_isDrawingModeEnabled;
      _updateTransformMatrix();
    });
  }
  
  // Handle scale start for zooming
  void _handleScaleStart(ScaleStartDetails details) {
    if (!_isDrawingModeEnabled) {
      setState(() {
        _baseScale = _currentScale;
        _baseTranslation = _currentTranslation;
        _lastFocalPoint = details.focalPoint;
        _isZooming = false;
        
        // Calculate the focal point relative to the image
        final focalPointRelativeToImage = details.focalPoint - _currentTranslation;
        _normalizedFocalPoint = Offset(
          focalPointRelativeToImage.dx / _currentScale,
          focalPointRelativeToImage.dy / _currentScale,
        );
      });
    }
  }
  
  // Handle scale update for zooming and panning
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!_isDrawingModeEnabled) {
      setState(() {
        // Handle zooming and panning together
        if (details.scale != 1.0) {
          _isZooming = true;
          // Zoom with focal point
          _currentScale = (_baseScale * details.scale).clamp(0.5, 5.0);
          
          // Calculate the focal point in the image's coordinate space
          final focalPointInImageSpace = Offset(
            _normalizedFocalPoint.dx * _currentScale,
            _normalizedFocalPoint.dy * _currentScale,
          );
          
          // Adjust the translation to keep the focal point under the finger
          _currentTranslation = details.focalPoint - focalPointInImageSpace;
        } else {
          // Handle pure panning
          final delta = details.focalPoint - _lastFocalPoint;
          _currentTranslation = _baseTranslation + delta;
        }
        
        // Update the last focal point for the next update
        _lastFocalPoint = details.focalPoint;
        
        // Apply constraints to keep the image within bounds
        _applyImageConstraints();
        
        // Update the transform matrix
        _updateTransformMatrix();
      });
    }
  }
  
  // Apply constraints to keep the image within bounds
  void _applyImageConstraints() {
    if (_imageRect == null) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate the scaled image dimensions
    final scaledWidth = _imageRect!.width * _currentScale;
    final scaledHeight = _imageRect!.height * _currentScale;
    
    // Calculate the maximum allowed translation
    final maxDx = math.max(0.0, (scaledWidth - screenWidth) / 2);
    final maxDy = math.max(0.0, (scaledHeight - screenHeight) / 2);
    
    // Calculate the minimum translation needed to keep the image on screen
    final minDx = -maxDx;
    final minDy = -maxDy;
    
    // Apply constraints to keep the image on screen
    _currentTranslation = Offset(
      _currentTranslation.dx.clamp(minDx, maxDx),
      _currentTranslation.dy.clamp(minDy, maxDy),
    );
  }
  
  // Update the transform matrix with current translation and scale
  void _updateTransformMatrix() {
    _transformMatrix = Matrix4.identity()
      ..translate(_currentTranslation.dx, _currentTranslation.dy)
      ..scale(_currentScale);
      
    // Update the image translation for compatibility with existing code
    _imageTranslation = _currentTranslation;
  }
  
  // Handle scale end - finalize the transform
  void _handleScaleEnd(ScaleEndDetails details) {
    if (!_isDrawingModeEnabled) {
      setState(() {
        _isZooming = false;
        
        // Ensure we have valid values
        _currentScale = _currentScale.clamp(0.5, 5.0);
        _baseScale = _currentScale;
        _baseTranslation = _currentTranslation;
        
        // Apply any final constraints
        _applyImageConstraints();
        _updateTransformMatrix();
        
        // Save the final state
        _savedTransformMatrix = Matrix4.identity()
          ..translate(_currentTranslation.dx, _currentTranslation.dy)
          ..scale(_currentScale);
      });
    }
  }

  // For drawing mode toggle
  bool _isDrawingModeEnabled = true; // By default, drawing mode is enabled

  // Loading state
  bool _isLoading = true; // Flag to track loading state

  loadFunc() async {
    setState(() => _isLoading = true); // Ensure loading state is set

    try {
      await _requestPermissions();
      await _loadSettings();
      await _initializeProjectData();
    } catch (e) {
      // print('Error during initialization: $e');
    } finally {
      // Set loading to false whether successful or not
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    loadFunc();

    // dev.log("Bg Color ${widget.existingProject?.backgroundColor.runtimeType}");
  }

  // Check if a point is near a line segment within a certain distance
  bool isPointNearLine(
    Offset point,
    Offset lineStart,
    Offset lineEnd,
    double maxDistance,
  ) {
    // Vector from lineStart to lineEnd
    final lineVector = lineEnd - lineStart;
    final lineLength = lineVector.distance;

    // If the line is too short, just do a simple check
    if (lineLength < 1.0) {
      return (point - lineStart).distance <= maxDistance;
    }

    // Calculate the projection of the point onto the line
    final lineDir = lineVector / lineLength;
    final pointVector = point - lineStart;
    final projectionLength =
        pointVector.dx * lineDir.dx + pointVector.dy * lineDir.dy;

    // If the projection is outside the line segment, calculate distance to nearest endpoint
    if (projectionLength < 0) {
      return (point - lineStart).distance <= maxDistance;
    }
    if (projectionLength > lineLength) {
      return (point - lineEnd).distance <= maxDistance;
    }

    // Calculate the perpendicular distance from the point to the line
    final projectionPoint = lineStart + lineDir * projectionLength;
    final distance = (point - projectionPoint).distance;

    return distance <= maxDistance;
  }

  // Implementation of the request permissions method
  Future<void> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses =
          await [Permission.camera, Permission.storage].request();
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  // Build the zoom preview widget
  // Method to load a File as a ui.Image
  Future<void> _loadUIImage(File file) async {
    try {
      // First check if the file exists to avoid PathNotFoundException
      if (!await file.exists()) {
        print('Image file does not exist: ${file.path}');
        setState(() {
          _uiImage = null; // Clear the image reference
        });
        return;
      }

      // Use a try-catch block for reading the file
      Uint8List? bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        print('Error reading image file: $e');
        setState(() {
          _uiImage = null;
        });
        return;
      }

      if (bytes.isEmpty) {
        print('Image bytes are null or empty');
        setState(() {
          _uiImage = null;
        });
        return;
      }

      // Load the image with error handling
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        setState(() {
          _uiImage = frameInfo.image;
        });
        print('UI Image loaded successfully for zoom preview');
      } catch (e) {
        print('Error decoding image: $e');
        setState(() {
          _uiImage = null;
        });
      }
    } catch (e) {
      print('Unexpected error loading UI image: $e');
      setState(() {
        _uiImage = null;
      });
    }
  }

  // Update the image rectangle to track where the image is displayed on screen
  void _updateImageRect(BuildContext context, BoxConstraints constraints) {
    if (_imageFile == null || !mounted) return;

    try {
      // Get the RenderBox of the image container
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null) return;

      // Get the image dimensions
      final imageWidth = _uiImage?.width.toDouble() ?? 0;
      final imageHeight = _uiImage?.height.toDouble() ?? 0;
      if (imageWidth == 0 || imageHeight == 0) return;

      // Calculate the scaling to fit the container (BoxFit.contain logic)
      final double screenWidth = constraints.maxWidth;
      final double screenHeight = constraints.maxHeight;

      // Calculate the scaling factor to fit the image within the container
      final double widthRatio = screenWidth / imageWidth;
      final double heightRatio = screenHeight / imageHeight;
      final double scale = math.min(widthRatio, heightRatio);

      // Calculate the scaled dimensions
      final double scaledWidth = imageWidth * scale;
      final double scaledHeight = imageHeight * scale;

      // Calculate the position (centered in container)
      final double left = (screenWidth - scaledWidth) / 2;
      final double top = (screenHeight - scaledHeight) / 2;

      // Create the rectangle representing the image boundaries
      setState(() {
        _imageRect = Rect.fromLTWH(left, top, scaledWidth, scaledHeight);
        print('Image rect updated: $_imageRect');
      });
    } catch (e) {
      print('Error updating image rect: $e');
    }
  }

  // Check if a point is within the image boundaries
  bool _isPointInImageBounds(Offset point) {
    // If there's no image, allow drawing anywhere
    if (_imageFile == null || _imageRect == null) return true;

    // Check if the point is inside the image rectangle
    return _imageRect!.contains(point);
  }

  Widget _buildZoomPreview(Offset point) {
    return Container(
      width: 300,
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 2),
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
            size: const Size(300, 300),
            painter: ZoomPainter(
              arrows: arrows,
              selectedArrowIndex: selectedArrowIndex,
              currentArrow: currentArrow,
              backgroundColor: _backgroundColor,
              currentPoint: point,
              zoomFactor: zoomFactor,
              imageObject: _uiImage, // Pass the direct UI image
              imageRect: _imageRect, // Pass the actual image position and size on screen
            ),
          ),
          // Crosshair in the center
          Positioned(
            top: 0,
            bottom: 0,
            left: 150, // Half of width
            width: 1,
            child: Container(color: Colors.red),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 150, // Half of height
            height: 1,
            child: Container(color: Colors.red),
          ),
          // Position indicator at bottom
          Positioned(
            bottom: 5,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'X:${point.dx.toInt()} Y:${point.dy.toInt()}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to check if a point is near an endpoint within a certain radius
  bool isNearEndpoint(Offset point, Offset endpoint, double radius) {
    return (point - endpoint).distance <= radius;
  }

  // Load default settings for arrows
  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.getSettings();
      setState(() {
        _settings = settings;
        _isSettingsLoaded = true;

        log("Font Size: ${settings.defaultFontSize}");
        log("Arrow Width: ${settings.defaultArrowWidth}");
        log("Arrow Color: ${settings.defaultArrowColor}");
        log("Text Color: ${settings.defaultTextColor}");
        log("Background Color: ${settings.defaultBackgroundColor}");
        log("Dashed Line: ${settings.defaultDashedLine}");

        // Apply background color from settings if not overridden by parameters
        if (widget.backgroundColor == Colors.black) {
          _backgroundColor = settings.defaultBackgroundColor;
        } else {
          _backgroundColor = widget.backgroundColor;
        }
      });
    } catch (e) {
      // Use default settings if loading fails
      setState(() {
        _settings = const AppSettings();
        _isSettingsLoaded = true;
        _backgroundColor = widget.backgroundColor;
      });
    }
  }

  // Initialize project data if opening an existing project
  Future<void> _initializeProjectData() async {
    // dev.log("Bg Color in func ${widget.existingProject?.backgroundColor.runtimeType}");
    setState(() {
      _projectName = widget.projectName;
    });
    // Check if we're opening an existing project
    if (widget.existingProject != null) {
      final project = widget.existingProject!;

      // Load the image if it exists
      File? imageFile;
      if (project.imagePath != null && project.imagePath!.isNotEmpty) {
        final imageFilePath = File(project.imagePath!);
        if (imageFilePath.existsSync()) {
          imageFile = imageFilePath;
          print('Loaded image file: ${imageFilePath.path}');
        }
      }

      setState(() {
        _projectId = project.id;
        _projectName = project.name;
        arrows = project.arrows;
        _backgroundColor = project.backgroundColor;
        _imageFile = imageFile;
      });

      // Load the UI image if available
      if (imageFile != null) {
        _loadUIImage(imageFile);
      }
    }
  }

  // Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _imageFile = file;
        print('Selected image from gallery: ${pickedFile.path}');
      });
      // Load the image as ui.Image for the zoom preview
      _loadUIImage(file);
    }
  }

  // Pick image from camera
  Future<void> _pickImageFromCamera() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _imageFile = file;
        print('Captured image from camera: ${pickedFile.path}');
      });
      // Load the image as ui.Image for the zoom preview
      _loadUIImage(file);
    }
  }

  // Capture screenshot with high quality for saving, PDF export, and thumbnails
  Future<Uint8List?> _captureScreenshot({double quality = 2.0}) async {
    try {
      if (_screenshotKey.currentContext == null) {
        print('Error: Screenshot context is null');
        return null;
      }

      RenderRepaintBoundary boundary =
          _screenshotKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      // Use consistent high quality for all captures
      ui.Image image = await boundary.toImage(pixelRatio: quality);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        // Convert to image data
        Uint8List imageData = byteData.buffer.asUint8List();
        print('Image captured successfully at ${quality}x quality');
        return imageData;
      }
    } catch (e) {
      print('Error capturing screenshot: $e');
    }
    return null;
  }

  // Save the current project
  Future<void> _saveProject() async {
    setState(() => _isSaving = true);
    showLoading(context);
    try {
      // Capture high-quality screenshot for thumbnail - using the same image quality
      // as we do for saving and PDF export
      Uint8List? screenshotData = await _captureScreenshot(quality: 2.5);

      // Call the helper function to save the project
      final savedProject = await saveProject(
        context: context,
        projectName: _projectName,
        arrows: arrows,
        backgroundColor: _backgroundColor,
        imageFile: _imageFile,
        screenshotData: screenshotData,
        projectId: _projectId,
        siteId: widget.siteId, // Pass the site ID if available
      );

      // If this is a new project and we're coming from a site view, return the saved project
      if (savedProject != null &&
          widget.siteId != null &&
          Navigator.canPop(context)) {
        Navigator.pop(context, savedProject);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving project: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        hideLoading(context);
      }
    }
  }

  // Save the current image with arrows
  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    showLoading(context);

    try {
      // Get the downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // For Android, use the external storage downloads directory
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          // Fallback to the app's documents directory
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else {
        // For iOS and other platforms
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'image_meter_$timestamp.png';
      final filePath = '${downloadsDir.path}/$fileName';

      // Use the same high-quality image capture method for saving
      final imageBytes = await _captureScreenshot(quality: 3.0);

      if (imageBytes != null) {
        // Save the image
        final File imgFile = File(filePath);
        await imgFile.writeAsBytes(imageBytes);

        if (mounted) {
          hideLoading(context);
          // Show success message with view and share options
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image saved to Downloads: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'VIEW',
                textColor: Colors.white,
                onPressed: () {
                  OpenFile.open(filePath);
                },
              ),
            ),
          );

          // Show share dialog
          _showShareOptions(filePath, 'image');
        }
      } else {
        throw Exception('Failed to capture image');
      }
    } catch (e) {
      if (mounted) {
        hideLoading(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Export the current view as PDF
  Future<void> _exportAsPDF() async {
    setState(() => _isSaving = true);
    showLoading(context);

    try {
      // Get the downloads directory
      Directory downloadsDir;
      if (Platform.isAndroid) {
        // For Android, use the external storage downloads directory
        final externalDir = Directory('/storage/emulated/0/Download');
        if (await externalDir.exists()) {
          downloadsDir = externalDir;
        } else {
          // Fallback to the app's documents directory
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else {
        // For iOS and other platforms
        downloadsDir = await getApplicationDocumentsDirectory();
      }
      
      // Ensure the directory exists
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Create simple filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'image_meter_$timestamp.pdf';
      final filePath = '${downloadsDir.path}/$fileName';

      // Use the same high-quality capture for PDF as we do for saving images
      final imageBytes = await _captureScreenshot(quality: 3.0);

      if (imageBytes != null) {
        // Convert to PDF
        final pdf = pw.Document();
        final pngImage = pw.MemoryImage(imageBytes);

        // Simple PDF with just the image
        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(pngImage));
            },
          ),
        );

        // Save PDF
        final File pdfFile = File(filePath);
        await pdfFile.writeAsBytes(await pdf.save());

        if (mounted) {
          hideLoading(context);
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to Downloads: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'VIEW',
                textColor: Colors.white,
                onPressed: () {
                  OpenFile.open(filePath);
                },
              ),
            ),
          );

          // Show share options
          _showShareOptions(filePath, 'PDF');
        }
      } else {
        throw Exception('Failed to capture image for PDF');
      }
    } catch (e) {
      if (mounted) {
        hideLoading(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting as PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Helper method to show share options for a file
  void _showShareOptions(String filePath, String fileType) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share),
                title: Text('Share $fileType'),
                onTap: () {
                  Navigator.pop(context);
                  Share.shareFiles([
                    filePath,
                  ], text: 'Measurement exported as $fileType');
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text('Open $fileType'),
                onTap: () {
                  Navigator.pop(context);
                  OpenFile.open(filePath);
                },
              ),
            ],
          ),
    );
  }

  // Print the current document
  Future<void> _printDocument() async {
    setState(() => _isSaving = true);
    showLoading(context);

    try {
      // Capture the current view
      RenderRepaintBoundary boundary =
          _screenshotKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        // Convert to PDF
        final pdf = pw.Document();
        final pngImage = pw.MemoryImage(byteData.buffer.asUint8List());

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(pngImage));
            },
          ),
        );

        // Print the document
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: _projectName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error printing document: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        hideLoading(context);
      }
    }
  }

  void deleteArrow(int index) {
    // First close the dialog
    Navigator.of(context).pop();

    // Then update the state
    if (mounted) {
      setState(() {
        if (index >= 0 && index < arrows.length) {
          arrows.removeAt(index);
        }
        selectedArrowIndex = null;
        currentArrow = null;
        _isStartPointDrag = false;
        _isEndPointDrag = false;
        _isMiddlePointDrag = false;
        dragOffset = null;
      });
    }
  }

  // Open dialog to edit an arrow's properties
  void _openLabelEditor(int index) {
    if (index < 0 || index >= arrows.length) return;
    final arrow = arrows[index];
    // Persistent controllers for text fields
    final labelController = TextEditingController(text: arrow.label ?? '');
    final unitController = TextEditingController(text: arrow.unit);
    double fontSize = arrow.fontSize;
    Color labelColor = arrow.arrowColor;
    Color textColor = arrow.textColor;
    double width = arrow.arrowWidth;
    bool isDashed = arrow.isDashed;
    bool showArrowStyle = arrow.showArrowStyle;

    // Function to update arrow properties in real-time
    void updateArrowInRealTime() {
      setState(() {
        arrows[index] = arrow.copyWith(
          label: labelController.text,
          unit: unitController.text,
          arrowColor: labelColor,
          textColor: textColor,
          fontSize: fontSize,
          arrowWidth: width,
          isDashed: isDashed,
          showArrowStyle: showArrowStyle,
        );
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Arrow Properties'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Label',
                        border: OutlineInputBorder(),
                      ),
                      controller: labelController,
                      onChanged: (value) {
                        updateArrowInRealTime();
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unit',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value:
                                  unitController.text.isEmpty
                                      ? getDefaultUnit()
                                      : unitController.text,
                              items:
                                  getUnitSymbols().map((String unit) {
                                    // Find the full unit info to display name
                                    final unitInfo = measurementUnits
                                        .firstWhere(
                                          (u) => u.symbol == unit,
                                          orElse:
                                              () => const MeasurementUnit(
                                                name: '',
                                                symbol: '',
                                              ),
                                        );

                                    return DropdownMenuItem<String>(
                                      value: unit,
                                      child: Row(
                                        children: [
                                          Text(
                                            unit,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (unitInfo.name.isNotEmpty)
                                            Expanded(
                                              child: Text(
                                                '(${unitInfo.name})',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    unitController.text = newValue;
                                    updateArrowInRealTime();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Line Color:'),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: () async {
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Pick a color'),
                              content: SingleChildScrollView(
                                child: ColorPicker(
                                  pickerColor: labelColor,
                                  onColorChanged: (color) {
                                    setState(() {
                                      labelColor = color;
                                      updateArrowInRealTime();
                                    });
                                  },
                                  pickerAreaHeightPercent: 0.8,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          color: labelColor,
                          border: Border.all(color: Colors.black),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Text Color:'),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Pick a text color'),
                              content: SingleChildScrollView(
                                child: ColorPicker(
                                  pickerColor: textColor,
                                  onColorChanged: (color) {
                                    setState(() {
                                      textColor = color;
                                      updateArrowInRealTime();
                                    });
                                  },
                                  pickerAreaHeightPercent: 0.8,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: primaryColor,
                                  ),
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          color: textColor,
                          border: Border.all(color: Colors.black),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Font Size: '),
                        Expanded(
                          child: Slider(
                            value: fontSize,
                            min: 5,
                            max: 50,
                            divisions: 45,
                            label: fontSize.round().toString(),
                            activeColor: primaryColor,
                            thumbColor: primaryColor,
                            onChanged: (value) {
                              setState(() {
                                fontSize = value;
                                updateArrowInRealTime();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Width: '),
                        Expanded(
                          child: Slider(
                            value: width,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: width.round().toString(),
                            activeColor: primaryColor,
                            thumbColor: primaryColor,
                            onChanged: (value) {
                              setState(() {
                                width = value;
                                updateArrowInRealTime();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Dashed Line: '),
                        Switch(
                          value: isDashed,
                          activeColor: primaryColor,
                          onChanged: (value) {
                            setState(() {
                              isDashed = value;
                              updateArrowInRealTime();
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Show Arrow Head: '),
                        Switch(
                          value: showArrowStyle,
                          activeColor: primaryColor,
                          onChanged: (value) {
                            setState(() {
                              showArrowStyle = value;
                              updateArrowInRealTime();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => deleteArrow(index),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('DELETE'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
                    handleDialogResult({
                      'index': index,
                      'label': labelController.text,
                      'unit': unitController.text,
                      'color': labelColor,
                      'textColor': textColor,
                      'fontSize': fontSize,
                      'width': width,
                      'isDashed': isDashed,
                      'showArrowStyle': showArrowStyle,
                    });
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Handle the result from the arrow properties dialog
  void handleDialogResult(Map<String, dynamic>? result) {
    if (result != null) {
      final index = result['index'] as int;
      if (index >= 0 && index < arrows.length) {
        setState(() {
          final arrow = arrows[index];
          arrows[index] = arrow.copyWith(
            label: result['label'],
            unit: result['unit'],
            arrowColor: result['color'],
            textColor: result['textColor'],
            fontSize: result['fontSize'],
            arrowWidth: result['width'],
            isDashed: result['isDashed'],
            showArrowStyle: result['showArrowStyle'],
          );
        });
      }
    }
  }

  // Calculate optimal position for zoom container to avoid drawing area
  void _updateZoomContainerPosition(Offset currentDrawingPoint) {
    final screenSize = MediaQuery.of(context).size;

    // Define the four possible positions: top-left, top-right, bottom-left, bottom-right
    final positions = [
      const Offset(20, 80), // top-left
      Offset(screenSize.width - zoomContainerSize.width - 20, 80), // top-right
      Offset(
        20,
        screenSize.height - zoomContainerSize.height - 80,
      ), // bottom-left
      Offset(
        screenSize.width - zoomContainerSize.width - 20,
        screenSize.height - zoomContainerSize.height - 80,
      ), // bottom-right
    ];

    // Calculate the distance from the current drawing point to the center of the zoom container at each position
    final distances =
        positions.map((position) {
          final containerCenter = Offset(
            position.dx + zoomContainerSize.width / 2,
            position.dy + zoomContainerSize.height / 2,
          );
          return (containerCenter - currentDrawingPoint).distance;
        }).toList();

    // Find the position with the maximum distance from the drawing point
    int maxDistanceIndex = 0;
    double maxDistance = distances[0];
    for (int i = 1; i < distances.length; i++) {
      if (distances[i] > maxDistance) {
        maxDistance = distances[i];
        maxDistanceIndex = i;
      }
    }

    // Update the zoom container position
    setState(() {
      zoomContainerPosition = positions[maxDistanceIndex];
    });
  }
  
  // Show the options bottom sheet with all functionality buttons
  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
              margin: const EdgeInsets.only(bottom: 20),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 24,
              children: [
                // Drawing mode toggle
                _buildOptionItem(
                  Icons.edit,
                  _isDrawingModeEnabled ? 'Drawing Mode (On)' : 'Drawing Mode (Off)',
                  _isDrawingModeEnabled ? primaryColor : Colors.grey.shade600,
                  () {
                    setState(() {
                      _isDrawingModeEnabled = !_isDrawingModeEnabled;
                    });
                    Navigator.pop(context);
                  },
                ),
                
                // Zoom mode toggle
                _buildOptionItem(
                  Icons.handshake,
                  !_isDrawingModeEnabled ? 'Zoom Mode (On)' : 'Zoom Mode (Off)',
                  !_isDrawingModeEnabled ? primaryColor : Colors.grey.shade600,
                  () {
                    setState(() {
                      _isDrawingModeEnabled = !_isDrawingModeEnabled;
                    });
                    Navigator.pop(context);
                  },
                ),
                
                // Export as PDF
                // _buildOptionItem(
                //   Icons.picture_as_pdf,
                //   'Export as PDF',
                //   primaryColor,
                //   () {
                //     Navigator.pop(context);
                //    _exportAsPDF();
                //   },
                // ),
                
                // Save as Image
                _buildOptionItem(
                  Icons.image,
                  'Save as Image',
                  primaryColor,
                  () {
                    Navigator.pop(context);
                    _saveImage();
                  },
                ),
                
                // Save Project
                _buildOptionItem(
                  Icons.save,
                  'Save Project',
                  primaryColor,
                  () {
                    Navigator.pop(context);
                    _saveProject();
                  },
                ),
                
                // Print Document
                _buildOptionItem(
                  Icons.print,
                  'Print',
                  primaryColor,
                  () {
                    Navigator.pop(context);
                    _printDocument();
                  },
                ),
                
                // Help
                _buildOptionItem(
                  Icons.help_outline,
                  'Help',
                  primaryColor,
                  () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Tips'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('• Tap and drag to create arrows.', style: TextStyle(fontSize: 16)),
                              SizedBox(height: 8),
                              Text('• Tap on an arrow to edit its properties.', style: TextStyle(fontSize: 16)),
                              SizedBox(height: 8),
                              Text('• Drag the endpoints to resize or rotate an arrow.', style: TextStyle(fontSize: 16)),
                              SizedBox(height: 8),
                              Text('• Save your project to edit it later.', style: TextStyle(fontSize: 16)),
                              SizedBox(height: 8),
                              Text('• Export as PDF or image to share your measurements.', style: TextStyle(fontSize: 16)),
                              SizedBox(height: 8),
                              Text('• Toggle drawing mode to enable zooming.', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('GOT IT'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                // Delete All Arrows - only show if there are arrows
                if (arrows.isNotEmpty)
                  _buildOptionItem(
                    Icons.delete_sweep,
                    'Delete All Lines',
                    Colors.red,
                    () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete All Lines?'),
                          content: const Text('Are you sure you want to delete all measurement lines? This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  arrows = [];
                                  selectedArrowIndex = null;
                                });
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('DELETE ALL'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build option items in the bottom sheet
  Widget _buildOptionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while resources are being loaded
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_projectName),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    
    // Main UI when loading is complete
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(_projectName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [

         
           IconButton(
            icon: _isDrawingModeEnabled ? Icon(Icons.edit) :Icon( Icons.zoom_in),
            tooltip: 'Mode',
            onPressed: _toggleDrawingMode,
          ),
           IconButton(
            icon: _isDrawingModeEnabled ? Icon(Icons.save) :Icon( Icons.zoom_in),
            tooltip: 'Save',
            onPressed: _saveProject,
          ),
          // _buildOptionItem(
          //         Icons.edit,
          //         _isDrawingModeEnabled ? 'Drawing Mode (On)' : 'Drawing Mode (Off)',
          //         _isDrawingModeEnabled ? primaryColor : Colors.grey.shade600,
          //         () {
          //           setState(() {
          //             _isDrawingModeEnabled = !_isDrawingModeEnabled;
          //           });
          //           Navigator.pop(context);
          //         },
          //       ),
                
          // Menu button to show all options
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menu',
            onPressed: () => _showOptionsBottomSheet(context),
          ),
        ],
      ),
      body: RepaintBoundary(
        key: _screenshotKey,
        child: Stack(
          children: [

        // Display image if available with gesture zooming support
        if (_imageFile != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onScaleEnd: _handleScaleEnd,
                  child: Transform(
                    transform: _transformMatrix,
                    alignment: Alignment.center,
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Handle image loading errors gracefully
                        print('Error loading image: $error');
                        // Return a placeholder widget when image fails to load
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Image could not be loaded',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                      frameBuilder: (
                        context,
                        child,
                        frame,
                        wasSynchronouslyLoaded,
                      ) {
                        // Capture image size and position once the image is loaded
                        if (frame != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _updateImageRect(context, constraints);
                          });
                        }
                        return child;
                      },
                    ),
                  ),
                );
              },
            ),
          ),
            // Background - always include the background color
            Positioned.fill(
              child: Container(
                color: _backgroundColor, // Always include the background color
              ),
            ),

            // Display image if available with gesture zooming support
            if (_imageFile != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      // Handle zooming gestures
                      onScaleStart: (details) {
                        if (!_isDrawingModeEnabled) {
                          setState(() {
                            _lastFocalPoint = details.focalPoint;
                            _baseScale = _currentScale;
                            _baseTranslation = _currentTranslation;
                            _isZooming = false;
                            
                            // Calculate the focal point relative to the image
                            final focalPointRelativeToImage = details.focalPoint - _currentTranslation;
                            _normalizedFocalPoint = Offset(
                              focalPointRelativeToImage.dx / _currentScale,
                              focalPointRelativeToImage.dy / _currentScale,
                            );
                          });
                        }
                      },
                      onScaleUpdate: (details) {
                        if (!_isDrawingModeEnabled) {
                          setState(() {
                            // Handle zooming and panning together
                            if (details.scale != 1.0) {
                              _isZooming = true;
                              // Zoom with focal point
                              _currentScale = (_baseScale * details.scale).clamp(0.5, 5.0);
                              
                              // Calculate the focal point in the image's coordinate space
                              final focalPointInImageSpace = Offset(
                                _normalizedFocalPoint.dx * _currentScale,
                                _normalizedFocalPoint.dy * _currentScale,
                              );
                              
                              // Adjust the translation to keep the focal point under the finger
                              _currentTranslation = details.focalPoint - focalPointInImageSpace;
                            } else {
                              // Handle pure panning
                              final delta = details.focalPoint - _lastFocalPoint;
                              _currentTranslation = _baseTranslation + delta;
                            }
                            
                            // Update the last focal point for the next update
                            _lastFocalPoint = details.focalPoint;
                            
                            // Apply constraints to keep the image within bounds
                            _applyImageConstraints();
                            
                            // Update the transform matrix
                            _updateTransformMatrix();
                            
                            // Hide zoom preview when using gesture zoom
                            _showZoomPreview = false;
                          });
                        }
                      },
                      onScaleEnd: (details) {
                        if (!_isDrawingModeEnabled) {
                          setState(() {
                            _isZooming = false;
                            // Save the current state for the next gesture
                            _baseScale = _currentScale;
                            _baseTranslation = _currentTranslation;
                            
                            // Save the final state
                            _savedTransformMatrix = Matrix4.identity()
                              ..translate(_currentTranslation.dx, _currentTranslation.dy)
                              ..scale(_currentScale);
                          });
                        }
                      },
                      child: Transform(
                        transform: _transformMatrix,
                        alignment: Alignment.center,
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Handle image loading errors gracefully
                            print('Error loading image: $error');
                            // Return a placeholder widget when image fails to load
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Image could not be loaded',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          },
                          frameBuilder: (
                            context,
                            child,
                            frame,
                            wasSynchronouslyLoaded,
                          ) {
                            // Capture image size and position once the image is loaded
                            if (frame != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _updateImageRect(context, constraints);
                              });
                            }
                            return child;
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Zoom preview container - shows when drawing
            if (_showZoomPreview &&
                _isDrawingModeEnabled &&
                (currentArrow != null || _isStartPointDrag || _isEndPointDrag))
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                top: _isZoomContainerAtTop ? zoomContainerTopMargin : null,
                bottom:
                    !_isZoomContainerAtTop ? zoomContainerBottomMargin : null,
                left: 0,
                right: 0,
                height: zoomContainerHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildZoomPreview(
                      currentArrow?.end ??
                          (selectedArrowIndex != null
                              ? (_isStartPointDrag
                                  ? arrows[selectedArrowIndex!].start
                                  : _isEndPointDrag
                                  ? arrows[selectedArrowIndex!].end
                                  : Offset(
                                    (arrows[selectedArrowIndex!].start.dx +
                                            arrows[selectedArrowIndex!]
                                                .end
                                                .dx) /
                                        2,
                                    (arrows[selectedArrowIndex!].start.dy +
                                            arrows[selectedArrowIndex!]
                                                .end
                                                .dy) /
                                        2,
                                  ))
                              : Offset.zero),
                    ),
                  ],
                ),
              ),

            // Arrow drawing canvas - make sure to apply same transform as the image
            Positioned.fill(
              child: Transform(
                transform: _transformMatrix,
                alignment: Alignment.center,
                child: IgnorePointer(
                  // Ignore pointer events when drawing mode is disabled
                  ignoring: !_isDrawingModeEnabled,
                  child: GestureDetector(
                    onTap: () {
                    setState(() {
                      selectedArrowIndex = null;
                      _isStartPointDrag = false;
                      _isMiddlePointDrag = false;
                      _isEndPointDrag = false;
                    });
                  },
                  onPanStart: (details) {
                    // Only handle if drawing mode is enabled
                    if (!_isDrawingModeEnabled) return;

                    // Check if we're grabbing an endpoint of an existing arrow
                    final position = details.localPosition;

                    // Enable zoom preview
                    setState(() {
                      _showZoomPreview = true;

                      // Determine if zoom container should be at top or bottom
                      if (position.dy < pointerPositionThreshold) {
                        _isZoomContainerAtTop =
                            false; // Move to bottom if touching near top
                      } else if (position.dy >
                          MediaQuery.of(context).size.height -
                              pointerPositionThreshold) {
                        _isZoomContainerAtTop =
                            true; // Move to top if touching near bottom
                      } else {
                        _isZoomContainerAtTop = true; // Default position at top
                      }
                    });

                    // Check if we're trying to manipulate an existing arrow's endpoint
                    for (int i = 0; i < arrows.length; i++) {
                      final arrow = arrows[i];

                      // Check if we're close to the start point
                      if (isNearEndpoint(
                        position,
                        arrow.start,
                        _endpointTouchRadius,
                      )) {
                        setState(() {
                          selectedArrowIndex = i;
                          _isStartPointDrag = true;
                          _isEndPointDrag = false;
                          _isMiddlePointDrag = false;
                          dragOffset = null;
                        });
                        return;
                      }

                      // Check if we're close to the end point
                      if (isNearEndpoint(
                        position,
                        arrow.end,
                        _endpointTouchRadius,
                      )) {
                        setState(() {
                          selectedArrowIndex = i;
                          _isEndPointDrag = true;
                          _isStartPointDrag = false;
                          _isMiddlePointDrag = false;
                          dragOffset = null;
                        });
                        return;
                      }

                      // Check if we're on the middle of the line
                      if (isPointNearLine(
                        position,
                        arrow.start,
                        arrow.end,
                        _middlePointTouchRadius,
                      )) {
                        // Calculate offset from the middle point for smooth dragging
                        final middle = Offset(
                          (arrow.start.dx + arrow.end.dx) / 2,
                          (arrow.start.dy + arrow.end.dy) / 2,
                        );
                        setState(() {
                          selectedArrowIndex = i;
                          _isMiddlePointDrag = true;
                          _isStartPointDrag = false;
                          _isEndPointDrag = false;
                          dragOffset = position - middle;
                        });
                        return;
                      }
                    }

                    // Check if the tap is within the image boundaries
                    if (_imageFile != null &&
                        !_isPointInImageBounds(details.localPosition)) {
                      // If outside image boundaries and we have an image, don't allow drawing
                      return;
                    }

                    // If we're not manipulating an existing arrow, create a new one
                    setState(() {
                      // load default values
                      // Create a new arrow
                      currentArrow = ArrowModel(
                        isDashed: _settings.defaultDashedLine,
                        showArrowStyle: _settings.defaultShowArrowStyle,
                        start: details.localPosition,
                        end: details.localPosition,
                        arrowColor: _settings.defaultArrowColor,
                        textColor: _settings.defaultTextColor,
                        fontSize: _settings.defaultFontSize,
                        arrowWidth: _settings.defaultArrowWidth,
                        unit: _settings.defaultUnit,
                      );
                      selectedArrowIndex = null;
                    });
                  },
                  onPanUpdate: (details) {
                    // Only handle if drawing mode is enabled
                    if (!_isDrawingModeEnabled) return;

                    // Update current focal point for zoom preview
                    _focalPoint = details.localPosition;

                    // Update zoom container position if needed
                    setState(() {
                      if (_isZoomContainerAtTop &&
                          details.localPosition.dy < pointerPositionThreshold) {
                        _isZoomContainerAtTop =
                            false; // Move to bottom if touching near top
                      } else if (!_isZoomContainerAtTop &&
                          details.localPosition.dy >
                              MediaQuery.of(context).size.height -
                                  pointerPositionThreshold) {
                        _isZoomContainerAtTop =
                            true; // Move to top if touching near bottom
                      }

                      // Show zoom preview while drawing
                      _showZoomPreview = true;
                      _isZooming = true;
                    });

                    // Using immediate state update to improve responsiveness
                    if (_isStartPointDrag && selectedArrowIndex != null) {
                      // Restrict to image boundaries if an image is present
                      Offset newStartPoint = details.localPosition;
                      if (_imageFile != null &&
                          _imageRect != null &&
                          !_isPointInImageBounds(newStartPoint)) {
                        // Clamp the start point to stay within the image boundaries
                        newStartPoint = Offset(
                          math.max(
                            _imageRect!.left,
                            math.min(newStartPoint.dx, _imageRect!.right),
                          ),
                          math.max(
                            _imageRect!.top,
                            math.min(newStartPoint.dy, _imageRect!.bottom),
                          ),
                        );
                      }

                      setState(() {
                        // Update the arrow's start point
                        final arrow = arrows[selectedArrowIndex!];
                        arrows[selectedArrowIndex!] = arrow.copyWith(
                          start: newStartPoint,
                        );
                      });
                    } else if (_isEndPointDrag && selectedArrowIndex != null) {
                      // Restrict to image boundaries if an image is present
                      Offset newEndPoint = details.localPosition;
                      if (_imageFile != null &&
                          _imageRect != null &&
                          !_isPointInImageBounds(newEndPoint)) {
                        // Clamp the end point to stay within the image boundaries
                        newEndPoint = Offset(
                          math.max(
                            _imageRect!.left,
                            math.min(newEndPoint.dx, _imageRect!.right),
                          ),
                          math.max(
                            _imageRect!.top,
                            math.min(newEndPoint.dy, _imageRect!.bottom),
                          ),
                        );
                      }

                      setState(() {
                        // Update the arrow's end point
                        final arrow = arrows[selectedArrowIndex!];
                        arrows[selectedArrowIndex!] = arrow.copyWith(
                          end: newEndPoint,
                        );
                      });
                    } else if (_isMiddlePointDrag &&
                        selectedArrowIndex != null) {
                      // Handle middle point (entire arrow) drag
                      final dragPosition = details.localPosition;
                      final middlePoint = dragPosition - dragOffset!;

                      final arrow = arrows[selectedArrowIndex!];
                      final currentMiddle = Offset(
                        (arrow.start.dx + arrow.end.dx) / 2,
                        (arrow.start.dy + arrow.end.dy) / 2,
                      );

                      // Calculate the offset to move the whole arrow
                      final deltaX = middlePoint.dx - currentMiddle.dx;
                      final deltaY = middlePoint.dy - currentMiddle.dy;

                      // Proposed new positions for both endpoints
                      final newStart = Offset(
                        arrow.start.dx + deltaX,
                        arrow.start.dy + deltaY,
                      );
                      final newEnd = Offset(
                        arrow.end.dx + deltaX,
                        arrow.end.dy + deltaY,
                      );

                      // If an image is present, check if the new positions would be inside the image
                      if (_imageFile != null && _imageRect != null) {
                        // If either endpoint would be outside the image area, adjust the movement
                        if (!_isPointInImageBounds(newStart) ||
                            !_isPointInImageBounds(newEnd)) {
                          // Calculate clamped positions - get as close to the desired position as possible
                          // while staying within image bounds
                          final Offset clampedStart = Offset(
                            math.max(
                              _imageRect!.left,
                              math.min(newStart.dx, _imageRect!.right),
                            ),
                            math.max(
                              _imageRect!.top,
                              math.min(newStart.dy, _imageRect!.bottom),
                            ),
                          );

                          final Offset clampedEnd = Offset(
                            math.max(
                              _imageRect!.left,
                              math.min(newEnd.dx, _imageRect!.right),
                            ),
                            math.max(
                              _imageRect!.top,
                              math.min(newEnd.dy, _imageRect!.bottom),
                            ),
                          );

                          // Calculate the maximum we can move in each direction without going outside
                          final startDeltaX = clampedStart.dx - arrow.start.dx;
                          final startDeltaY = clampedStart.dy - arrow.start.dy;
                          final endDeltaX = clampedEnd.dx - arrow.end.dx;
                          final endDeltaY = clampedEnd.dy - arrow.end.dy;

                          // Take the smaller movement to ensure both points stay inside
                          final effectiveDeltaX =
                              (deltaX >= 0)
                                  ? math.min(startDeltaX, endDeltaX)
                                  : math.max(startDeltaX, endDeltaX);

                          final effectiveDeltaY =
                              (deltaY >= 0)
                                  ? math.min(startDeltaY, endDeltaY)
                                  : math.max(startDeltaY, endDeltaY);

                          // Apply the constrained movement
                          setState(() {
                            arrows[selectedArrowIndex!] = arrow.copyWith(
                              start: Offset(
                                arrow.start.dx + effectiveDeltaX,
                                arrow.start.dy + effectiveDeltaY,
                              ),
                              end: Offset(
                                arrow.end.dx + effectiveDeltaX,
                                arrow.end.dy + effectiveDeltaY,
                              ),
                            );
                          });
                          return;
                        }
                      }

                      // If we reach here, either there's no image or both points stay inside the image
                      setState(() {
                        // Update both start and end points to move the entire arrow
                        arrows[selectedArrowIndex!] = arrow.copyWith(
                          start: newStart,
                          end: newEnd,
                        );
                      });
                    } else if (currentArrow != null) {
                      // For drawing new arrows, restrict to image boundaries if an image is present
                      // If the point is outside the image boundaries and we have an image, clamp it to the image
                      Offset newEndpoint = details.localPosition;
                      if (_imageFile != null &&
                          _imageRect != null &&
                          !_isPointInImageBounds(newEndpoint)) {
                        // Clamp the endpoint to stay within the image boundaries
                        newEndpoint = Offset(
                          math.max(
                            _imageRect!.left,
                            math.min(newEndpoint.dx, _imageRect!.right),
                          ),
                          math.max(
                            _imageRect!.top,
                            math.min(newEndpoint.dy, _imageRect!.bottom),
                          ),
                        );
                      }

                      // Update the end point of the new arrow being drawn
                      setState(() {
                        currentArrow = currentArrow!.copyWith(end: newEndpoint);
                      });
                    }
                  },
                  onPanEnd: (details) {
                    if (currentArrow != null) {
                      // We were drawing a new arrow
                      // Only add it if it's long enough to be visible
                      if ((currentArrow!.end - currentArrow!.start).distance >
                          10) {
                        setState(() {
                          arrows.add(currentArrow!);
                          currentArrow = null;
                        });
                      } else {
                        setState(() {
                          currentArrow = null;
                        });
                      }
                    }

                    // Reset the manipulation flags and hide zoom preview
                    setState(() {
                      _isStartPointDrag = false;
                      _isEndPointDrag = false;
                      _isMiddlePointDrag = false;
                      dragOffset = null;
                      _showZoomPreview = false; // Hide zoom preview when done
                      _isZoomContainerAtTop = true; // Reset position
                      _isEndPointDrag = false;
                      _isStartPointDrag = false;
                      _isMiddlePointDrag = false;
                    });
                  },
                  onTapUp: (details) {
                    final index = getArrowAtPosition(
                      details.localPosition,
                      arrows,
                    );
                    if (index != null) {
                      _openLabelEditor(index);
                    }
                  },
                  child: CustomPaint(
                    painter: MultiArrowPainter(
                      arrows: arrows,
                      currentArrow: currentArrow,
                      selectedArrowIndex: selectedArrowIndex,
                    ),
                    child: Container(),
                  ),
                ),
              ),
            ),
        )],
        ),
      ),
      // Bottom navigation bar removed - all buttons moved to app bar
      floatingActionButton:
          _imageFile == null
              ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Camera Button
                  FloatingActionButton(
                    onPressed: _pickImageFromCamera,
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    heroTag: "btn1",
                    child: const Icon(Icons.camera_alt),
                  ),
                  const SizedBox(height: 16),

                  // Gallery Button
                  FloatingActionButton(
                    onPressed: _pickImageFromGallery,
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    heroTag: "btn2",
                    child: const Icon(Icons.photo_library),
                  ),
                ],
              )
              : SizedBox(),
    );
  }
}
