import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final DatabaseService _dbService = DatabaseService();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Map of date -> list of scheduled runs
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final scheduledRuns = await _dbService.getScheduledRuns();
      final trips = await _dbService.getTrips(limit: 100);
      
      final Map<DateTime, List<Map<String, dynamic>>> newEvents = {};
      
      // 1. Process Scheduled Runs
      for (var run in scheduledRuns) {
        final date = run['date'] as DateTime;
        final key = DateTime(date.year, date.month, date.day);
        
        if (newEvents[key] == null) newEvents[key] = [];
        
        newEvents[key]!.add({
          ...run,
          'type': 'scheduled',
        });
      }

      // 2. Process Completed Trips (Real Runs)
      for (var trip in trips) {
        final date = trip.createdAt;
        final key = DateTime(date.year, date.month, date.day);
        
        if (newEvents[key] == null) newEvents[key] = [];
        
        newEvents[key]!.add({
          'id': trip.id,
          'date': trip.createdAt,
          'distance': (trip.distance / 1000), // Convert to km for consistency
          'notes': '${(trip.duration / 60).toStringAsFixed(0)} min run',
          'completed': true,
          'type': 'trip',
        });
      }
      
      if (mounted) {
        setState(() {
          _events = newEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading schedule: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  Future<void> _addRun() async {
    // ... (Keep existing _addRun implementation) ...
    final distanceController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Run'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: distanceController,
              decoration: const InputDecoration(
                labelText: 'Target Distance (km)',
                suffixText: 'km',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g., Easy run, Tempo...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (distanceController.text.isNotEmpty) {
                final distance = double.tryParse(distanceController.text) ?? 0;
                await _dbService.addScheduledRun(
                  date: _selectedDay ?? DateTime.now(),
                  distance: distance,
                  notes: notesController.text,
                );
                _loadEvents();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRunStatus(String id, bool currentStatus) async {
    await _dbService.toggleScheduledRunStatus(id, !currentStatus);
    _loadEvents();
  }

  Future<void> _deleteRun(String id) async {
    await _dbService.deleteScheduledRun(id);
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Run Schedule', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              markersMaxCount: 1,
              markerDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text(
                  _selectedDay != null 
                      ? DateFormat('EEEE, MMM d').format(_selectedDay!)
                      : 'Select a day',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._getEventsForDay(_selectedDay ?? DateTime.now()).map((run) {
                  final isTrip = run['type'] == 'trip';
                  final isCompleted = run['completed'] ?? false;
                  final distance = run['distance'] is double 
                      ? (run['distance'] as double).toStringAsFixed(2)
                      : run['distance'].toString();

                  // Render logic varies for Trip vs Scheduled
                  Widget cardContent = Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isTrip 
                              ? Colors.purple.withOpacity(0.1) 
                              : (isCompleted ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isTrip ? Icons.emoji_events : Icons.directions_run,
                          color: isTrip 
                              ? Colors.purple 
                              : (isCompleted ? Colors.green : Colors.blue),
                        ),
                      ),
                      title: Text(
                        '$distance km ${isTrip ? 'Completed' : 'Run'}',
                        style: TextStyle(
                          decoration: (!isTrip && isCompleted) ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: run['notes'] != '' ? Text(run['notes']) : null,
                      trailing: isTrip 
                          ? const Icon(Icons.check_circle, color: Colors.purple, size: 20)
                          : Checkbox(
                              value: isCompleted,
                              onChanged: (_) => _toggleRunStatus(run['id'], isCompleted),
                              activeColor: Colors.green,
                            ),
                    ),
                  );

                  // Wrap in Dismissible only if it's a scheduled run
                  if (!isTrip) {
                    return Dismissible(
                      key: Key(run['id']),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deleteRun(run['id']),
                      child: cardContent,
                    );
                  }
                  
                  return cardContent;
                }).toList(),
                if (_getEventsForDay(_selectedDay ?? DateTime.now()).isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: Text(
                        'No runs for this day',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRun,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}
