import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_preferences.dart';
import '../models/trip.dart';
import '../models/favorite_route.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // ============ USER PROFILE ============

  /// Get or create user document reference
  DocumentReference get _userDoc {
    if (_userId == null) throw Exception('User not authenticated');
    return _db.collection('users').doc(_userId);
  }

  /// Initialize user profile on first sign-in
  Future<void> initializeUserProfile({String? displayName, String? username}) async {
    final doc = await _userDoc.get();
    if (!doc.exists) {
      final finalUsername = username ?? 'runner_${_userId!.substring(0, 6)}';
      
      await _userDoc.set({
        'displayName': displayName ?? _auth.currentUser?.displayName ?? 'Runner',
        'username': finalUsername,
        'photoUrl': _auth.currentUser?.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'totalDistance': 0.0,
        'runCount': 0,
      });
      
      // Create public username entry for searchability
      await _db.collection('usernames').doc(finalUsername.toLowerCase()).set({
        'uid': _userId,
        'username': finalUsername,
        'displayName': displayName ?? _auth.currentUser?.displayName ?? 'Runner',
        'photoUrl': _auth.currentUser?.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Initialize default preferences
      await savePreferences(UserPreferences());
    }
  }
  
  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _db.collection('usernames').doc(username.toLowerCase()).get();
    return !doc.exists;
  }


  /// Get current user's profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final doc = await _userDoc.get();
      if (doc.exists) {
        return {'uid': _userId, ...doc.data() as Map<String, dynamic>};
      }
    } catch (e) {
      print('Error getting user profile: $e');
    }
    return null;
  }

  /// Get any user's public profile by ID (from usernames collection)
  Future<Map<String, dynamic>?> getUserProfileById(String userId) async {
    try {
      // Search usernames collection by uid field (public data)
      final snapshot = await _db.collection('usernames')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {
          'uid': userId,
          'username': data['username'],
          'displayName': data['displayName'],
          'photoUrl': data['photoUrl'],
          'totalDistance': data['totalDistance'] ?? 0.0,
        };
      }
    } catch (e) {
      print('Error getting profile: $e');
    }
    return null;
  }

  /// Update user profile fields
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    await _userDoc.update(updates);
  }

  /// Update user stats (call after completing a run)
  Future<void> updateUserStats(double distance) async {
    await _userDoc.update({
      'totalDistance': FieldValue.increment(distance),
      'runCount': FieldValue.increment(1),
    });
  }

  /// Search users by username (exact match on document ID)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty || query.length < 2) return [];
    
    final queryLower = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    List<Map<String, dynamic>> results = [];
    
    try {
      // Try exact match first (document ID is the username)
      final doc = await _db.collection('usernames').doc(queryLower).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final uid = data['uid'] as String?;
        if (uid != null && uid != _userId) {
          results.add({
            'uid': uid,
            'username': data['username'],
            'displayName': data['displayName'],
            'photoUrl': data['photoUrl'],
          });
        }
      }
    } catch (e) {
      print('Error searching users: $e');
    }
    
    return results;
  }
  
  /// Create or update username entry in public collection (for existing users)
  Future<void> createUsernameEntry(String username) async {
    if (_userId == null) return;
    
    final profile = await getUserProfile();
    final displayName = profile?['displayName'] ?? 'Runner';
    final photoUrl = profile?['photoUrl'];
    
    await _db.collection('usernames').doc(username.toLowerCase()).set({
      'uid': _userId,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Also update the user's profile with the username
    await _userDoc.update({'username': username});
  }

  // ============ FRIENDS ============

  /// Add a friend (one-way follow - only modifies current user's data)
  Future<void> addFriend(String friendId) async {
    if (friendId == _userId) return;
    
    // Add to current user's friends list only
    await _userDoc.collection('friends').doc(friendId).set({
      'addedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  /// Remove a friend
  Future<void> removeFriend(String friendId) async {
    await _userDoc.collection('friends').doc(friendId).delete();
  }

  /// Get friend IDs
  Future<List<String>> getFriendIds() async {
    final snapshot = await _userDoc.collection('friends').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Get friends with their profile data
  Future<List<Map<String, dynamic>>> getFriends() async {
    final friendIds = await getFriendIds();
    List<Map<String, dynamic>> friends = [];
    
    for (var friendId in friendIds) {
      final profile = await getUserProfileById(friendId);
      if (profile != null) friends.add(profile);
    }
    
    return friends;
  }

  /// Check if user is a friend
  Future<bool> isFriend(String userId) async {
    final doc = await _userDoc.collection('friends').doc(userId).get();
    return doc.exists;
  }

  // ============ ACTIVITY FEED ============

  /// Get recent activities from friends
  Future<List<Map<String, dynamic>>> getFriendActivities({int limit = 20}) async {
    final friendIds = await getFriendIds();
    if (friendIds.isEmpty) return [];
    
    List<Map<String, dynamic>> activities = [];
    
    for (var friendId in friendIds) {
      try {
        final trips = await _db.collection('users').doc(friendId)
            .collection('trips')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
        
        final profile = await getUserProfileById(friendId);
        
        for (var doc in trips.docs) {
          activities.add({
            'tripId': doc.id,
            'userId': friendId,
            'userName': profile?['displayName'] ?? 'Unknown',
            'userPhoto': profile?['photoUrl'],
            ...doc.data(),
          });
        }
      } catch (e) {
        print('Error loading trips for $friendId: $e');
      }
    }
    
    // Sort by date
    activities.sort((a, b) {
      final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return bDate.compareTo(aDate);
    });
    
    return activities.take(limit).toList();
  }

  // ============ LEADERBOARD ============

  /// Get leaderboard (friends + self ranked by distance)
  Future<List<Map<String, dynamic>>> getLeaderboard({String period = 'weekly'}) async {
    final friendIds = await getFriendIds();
    List<Map<String, dynamic>> leaderboard = [];
    
    // Add current user
    final myProfile = await getUserProfile();
    if (myProfile != null) {
      final myDistance = await _getDistanceForPeriod(_userId!, period);
      leaderboard.add({...myProfile, 'periodDistance': myDistance, 'isCurrentUser': true});
    }
    
    // Add friends
    for (var friendId in friendIds) {
      final profile = await getUserProfileById(friendId);
      if (profile != null) {
        final distance = await _getDistanceForPeriod(friendId, period);
        leaderboard.add({...profile, 'periodDistance': distance, 'isCurrentUser': false});
      }
    }
    
    // Sort by distance descending
    leaderboard.sort((a, b) => (b['periodDistance'] as double).compareTo(a['periodDistance'] as double));
    
    // Add ranks
    for (int i = 0; i < leaderboard.length; i++) {
      leaderboard[i]['rank'] = i + 1;
    }
    
    return leaderboard;
  }

  Future<double> _getDistanceForPeriod(String userId, String period) async {
    DateTime startDate;
    if (period == 'weekly') {
      startDate = DateTime.now().subtract(const Duration(days: 7));
    } else {
      startDate = DateTime.now().subtract(const Duration(days: 30));
    }
    
    try {
      final snapshot = await _db.collection('users').doc(userId)
          .collection('trips')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
          .get();
      
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['distance'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      print('Error getting distance for $userId: $e');
      return 0.0;
    }
  }

  // ============ PREFERENCES ============

  /// Get user preferences
  Future<UserPreferences> getPreferences() async {
    try {
      final doc = await _userDoc.collection('settings').doc('preferences').get();
      if (doc.exists) {
        return UserPreferences.fromMap(doc.data()!);
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
    return UserPreferences(); // Return defaults
  }

  /// Save user preferences
  Future<void> savePreferences(UserPreferences prefs) async {
    await _userDoc.collection('settings').doc('preferences').set(prefs.toMap());
  }

  /// Update specific preference fields
  Future<void> updatePreferences(Map<String, dynamic> updates) async {
    await _userDoc.collection('settings').doc('preferences').update(updates);
  }

  // ============ TRIPS ============

  /// Save a completed trip
  Future<String> saveTrip(Trip trip) async {
    final docRef = await _userDoc.collection('trips').add(trip.toFirestore());
    return docRef.id;
  }

  /// Get all trips for current user
  Future<List<Trip>> getTrips({int limit = 20}) async {
    final snapshot = await _userDoc
        .collection('trips')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => Trip.fromFirestore(doc)).toList();
  }

  /// Get a specific trip
  Future<Trip?> getTrip(String tripId) async {
    final doc = await _userDoc.collection('trips').doc(tripId).get();
    if (doc.exists) {
      return Trip.fromFirestore(doc);
    }
    return null;
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    await _userDoc.collection('trips').doc(tripId).delete();
  }

  /// Rate a trip
  Future<void> rateTrip(String tripId, int rating) async {
    await _userDoc.collection('trips').doc(tripId).update({'rating': rating});
  }

  // ============ STATS ============

  /// Get total distance run
  Future<double> getTotalDistance() async {
    final snapshot = await _userDoc.collection('trips').get();
    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['distance'] ?? 0).toDouble();
    }
    return total;
  }

  /// Get trip count
  Future<int> getTripCount() async {
    final snapshot = await _userDoc.collection('trips').count().get();
    return snapshot.count ?? 0;
  }

  // ============ VISITED POIs & RATINGS ============

  /// Mark a POI as visited (increments visit count or creates new record)
  Future<void> markPoiVisited({
    required String poiId,
    required String poiName,
    required String poiCategory,
    required double lat,
    required double lon,
  }) async {
    final docRef = _userDoc.collection('visitedPois').doc(poiId);
    final doc = await docRef.get();
    
    if (doc.exists) {
      // Increment visit count
      await docRef.update({
        'visitCount': FieldValue.increment(1),
        'lastVisited': Timestamp.now(),
      });
    } else {
      // Create new visited POI record
      await docRef.set({
        'poiName': poiName,
        'poiCategory': poiCategory,
        'lat': lat,
        'lon': lon,
        'visitCount': 1,
        'lastVisited': Timestamp.now(),
      });
    }
  }

  /// Get all visited POI IDs for the user
  Future<Set<String>> getVisitedPoiIds() async {
    final snapshot = await _userDoc.collection('visitedPois').get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  /// Rate a POI (1-5 stars)
  Future<void> ratePoi(String poiId, int rating) async {
    if (rating < 1 || rating > 5) return;
    
    final docRef = _userDoc.collection('visitedPois').doc(poiId);
    await docRef.update({
      'rating': rating,
      'ratedAt': Timestamp.now(),
    });
  }

  /// Get user's rating for a POI (null if not rated)
  Future<int?> getPoiRating(String poiId) async {
    final doc = await _userDoc.collection('visitedPois').doc(poiId).get();
    if (doc.exists) {
      return doc.data()?['rating'];
    }
    return null;
  }

  /// Get all visited POIs with their ratings
  Future<List<Map<String, dynamic>>> getVisitedPoisWithRatings() async {
    final snapshot = await _userDoc.collection('visitedPois').get();
    return snapshot.docs.map((doc) => {
      'poiId': doc.id,
      ...doc.data(),
    }).toList();
  }

  // ============ FAVORITE ROUTES ============

  /// Save a route as favorite
  Future<String> saveFavoriteRoute(FavoriteRoute route) async {
    final docRef = await _userDoc.collection('favoriteRoutes').add(route.toFirestore());
    return docRef.id;
  }

  /// Get all favorite routes
  Future<List<FavoriteRoute>> getFavoriteRoutes() async {
    final snapshot = await _userDoc
        .collection('favoriteRoutes')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => FavoriteRoute.fromFirestore(doc)).toList();
  }

  /// Delete a favorite route
  Future<void> deleteFavoriteRoute(String routeId) async {
    await _userDoc.collection('favoriteRoutes').doc(routeId).delete();
  }

  /// Increment times used for a favorite route
  Future<void> incrementRouteUsage(String routeId) async {
    await _userDoc.collection('favoriteRoutes').doc(routeId).update({
      'timesUsed': FieldValue.increment(1),
    });
  }

  // ============ SCHEDULED RUNS ============

  /// Get all scheduled runs
  Future<List<Map<String, dynamic>>> getScheduledRuns() async {
    final snapshot = await _userDoc.collection('scheduled_runs')
        .orderBy('date', descending: false)
        .get();
    
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
      'date': (doc.data()['date'] as Timestamp).toDate(),
    }).toList();
  }

  /// Add a scheduled run
  Future<void> addScheduledRun({
    required DateTime date,
    required double distance,
    String? notes,
  }) async {
    await _userDoc.collection('scheduled_runs').add({
      'date': Timestamp.fromDate(date),
      'distance': distance,
      'notes': notes ?? '',
      'completed': false,
      'createdAt': Timestamp.now(),
    });
  }

  /// Toggle scheduled run completion status
  Future<void> toggleScheduledRunStatus(String runId, bool completed) async {
    await _userDoc.collection('scheduled_runs').doc(runId).update({
      'completed': completed,
    });
  }

  /// Delete a scheduled run
  Future<void> deleteScheduledRun(String runId) async {
    await _userDoc.collection('scheduled_runs').doc(runId).delete();
  }
}
