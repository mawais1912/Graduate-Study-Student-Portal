import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unienroll_student/screens/coursesscreen.dart';
import 'package:unienroll_student/screens/detailedinformationscreen.dart';
import 'package:unienroll_student/screens/enrolled_courses_screen.dart';
import 'package:unienroll_student/screens/notificationscreen.dart';
import 'package:unienroll_student/screens/previewcreen.dart';
import 'package:unienroll_student/screens/profile_screen.dart';
import 'package:unienroll_student/screens/update_details_screen.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forget_password_screen.dart';
import 'screens/home_screen.dart';

// Firebase options
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniEnroll Student Portal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),

      // ✅ Auth check
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          } else if (snapshot.hasData) {
            return const HomeScreen();
          } else {
            return const SplashScreen();
          }
        },
      ),

      // ✅ Routes
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forget': (context) => const ForgetPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/details': (context) => const DetailInformationScreen(),
        '/courses': (context) => const CoursesScreen(),
        '/preview': (context) => const PreviewScreen(),
        '/notifications': (context) => const NotificationScreen(),
        '/enrolled': (context) => const EnrolledCoursesScreen(),
        '/updateDetails': (context) => const UpdateDetailsScreen(),

      },
    );
  }
}
