import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PostScreen extends StatefulWidget {
  final String postId;
  final String postContent;
  final String username;
  final String? media;
  final String? mediaType;

  const PostScreen({
    super.key,
    required this.postId,
    required this.postContent,
    required this.username,
    this.media,
    this.mediaType,
  });

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  bool _isStarred = false;
  int _starCount = 0;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadStarStatus();
    await _loadComments();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadStarStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8082/star/count?postId=${widget.postId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _starCount = data['count'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading stars: $e');
    }
  }

  Future<void> _toggleStar() async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8082/star/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'postId': widget.postId,
          'userId': 'user123',
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isStarred = data['starred'];
          _starCount = data['count'];
        });
      }
    } catch (e) {
      print('Error toggling star: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8082/comment/list?postId=${widget.postId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _comments = List<Map<String, dynamic>>.from(data['comments']);
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8082/comment/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'postId': widget.postId,
          'userId': 'user123',
          'text': _commentController.text,
        }),
      );
      if (response.statusCode == 200) {
        _commentController.clear();
        await _loadComments();
      }
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.purple.shade100,
                        child: Text(
                          widget.username[0],
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.postContent,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (widget.media != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: widget.mediaType == 'video'
                                ? Container(
                                    height: 250,
                                    color: Colors.black,
                                    child: const Center(
                                      child: Icon(
                                        Icons.play_circle_filled,
                                        color: Colors.white,
                                        size: 70,
                                      ),
                                    ),
                                  )
                                : Image.memory(
                                    base64Decode(widget.media!),
                                    width: double.infinity,
                                    height: 250,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isStarred ? Icons.star : Icons.star_border,
                          color: _isStarred ? Colors.amber : Colors.grey,
                          size: 32,
                        ),
                        onPressed: _toggleStar,
                      ),
                      Text(
                        '$_starCount stars',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.shade100,
                            child: Text(
                              (comment['userId'] ?? 'U')[0],
                              style: TextStyle(
                                color: Colors.purple.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            comment['text'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            _formatTime(comment['time'] ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.purple,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _addComment,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${diff.inDays ~/ 7}w ago';
    } catch (e) {
      return timestamp;
    }
  }
}