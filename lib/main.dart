import 'package:flutter/material.dart';
import 'package:running_app/screens/HomePage.dart';
import 'package:running_app/screens/ProfilePage.dart';
import 'package:running_app/screens/SocialPage.dart';
import './screens/SignUpPage.dart';
import './screens/SignInPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/SignUpPage',
      routes: {
        '/SignUpPage': (context) => SignupPage(),
        '/SignInPage': (context) => SignInPage(),
        '/HomePage': (context) => HomePage(),
        '/SocialPage': (context) => SocialPage(),
        '/ProfilePage': (context) => ProfilePage()

      },
      debugShowCheckedModeBanner: false,
    );
  }
}
