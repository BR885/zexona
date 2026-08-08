import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'main.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const ProfileScreen({
    super.key,
    this.userId = '',
    this.isOwnProfile = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  String? _avatarUrl;
  String? _avatarBase64;
  final TextEditingController _nameController = TextEditingController(text: 'Loading...');
  final TextEditingController _bioController = TextEditingController(text: 'Hey there! I\'m using Zexona');
  final ImagePicker _picker = ImagePicker();
  bool _avatarError = false;

  String get _userId {
    // First priority: passed userId
    if (widget.userId.isNotEmpty) {
      print('🆔 Using widget userId: ${widget.userId}');
      return widget.userId;
    }
    // Second priority: UserManager
    if (UserManager.userId != null && UserManager.userId!.isNotEmpty) {
      print('🆔 Using UserManager userId: ${UserManager.userId}');
      return UserManager.userId!;
    }
    // Fallback
    print('⚠️ No user ID found, using default');
    return 'user123';
  }

  @override
  void initState() {
    super.initState();
    print('🆔 Profile screen initialized with user ID: $_userId');
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    print('🆔 Loading profile for user: $_userId');
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8082/profile?userId=${_userId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Profile data received: ${data['name']}');
        setState(() {
          _nameController.text = data['name'] ?? UserManager.displayName ?? 'User';
          _bioController.text = data['bio'] ?? 'Hey there! I\'m using Zexona';
          final avatar = data['avatar'] ?? '';
          _avatarError = false;
          if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
            _avatarUrl = avatar;
            _avatarBase64 = null;
          } else if (avatar.isNotEmpty) {
            _avatarBase64 = avatar;
            _avatarUrl = null;
          } else {
            _avatarUrl = null;
            _avatarBase64 = null;
          }
        });
      } else {
        print('❌ Failed to load profile: ${response.statusCode}');
        // Fallback to UserManager name
        setState(() {
          _nameController.text = UserManager.displayName ?? 'User';
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _nameController.text = UserManager.displayName ?? 'User';
      });
    }
  }

  Future<void> _updateProfile() async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8082/profile/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'name': _nameController.text,
          'bio': _bioController.text,
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile updated!')),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
    }
  }

  Future<void> _uploadAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);

        final response = await http.post(
          Uri.parse('http://localhost:8082/profile/avatar'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': _userId,
            'avatar': base64Image,
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _avatarBase64 = data['avatar'];
            _avatarUrl = null;
            _avatarError = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📸 Avatar updated!')),
          );
        }
      }
    } catch (e) {
      print('Error uploading avatar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isOwnProfile ? 'My Profile' : 'Profile',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.isOwnProfile)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.save : Icons.edit,
                color: Colors.white,
              ),
              onPressed: () {
                if (_isEditing) {
                  _updateProfile();
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture
            GestureDetector(
              onTap: widget.isOwnProfile ? _uploadAvatar : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.purple.shade100,
                    child: _getAvatarContent(),
                  ),
                  if (widget.isOwnProfile)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.purple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name
            if (_isEditing)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  prefixIcon: Icon(Icons.person),
                ),
              )
            else
              Text(
                _nameController.text,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),

            // Bio
            if (_isEditing)
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell us about yourself...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 3,
              )
            else
              Text(
                _bioController.text,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            const SizedBox(height: 24),

            // Action Buttons
            if (!widget.isOwnProfile)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chat),
                  label: const Text('Send Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isEditing = !_isEditing;
                        });
                      },
                      icon: Icon(_isEditing ? Icons.close : Icons.edit),
                      label: Text(_isEditing ? 'Cancel' : 'Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_isEditing)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _updateProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),

            if (widget.isOwnProfile)
              Text(
                'Tap profile picture to change',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getAvatarContent() {
    if (_avatarError) {
      return _getDefaultAvatar();
    }

    if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(_avatarBase64!),
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              _avatarError = true;
              return _getDefaultAvatar();
            },
          ),
        );
      } catch (e) {
        return _getDefaultAvatar();
      }
    }

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _avatarUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            _avatarError = true;
            return _getDefaultAvatar();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _getDefaultAvatar();
          },
        ),
      );
    }

    return _getDefaultAvatar();
  }

  Widget _getDefaultAvatar() {
    return Text(
      _nameController.text.isNotEmpty
          ? _nameController.text[0].toUpperCase()
          : '?',
      style: TextStyle(
        fontSize: 40,
        color: Colors.purple.shade700,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}