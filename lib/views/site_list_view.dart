import 'package:flutter/material.dart';
import 'dart:io';
import '../models/site_model.dart';
import '../models/project_model.dart';
import '../services/site_service.dart';
import '../services/project_service.dart';
import '../services/settings_service.dart';
import 'home_view.dart'; // Needed for ArrowDrawPage

class SiteListView extends StatefulWidget {
  const SiteListView({Key? key}) : super(key: key);

  @override
  _SiteListViewState createState() => _SiteListViewState();
}

class _SiteListViewState extends State<SiteListView> {
  final SiteService _siteService = SiteService();
  List<Site> _sites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final sites = await _siteService.getAllSites();
      setState(() {
        _sites = sites;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sites: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSites,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sites.isEmpty
              ? _buildEmptyState()
              : _buildSiteList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSiteDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_city_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Sites Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a site to organize your projects',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddSiteDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Site'),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sites.length,
      itemBuilder: (context, index) {
        final site = _sites[index];
        return _buildSiteCard(site);
      },
    );
  }

  Widget _buildSiteCard(Site site) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToSiteDetail(site),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Site header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      site.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleSiteAction(value, site),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Site'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Site'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Project count
            FutureBuilder<List<Project>>(
              future: _siteService.getProjectsForSite(site.id),
              builder: (context, snapshot) {
                final projectCount = snapshot.hasData ? snapshot.data!.length : 0;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$projectCount ${projectCount == 1 ? 'Project' : 'Projects'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToSiteDetail(site),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('View'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSiteDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Site'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Site Name',
              hintText: 'Enter a name for the site',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  await _createNewSite(nameController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewSite(String name) async {
    try {
      await _siteService.saveSite(
        name: name,
        projectIds: [],
        screenshotData: null,
      );
      _loadSites();
    } catch (e) {
      print('Error creating site: $e');
    }
  }

  void _handleSiteAction(String action, Site site) async {
    switch (action) {
      case 'edit':
        _showEditSiteDialog(site);
        break;
      case 'delete':
        _showDeleteSiteDialog(site);
        break;
    }
  }

  Future<void> _showEditSiteDialog(Site site) async {
    final TextEditingController nameController = TextEditingController(text: site.name);
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Site'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Site Name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  await _updateSite(site, nameController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateSite(Site site, String newName) async {
    try {
      await _siteService.saveSite(
        name: newName,
        projectIds: site.projectIds,
        screenshotData: null,
        existingId: site.id,
      );
      _loadSites();
    } catch (e) {
      print('Error updating site: $e');
    }
  }

  Future<void> _showDeleteSiteDialog(Site site) async {
    final projectCount = (await _siteService.getProjectsForSite(site.id)).length;
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Site'),
          content: Text(
            'Are you sure you want to delete the site "${site.name}"?\n\n'
            'This site contains $projectCount ${projectCount == 1 ? 'project' : 'projects'}.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _showDeleteOptionDialog(site);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteOptionDialog(Site site) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Projects?'),
          content: const Text(
            'Do you also want to delete all projects associated with this site?'
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Delete site but keep projects
                await _siteService.deleteSite(site.id, false);
                Navigator.pop(context);
                _loadSites();
              },
              child: const Text('Keep Projects'),
            ),
            TextButton(
              onPressed: () async {
                // Delete site and all projects
                await _siteService.deleteSite(site.id, true);
                Navigator.pop(context);
                _loadSites();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToSiteDetail(Site site) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SiteDetailView(site: site),
      ),
    ).then((_) => _loadSites());
  }
}

class SiteDetailView extends StatefulWidget {
  final Site site;

  const SiteDetailView({Key? key, required this.site}) : super(key: key);

  @override
  _SiteDetailViewState createState() => _SiteDetailViewState();
}

class _SiteDetailViewState extends State<SiteDetailView> {
  final SiteService _siteService = SiteService();
  final ProjectService _projectService = ProjectService();
  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final projects = await _siteService.getProjectsForSite(widget.site.id);
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading projects: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditSiteDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? _buildEmptyState()
              : _buildProjectList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProjectOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.article_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Projects Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a project or add existing projects to this site',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddProjectOptions(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        return _buildProjectCard(project);
      },
    );
  }
  
  Widget _buildProjectCard(Project project) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
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
                  
                  // Action menu button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PopupMenuButton<String>(
                      onSelected: (value) => _handleProjectAction(value, project),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'open',
                          child: Text('Open Project'),
                        ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove from Site'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Project'),
                        ),
                      ],
                      icon: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.more_vert),
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

  Future<void> _showEditSiteDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController(text: widget.site.name);
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Site'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Site Name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  await _updateSite(nameController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateSite(String newName) async {
    try {
      await _siteService.saveSite(
        name: newName,
        projectIds: widget.site.projectIds,
        screenshotData: null,
        existingId: widget.site.id,
      );
      setState(() {});
    } catch (e) {
      print('Error updating site: $e');
    }
  }

  void _showAddProjectOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle),
                title: const Text('Create New Project'),
                onTap: () {
                  Navigator.pop(context);
                  _createNewProject();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Add Existing Project'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddExistingProjectDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _createNewProject() {
    _showCreateNewProjectDialog(context);
  }
  
  void _showCreateNewProjectDialog(BuildContext context) async {
    final SettingsService settingsService = SettingsService();
    final settings = await settingsService.getSettings();
    final TextEditingController nameController = TextEditingController(text: 'New Project');
    
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
                      labelText: 'Project Name',
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
                  onPressed: () async {
                    Navigator.pop(context);
                    final projectName = nameController.text.isNotEmpty ? nameController.text : 'New Project';
                    await _createAndNavigateToProject(projectName, selectedColor);
                  },
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
    final primaryColor = Theme.of(context).primaryColor;
    
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
  
  Future<void> _createAndNavigateToProject(String name, Color backgroundColor) async {
    try {
      // Navigate to drawing page with blank canvas
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArrowDrawPage(
            projectName: name,
            backgroundColor: backgroundColor,
            siteId: widget.site.id, // Pass the site ID to the drawing page
          ),
        ),
      );
      
      // If a project was created and saved
      if (result != null && result is Project) {
        // Add the new project to this site
        await _siteService.addProjectToSite(widget.site.id, result.id);
      }
      
      // Always refresh the project list when returning from project creation
      // This ensures we see the latest changes
      await _loadProjects();
    } catch (e) {
      print('Error creating project: $e');
    }
  }

  Future<void> _showAddExistingProjectDialog() async {
    // Get all projects not already in this site
    final allProjects = await _projectService.getAllProjects();
    final siteProjectIds = widget.site.projectIds.toSet();
    final availableProjects = allProjects.where(
      (project) => !siteProjectIds.contains(project.id)
    ).toList();
    
    if (availableProjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available projects to add.')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Existing Project'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableProjects.length,
              itemBuilder: (context, index) {
                final project = availableProjects[index];
                return ListTile(
                  title: Text(project.name),
                  subtitle: Text('Modified: ${_formatDate(project.lastModified)}'),
                  onTap: () async {
                    await _siteService.addProjectToSite(widget.site.id, project.id);
                    Navigator.pop(context);
                    _loadProjects();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _handleProjectAction(String action, Project project) async {
    switch (action) {
      case 'open':
        _openProject(project);
        break;
      case 'remove':
        _removeProjectFromSite(project);
        break;
      case 'delete':
        _showDeleteProjectDialog(project);
        break;
    }
  }

  void _openProject(Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArrowDrawPage(
          existingProject: project,
          siteId: widget.site.id, // Pass the site ID to ensure proper association
        ),
      ),
    ).then((_) => _loadProjects()); // Reload projects when returning
  }

  Future<void> _removeProjectFromSite(Project project) async {
    try {
      await _siteService.removeProjectFromSite(widget.site.id, project.id, false);
      _loadProjects();
    } catch (e) {
      print('Error removing project from site: $e');
    }
  }

  Future<void> _showDeleteProjectDialog(Project project) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text(
            'Are you sure you want to delete the project "${project.name}"?\n\n'
            'This action cannot be undone.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _siteService.removeProjectFromSite(widget.site.id, project.id, true);
                Navigator.pop(context);
                _loadProjects();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
