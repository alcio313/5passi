import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'providers/tracker_provider.dart';
import 'services/background_service.dart';
import 'ui/screens/join_room_screen.dart';
import 'ui/screens/tracker_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive dark UI overlay styles
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize native background location service
  await BackgroundTrackingManager.initializeService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => TrackerProvider(),
      child: const LiveMapTrackerApp(),
    ),
  );
}

class LiveMapTrackerApp extends StatelessWidget {
  const LiveMapTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '5passi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.radarCore,
          surface: AppColors.surface,
          error: AppColors.danger,
        ),
      ),
      home: Consumer<TrackerProvider>(
        builder: (context, tracker, _) {
          return tracker.isInRoom ? const TrackerMapScreen() : const JoinRoomScreen();
        },
      ),
    );
  }
}
