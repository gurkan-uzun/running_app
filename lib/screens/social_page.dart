import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:running_app/screens/chat_detail_screen.dart';

class SocialPage extends StatelessWidget {
  const SocialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Analysis (Feed) & Chats
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {},
          ),
          title: const Text(
            "Social",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=12"),
                radius: 18,
              ),
            )
          ],
          // --- TAB BAR ADDED HERE ---
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Feed"),
              Tab(text: "Chats"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SocialFeedTab(), // Your original content
            _ChatsTab(),      // The new Chat list
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: FEED (Map, Chart, Friends)
// ---------------------------------------------------------------------------
class _SocialFeedTab extends StatelessWidget {
  const _SocialFeedTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // 1. Mini Map
            SizedBox(
              height: 180,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
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
            ),

            const SizedBox(height: 30),

            // 2. "Your Friends" Chart Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your Friends",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      _mainData(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. "Your Circle" List
            const Text(
              "Your Circle",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildFriendItem(
              "Sena Eğilmezbaş",
              "sena.egilmezbas@sabanciuniv.edu",
              "https://i.pravatar.cc/150?img=5",
            ),
            _buildFriendItem(
              "Erim Zak Bosson",
              "ronaldoCR7@fakedomain.net",
              "https://i.pravatar.cc/150?img=8",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(String name, String email, String imageUrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(imageUrl),
            radius: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                email,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          )
        ],
      ),
    );
  }

  LineChartData _mainData() {
    return LineChartData(
      // --- FIX: Compatible with your version ---
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          // In older versions, use 'tooltipBgColor' (Color) instead of 'getTooltipColor' (Function)
          tooltipBgColor: Colors.black, 
          
          // Customize text to be White and Bold
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              return LineTooltipItem(
                '${barSpot.y.toInt()} km', // Showing value
                const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
      // ----------------------------------------
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 5,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey[200], strokeWidth: 1);
        },
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
              if (value == 0) return const Text('Nov', style: TextStyle(color: Colors.grey, fontSize: 12));
              if (value >= 1 && value <= 7) return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 12));
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              if (value == 5) return const Text('5 km', style: TextStyle(color: Colors.grey, fontSize: 10));
              if (value == 25) return const Text('25 km', style: TextStyle(color: Colors.grey, fontSize: 10));
              return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 7,
      minY: 0,
      maxY: 25,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 5), FlSpot(1, 8), FlSpot(2, 5),
            FlSpot(3, 12), FlSpot(4, 10), FlSpot(5, 18),
            FlSpot(6, 15), FlSpot(7, 20),
          ],
          isCurved: true,
          color: Colors.black.withOpacity(0.5), 
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.grey.withOpacity(0.05),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: CHATS
// ---------------------------------------------------------------------------
class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    // Dummy Chat Data
    final List<Map<String, String>> chats = [
      {
        "name": "Run Club Group",
        "message": "Are we meeting at 7 AM tomorrow?",
        "time": "10:30 AM",
        "image": "https://i.pravatar.cc/150?img=15"
      },
      {
        "name": "Sena Eğilmezbaş",
        "message": "Great run today!",
        "time": "Yesterday",
        "image": "https://i.pravatar.cc/150?img=5"
      },
      {
        "name": "Erim Zak Bosson",
        "message": "Check out this new route.",
        "time": "Mon",
        "image": "https://i.pravatar.cc/150?img=8"
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: chats.length,
      separatorBuilder: (context, index) => Divider(color: Colors.grey[100]),
      itemBuilder: (context, index) {
        final chat = chats[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(chat['image']!),
          ),
          title: Text(
            chat['name']!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            chat['message']!,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            chat['time']!,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          // --- NAVIGATION LOGIC HERE ---
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  name: chat['name']!,
                  imageUrl: chat['image']!,
                ),
              ),
            );
          },
        );
      },
    );
  }
}