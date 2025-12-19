import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'preferences_screen.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // We have 2 tabs: Analysis and Profile Info
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "My Profile",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          // The TabBar goes here to divide the screen at the top
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Analysis"),
              Tab(text: "Profile Info"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Tab 1: The Analysis UI (from your screenshot)
            _AnalysisTab(),
            
            // Tab 2: Profile Placeholders
            _ProfileInfoTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: ANALYSIS UI
// ---------------------------------------------------------------------------
class _AnalysisTab extends StatelessWidget {
  const _AnalysisTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            
            // 1. Top Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Last 28 days",
                    "19,03 km",
                    "+20% month over month",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Last 28 days",
                    "7,53’",
                    "+33% month over month",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2. Weekly Performance Chart
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Weekly Performance",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: LineChart(_mainData()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Where You Ran Header
            const Text(
              "Where You Ran",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text("Map Placeholder", style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  // Chart Configuration
  LineChartData _mainData() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 5, // Lines every 5 units
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey[200],
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              const style = TextStyle(color: Colors.grey, fontSize: 10);
              String text;
              switch (value.toInt()) {
                case 0: text = 'Nov'; break;
                case 1: text = '1'; break;
                case 2: text = '2'; break;
                case 3: text = '3'; break;
                case 4: text = '4'; break;
                case 5: text = '5'; break;
                case 6: text = '6'; break;
                case 7: text = '7'; break;
                default: return Container();
              }
              return Text(text, style: style);
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            reservedSize: 32,
            getTitlesWidget: (value, meta) {
               if (value == 5) return const Text('5 km', style: TextStyle(color: Colors.grey, fontSize: 10));
               if (value == 25) return const Text('25 km', style: TextStyle(color: Colors.grey, fontSize: 10));
               return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[200]!)),
      minX: 0,
      maxX: 7,
      minY: 0,
      maxY: 25,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(1, 15),
            FlSpot(2, 12),
            FlSpot(3, 17),
            FlSpot(4, 5),
            FlSpot(5, 12),
            FlSpot(6, 18),
            FlSpot(7, 22),
          ],
          isCurved: false, // Straight lines as per image
          color: const Color(0xFF4A6FFF), // Blueish color
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: PROFILE INFO
// ---------------------------------------------------------------------------
class _ProfileInfoTab extends StatelessWidget {
  const _ProfileInfoTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Runner';
    final email = user?.email ?? '';
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundImage: user?.photoURL != null 
                ? NetworkImage(user!.photoURL!) 
                : const NetworkImage("https://i.pravatar.cc/300"),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              email,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            _buildProfileItem(context, Icons.route, "Route Preferences", onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PreferencesScreen()),
              );
            }),
            _buildProfileItem(context, Icons.person_outline, "Edit Profile"),
            _buildProfileItem(context, Icons.notifications_outlined, "Notifications"),
            _buildProfileItem(context, Icons.privacy_tip_outlined, "Privacy Policy"),
            _buildProfileItem(context, Icons.logout, "Log Out", isDestructive: true, onTap: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/SignInPage');
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(context, IconData icon, String text, {bool isDestructive = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red : Colors.black),
        title: Text(
          text,
          style: TextStyle(
            color: isDestructive ? Colors.red : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}