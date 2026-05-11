import 'package:flutter/material.dart';
import '../models/generated_route.dart';

/// Widget to display and select from multiple route options
class RouteSelector extends StatelessWidget {
  final List<GeneratedRoute> routes;
  final GeneratedRoute? selectedRoute;
  final Function(GeneratedRoute) onRouteSelected;
  final VoidCallback onGenerateMore;
  final VoidCallback onStartRun;
  final Function(GeneratedRoute)? onSaveFavorite;
  
  const RouteSelector({
    super.key,
    required this.routes,
    required this.selectedRoute,
    required this.onRouteSelected,
    required this.onGenerateMore,
    required this.onStartRun,
    this.onSaveFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          const Text(
            'Choose Your Route',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Route cards
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                final isSelected = selectedRoute?.id == route.id;
                return _RouteCard(
                  route: route,
                  isSelected: isSelected,
                  onTap: () => onRouteSelected(route),
                  onSaveFavorite: onSaveFavorite != null 
                      ? () => onSaveFavorite!(route) 
                      : null,
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              // Generate More button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGenerateMore,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Start Run button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: selectedRoute != null ? onStartRun : null,
                  icon: const Icon(Icons.directions_run),
                  label: const Text('Start Run'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final GeneratedRoute route;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onSaveFavorite;
  
  const _RouteCard({
    required this.route,
    required this.isSelected,
    required this.onTap,
    this.onSaveFavorite,
  });

  Color _getRouteColor() {
    switch (route.id) {
      case 'A': return Colors.blue;
      case 'B': return Colors.green;
      case 'C': return Colors.orange;
      default: return Colors.purple;
    }
  }
  
  /// Estimate calories burned based on distance
  /// Average running burns ~60 calories per km (varies by weight)
  int get estimatedCalories => (route.distanceKm * 60).round();

  @override
  Widget build(BuildContext context) {
    final color = _getRouteColor();
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with badge and save button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Route ${route.id}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onSaveFavorite != null)
                  GestureDetector(
                    onTap: onSaveFavorite,
                    child: Icon(Icons.favorite_border, size: 20, color: Colors.grey[500]),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            
            // Route type name
            Text(
              route.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
            
            // Stats row 1: Distance & Time
            Wrap(
              spacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.straighten, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 2),
                    Text(
                      '${route.distanceKm.toStringAsFixed(1)}km',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 2),
                    Text(
                      '${route.estimatedTimeMinutes}m',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 3),
            
            // Stats row 2: POIs & Calories
            Wrap(
              spacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 2),
                    Text(
                      '${route.pois.length}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, size: 12, color: Colors.orange[400]),
                    const SizedBox(width: 2),
                    Text(
                      '$estimatedCalories',
                      style: TextStyle(fontSize: 11, color: Colors.orange[600]),
                    ),
                  ],
                ),
              ],
            ),
            
            const Spacer(),
            
            // Category breakdown
            Text(
              route.categoryString,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
