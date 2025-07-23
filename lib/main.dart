import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'views/landing_view.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/forgot_password_view.dart';
import 'views/dashboard_view.dart';
import 'providers/auth_provider.dart';
import 'views/manage_children_view.dart';
import 'views/children/create_child.dart';
import 'views/children/edit_child.dart';
import 'models/child_model.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Welcome App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'CorpsFont',
          scaffoldBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
            displayLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Colors.black,           // Caret
            selectionColor: Colors.black26,      // Highlighted text
            selectionHandleColor: Colors.black,  // The little grab‑handles
          ),
        ),
        home: const LandingView(),
        routes: {
          '/landing':(context) => const LandingView(),
          '/login': (context) => const LoginView(),
          '/register': (context) => const RegisterView(),
          '/forgot-password': (context) => const ForgotPasswordView(),
          '/dashboard': (context) => const DashboardView(),
          '/children': (context) => const ManageChildrenView(),
          '/children/create': (_) => const CreateChildView(),
          '/children/edit': (context) {
            final child = ModalRoute.of(context)!.settings.arguments as ChildModel;
            return EditChildView(child: child);
          },
        },
              ),
    );
  }
}