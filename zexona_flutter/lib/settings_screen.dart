import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _displayName = 'Loading...';
  String _lastSeen = 'Everyone';
  String _brightness = 'Light';
  Color _chatColor = Colors.purple;
  String _chatColorName = 'Purple';
  List<String> _blockedUsers = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _blockController = TextEditingController();
  final TextEditingController _reportController = TextEditingController();

  String get _userId {
    if (UserManager.userId != null && UserManager.userId!.isNotEmpty) {
      return UserManager.userId!;
    }
    return 'user123';
  }

  final List<Map<String, dynamic>> _colorOptions = [
    {'color': Colors.purple, 'name': 'Purple'},
    {'color': Colors.blue, 'name': 'Blue'},
    {'color': Colors.green, 'name': 'Green'},
    {'color': Colors.orange, 'name': 'Orange'},
    {'color': Colors.red, 'name': 'Red'},
    {'color': Colors.pink, 'name': 'Pink'},
    {'color': Colors.teal, 'name': 'Teal'},
    {'color': Colors.indigo, 'name': 'Indigo'},
    {'color': Colors.deepPurple, 'name': 'Deep Purple'},
    {'color': Colors.amber, 'name': 'Amber'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8082/settings?userId=${_userId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _displayName = data['name'] ?? 'User';
          _lastSeen = data['lastSeen'] ?? 'Everyone';
          _brightness = data['brightness'] ?? 'Light';
          final colorHex = data['chatColor'] ?? '#7B2FBE';
          _chatColor = _hexToColor(colorHex);
          _chatColorName = _getColorName(_chatColor);
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  String _getColorName(Color color) {
    for (var option in _colorOptions) {
      if (option['color'] == color) {
        return option['name'];
      }
    }
    return 'Custom';
  }

  Future<void> _saveSettingsToServer() async {
    try {
      await http.post(
        Uri.parse('http://localhost:8082/settings/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'name': _displayName,
          'lastSeen': _lastSeen,
          'brightness': _brightness,
          'chatColor': '#${_chatColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        }),
      );
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  void _updateName() {
    _nameController.text = _displayName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Display Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'New Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                setState(() {
                  _displayName = _nameController.text;
                });
                _saveSettingsToServer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Name updated!')),
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _updateLastSeen() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hide Last Seen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: const Text('👥 Everyone'),
              value: 'Everyone',
              groupValue: _lastSeen,
              onChanged: (value) {
                setState(() {
                  _lastSeen = value.toString();
                });
                _saveSettingsToServer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Last seen updated!')),
                );
              },
              activeColor: Colors.purple,
            ),
            RadioListTile(
              title: const Text('📇 Contacts Only'),
              value: 'Contacts Only',
              groupValue: _lastSeen,
              onChanged: (value) {
                setState(() {
                  _lastSeen = value.toString();
                });
                _saveSettingsToServer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Last seen updated!')),
                );
              },
              activeColor: Colors.purple,
            ),
            RadioListTile(
              title: const Text('🔒 Nobody'),
              value: 'Nobody',
              groupValue: _lastSeen,
              onChanged: (value) {
                setState(() {
                  _lastSeen = value.toString();
                });
                _saveSettingsToServer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Last seen updated!')),
                );
              },
              activeColor: Colors.purple,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _blockUser() {
    _blockController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the phone number of the user you want to block:'),
            const SizedBox(height: 12),
            TextField(
              controller: _blockController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.block),
              ),
              keyboardType: TextInputType.phone,
            ),
            if (_blockedUsers.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                'Blocked Users:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._blockedUsers.map((user) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.block, color: Colors.red, size: 20),
                  title: Text(user),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _blockedUsers.remove(user);
                      });
                      _saveSettingsToServer();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🔓 User unblocked!')),
                      );
                    },
                  ),
                ),
              )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              if (_blockController.text.isNotEmpty) {
                setState(() {
                  _blockedUsers.add(_blockController.text);
                  _blockController.clear();
                });
                _saveSettingsToServer();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔒 User blocked!')),
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _updateBrightness() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brightness'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: const Text('☀️ Light'),
              value: 'Light',
              groupValue: _brightness,
              onChanged: (value) {
                setState(() {
                  _brightness = value.toString();
                });
                _saveSettingsToServer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Brightness updated!')),
                );
              },
              activeColor: Colors.purple,
            ),
            RadioListTile(
              title: const Text('🌙 Dark'),
              value: 'Dark',
              groupValue: _brightness,
              onChanged: (value) {
                setState(() {
                  _brightness = value.toString();
                });
                _saveSettingsToServer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Brightness updated!')),
                );
              },
              activeColor: Colors.purple,
            ),
            RadioListTile(
              title: const Text('📱 System Default'),
              value: 'System',
              groupValue: _brightness,
              onChanged: (value) {
                setState(() {
                  _brightness = value.toString();
                });
                _saveSettingsToServer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Brightness updated!')),
                );
              },
              activeColor: Colors.purple,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _updateChatColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Chat Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colorOptions.map((option) {
            final color = option['color'] as Color;
            final name = option['name'] as String;
            final isSelected = _chatColor == color;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _chatColor = color;
                  _chatColorName = name;
                });
                _saveSettingsToServer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('🎨 Chat color set to $name!')),
                );
              },
              child: Column(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.black : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _reportProblem() {
    _reportController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report a Problem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Describe the problem you are experiencing:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reportController,
              decoration: const InputDecoration(
                labelText: 'Describe the issue',
                hintText: 'e.g., App crashes when I send a photo...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.report_problem_outlined),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'We will review your report and get back to you within 24 hours.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_reportController.text.isNotEmpty) {
                print('📝 Report: ${_reportController.text}');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📝 Report sent! We\'ll look into it.'),
                    duration: Duration(seconds: 3),
                  ),
                );
                _reportController.clear();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please describe the problem.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await UserManager.clear();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Profile Settings'),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'Display Name',
            subtitle: _displayName,
            onTap: _updateName,
          ),

          _buildSectionHeader('Privacy'),
          _buildSettingsTile(
            icon: Icons.visibility_off,
            title: 'Hide Last Seen',
            subtitle: _lastSeen,
            onTap: _updateLastSeen,
          ),
          _buildSettingsTile(
            icon: Icons.block,
            title: 'Block User',
            subtitle: 'Block someone from contacting you',
            onTap: _blockUser,
          ),

          _buildSectionHeader('Appearance'),
          _buildSettingsTile(
            icon: Icons.brightness_6,
            title: 'Brightness',
            subtitle: _brightness,
            onTap: _updateBrightness,
          ),
          _buildSettingsTile(
            icon: Icons.color_lens,
            title: 'Chat Color',
            subtitle: _chatColorName,
            trailing: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _chatColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            onTap: _updateChatColor,
          ),

          _buildSectionHeader('Support'),
          _buildSettingsTile(
            icon: Icons.report_problem,
            title: 'Report a Problem',
            subtitle: 'Let us know about any issues',
            onTap: _reportProblem,
          ),

          const Divider(),
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            iconColor: Colors.red,
            onTap: _logout,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Colors.purple.shade700,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}