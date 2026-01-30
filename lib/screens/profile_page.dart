import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'preferences_screen.dart';
import 'edit_profile_screen.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 2 tabs: Analysis, Settings
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
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Analysis"),
              Tab(text: "Settings"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Tab 1: Analysis UI
            _AnalysisTab(),
            
            // Tab 2: Profile Settings
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
class _AnalysisTab extends StatefulWidget {
  const _AnalysisTab();

  @override
  State<_AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<_AnalysisTab> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  
  // Stats
  double _last28DaysDistance = 0;
  double _last28DaysPace = 0;
  String _distanceChange = "0%";
  String _paceChange = "0%";
  
  // Chart Data
  List<FlSpot> _weeklySpots = [];
  double _maxChartY = 10;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final trips = await _dbService.getTrips(limit: 100);
      if (!mounted) return;

      final now = DateTime.now();
      final last28DaysStart = now.subtract(const Duration(days: 28));
      final prev28DaysStart = last28DaysStart.subtract(const Duration(days: 28));

      // 1. Calculate Period Stats
      double currentDist = 0;
      double prevDist = 0;
      double currentDuration = 0;
      double prevDuration = 0;

      for (var trip in trips) {
        if (trip.createdAt.isAfter(last28DaysStart)) {
          currentDist += trip.distance / 1000.0; // km
          currentDuration += trip.duration / 60.0; // min
        } else if (trip.createdAt.isAfter(prev28DaysStart)) {
          prevDist += trip.distance / 1000.0;
          prevDuration += trip.duration / 60.0;
        }
      }

      // 2. Calculate Comparison
      // Distance
      String distChange = "";
      if (prevDist > 0) {
        final change = ((currentDist - prevDist) / prevDist) * 100;
        distChange = "${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% month over month";
      } else {
        distChange = "No previous data";
      }

      // Pace (min/km)
      double currentPace = currentDist > 0 ? currentDuration / currentDist : 0;
      double prevPace = prevDist > 0 ? prevDuration / prevDist : 0;
      
      String paceChange = "";
      if (prevPace > 0) {
        final change = ((currentPace - prevPace) / prevPace) * 100;
        paceChange = "${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% month over month";
      } else {
        paceChange = "No previous data";
      }

      // 3. Weekly Chart Data (Last 7 days)
      final weekStart = now.subtract(const Duration(days: 6)); // 7 days including today
      Map<int, double> dailyDistances = {};
      
      // Initialize 0 for last 7 days
      for (int i = 0; i < 7; i++) {
        dailyDistances[i] = 0;
      }

      for (var trip in trips) {
        final dayDiff = now.difference(trip.createdAt).inDays;
        if (dayDiff < 7 && dayDiff >= 0) {
          // Map index: 6 is today, 0 is 6 days ago (chart left to right)
          final index = 6 - dayDiff; 
          dailyDistances[index] = (dailyDistances[index] ?? 0) + (trip.distance / 1000.0);
        }
      }

      List<FlSpot> spots = [];
      double maxY = 0;
      dailyDistances.forEach((key, value) {
        spots.add(FlSpot(key.toDouble() + 1, value));
        if (value > maxY) maxY = value;
      });
      
      // Add padding to max Y
      maxY = (maxY * 1.2).ceilToDouble();
      if (maxY < 10) maxY = 10;

      setState(() {
        _last28DaysDistance = currentDist;
        _last28DaysPace = currentPace;
        _distanceChange = distChange;
        _paceChange = paceChange;
        _weeklySpots = spots;
        _maxChartY = maxY;
        _isLoading = false;
      });

    } catch (e) {
      print("Error loading stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            
            // 1. Top Stats Row
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Last 28 days",
                      "${_last28DaysDistance.toStringAsFixed(2)} km",
                      _distanceChange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      "Avg Pace",
                      "${_last28DaysPace.toStringAsFixed(2)} min/km",
                      _paceChange,
                    ),
                  ),
                ],
              ),
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
                    child: _weeklySpots.isEmpty 
                      ? const Center(child: Text("No runs this week"))
                      : LineChart(_mainData()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    final isPositive = subtitle.startsWith('+');
    
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
          Text(
            subtitle, 
            style: TextStyle(
              fontSize: 10, 
              color: isPositive ? Colors.green : (subtitle.startsWith('No') ? Colors.grey : Colors.red)
            )
          ),
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
        horizontalInterval: _maxChartY / 5, // Dynamic interval
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
              // Calculate day name based on current day
              // value 1 is 6 days ago, 7 is today
              final now = DateTime.now();
              final dayIndex = value.toInt() - 1; // 0 to 6
              final date = now.subtract(Duration(days: 6 - dayIndex));
              
              String text;
              switch (date.weekday) {
                case 1: text = 'Mon'; break;
                case 2: text = 'Tue'; break;
                case 3: text = 'Wed'; break;
                case 4: text = 'Thu'; break;
                case 5: text = 'Fri'; break;
                case 6: text = 'Sat'; break;
                case 7: text = 'Sun'; break;
                default: text = '';
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(text, style: style),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: _maxChartY / 5,
            reservedSize: 32,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink();
              return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[200]!)),
      minX: 1,
      maxX: 7,
      minY: 0,
      maxY: _maxChartY,
      lineBarsData: [
        LineChartBarData(
          spots: _weeklySpots,
          isCurved: false, // Straight lines as per image
          color: const Color(0xFF4A6FFF), // Blueish color
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: PROFILE INFO (renamed from TAB 4)
// ---------------------------------------------------------------------------
class _ProfileInfoTab extends StatefulWidget {
  const _ProfileInfoTab();

  @override
  State<_ProfileInfoTab> createState() => _ProfileInfoTabState();
}

class _ProfileInfoTabState extends State<_ProfileInfoTab> {
  String? _username;
  
  @override
  void initState() {
    super.initState();
    _loadUsername();
  }
  
  Future<void> _loadUsername() async {
    try {
      final dbService = DatabaseService();
      final profile = await dbService.getUserProfile();
      if (mounted && profile != null) {
        setState(() {
          _username = profile['username'];
        });
      }
    } catch (e) {
      print('Error loading username: $e');
    }
  }

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
            if (_username != null) ...[
              const SizedBox(height: 4),
              Text(
                '@$_username',
                style: TextStyle(color: Colors.blue[600], fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 4),
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
            _buildProfileItem(context, Icons.person_outline, "Edit Profile", onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              ).then((_) => _loadUsername()); // Refresh username after editing
            }),
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