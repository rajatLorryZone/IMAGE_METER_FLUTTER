import 'package:flutter/material.dart';
import 'package:image_meter/models/settings_model.dart';
import '../../utils/constants.dart'; // Import constants file
import '../../services/settings_service.dart';
import '../home_view.dart';
import '../site_list_view.dart';
import 'recent_works_screen.dart';
import 'settings_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({Key? key}) : super(key: key);

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final SettingsService _settingsService = SettingsService();
  late AppSettings _settings;
 
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.getSettings();
    setState(() {
      _settings = settings;
     
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpalSpace'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                childAspectRatio: 0.7,
                mainAxisSpacing: 16,
                children: [
                  // Create Blank Canvas Card
                  _buildOptionCard(
                    context: context,
                    icon: Icons.add,
                    title: 'New Project',
                    description: 'Create a blank canvas',
                    color: primaryColor,
                    onTap: () async{
                      await _loadSettings();
                      _showCreateNewProjectDialog(context);
                    },
                  ),
                  
                  // Recent Works Card
                  _buildOptionCard(
                    context: context,
                    icon: Icons.history,
                    title: 'Recent Works',
                    description: 'Open a recent project',
                    color: accentColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecentWorksScreen(),
                        ),
                      );
                    },
                  ),
                  
                  // Sites Card
                  _buildOptionCard(
                    context: context,
                    icon: Icons.location_city,
                    title: 'Sites',
                    description: 'Organize projects by site',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SiteListView(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Footer with info
          Container(
            padding: const EdgeInsets.all(8.0),
            color: primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.folder),
                  label: const Text('My Files'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecentWorksScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateNewProjectDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    
    // For color selection

    // default color
    Color selectedColor = _settings.defaultBackgroundColor;
    
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
                      _buildColorOption(context,_settings.defaultBackgroundColor, selectedColor, (color) {
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
                    _createNewProject(context, nameController.text, selectedColor);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
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
    // Get default settings for new project (in a real app, this would be loaded from settings)
    final settingsService = SettingsService();
    
    // Navigate to drawing page with blank canvas
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArrowDrawPage(
          projectName: name,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}
