import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:running_app/screens/chat_detail_screen.dart';
import 'package:running_app/services/database_service.dart';

class SocialPage extends StatelessWidget {
  const SocialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Social",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Feed"),
              Tab(text: "Chats"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SocialFeedTab(),
            _ChatsTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: FEED (Activity Feed, Leaderboard, Friends)
// ---------------------------------------------------------------------------
class _SocialFeedTab extends StatefulWidget {
  const _SocialFeedTab();

  @override
  State<_SocialFeedTab> createState() => _SocialFeedTabState();
}

class _SocialFeedTabState extends State<_SocialFeedTab> {
  final DatabaseService _dbService = DatabaseService();
  
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _leaderboard = [];
  String _leaderboardPeriod = 'weekly';
  bool _isLoading = true;
  bool _showSearch = false;
  bool _showAllActivities = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _dbService.getUserProfile();
      final friends = await _dbService.getFriends();
      final activities = await _dbService.getFriendActivities(limit: 10);
      final leaderboard = await _dbService.getLeaderboard(period: _leaderboardPeriod);
      
      setState(() {
        _userProfile = profile;
        _friends = friends;
        _activities = activities;
        _leaderboard = leaderboard;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading social data: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await _dbService.searchUsers(query);
      setState(() => _searchResults = results);
      if (results.isEmpty && query.length >= 2) {
        // Show hint if no results
        print('No users found for query: $query');
      }
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addFriend(String userId) async {
    try {
      await _dbService.addFriend(userId);
      await _loadData();
      setState(() {
        _showSearch = false;
        _searchController.clear();
        _searchResults = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend added!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('Add friend error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add friend: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeFriend(String userId) async {
    await _dbService.removeFriend(userId);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity Feed Section
              _buildSectionHeader('Activity Feed', Icons.directions_run),
              const SizedBox(height: 12),
              _buildActivityFeed(),
              
              const SizedBox(height: 24),
              
              // Leaderboard Section
              _buildSectionHeader('Leaderboard', Icons.leaderboard),
              const SizedBox(height: 8),
              _buildLeaderboardToggle(),
              const SizedBox(height: 12),
              _buildLeaderboard(),
              
              const SizedBox(height: 24),
              
              // Your Circle Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('Your Circle', Icons.people),
                  IconButton(
                    icon: Icon(_showSearch ? Icons.close : Icons.person_add, color: Colors.blue),
                    onPressed: () => setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchController.clear();
                        _searchResults = [];
                      }
                    }),
                  ),
                ],
              ),
              if (_showSearch) _buildSearchField(),
              const SizedBox(height: 12),
              _buildFriendsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActivityFeed() {
    if (_activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('No activity yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
              Text('Add friends to see their runs here', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final displayedActivities = _showAllActivities ? _activities : _activities.take(3).toList();

    return Column(
      children: [
        ...displayedActivities.map((activity) => _buildActivityCard(activity)),
        if (_activities.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showAllActivities = !_showAllActivities;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_showAllActivities ? 'Show Less' : 'Show More'),
                  const SizedBox(width: 4),
                  Icon(_showAllActivities ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16),
                ],
              ),
            ),
          ),
      ],
    );
  }

  MapOptions _getMapOptions(List<LatLng> points) {
    if (points.length < 2) {
      return MapOptions(
        initialCenter: points.isNotEmpty ? points.first : const LatLng(0, 0),
        initialZoom: 15,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      );
    }
    
    // Check if creates zero area bounds
    final bounds = LatLngBounds.fromPoints(points);
    if (bounds.north == bounds.south && bounds.east == bounds.west) {
      return MapOptions(
        initialCenter: bounds.center,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      );
    }

    return MapOptions(
      initialCameraFit: CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(20),
      ),
      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final distance = (activity['distance'] ?? 0).toDouble();
    final duration = activity['duration'] ?? 0;
    final createdAt = (activity['createdAt'] as Timestamp?)?.toDate();
    
    // Parse route coordinates (stored as List<dynamic> of GeoPoint in Firestore)
    List<LatLng> routePoints = [];
    if (activity['routeCoords'] != null) {
      try {
        final coordsList = activity['routeCoords'] as List<dynamic>;
        routePoints = coordsList.map((p) {
          if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
          // Handle case where it might be a map (backwards compatibility if needed)
          if (p is Map<String, dynamic>) {
            return LatLng(
              (p['lat'] ?? p['latitude'] ?? 0).toDouble(), 
              (p['lng'] ?? p['longitude'] ?? 0).toDouble()
            );
          }
          return const LatLng(0, 0);
        }).toList();
      } catch (e) {
        print('Error parsing route coords: $e');
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: activity['userPhoto'] != null 
                    ? NetworkImage(activity['userPhoto']) 
                    : null,
                child: activity['userPhoto'] == null 
                    ? const Icon(Icons.person, size: 20) 
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity['userName'] ?? 'Unknown', 
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_formatTimeAgo(createdAt), 
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (routePoints.isNotEmpty) _buildMiniRouteMap(routePoints),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip(Icons.straighten, '${distance.toStringAsFixed(2)} km'),
              _buildStatChip(Icons.timer, _formatDuration(duration)),
              _buildStatChip(Icons.speed, '${(duration > 0 ? distance / duration * 60 : 0).toStringAsFixed(1)} min/km'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniRouteMap(List<LatLng> routePoints) {
    if (routePoints.isEmpty) return const SizedBox.shrink();
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 100,
        child: FlutterMap(
          options: _getMapOptions(routePoints),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            PolylineLayer(
              polylines: [
                Polyline(points: routePoints, strokeWidth: 4, color: Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
      ],
    );
  }

  Widget _buildLeaderboardToggle() {
    return Row(
      children: [
        _buildToggleButton('Weekly', 'weekly'),
        const SizedBox(width: 8),
        _buildToggleButton('Monthly', 'monthly'),
      ],
    );
  }

  Widget _buildToggleButton(String label, String period) {
    final isSelected = _leaderboardPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _leaderboardPeriod = period);
        _dbService.getLeaderboard(period: period).then((lb) {
          setState(() => _leaderboard = lb);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    if (_leaderboard.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No data for this period', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: _leaderboard.take(5).map((entry) => _buildLeaderboardEntry(entry)).toList(),
      ),
    );
  }

  Widget _buildLeaderboardEntry(Map<String, dynamic> entry) {
    final rank = entry['rank'] ?? 0;
    final isCurrentUser = entry['isCurrentUser'] ?? false;
    final distance = (entry['periodDistance'] ?? 0).toDouble();
    
    Color? rankColor;
    if (rank == 1) rankColor = Colors.amber;
    else if (rank == 2) rankColor = Colors.grey[400];
    else if (rank == 3) rankColor = Colors.orange[300];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue.withValues(alpha: 0.1) : null,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor ?? Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rankColor != null ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundImage: entry['photoUrl'] != null ? NetworkImage(entry['photoUrl']) : null,
            child: entry['photoUrl'] == null ? const Icon(Icons.person, size: 18) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry['displayName'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${distance.toStringAsFixed(1)} km',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by username...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: _searchUsers,
        ),
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: Column(
              children: _searchResults.map((user) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['photoUrl'] != null ? NetworkImage(user['photoUrl']) : null,
                  child: user['photoUrl'] == null ? const Icon(Icons.person) : null,
                ),
                title: Text(user['displayName'] ?? 'Unknown'),
                subtitle: Text(user['email'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.blue),
                  onPressed: () => _addFriend(user['uid']),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              const Text('No friends yet', style: TextStyle(color: Colors.grey)),
              const Text('Tap + to add friends', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _friends.map((friend) => _buildFriendItem(friend)).toList(),
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: friend['photoUrl'] != null ? NetworkImage(friend['photoUrl']) : null,
            child: friend['photoUrl'] == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend['displayName'] ?? 'Unknown', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${((friend['totalDistance'] ?? 0) as num).toStringAsFixed(1)} km total',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 20),
            onPressed: () => _showRemoveFriendDialog(friend),
          ),
        ],
      ),
    );
  }

  void _showRemoveFriendDialog(Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${friend['displayName']} from your friends?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(friend['uid']);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Recently';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}:${secs.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// TAB 2: CHATS
// ---------------------------------------------------------------------------
class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
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