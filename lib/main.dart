

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:image_meter/views/test_view.dart';
import 'package:path_provider/path_provider.dart';
import 'models/arrow_model.dart';
import 'models/color_adapter.dart';
import 'models/project_model.dart';
import 'models/settings_model.dart';
import 'models/site_model.dart';
import 'views/screens/start_screen.dart';
import 'utils/constants.dart'; // Import our new constants file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  
  // Register adapters
  Hive.registerAdapter(ColorAdapter());
  Hive.registerAdapter(OffsetAdapter());
  Hive.registerAdapter(ArrowModelAdapter());
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(AppSettingsAdapter());
  Hive.registerAdapter(SiteAdapter());
  
  // Start the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpalSpace',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: accentColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,  
      home: const StartScreen(),
    );
  }
}
