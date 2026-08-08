import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'profile_screen.dart';
import 'main.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  Color _chatColor = Colors.purple;
  
  String get _userId {
    if (UserManager.userId != null && UserManager.userId!.isNotEmpty) {
      return UserManager.userId!;
    }
    return 'user123';
  }

  @override
  void initState() {
    super.initState();
    _loadChatColor();
    _loadMessages();
  }

  Future<void> _loadChatColor() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8082/settings?userId=${_userId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final colorHex = data['chatColor'] ?? '#7B2FBE';
        setState(() {
          _chatColor = _hexToColor(colorHex);
        });
      }
    } catch (e) {
      print('Error loading chat color: $e');
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  Future<void> _loadMessages() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8082/chat/messages?chatId=${widget.chatId}&userId=${_userId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Loaded ${data['messages'].length} messages');
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data['messages']);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage({String? text, String? fileId, String? fileType}) async {
    if (text == null && fileId == null) return;

    // Get sender name
    final senderName = UserManager.displayName ?? 'You';
    
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'userId': _userId,
      'text': text ?? '',
      'fileId': fileId,
      'fileType': fileType,
      'time': DateTime.now().toIso8601String(),
      'read': false,
      'senderName': senderName,
      'senderAvatar': '',
      'receiverName': widget.chatName,
      'receiverAvatar': '',
    };

    setState(() {
      _messages.add(tempMessage);
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8082/chat/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatId': widget.chatId,
          'userId': _userId,
          'text': text ?? '',
          'fileId': fileId,
          'fileType': fileType,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.removeWhere((msg) => msg['id'] == tempMessage['id']);
          _messages.add(data['message']);
        });
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<String?> _uploadFile(XFile file, String fileType) async {
    try {
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = file.path.split('/').last;

      final response = await http.post(
        Uri.parse('http://localhost:8082/upload/file'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fileId': fileId,
          'fileData': base64Data,
          'fileType': fileType,
          'fileName': fileName,
        }),
      );
      if (response.statusCode == 200) {
        return fileId;
      }
    } catch (e) {
      print('Error uploading file: $e');
    }
    return null;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image != null) {
      final fileId = await _uploadFile(image, 'image');
      if (fileId != null) {
        await _sendMessage(fileId: fileId, fileType: 'image');
      }
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (video != null) {
      final fileId = await _uploadFile(video, 'video');
      if (fileId != null) {
        await _sendMessage(fileId: fileId, fileType: 'video');
      }
    }
  }

  Future<void> _pickAudio() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Sharing'),
        content: const Text('🎵 Audio sharing coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDocument() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Sharing'),
        content: const Text('📄 Document sharing coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startVoiceCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📞 Voice Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call, size: 60, color: Colors.green),
            const SizedBox(height: 16),
            Text('Calling ${widget.chatName}...'),
            const SizedBox(height: 16),
            Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.call_end, size: 30, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            widget.isGroup
                ? const Icon(Icons.group, size: 20)
                : const Icon(Icons.person, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _chatColor,
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
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: _startVoiceCall,
            tooltip: 'Voice Call',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      final isMe = msg['userId'] == _userId;
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text'] ?? '';
    final fileId = msg['fileId'];
    final fileType = msg['fileType'];
    final time = _formatTime(msg['time']);
    
    // Get sender name from the message
    final senderName = msg['senderName'] ?? (isMe ? 'You' : (msg['userId'] ?? 'User'));
    final senderAvatar = msg['senderAvatar'] ?? '';
    
    // Display name for the sender
    final displayName = isMe ? 'You' : senderName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            _buildAvatar(senderAvatar, displayName, false),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMe ? _chatColor : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _chatColor.withOpacity(0.8),
                      ),
                    ),
                  if (fileId != null) ...[
                    _buildFilePreview(fileId, fileType ?? ''),
                    const SizedBox(height: 4),
                  ],
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            _buildAvatar(senderAvatar, 'You', true),
        ],
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl, String name, bool isMe) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _defaultAvatar(name, isMe);
    }
    
    if (avatarUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: isMe ? _chatColor : Colors.purple.shade100,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (e, s) {
          print('Error loading avatar: $e');
          if (mounted) {
            setState(() {});
          }
        },
        child: null,
      );
    }
    
    try {
      return CircleAvatar(
        radius: 16,
        backgroundColor: isMe ? _chatColor : Colors.purple.shade100,
        backgroundImage: MemoryImage(base64Decode(avatarUrl)),
        onBackgroundImageError: (e, s) {
          print('Error loading avatar: $e');
        },
        child: null,
      );
    } catch (e) {
      return _defaultAvatar(name, isMe);
    }
  }

  Widget _defaultAvatar(String name, bool isMe) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isMe ? _chatColor : Colors.purple.shade100,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: isMe ? Colors.white : Colors.purple.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFilePreview(String fileId, String fileType) {
    if (fileType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          'http://localhost:8082/file?fileId=$fileId',
          height: 150,
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              width: 200,
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
              ),
            );
          },
        ),
      );
    } else if (fileType == 'video') {
      return Container(
        height: 150,
        width: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 150,
              width: 200,
              color: Colors.black,
              child: const Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 50,
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Video',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return const Text('📎 File attached');
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.attach_file, color: Colors.purple, size: 28),
            onSelected: (value) {
              switch (value) {
                case 'image':
                  _pickImage();
                  break;
                case 'video':
                  _pickVideo();
                  break;
                case 'audio':
                  _pickAudio();
                  break;
                case 'document':
                  _pickDocument();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'image',
                child: Row(
                  children: [
                    Icon(Icons.photo, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Photo'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'video',
                child: Row(
                  children: [
                    Icon(Icons.video_collection, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Video'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'audio',
                child: Row(
                  children: [
                    Icon(Icons.audio_file, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Audio'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'document',
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Document'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(text: _messageController.text),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _chatColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () {
                if (_messageController.text.isNotEmpty) {
                  _sendMessage(text: _messageController.text);
                  _messageController.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}