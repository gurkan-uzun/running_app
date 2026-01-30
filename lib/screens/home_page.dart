import 'package:flutter/material.dart';
import 'package:running_app/screens/schedule_page.dart';
import 'package:running_app/screens/profile_page.dart';
import 'package:running_app/screens/social_page.dart';
import 'package:running_app/screens/route_screen.dart';
import 'package:running_app/screens/saved_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // This list defines which widget is shown for each tab
  final List<Widget> _pages = [
    const RouteScreen(), // Route generation (main feature)
    const SchedulePage(),
    const SocialPage(),
    const SavedPage(), // Saved runs and favorite routes
    const ProfilePage(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home", activeIcon: Icon(Icons.home)),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: "Schedule"),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: "Social"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: "Saved"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }
}

// Old HomeContent class removed - now using RouteScreen