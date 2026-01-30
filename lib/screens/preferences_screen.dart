import 'package:flutter/material.dart';
import '../models/user_preferences.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  UserPreferences _preferences = UserPreferences();
  
  // Track selected categories
  Set<PoiCategory> _selectedCategories = {};
  Set<PoiCategory> _avoidCategories = {};
  double _targetDistance = 5.0;
  String _routeType = 'shortest';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _dbService.getPreferences();
      setState(() {
        _preferences = prefs;
        _selectedCategories = Set.from(prefs.preferredCategories);
        _avoidCategories = Set.from(prefs.avoidCategories);
        _targetDistance = prefs.targetDistance;
        _routeType = prefs.routeType;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    
    final newPrefs = UserPreferences(
      targetDistance: _targetDistance,
      routeType: _routeType,
      preferredCategories: _selectedCategories.toList(),
      avoidCategories: _avoidCategories.toList(),
    );
    
    try {
      await _dbService.savePreferences(newPrefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Route Preferences",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePreferences,
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target Distance
                  _buildSectionTitle("Target Distance"),
                  const SizedBox(height: 8),
                  _buildDistanceSlider(),
                  
                  const SizedBox(height: 24),
                  
                  // Route Type
                  _buildSectionTitle("Route Type"),
                  const SizedBox(height: 8),
                  _buildRouteTypeSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // Preferred POI Categories
                  _buildSectionTitle("Places I'd Like To Visit"),
                  const SizedBox(height: 4),
                  Text(
                    "Select POI categories to prioritize in your routes",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryChips(_selectedCategories, Colors.green, onToggle: (cat) {
                    setState(() {
                      if (_selectedCategories.contains(cat)) {
                        _selectedCategories.remove(cat);
                      } else {
                        _selectedCategories.add(cat);
                        _avoidCategories.remove(cat); // Can't be in both
                      }
                    });
                  }),
                  
                  const SizedBox(height: 24),
                  
                  // Avoid Categories
                  _buildSectionTitle("Places To Avoid"),
                  const SizedBox(height: 4),
                  Text(
                    "These places won't be suggested",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryChips(_avoidCategories, Colors.red, onToggle: (cat) {
                    setState(() {
                      if (_avoidCategories.contains(cat)) {
                        _avoidCategories.remove(cat);
                      } else {
                        _avoidCategories.add(cat);
                        _selectedCategories.remove(cat); // Can't be in both
                      }
                    });
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDistanceSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${_targetDistance.toStringAsFixed(1)} km", 
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text("Target", style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          Slider(
            value: _targetDistance,
            min: 1.0,
            max: 20.0,
            divisions: 38,
            activeColor: Colors.black,
            onChanged: (value) {
              setState(() => _targetDistance = value);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("1 km", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              Text("20 km", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildRouteOption('shortest', 'Shortest', Icons.straighten, 'Fastest route by distance'),
          _buildRouteOption('scenic', 'Scenic', Icons.park, 'Prefer parks and nature areas'),
          _buildRouteOption('footpath-first', 'Footpath First', Icons.directions_walk, 'Prioritize pedestrian paths'),
        ],
      ),
    );
  }

  Widget _buildRouteOption(String value, String title, IconData icon, String subtitle) {
    final isSelected = _routeType == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.black : Colors.grey),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
      onTap: () => setState(() => _routeType = value),
    );
  }

  Widget _buildCategoryChips(Set<PoiCategory> selected, Color color, {required void Function(PoiCategory) onToggle}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PoiCategory.values.map((cat) {
        final isSelected = selected.contains(cat);
        return FilterChip(
          selected: isSelected,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cat.icon),
              const SizedBox(width: 4),
              Text(cat.displayName),
            ],
          ),
          selectedColor: color.withOpacity(0.2),
          checkmarkColor: color,
          onSelected: (_) => onToggle(cat),
        );
      }).toList(),
    );
  }
}
