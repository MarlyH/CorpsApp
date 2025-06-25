import 'package:flutter/material.dart';
import 'views/landing_view.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/forgot_password_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome App',
      // theme: ThemeData(primarySwatch: Colors.blue),
      theme: ThemeData(
        fontFamily: 'CorpsFont',
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          displayLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      home: const LandingView(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginView(),
        '/register': (context) => const RegisterView(),
        '/forgot-password': (context) => const ForgotPasswordView(),
      },
    );
  }
}
