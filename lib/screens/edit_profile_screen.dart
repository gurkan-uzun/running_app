import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _dbService = DatabaseService();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSaving = false;
  String? _currentUsername;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final profile = await _dbService.getUserProfile();
      
      _displayNameController.text = profile?['displayName'] ?? user?.displayName ?? '';
      _currentUsername = profile?['username'];
      _usernameController.text = _currentUsername ?? '';
    } catch (e) {
      print('Error loading profile: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _validateUsername(String username) async {
    if (username.isEmpty) {
      setState(() => _usernameError = null);
      return;
    }
    
    if (username.length < 3) {
      setState(() => _usernameError = 'Username must be at least 3 characters');
      return;
    }
    
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      setState(() => _usernameError = 'Only lowercase letters, numbers, and underscores');
      return;
    }
    
    // Check availability if different from current
    if (username != _currentUsername) {
      final isAvailable = await _dbService.isUsernameAvailable(username);
      if (!isAvailable) {
        setState(() => _usernameError = 'Username is already taken');
        return;
      }
    }
    
    setState(() => _usernameError = null);
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim().toLowerCase();
    final displayName = _displayNameController.text.trim();
    
    // Validate username
    await _validateUsername(username);
    if (_usernameError != null) return;
    
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      // Update display name
      await _dbService.updateUserProfile({'displayName': displayName});
      
      // Update username if changed or new
      if (username.isNotEmpty && username != _currentUsername) {
        // Delete old username entry if exists
        if (_currentUsername != null && _currentUsername!.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('usernames')
                .doc(_currentUsername!.toLowerCase())
                .delete();
          } catch (e) {
            // Might not exist, ignore
          }
        }
        
        // Create new username entry
        await _dbService.createUsernameEntry(username);
        _currentUsername = username;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photo
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                              ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                              : const NetworkImage("https://i.pravatar.cc/300"),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Display Name
                  const Text(
                    'Display Name',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _displayNameController,
                    decoration: InputDecoration(
                      hintText: 'Your display name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Username
                  const Text(
                    'Username',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This is how friends can find you',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      hintText: 'username',
                      prefixText: '@',
                      prefixStyle: TextStyle(color: Colors.grey[600]),
                      errorText: _usernameError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) => _validateUsername(value.toLowerCase()),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Username rules
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Username tips',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[700]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• At least 3 characters\n• Only lowercase letters, numbers, underscores\n• Must be unique',
                          style: TextStyle(color: Colors.blue[700], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
