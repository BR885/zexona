import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'main.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isSaving = false;
  
  String get _userId {
    if (UserManager.userId != null && UserManager.userId!.isNotEmpty) {
      return UserManager.userId!;
    }
    return 'user123';
  }

  Future<void> _searchUsers(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8082/search/users?q=${Uri.encodeComponent(trimmedQuery)}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Search results: ${data['users'].length} found');
        setState(() {
          _results = List<Map<String, dynamic>>.from(data['users']);
          _isLoading = false;
        });
      } else {
        print('❌ Search failed: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error searching users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveContact(String contactId) async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8082/contacts/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'contactUserId': contactId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['alreadySaved'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ℹ️ Already saved this person'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Person saved! They will be notified.'),
              duration: Duration(seconds: 3),
            ),
          );
          await _notifyPerson(contactId);
        }
      }
    } catch (e) {
      print('Error saving person: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving person: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _notifyPerson(String contactId) async {
    try {
      // Get current user's name
      final profileResponse = await http.get(
        Uri.parse('http://localhost:8082/profile?userId=${_userId}'),
      );
      String senderName = 'Someone';
      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        senderName = profileData['name'] ?? 'Someone';
      }
      
      // Get contact's name
      final contactResponse = await http.get(
        Uri.parse('http://localhost:8082/profile?userId=${contactId}'),
      );
      String contactName = 'them';
      if (contactResponse.statusCode == 200) {
        final contactData = jsonDecode(contactResponse.body);
        contactName = contactData['name'] ?? 'them';
      }
      
      // Create chat and send notification
      final chatId = 'chat_${[_userId, contactId]..sort()..join('_')}';
      
      // Start chat first
      await http.post(
        Uri.parse('http://localhost:8082/chat/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'targetUserId': contactId,
        }),
      );
      
      // Send notification message
      await http.post(
        Uri.parse('http://localhost:8082/chat/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatId': chatId,
          'userId': 'system',
          'text': '👋 $senderName has added you as a contact on Zexona! Start chatting now!',
          'fileId': null,
          'fileType': null,
        }),
      );
      
      print('✅ Notification sent to $contactName');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> _startChat(String userId, String username, String name) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8082/chat/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'targetUserId': userId,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: data['chatId'],
              chatName: name ?? username,
              isGroup: false,
            ),
          ),
        );
      } else {
        print('❌ Failed to start chat: ${response.body}');
      }
    } catch (e) {
      print('❌ Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find People',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: _searchUsers,
            ),
          ),
        ),
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
                    'Searching...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _hasSearched && _results.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No people found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'Try a different name',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : !_hasSearched
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Search for people',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Type a name to find people',
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
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final user = _results[index];
                        return _buildUserTile(user);
                      },
                    ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final username = user['username'] ?? '';
    final name = user['name'] ?? username;
    final avatar = user['avatar'] ?? '';
    final bio = user['bio'] ?? '';
    final userId = user['id'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          radius: 24,
          backgroundImage: avatar.isNotEmpty && avatar.startsWith('http')
              ? NetworkImage(avatar) as ImageProvider
              : (avatar.isNotEmpty
                  ? MemoryImage(base64Decode(avatar)) as ImageProvider
                  : null),
          child: avatar.isEmpty
              ? Text(
                  name[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@$username',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            if (bio.isNotEmpty)
              Text(
                bio,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Save Person Button
            Tooltip(
              message: _isSaving ? 'Saving...' : 'Save Person',
              child: IconButton(
                icon: Icon(
                  Icons.person_add,
                  color: _isSaving ? Colors.grey : Colors.green,
                ),
                onPressed: _isSaving ? null : () => _saveContact(userId),
              ),
            ),
            // View Profile Button
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.purple),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: userId,
                      isOwnProfile: false,
                    ),
                  ),
                );
              },
              tooltip: 'View Profile',
            ),
            // Start Chat Button
            IconButton(
              icon: const Icon(Icons.chat, color: Colors.purple),
              onPressed: () => _startChat(userId, username, name),
              tooltip: 'Start Chat',
            ),
          ],
        ),
      ),
    );
  }
}