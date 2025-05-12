import 'dart:io';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/site_model.dart';
import '../models/project_model.dart';
import 'project_service.dart';

class SiteService {
  static const String _sitesBoxName = 'sites';
  final ProjectService _projectService = ProjectService();
  
  // Get all sites
  Future<List<Site>> getAllSites() async {
    final box = await Hive.openBox<Site>(_sitesBoxName);
    return box.values.toList();
  }
  
  // Get recent sites (limited to the most recent ones)
  Future<List<Site>> getRecentSites({int limit = 10}) async {
    final sites = await getAllSites();
    
    // Sort by last modified date, most recent first
    sites.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    
    // Return limited number of sites
    return sites.take(limit).toList();
  }
  
  // Save a site with the screenshot data for the thumbnail
  Future<Site> saveSite({
    required String name,
    required List<String> projectIds,
    required Uint8List? screenshotData,
    String? existingId,
  }) async {
    final box = await Hive.openBox<Site>(_sitesBoxName);
    
    // Generate a unique ID if not updating an existing site
    final id = existingId ?? const Uuid().v4();
    final now = DateTime.now();
    
    // Save thumbnail from screenshot data
    String thumbnailPath = '';
    if (screenshotData != null) {
      thumbnailPath = await _saveThumbnailFromScreenshot(screenshotData);
    }
    
    // Create or update the site
    final site = Site(
      id: id,
      name: name,
      createdAt: existingId != null ? box.get(existingId)!.createdAt : now,
      lastModified: now,
      projectIds: projectIds,
      thumbnailPath: thumbnailPath,
    );
    
    // Save to Hive
    await box.put(id, site);
    
    return site;
  }
  
  // Delete a site
  Future<void> deleteSite(String id, bool deleteProjects) async {
    final box = await Hive.openBox<Site>(_sitesBoxName);
    final site = box.get(id);
    
    if (site != null && deleteProjects) {
      // Delete all projects associated with this site
      for (final projectId in site.projectIds) {
        await _projectService.deleteProject(projectId);
      }
    }
    
    // Delete the site
    await box.delete(id);
  }
  
  // Get a site by ID
  Future<Site?> getSite(String id) async {
    final box = await Hive.openBox<Site>(_sitesBoxName);
    return box.get(id);
  }
  
  // Add a project to a site
  Future<Site> addProjectToSite(String siteId, String projectId) async {
    final site = await getSite(siteId);
    if (site == null) {
      throw Exception("Site not found");
    }
    
    final updatedProjectIds = List<String>.from(site.projectIds);
    if (!updatedProjectIds.contains(projectId)) {
      updatedProjectIds.add(projectId);
    }
    
    return await saveSite(
      name: site.name,
      projectIds: updatedProjectIds,
      screenshotData: null,
      existingId: siteId,
    );
  }
  
  // Remove a project from a site
  Future<Site> removeProjectFromSite(String siteId, String projectId, bool deleteProject) async {
    final site = await getSite(siteId);
    if (site == null) {
      throw Exception("Site not found");
    }
    
    final updatedProjectIds = List<String>.from(site.projectIds)
      ..removeWhere((id) => id == projectId);
    
    if (deleteProject) {
      await _projectService.deleteProject(projectId);
    }
    
    return await saveSite(
      name: site.name,
      projectIds: updatedProjectIds,
      screenshotData: null,
      existingId: siteId,
    );
  }
  
  // Get all projects for a site
  Future<List<Project>> getProjectsForSite(String siteId) async {
    final site = await getSite(siteId);
    if (site == null) {
      return [];
    }
    
    final List<Project> projects = [];
    for (final projectId in site.projectIds) {
      final project = await _projectService.getProject(projectId);
      if (project != null) {
        projects.add(project);
      }
    }
    
    return projects;
  }
  
  // Save a screenshot as a thumbnail image
  Future<String> _saveThumbnailFromScreenshot(Uint8List screenshotData) async {
    try {
      // Create thumbnails directory in app documents
      final directory = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory('${directory.path}/thumbnails/sites');
      
      // Ensure thumbnails directory exists
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }
      
      // Generate a unique filename for the thumbnail with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final thumbnailPath = '${thumbnailsDir.path}/site_thumbnail_$timestamp.png';
      
      // Write the screenshot data directly to the thumbnail file
      final File thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(screenshotData);
      
      print('Site thumbnail saved successfully at: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      print('Error saving site thumbnail: $e');
      return ''; // Return empty string if thumbnail creation fails
    }
  }
}
