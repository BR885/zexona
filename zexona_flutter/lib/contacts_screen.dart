import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_screen.dart';
import 'main.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Map<String, dynamic>> _savedPeople = [];
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
    _loadSavedPeople();
  }

  Future<void> _loadSavedPeople() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8082/contacts/list?userId=${_userId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _savedPeople = List<Map<String, dynamic>>.from(data['contacts']);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading saved people: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removePerson(String personId) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8082/contacts/remove'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'contactUserId': personId,
        }),
      );
      if (response.statusCode == 200) {
        await _loadSavedPeople();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Person removed')),
        );
      }
    } catch (e) {
      print('Error removing person: $e');
    }
  }

  void _startChat(String personId, String name) async {
    var chatId = 'chat_${[_userId, personId]..sort()..join('_')}';

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8082/chat/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'targetUserId': personId,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: data['chatId'],
              chatName: name,
              isGroup: false,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error starting chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved People',
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
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
            tooltip: 'Find People',
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
                    'Loading saved people...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _savedPeople.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No saved people yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search for people and save them!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/search');
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Find People'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _savedPeople.length,
                  itemBuilder: (context, index) {
                    final person = _savedPeople[index];
                    return _buildPersonTile(person);
                  },
                ),
    );
  }

  Widget _buildPersonTile(Map<String, dynamic> person) {
    final name = person['name'] ?? 'Unknown';
    final username = person['username'] ?? 'user';
    final avatar = person['avatar'] ?? '';
    final personId = person['id'];

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
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chat, color: Colors.purple),
              onPressed: () => _startChat(personId, name),
              tooltip: 'Chat',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Person'),
                    content: Text('Remove $name from your saved people?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _removePerson(personId);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Remove Person',
            ),
          ],
        ),
        onTap: () => _startChat(personId, name),
      ),
    );
  }
}