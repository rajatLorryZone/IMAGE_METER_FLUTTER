import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/settings_model.dart';
import '../../services/settings_service.dart';
import '../../utils/constants.dart'; // Import constants file with measurement units
import 'dart:math' as math;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// Custom painter for arrow preview
class ArrowPreviewPainter extends CustomPainter {
  final Color arrowColor;
  final Color textColor;
  final double fontSize;
  final double arrowWidth;
  final bool isDashed;
  final bool showArrowStyle;
  final String unit;

  ArrowPreviewPainter({
    required this.arrowColor,
    required this.textColor,
    required this.fontSize,
    required this.arrowWidth,
    required this.isDashed,
    required this.showArrowStyle,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw arrow
    final paint = Paint()
      ..color = arrowColor
      ..strokeWidth = arrowWidth
      ..style = PaintingStyle.stroke;

    // Starting and ending points for the arrow
    final start = Offset(size.width * 0.2, size.height / 2);
    final end = Offset(size.width * 0.8, size.height / 2);
    
    // Draw the line
    if (isDashed) {
      // Draw dashed line
      final dashWidth = 6.0;
      final dashSpace = 3.0;
      double distance = (end - start).distance;
      double drawn = 0;
      
      while (drawn < distance) {
        double toDraw = dashWidth;
        if (drawn + toDraw > distance) {
          toDraw = distance - drawn;
        }
        
        // Calculate normalized direction vector
        final dx = (end.dx - start.dx) / distance;
        final dy = (end.dy - start.dy) / distance;
        
        final startDash = Offset(
          start.dx + dx * drawn,
          start.dy + dy * drawn
        );
        
        final endDash = Offset(
          start.dx + dx * (drawn + toDraw),
          start.dy + dy * (drawn + toDraw)
        );
        
        canvas.drawLine(startDash, endDash, paint);
        
        drawn += toDraw + dashSpace;
      }
    } else {
      // Draw solid line
      canvas.drawLine(start, end, paint);
    }
    
    // Draw arrow heads if enabled
    if (showArrowStyle) {
      final arrowSize = 8.0 + arrowWidth;
      
      // Helper function to calculate arrow head points
      Offset getArrowPoint(Offset start, Offset end, double angle) {
        // Calculate direction vector
        final distance = (end - start).distance;
        final dx = (end.dx - start.dx) / distance;
        final dy = (end.dy - start.dy) / distance;
        
        // Rotate the direction vector
        final radians = angle * (3.14159 / 180.0);
        final rotatedDx = dx * math.cos(radians) - dy * math.sin(radians);
        final rotatedDy = dx * math.sin(radians) + dy * math.cos(radians);
        
        // Create the arrow point
        return Offset(
          end.dx - rotatedDx * arrowSize,
          end.dy - rotatedDy * arrowSize
        );
      }
      
      // Left arrow head
      final leftArrowP1 = getArrowPoint(end, start, 30);
      final leftArrowP2 = getArrowPoint(end, start, -30);
      
      canvas.drawLine(start, leftArrowP1, paint);
      canvas.drawLine(start, leftArrowP2, paint);
      
      // Right arrow head
      final rightArrowP1 = getArrowPoint(start, end, 30);
      final rightArrowP2 = getArrowPoint(start, end, -30);
      
      canvas.drawLine(end, rightArrowP1, paint);
      canvas.drawLine(end, rightArrowP2, paint);
    }
    
    // Draw measurement text
    final distance = ((end - start).distance / 10).toStringAsFixed(1); // Converting to cm for demo
    final textSpan = TextSpan(
      text: '$distance $unit',
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Position the text above the line
    final textOffset = Offset(
      (start.dx + end.dx) / 2 - textPainter.width / 2,
      (start.dy + end.dy) / 2 - textPainter.height - 10,
    );
    
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All settings are applied to newly created arrows')),
              );
            },
            tooltip: 'About Settings',
          ),
        ],
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                  child: Text('Default Font Size', style: TextStyle(fontSize: 16)),
                ),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    const Text('5', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _settings.defaultFontSize,
                        min: 5,
                        max: 50,
                        divisions: 45,
                        label: _settings.defaultFontSize.round().toString(),
                        activeColor: Colors.indigo,
                        thumbColor: Colors.indigo,
                        onChanged: (value) {
                          setState(() {
                            _fontSizeController.text = value.toStringAsFixed(1);
                            _settings = _settings.copyWith(defaultFontSize: value);
                          });
                        },
                      ),
                    ),
                    const Text('50', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    Container(
                      width: 50,
                      height: 35,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          _settings.defaultFontSize.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Arrow Width
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                  child: Text('Default Arrow Width', style: TextStyle(fontSize: 16)),
                ),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    const Text('1', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _settings.defaultArrowWidth,
                        min: 1,
                        max: 10,
                        divisions: 18,
                        label: _settings.defaultArrowWidth.toStringAsFixed(1),
                        activeColor: Colors.indigo,
                        thumbColor: Colors.indigo,
                        onChanged: (value) {
                          setState(() {
                            _arrowWidthController.text = value.toStringAsFixed(1);
                            _settings = _settings.copyWith(defaultArrowWidth: value);
                          });
                        },
                      ),
                    ),
                    const Text('10', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    Container(
                      width: 50,
                      height: 35,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          _settings.defaultArrowWidth.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
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
            SwitchListTile(
              title: const Text('Default Line Style: Dashed'),
              subtitle: const Text('When enabled, arrows will use dashed lines by default'),
              value: _settings.defaultDashedLine,
              activeColor: Colors.indigo,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(defaultDashedLine: value);
                });
              },
            ),
            
            // Show Arrow Style Toggle
            SwitchListTile(
              title: const Text('Show Arrow Heads'),
              subtitle: const Text('When enabled, arrows will display with arrow heads'),
              value: _settings.defaultShowArrowStyle,
              activeColor: Colors.indigo,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(defaultShowArrowStyle: value);
                });
              },
            ),
            
            const SizedBox(height: 32),
            
            // Preview Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('This is how new arrows will look:'),
                  const SizedBox(height: 16),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: _settings.defaultBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: ArrowPreviewPainter(
                        arrowColor: _settings.defaultArrowColor,
                        textColor: _settings.defaultTextColor,
                        fontSize: _settings.defaultFontSize,
                        arrowWidth: _settings.defaultArrowWidth,
                        isDashed: _settings.defaultDashedLine,
                        showArrowStyle: _settings.defaultShowArrowStyle,
                        unit: _settings.defaultUnit,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Save Button
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _saveSettings();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings saved! They will be applied to newly created arrows.'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('SAVE SETTINGS'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Settings will apply to newly created arrows',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
