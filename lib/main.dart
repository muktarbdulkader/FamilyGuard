import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/providers/router_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'firebase_options.dart';

/// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  return firebaseMessagingBackgroundHandler(message);
}

/// Main entry point of the Flutter Parental Control App
/// Initializes Firebase and sets up the app with Riverpod state management
void main() async {
  // Ensure Flutter bindings are initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Enable Firestore offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase init notice: $e');
  }
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize notification service
  await NotificationService.instance.initialize();
  
  // Run app with Riverpod provider scope for state management
  runApp(
    const ProviderScope(
      child: ParentalControlApp(),
    ),
  );
}

/// Root widget of the parental control application
/// Sets up theming and routing using GoRouter
class ParentalControlApp extends ConsumerWidget {
  const ParentalControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get router instance from Riverpod provider
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      
      // Use custom theme system
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      
      // Router configuration for navigation
      routerConfig: router,
    );
  }
}