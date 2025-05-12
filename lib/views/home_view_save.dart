import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_meter/models/arrow_model.dart';
import 'package:image_meter/models/project_model.dart';
import 'package:image_meter/services/project_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

// Helper function to save projects that can be included in home_view.dart
Future<void> saveProject({
  required BuildContext context,
  required String projectName,
  required List<ArrowModel> arrows,
  required Color backgroundColor,
  required File? imageFile,
  required Uint8List? screenshotData,
  String? projectId,
}) async {
  final projectService = ProjectService();
  bool isLoading = true;
  
  try {
    String? thumbnailPath;
    String? imagePath;
    
    // Save screenshot if captured successfully
    if (screenshotData != null) {
      // Get application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory('${directory.path}/thumbnails');
      
      // Create directory if it doesn't exist
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }
      
      // Save thumbnail
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      thumbnailPath = '${thumbnailsDir.path}/thumbnail_$timestamp.png';
      await File(thumbnailPath).writeAsBytes(screenshotData);
      
      // Save current image if available
      if (imageFile != null) {
        try {
          final imagesDir = Directory('${directory.path}/images');
          
          // Create directory if it doesn't exist
          if (!await imagesDir.exists()) {
            await imagesDir.create(recursive: true);
          }
          
          // Copy image to app documents directory
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          imagePath = '${imagesDir.path}/image_$timestamp.png';
          
          // Check if source image exists and is readable
          if (!await imageFile.exists()) {
            print('Image file does not exist: ${imageFile.path}');
            throw Exception('Image file does not exist');
          }
          
          // Read image bytes and write to new location instead of using copy
          // This is more reliable across different platforms
          final bytes = await imageFile.readAsBytes();
          await File(imagePath).writeAsBytes(bytes);
          
          print('Image saved successfully to: $imagePath');
        } catch (e) {
          print('Error saving image: $e');
          // Continue without image if there was an error
          imagePath = null;
        }
      }
    }
    
    // Show dialog to get project name
    final TextEditingController nameController = TextEditingController(text: projectName);
    bool shouldSave = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Project Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: Text('Save'),
          ),
        ],
      ),
    ) ?? false;
    
    if (shouldSave) {
      // Save project to Hive with the high-quality screenshot data for thumbnail
      await projectService.saveProject(
        name: nameController.text,
        imagePath: imagePath,
        arrows: arrows,
        backgroundColor: backgroundColor,
        screenshotData: screenshotData, // Pass the screenshot data for thumbnail creation
        existingId: projectId,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project saved successfully')),
      );
      
      return;
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving project: $e')),
    );
  } finally {
    isLoading = false;
  }
}
