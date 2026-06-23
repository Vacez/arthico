import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'providers/theme_provider.dart';
import 'package:app_links/app_links.dart';

import 'dart:io';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase initialization error: $e");
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // 1. Cold start deep link checking
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print("Error getting initial deep link: $e");
    }

    // 2. Warm start deep link listening
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      print("Error listening to deep links: $err");
    });
  }

  void _handleDeepLink(Uri uri) async {
    print("Received deep link: $uri");
    if (uri.path == '/__/auth/action') {
      final mode = uri.queryParameters['mode'];
      final oobCode = uri.queryParameters['oobCode'];

      if (mode == 'verifyEmail' && oobCode != null) {
        try {
          // Apply verification code
          await FirebaseAuth.instance.applyActionCode(oobCode);
          print("Firebase email verification success via App Link!");

          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('✅ Email Anda berhasil diverifikasi! Selamat datang di Arthico. Silakan masuk.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 6),
            ),
          );
        } catch (e) {
          print("Failed to verify email via App Link: $e");
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('❌ Gagal memverifikasi email: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Arthico',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeProvider.lightTheme,
      darkTheme: ThemeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService auth = AuthService();
    
    return StreamBuilder<User?>(
      stream: auth.user,
      builder: (context, snapshot) {
        // If the snapshot has data, then the user is logged in
        if (snapshot.hasData) {
          return HomeScreen();
        } else {
          // Otherwise, show the LoginScreen
          return const LoginScreen();
        }
      },
    );
  }
}
