import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/providers/router_provider.dart';
import 'firebase_options.dart';

/// Main entry point of the Flutter Parental Control App
/// Initializes Firebase and sets up the app with Riverpod state management
void main() async {
  // Ensure Flutter bindings are initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
      title: 'Family Guardian',
      debugShowCheckedModeBanner: false,
      
      // App theme configuration
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      
      // Dark theme configuration
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      
      // Router configuration for navigation
      routerConfig: router,
    );
  }
}