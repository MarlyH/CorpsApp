import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'views/landing_view.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/forgot_password_view.dart';
import 'views/dashboard_view.dart';
import 'views/manage_children_view.dart';
import 'views/children/create_child.dart';
import 'views/children/edit_child.dart';
import 'models/child_model.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'widgets/no_internet_overlay.dart';
import 'firebase_options.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background msg: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Welcome App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: '',
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          displayLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF121212),
          selectionColor: Colors.black26,
          selectionHandleColor: Color(0xFF121212),
        ),
      ),
      home: const LandingView(),
      routes: {
        '/landing': (_) => const LandingView(),
        '/login': (_) => const LoginView(),
        '/register': (_) => const RegisterView(),
        '/forgot-password': (_) => const ForgotPasswordView(),
        '/dashboard': (_) => const DashboardView(),
        '/children': (_) => const ManageChildrenView(),
        '/children/create': (_) => const CreateChildView(),
        '/children/edit': (context) {
          final child = ModalRoute.of(context)!.settings.arguments as ChildModel;
          return EditChildView(child: child);
        },
      },
      builder: (context, child) {
        return Consumer<ConnectivityProvider>(
          builder: (context, conn, _) {
            return Stack(
              children: [
                if (child != null) child,
                if (conn.isOffline) const NoInternetOverlay(),
              ],
            );
          },
        );
      },
    );
  }
}
