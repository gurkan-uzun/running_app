import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_preferences.dart';
import '../models/trip.dart';

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
  Future<void> initializeUserProfile({String? displayName}) async {
    final doc = await _userDoc.get();
    if (!doc.exists) {
      await _userDoc.set({
        'displayName': displayName ?? _auth.currentUser?.displayName ?? 'Runner',
        'email': _auth.currentUser?.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Initialize default preferences
      await savePreferences(UserPreferences());
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
}
