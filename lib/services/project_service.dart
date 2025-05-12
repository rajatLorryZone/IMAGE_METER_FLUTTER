import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/project_model.dart';
import '../models/arrow_model.dart';

class ProjectService {
  static const String _projectsBoxName = 'projects';
  static const String _recentProjectsKey = 'recent_projects';
  
  // Get all projects
  Future<List<Project>> getAllProjects() async {
    final box = await Hive.openBox<Project>(_projectsBoxName);
    return box.values.toList();
  }
  
  // Get recent projects (limited to the most recent ones)
  Future<List<Project>> getRecentProjects({int limit = 10}) async {
    final projects = await getAllProjects();
    
    // Sort by last modified date, most recent first
    projects.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    
    // Return limited number of projects
    return projects.take(limit).toList();
  }
  
  // Save a project with the screenshot data for the thumbnail
  Future<Project> saveProject({
    required String name, 
    required String? imagePath, 
    required List<ArrowModel> arrows,
    required Color backgroundColor,
    required Uint8List? screenshotData, // Add screenshot data parameter
    String? existingId,
  }) async {
    final box = await Hive.openBox<Project>(_projectsBoxName);
    
    // Generate a unique ID if not updating an existing project
    final id = existingId ?? const Uuid().v4();
    final now = DateTime.now();
    
    // Save thumbnail from screenshot data
    String thumbnailPath = '';
    if (screenshotData != null) {
      thumbnailPath = await _saveThumbnailFromScreenshot(screenshotData);
    }
    
    // Create or update the project
    final project = Project(
      id: id,
      name: name,
      createdAt: existingId != null ? box.get(existingId)!.createdAt : now,
      lastModified: now,
      imagePath: imagePath,
      arrows: arrows,
      backgroundColor: backgroundColor,
      thumbnailPath: thumbnailPath,
    );
    
    // Save to Hive
    await box.put(id, project);
    
    return project;
  }
  
  // Delete a project
  Future<void> deleteProject(String id) async {
    final box = await Hive.openBox<Project>(_projectsBoxName);
    
    // Delete the project
    await box.delete(id);
  }
  
  // Get a project by ID
  Future<Project?> getProject(String id) async {
    final box = await Hive.openBox<Project>(_projectsBoxName);
    return box.get(id);
  }
  
  // Save a screenshot as a thumbnail image
  Future<String> _saveThumbnailFromScreenshot(Uint8List screenshotData) async {
    try {
      // Create thumbnails directory in app documents
      final directory = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory('${directory.path}/thumbnails');
      
      // Ensure thumbnails directory exists
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }
      
      // Generate a unique filename for the thumbnail with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final thumbnailPath = '${thumbnailsDir.path}/thumbnail_$timestamp.png';
      
      // Write the screenshot data directly to the thumbnail file
      final File thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(screenshotData);
      
      print('Thumbnail saved successfully at: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      print('Error saving thumbnail: $e');
      return ''; // Return empty string if thumbnail creation fails
    }
  }
}
