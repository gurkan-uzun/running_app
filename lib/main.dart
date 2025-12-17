import 'package:flutter/material.dart';
import 'package:running_app/screens/home_page.dart';
import 'package:running_app/screens/profile_page.dart';
import 'package:running_app/screens/social_page.dart';
import './screens/sign_up_page.dart';
import './screens/sign_in_page.dart';
import './screens/map_test_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/MapTest',
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
