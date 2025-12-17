import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:running_app/screens/profile_page.dart';
import 'package:running_app/screens/social_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // This list defines which widget is shown for each tab
  final List<Widget> _pages = [
    const HomeContent(),
    const Center(child: Text("Schedule Page")), // Index 1: Placeholder
    const SocialPage(),
    const Center(child: Text("Saved Page")),    // Index 3: Placeholder
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

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // Logic specific to the Home Page (Carousel & Data)
  late PageController _pageController;
  final int _initialPage = 1000;

  // Dummy Data
  final List<Map<String, dynamic>> _routes = [
    {
      "title": "Heart Of Barcelona",
      "image": "https://images.unsplash.com/photo-1583422409516-2895a77efded?q=80&w=2070&auto=format&fit=crop",
      "rating": 4.8,
      "reviews": 500,
      "distance": "1.2 miles",
    },
    {
      "title": "Coastal Run",
      "image": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=2073&auto=format&fit=crop",
      "rating": 4.9,
      "reviews": 120,
      "distance": "3.5 miles",
    },
    {
      "title": "City Park Loop",
      "image": "https://images.unsplash.com/photo-1476610182048-b716b8518aae?q=80&w=2027&auto=format&fit=crop",
      "rating": 4.5,
      "reviews": 340,
      "distance": "2.0 miles",
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage, viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Running App",
          style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Search & Filter Section ---s
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: "Where To?",
                        hintStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                        prefixIcon: Icon(Icons.search, color: Colors.black),
                        suffixIcon: Icon(Icons.edit_outlined, color: Colors.black),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildFilterChip("Filter"),
                          const SizedBox(width: 8),
                          _buildFilterChip("Sort"),
                        ],
                      ),
                      const Text(
                        "99 results",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      )
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- 2. The Map ---
            SizedBox(
              height: 300,
              width: double.infinity,
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(41.3851, 2.1734), // Barcelona
                  initialZoom: 13.0,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.running_app',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. Suggested Routes Title ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Suggested Routes For You",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // --- 4. The Infinite Carousel ---
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                itemBuilder: (context, index) {
                  final int realIndex = index % _routes.length;
                  return _buildRouteCard(_routes[realIndex]);
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16),
        ],
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image: DecorationImage(
                      image: NetworkImage(data['image']),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[400],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: const Text("Start"),
                      ),
                      const SizedBox(width: 8),                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data['title'],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                "${data['rating']} (${data['reviews']} reviews)",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                data['distance'],
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}