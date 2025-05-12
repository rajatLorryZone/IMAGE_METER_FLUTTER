import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/settings_model.dart';
import '../../services/settings_service.dart';
import '../../utils/constants.dart'; // Import constants file with measurement units

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  late AppSettings _settings;
  bool _isLoading = true;

  // Controllers
  final _fontSizeController = TextEditingController();
  final _arrowWidthController = TextEditingController();
  final _unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.getSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
      
      // Initialize controllers
      _fontSizeController.text = settings.defaultFontSize.toString();
      _arrowWidthController.text = settings.defaultArrowWidth.toString();
      _unitController.text = settings.defaultUnit;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    
    // Parse values from controllers
    final fontSize = double.tryParse(_fontSizeController.text) ?? _settings.defaultFontSize;
    final arrowWidth = double.tryParse(_arrowWidthController.text) ?? _settings.defaultArrowWidth;
    
    // Create updated settings
    final updatedSettings = _settings.copyWith(
      defaultFontSize: fontSize,
      defaultArrowWidth: arrowWidth,
      defaultUnit: _unitController.text,
    );
    
    // Save to local storage
    await _settingsService.saveSettings(updatedSettings);
    
    setState(() {
      _settings = updatedSettings;
      _isLoading = false;
    });
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  @override
  void dispose() {
    _fontSizeController.dispose();
    _arrowWidthController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _showColorPicker(
    BuildContext context, 
    Color initialColor, 
    String title, 
    Function(Color) onColorChanged
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: initialColor,
              onColorChanged: onColorChanged,
              pickerAreaHeightPercent: 0.8,
              enableAlpha: true,
              displayThumbColor: true,
              showLabel: true,
              paletteType: PaletteType.hsv,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Default Arrow Settings Section
            const Text(
              'Default Arrow Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Arrow Color
            ListTile(
              title: const Text('Default Arrow Color'),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _settings.defaultArrowColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black),
                ),
              ),
              onTap: () {
                _showColorPicker(
                  context, 
                  _settings.defaultArrowColor, 
                  'Select Arrow Color',
                  (color) {
                    setState(() {
                      _settings = _settings.copyWith(defaultArrowColor: color);
                    });
                  },
                );
              },
            ),
            
            // Text Color
            ListTile(
              title: const Text('Default Text Color'),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _settings.defaultTextColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black),
                ),
              ),
              onTap: () {
                _showColorPicker(
                  context, 
                  _settings.defaultTextColor, 
                  'Select Text Color',
                  (color) {
                    setState(() {
                      _settings = _settings.copyWith(defaultTextColor: color);
                    });
                  },
                );
              },
            ),
            
            // Background Color
            ListTile(
              title: const Text('Default Background Color'),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _settings.defaultBackgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black),
                ),
              ),
              onTap: () {
                _showColorPicker(
                  context, 
                  _settings.defaultBackgroundColor, 
                  'Select Background Color',
                  (color) {
                    setState(() {
                      _settings = _settings.copyWith(defaultBackgroundColor: color);
                    });
                  },
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Font Size
            TextField(
              controller: _fontSizeController,
              decoration: const InputDecoration(
                labelText: 'Default Font Size',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final fontSize = double.tryParse(value);
                if (fontSize != null) {
                  setState(() {
                    _settings = _settings.copyWith(defaultFontSize: fontSize);
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Arrow Width
            TextField(
              controller: _arrowWidthController,
              decoration: const InputDecoration(
                labelText: 'Default Arrow Width',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final width = double.tryParse(value);
                if (width != null) {
                  setState(() {
                    _settings = _settings.copyWith(defaultArrowWidth: width);
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Default Unit
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Default Measurement Unit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _unitController.text.isEmpty ? getDefaultUnit() : _unitController.text,
                      items: getUnitSymbols().map((String unit) {
                        // Find the full unit info to display name
                        final unitInfo = measurementUnits.firstWhere(
                          (u) => u.symbol == unit,
                          orElse: () => const MeasurementUnit(name: '', symbol: ''),
                        );
                        
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Row(
                            children: [
                              Text(unit, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              if (unitInfo.name.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    '(${unitInfo.name})',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                            _unitController.text = newValue;
                            _settings = _settings.copyWith(defaultUnit: newValue);
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Dashed Line Toggle
            // SwitchListTile(
            //   title: const Text('Default Line Style: Dashed'),
            //   value: _settings.defaultDashedLine,
            //   onChanged: (value) {
            //     setState(() {
            //       _settings = _settings.copyWith(defaultDashedLine: value);
            //     });
            //   },
            // ),
            
            // // Show Arrow Style Toggle
            // SwitchListTile(
            //   title: const Text('Show Arrow Heads'),
            //   value: _settings.defaultShowArrowStyle,
            //   onChanged: (value) {
            //     setState(() {
            //       _settings = _settings.copyWith(defaultShowArrowStyle: value);
            //     });
            //   },
            // ),
            
            const SizedBox(height: 32),
            
            // Save Button
            Center(
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
