import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:running_app/screens/home_page.dart';
import 'package:running_app/screens/profile_page.dart';
import 'package:running_app/screens/social_page.dart';
import './screens/sign_up_page.dart';
import './screens/sign_in_page.dart';
import './screens/map_test_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/SignInPage',
      routes: {
        '/SignUpPage': (context) => SignupPage(),
        '/SignInPage': (context) => SignInPage(),
        '/HomePage': (context) => HomePage(),
        '/SocialPage': (context) => SocialPage(),
        '/ProfilePage': (context) => ProfilePage(),
        '/MapTest': (context) => MapTestScreen(),

      },
      debugShowCheckedModeBanner: false,
    );
  }
}
