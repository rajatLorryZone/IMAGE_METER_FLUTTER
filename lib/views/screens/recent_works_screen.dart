import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/project_model.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../home_view.dart';

class RecentWorksScreen extends StatefulWidget {
  const RecentWorksScreen({Key? key}) : super(key: key);

  @override
  State<RecentWorksScreen> createState() => _RecentWorksScreenState();
}

class _RecentWorksScreenState extends State<RecentWorksScreen> {
  final ProjectService _projectService = ProjectService();
  List<Project> _recentProjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentProjects();
  }

  Future<void> _loadRecentProjects() async {
    try {
      final projects = await _projectService.getRecentProjects();
      setState(() {
        _recentProjects = projects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recent projects: $e')),
        );
      }
    }
  }

  void _openProject(Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArrowDrawPage(
          existingProject: project,
        ),
      ),
    ).then((_) => _loadRecentProjects());
  }

  Future<void> _deleteProject(String id) async {
    try {
      await _projectService.deleteProject(id);
      await _loadRecentProjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting project: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentProjects.isEmpty) {
      return Scaffold(
          appBar: AppBar(
        title: const Text('Recent Works'),
      ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No recent projects found',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _showCreateNewProjectDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create New Project'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Works'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecentProjects,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: _recentProjects.length,
          itemBuilder: (context, index) {
            final project = _recentProjects[index];
            return _buildProjectCard(project);
          },
        ),
      ),
    );
  }

  void _showCreateNewProjectDialog(BuildContext context) async {
    final SettingsService settingsService = SettingsService();
    final settings = await settingsService.getSettings();
    final TextEditingController nameController = TextEditingController();
    
    // Default color
    Color selectedColor = settings.defaultBackgroundColor;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Project'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter project name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Background Color:'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildColorOption(context, settings.defaultBackgroundColor, selectedColor, (color) {
                        setState(() => selectedColor = color);
                      }),
                      _buildColorOption(context, Colors.black, selectedColor, (color) {
                        setState(() => selectedColor = color);
                      }),
                      _buildColorOption(context, Colors.white, selectedColor, (color) {
                        setState(() => selectedColor = color);
                      }),
                      _buildColorOption(context, Colors.blue.shade100, selectedColor, (color) {
                        setState(() => selectedColor = color);
                      }),
                      _buildColorOption(context, Colors.grey.shade300, selectedColor, (color) {
                        setState(() => selectedColor = color);
                      }),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final projectName = nameController.text.isNotEmpty ? nameController.text : 'New Project';
                    _createNewProject(context, projectName, selectedColor);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildColorOption(
    BuildContext context, 
    Color color, 
    Color selectedColor, 
    Function(Color) onSelected
  ) {
    final isSelected = color.value == selectedColor.value;
    final primaryColor = Colors.indigo;
    
    return GestureDetector(
      onTap: () => onSelected(color),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
      ),
    );
  }

  void _createNewProject(BuildContext context, String name, Color backgroundColor) {
    // Navigate to drawing page with blank canvas
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArrowDrawPage(
          projectName: name,
          backgroundColor: backgroundColor,
        ),
      ),
    ).then((_) => _loadRecentProjects()); // Reload projects after coming back
  }

  Widget _buildProjectCard(Project project) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        // onTap: (){
        //   // bg color 
        //   log("Bg Color ${project.backgroundColor}");
        // },
        onTap: () => _openProject(project),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Project thumbnail or placeholder
                  if (project.thumbnailPath.isNotEmpty && File(project.thumbnailPath).existsSync())
                    Image.file(
                      File(project.thumbnailPath),
                      fit: BoxFit.cover,
                    )
                  else if (project.imagePath != null && project.imagePath!.isNotEmpty && File(project.imagePath!).existsSync())
                    // If thumbnail is missing but we have the original image
                    Image.file(
                      File(project.imagePath!),
                      fit: BoxFit.cover,
                    )
                  else
                    // Placeholder with project background color
                    Container(
                      color: project.backgroundColor,
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  
                  // Visual indicator if project has an image
                  if (project.imagePath != null && project.imagePath!.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Image', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  
                  // Delete button overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ClipOval(
                      child: Material(
                        color: Colors.white.withOpacity(0.8),
                        child: InkWell(
                          onTap: () => _deleteProject(project.id),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Project details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last modified: ${_formatDate(project.lastModified)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
