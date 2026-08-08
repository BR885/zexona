import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'main.dart';
import 'search_users_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  
  String get _userId {
    if (UserManager.userId != null && UserManager.userId!.isNotEmpty) {
      return UserManager.userId!;
    }
    return 'user123';
  }

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8082/chat/list?userId=${_userId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _chats = List<Map<String, dynamic>>.from(data['chats']);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading chats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchUsersScreen(),
                ),
              );
            },
            tooltip: 'Find Users',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.purple,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading chats...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _chats.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No chats yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'Search for users to start chatting!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return _buildChatTile(chat);
                  },
                ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final isGroup = chat['isGroup'] ?? false;
    final name = chat['name'] ?? 'Unknown';
    final lastMessage = chat['lastMessage'] ?? 'No messages';
    final time = chat['time'] ?? DateTime.now().toIso8601String();
    final avatar = chat['avatar'] ?? '';
    final chatId = chat['id'];

    // Determine avatar widget
    Widget avatarWidget;
    
    if (avatar.isNotEmpty && avatar.startsWith('http')) {
      // Network image
      avatarWidget = CircleAvatar(
        backgroundColor: isGroup ? Colors.orange.shade100 : Colors.purple.shade100,
        backgroundImage: NetworkImage(avatar),
        child: null,
        onBackgroundImageError: (e, s) {
          print('Error loading avatar: $e');
        },
      );
    } else if (avatar.isNotEmpty) {
      // Base64 image
      try {
        avatarWidget = CircleAvatar(
          backgroundColor: isGroup ? Colors.orange.shade100 : Colors.purple.shade100,
          backgroundImage: MemoryImage(base64Decode(avatar)),
          child: null,
          onBackgroundImageError: (e, s) {
            print('Error loading avatar: $e');
          },
        );
      } catch (e) {
        // If base64 decode fails, show default
        avatarWidget = CircleAvatar(
          backgroundColor: isGroup ? Colors.orange.shade100 : Colors.purple.shade100,
          child: Icon(
            isGroup ? Icons.group : Icons.person,
            color: isGroup ? Colors.orange : Colors.purple,
          ),
        );
      }
    } else {
      // Default avatar
      avatarWidget = CircleAvatar(
        backgroundColor: isGroup ? Colors.orange.shade100 : Colors.purple.shade100,
        child: Icon(
          isGroup ? Icons.group : Icons.person,
          color: isGroup ? Colors.orange : Colors.purple,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: avatarWidget,
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatTime(time),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                chatName: name,
                isGroup: isGroup,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      if (diff.inDays < 30) return '${diff.inDays ~/ 7}w';
      if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo';
      return '${diff.inDays ~/ 365}y';
    } catch (e) {
      return timestamp;
    }
  }
}