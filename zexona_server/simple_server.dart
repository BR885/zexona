import 'dart:io';
import 'dart:convert';
import 'package:postgres/postgres.dart';

// ============ DATABASE CONNECTION ============
late Connection db;

// ============ MEMORY CACHE ============
Map<String, List<Map<String, dynamic>>> messages = {};
Map<String, List<String>> groupMembers = {};
Map<String, String> groupNames = {};
Map<String, List<String>> userChats = {};
Map<String, String> registeredUsers = {};
Map<String, String> userNames = {};
Map<String, String> nameToUserId = {};
Map<String, List<Map<String, String>>> userContacts = {};
Map<String, Map<String, String>> fileStorage = {};
Map<String, Map<String, dynamic>> userProfiles = {};
Map<String, Map<String, dynamic>> userSettings = {};
Map<String, String> googleUsers = {};
String? currentUserId;

// ============ MAIN ============
void main() async {
  try {
    db = await Connection.open(
      Endpoint(
        host: 'localhost',
        port: 5432,
        database: 'zexona',
        username: 'postgres',
        password: 'postgres',
      ),
      settings: ConnectionSettings(
        sslMode: SslMode.disable,
      ),
    );
    print('✅ Connected to PostgreSQL');

    await _createTables();
    await _loadDataFromDatabase();

    var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8082);
    print('🚀 Zexona server running on http://localhost:8082');
    print('📡 Waiting for requests...');

    await for (HttpRequest request in server) {
      if (request.method == 'OPTIONS') {
        request.response
          ..statusCode = 200
          ..headers.add('Access-Control-Allow-Origin', '*')
          ..headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
          ..headers.add('Access-Control-Allow-Headers', 'Content-Type')
          ..close();
        continue;
      }

      print('📨 ${request.method} ${request.uri.path}');

      try {
        // ============ AUTH ENDPOINTS ============
        if (request.method == 'POST' && request.uri.path == '/auth/google') {
          var body = await utf8.decoder.bind(request).join();
          var data = jsonDecode(body);
          var email = data['email'];
          var name = data['name'] ?? email;
          var avatarUrl = data['avatar'] ?? '';

          if (!googleUsers.containsKey(email)) {
            var userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
            googleUsers[email] = userId;
            registeredUsers[email] = userId;
            userContacts[userId] = <Map<String, String>>[];

            var username = _generateUsername(email);
            userNames[userId] = username;
            nameToUserId[username] = userId;

            // Store the Google name
            userProfiles[userId] = {
              'name': name,
              'bio': 'Hey there! I\'m using Zexona',
              'avatar': avatarUrl,
            };

            userSettings[userId] = {
              'lastSeen': 'everyone',
              'chatColor': '#7B2FBE',
              'brightness': 'light',
              'phone': '',
              'blockedUsers': [],
            };

            await db.execute(
              'INSERT INTO users (id, email, username) VALUES (\$1, \$2, \$3)',
              parameters: [userId, email, username]
            );
            await db.execute(
              'INSERT INTO profiles (user_id, name, bio, avatar) VALUES (\$1, \$2, \$3, \$4)',
              parameters: [userId, name, 'Hey there! I\'m using Zexona', avatarUrl]
            );
            await db.execute(
              'INSERT INTO settings (user_id, last_seen, chat_color, brightness, phone, blocked_users) '
              'VALUES (\$1, \$2, \$3, \$4, \$5, \$6)',
              parameters: [
                userId,
                'everyone',
                '#7B2FBE',
                'light',
                '',
                '[]',
              ]
            );

            print('✅ New Google user registered: $email -> $userId (Name: $name)');
          }

          var userId = googleUsers[email];
          var username = userNames[userId] ?? email;
          
          currentUserId = userId;
          print('✅ Current user ID set to: $currentUserId');
          print('✅ User name: ${userProfiles[userId]?['name']}');

          _sendJson(request.response, {
            'success': true,
            'userId': userId,
            'username': username,
            'message': 'Google login successful',
          });
        }

        // ============ DEBUG USERS ENDPOINT ============
        else if (request.method == 'GET' && request.uri.path == '/debug/users') {
          var userList = [];
          for (var entry in userProfiles.entries) {
            userList.add({
              'userId': entry.key,
              'name': entry.value['name'],
              'avatar': entry.value['avatar'],
              'username': userNames[entry.key] ?? entry.key,
            });
          }
          _sendJson(request.response, {'users': userList});
        }

        // ============ SEARCH USERS ============
        else if (request.method == 'GET' && request.uri.path == '/search/users') {
          var query = request.uri.queryParameters['q']?.toLowerCase().trim() ?? '';
          var results = [];
          var currentUsername = currentUserId != null ? userNames[currentUserId] : '';
          
          if (query.isEmpty) {
            _sendJson(request.response, {'users': results});
            continue;
          }
          
          for (var entry in nameToUserId.entries) {
            var username = entry.key.toLowerCase();
            if (username == currentUsername) continue;
            
            if (username.contains(query)) {
              var userId = entry.value;
              var profile = userProfiles[userId] ?? {};
              results.add({
                'id': userId,
                'username': entry.key,
                'name': profile['name'] ?? entry.key,  // ← Real Google name
                'avatar': profile['avatar'] ?? '',
                'bio': profile['bio'] ?? '',
              });
            }
          }
          
          _sendJson(request.response, {'users': results});
        }

        // ============ SAVE CONTACT ============
        else if (request.method == 'POST' && request.uri.path == '/contacts/save') {
          var body = await utf8.decoder.bind(request).join();
          var data = jsonDecode(body);
          var userId = data['userId'];
          var contactUserId = data['contactUserId'];
          
          userContacts.putIfAbsent(userId, () => <Map<String, String>>[]);
          
          bool alreadySaved = false;
          for (var contact in userContacts[userId]!) {
            if (contact['id'] == contactUserId) {
              alreadySaved = true;
              break;
            }
          }
          
          if (!alreadySaved) {
            userContacts[userId]!.add({
              'id': contactUserId,
            });
            print('✅ User $userId saved contact $contactUserId');
          }
          
          _sendJson(request.response, {
            'success': true,
            'alreadySaved': alreadySaved,
            'message': alreadySaved ? 'Already saved' : 'Contact saved',
          });
        }

        // ============ GET SAVED CONTACTS ============
        else if (request.method == 'GET' && request.uri.path == '/contacts/list') {
          var userId = request.uri.queryParameters['userId'] ?? currentUserId ?? 'user123';
          var contacts = userContacts[userId] ?? [];
          var contactList = [];
          
          for (var contact in contacts) {
            var contactId = contact['id'] ?? '';
            var profile = userProfiles[contactId] ?? {};
            var username = userNames[contactId] ?? contactId;
            contactList.add({
              'id': contactId,
              'name': profile['name'] ?? username,  // ← Real Google name
              'avatar': profile['avatar'] ?? '',
              'username': username,
            });
          }
          
          _sendJson(request.response, {'contacts': contactList});
        }

        // ============ REMOVE CONTACT ============
        else if (request.method == 'POST' && request.uri.path == '/contacts/remove') {
          var body = await utf8.decoder.bind(request).join();
          var data = jsonDecode(body);
          var userId = data['userId'];
          var contactUserId = data['contactUserId'];
          
          if (userContacts.containsKey(userId)) {
            userContacts[userId]!.removeWhere((contact) => contact['id'] == contactUserId);
            print('✅ Removed contact $contactUserId for user $userId');
          }
          
          _sendJson(request.response, {
            'success': true,
            'message': 'Contact removed',
          });
        }

        // ============ START CHAT ============
        else if (request.method == 'POST' && request.uri.path == '/chat/start') {
          var body = await utf8.decoder.bind(request).join();
          var data = jsonDecode(body);
          var userId = data['userId'];
          var targetUserId = data['targetUserId'];

          var chatId = 'chat_${[userId, targetUserId]..sort()..join('_')}';

          if (userId != null) {
            userChats.putIfAbsent(userId, () => <String>[]);
            if (!userChats[userId]!.contains(chatId)) {
              userChats[userId]!.add(chatId);
              print('✅ Added chat $chatId to user $userId');
            }
          }
          
          if (targetUserId != null) {
            userChats.putIfAbsent(targetUserId, () => <String>[]);
            if (!userChats[targetUserId]!.contains(chatId)) {
              userChats[targetUserId]!.add(chatId);
              print('✅ Added chat $chatId to user $targetUserId');
            }
          }

          _sendJson(request.response, {
            'success': true,
            'chatId': chatId,
            'message': 'Chat started',
          });
        }

        // ============ PROFILE ENDPOINTS ============
        else if (request.method == 'GET' && request.uri.path == '/profile') {
          var userId = request.uri.queryParameters['userId'] ?? currentUserId ?? 'user123';
          var profile = userProfiles[userId] ?? {};
          var username = userNames[userId] ?? userId;
          _sendJson(request.response, {
            'userId': userId,
            'name': profile['name'] ?? userId,
            'username': username,
            'bio': profile['bio'] ?? 'Hey there! I\'m using Zexona',
            'avatar': profile['avatar'] ?? '',
          });
        }

        else if (request.method == 'POST' && request.uri.path == '/profile/update') {
          var body = await utf8.decoder.bind(request).join();
          var data = jsonDecode(body);
          var userId = data['userId'];
          var name = data['name'] ?? '';
          var bio = data['bio'] ?? '';
          var avatar = data['avatar'] ?? '';

          userProfiles.putIfAbsent(userId, () => {});
          if (name.isNotEmpty) userProfiles[userId]!['name'] = name;
          if (bio.isNotEmpty) userProfiles[userId]!['bio'] = bio;
          if (avatar.isNotEmpty) userProfiles[userId]!['avatar'] = avatar;

          await db.execute(
            'INSERT INTO profiles (user_id, name, bio, avatar) VALUES (\$1, \$2, \$3, \$4) '
            'ON CONFLICT (user_id) DO UPDATE SET name = \$2, bio = \$3, avatar = \$4',
            parameters: [userId, name, bio, avatar]
          );

          _sendJson(request.response, {
            'success': true,
            'message': 'Profile updated',
            'profile': userProfiles[userId],
          });
        }

        else if (request.method == 'POST' && request.uri.path == '/profile/avatar') {
          var body = await utf8.decoder.bind(request).join();
          var data = jsonDecode(body);
          var userId = data['userId'];
          var avatarData = data['avatar'];

          userProfiles.putIfAbsent(userId, () => {});
          userProfiles[userId]!['avatar'] = avatarData;

          await db.execute(
            'INSERT INTO profiles (user_id, avatar) VALUES (\$1, \$2) '
            'ON CONFLICT (user_id) DO UPDATE SET avatar = \$2',
            parameters: [userId, avatarData]
          );

          _sendJson(request.response, {
            'success': true,
            'message': 'Avatar updated',
            'avatar': avatarData,
          });
        }

        // ============ SETTINGS ENDPOINTS ============
        else if (request.method == 'GET' && request.uri.path == '/settings') {
          var userId = request.uri.queryParameters['userId'] ?? currentUserId ?? 'user123';
          var settings = userSettings[userId] ?? {};
          _sendJson(request.response, {
            'lastSeen': settings['lastSeen'] ?? 'everyone',
            'blockedUsers': settings['blockedUsers'] ?? [],
            'phone': settings['phone'] ?? '',
            'chatColor': settings['chatColor'] ?? '#7B2FBE',
            'brightness': settings['brightness'] ?? 'light',
          });
        }

        else if (request.method == 'POST' && request.uri.path == '/settings/update') {
          var body = await utf8.decoder.bind(request).join();
          var data = jsonDecode(body);
          var userId = data['userId'];

          userSettings.putIfAbsent(userId, () => {});

          if (data.containsKey('lastSeen')) {
            userSettings[userId]!['lastSeen'] = data['lastSeen'];
          }
          if (data.containsKey('chatColor')) {
            userSettings[userId]!['chatColor'] = data['chatColor'];
          }
          if (data.containsKey('brightness')) {
            userSettings[userId]!['brightness'] = data['brightness'];
          }
          if (data.containsKey('phone')) {
            userSettings[userId]!['phone'] = data['phone'];
          }

          await db.execute(
            'INSERT INTO settings (user_id, last_seen, chat_color, brightness, phone) '
            'VALUES (\$1, \$2, \$3, \$4, \$5) '
            'ON CONFLICT (user_id) DO UPDATE SET '
            'last_seen = \$2, chat_color = \$3, brightness = \$4, phone = \$5',
            parameters: [
              userId,
              userSettings[userId]!['lastSeen'] ?? 'everyone',
              userSettings[userId]!['chatColor'] ?? '#7B2FBE',
              userSettings[userId]!['brightness'] ?? 'light',
              userSettings[userId]!['phone'] ?? '',
            ]
          );

          _sendJson(request.response, {
            'success': true,
            'message': 'Settings updated',
            'settings': userSettings[userId],
          });
        }

        // ============ CHAT ENDPOINTS ============
        else if (request.method == 'GET' && request.uri.path == '/chat/list') {
          var userId = request.uri.queryParameters['userId'] ?? currentUserId ?? 'user123';
          print('📋 Getting chats for user: $userId');
          var chatIds = userChats[userId] ?? [];
          print('📋 Found ${chatIds.length} chat IDs');
          var chatList = [];
          
          for (var chatId in chatIds) {
            var msgs = messages[chatId] ?? [];
            var lastMsg = msgs.isNotEmpty ? msgs.last : null;
            var isGroup = chatId.startsWith('group_');
            var name = '';
            var avatar = '';
            
            if (isGroup) {
              name = groupNames[chatId] ?? 'Group';
            } else {
              var parts = chatId.replaceAll('chat_', '').split('_');
              var otherUserId = parts.firstWhere((id) => id != userId, orElse: () => '');
              
              if (otherUserId.isNotEmpty) {
                var profile = userProfiles[otherUserId] ?? {};
                var username = userNames[otherUserId] ?? otherUserId;
                name = profile['name'] ?? username;  // ← Real Google name
                avatar = profile['avatar'] ?? '';
              } else {
                name = 'Unknown User';
              }
            }
            
            var senderName = 'You';
            var lastMessageText = 'No messages';
            var time = DateTime.now().toIso8601String();
            
            if (lastMsg != null) {
              var senderId = lastMsg['userId'];
              if (senderId != userId) {
                // Get sender's real name from the message
                senderName = lastMsg['senderName'] ?? 'User';
              } else {
                senderName = 'You';
              }
              lastMessageText = lastMsg['text'] ?? 'No messages';
              time = lastMsg['time'] ?? DateTime.now().toIso8601String();
            }
            
            var displayMessage = lastMsg != null ? '$senderName: $lastMessageText' : 'No messages';
            
            chatList.add({
              'id': chatId,
              'name': name,
              'lastMessage': displayMessage,
              'time': time,
              'isGroup': isGroup,
              'avatar': avatar,
            });
          }
          
          chatList.sort((a, b) => b['time'].compareTo(a['time']));
          
          print('📋 Returning ${chatList.length} chats');
          _sendJson(request.response, {'chats': chatList});
        }

        else if (request.method == 'GET' && request.uri.path == '/chat/messages') {
          var chatId = request.uri.queryParameters['chatId'] ?? '';
          var userId = request.uri.queryParameters['userId'] ?? currentUserId ?? 'user123';
          var msgs = messages[chatId] ?? [];
          
          print('💬 Getting messages for chat: $chatId');
          print('💬 Found ${msgs.length} messages');
          
          var enrichedMessages = [];
          for (var msg in msgs) {
            var senderId = msg['userId'];
            var senderProfile = userProfiles[senderId] ?? {};
            var senderUsername = userNames[senderId] ?? senderId;
            var senderName = msg['senderName'] ?? senderProfile['name'] ?? senderUsername;
            var senderAvatar = msg['senderAvatar'] ?? senderProfile['avatar'] ?? '';
            
            var receiverId = '';
            var receiverName = '';
            var receiverAvatar = '';
            if (!chatId.startsWith('group_')) {
              var parts = chatId.replaceAll('chat_', '').split('_');
              for (var part in parts) {
                if (part != senderId) {
                  receiverId = part;
                  break;
                }
              }
              if (receiverId.isNotEmpty) {
                var receiverProfile = userProfiles[receiverId] ?? {};
                var receiverUsername = userNames[receiverId] ?? receiverId;
                receiverName = receiverProfile['name'] ?? receiverUsername;
                receiverAvatar = receiverProfile['avatar'] ?? '';
              }
            }
            
            enrichedMessages.add({
              'id': msg['id'],
              'userId': senderId,
              'text': msg['text'],
              'fileId': msg['fileId'],
              'fileType': msg['fileType'],
              'time': msg['time'],
              'read': msg['read'],
              'senderName': senderName,  // ← Real Google name
              'senderAvatar': senderAvatar,
              'receiverId': receiverId,
              'receiverName': receiverName,
              'receiverAvatar': receiverAvatar,
            });
          }
          
          _sendJson(request.response, {'messages': enrichedMessages});
        }

        else if (request.method == 'POST' && request.uri.path == '/chat/send') {
          var body = await utf8.decoder.bind(request).join();
          var data = jsonDecode(body);
          var chatId = data['chatId'];
          var userId = data['userId'];
          var text = data['text'] ?? '';
          var fileId = data['fileId'];
          var fileType = data['fileType'];

          var msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

          // Get sender info from userProfiles (Google name)
          var senderProfile = userProfiles[userId] ?? {};
          var senderUsername = userNames[userId] ?? userId;
          var senderName = senderProfile['name'] ?? senderUsername;
          var senderAvatar = senderProfile['avatar'] ?? '';
          
          // Get receiver info for 1-on-1 chats
          var receiverId = '';
          var receiverName = '';
          var receiverAvatar = '';
          if (!chatId.startsWith('group_')) {
            var parts = chatId.replaceAll('chat_', '').split('_');
            for (var part in parts) {
              if (part != userId) {
                receiverId = part;
                break;
              }
            }
            if (receiverId.isNotEmpty) {
              var receiverProfile = userProfiles[receiverId] ?? {};
              var receiverUsername = userNames[receiverId] ?? receiverId;
              receiverName = receiverProfile['name'] ?? receiverUsername;
              receiverAvatar = receiverProfile['avatar'] ?? '';
            }
          }
          
          // Create message with sender's real name
          var msg = {
            'id': msgId,
            'userId': userId,
            'text': text,
            'fileId': fileId,
            'fileType': fileType,
            'time': DateTime.now().toIso8601String(),
            'read': false,
            'senderName': senderName,  // ← Real Google name
            'senderAvatar': senderAvatar,
            'receiverId': receiverId,
            'receiverName': receiverName,
            'receiverAvatar': receiverAvatar,
          };

          await db.execute(
            'INSERT INTO messages (id, chat_id, user_id, text, file_id, file_type) '
            'VALUES (\$1, \$2, \$3, \$4, \$5, \$6)',
            parameters: [msgId, chatId, userId, text, fileId, fileType]
          );

          messages.putIfAbsent(chatId, () => []);
          messages[chatId]!.add(msg);

          // Add chat to sender's list
          if (userId != null) {
            userChats.putIfAbsent(userId, () => <String>[]);
            if (!userChats[userId]!.contains(chatId)) {
              userChats[userId]!.add(chatId);
              print('✅ Added chat $chatId to sender $userId');
            }
          }

          // Add chat to receiver's list (for 1-on-1 chats)
          if (!chatId.startsWith('group_') && receiverId.isNotEmpty) {
            userChats.putIfAbsent(receiverId, () => <String>[]);
            if (!userChats[receiverId]!.contains(chatId)) {
              userChats[receiverId]!.add(chatId);
              print('✅ Added chat $chatId to receiver $receiverId');
            }
          }

          _sendJson(request.response, {'success': true, 'message': msg});
        }

        // ============ FILE ENDPOINTS ============
        else if (request.method == 'POST' && request.uri.path == '/upload/file') {
          var body = await utf8.decoder.bind(request).join();
          var data = jsonDecode(body);
          var fileId = data['fileId'];
          var fileData = data['fileData'];
          var fileType = data['fileType'];
          var fileName = data['fileName'];

          await db.execute(
            'INSERT INTO files (id, file_data, file_type, file_name) VALUES (\$1, \$2, \$3, \$4)',
            parameters: [fileId, fileData, fileType, fileName]
          );

          fileStorage[fileId] = {
            'data': fileData,
            'type': fileType,
            'name': fileName,
          };
          print('📁 File stored: $fileName ($fileType)');
          _sendJson(request.response, {'success': true, 'fileId': fileId});
        }

        else if (request.method == 'GET' && request.uri.path == '/file') {
          var fileId = request.uri.queryParameters['fileId'] ?? '';
          if (fileStorage.containsKey(fileId)) {
            _sendJson(request.response, {
              'success': true,
              'fileData': fileStorage[fileId]!['data'],
              'fileType': fileStorage[fileId]!['type'],
              'fileName': fileStorage[fileId]!['name'],
            });
          } else {
            _sendJson(request.response, {'success': false, 'message': 'File not found'});
          }
        }

        else {
          request.response
            ..statusCode = 404
            ..headers.add('Access-Control-Allow-Origin', '*')
            ..write('Not found')
            ..close();
        }
      } catch (e) {
        print('❌ Error: $e');
        _sendJson(request.response, {'error': '$e'}, 500);
      }
    }
  } catch (e) {
    print('❌ Server failed to start: $e');
  }
}

// ============ HELPER FUNCTIONS ============

String _cleanPhone(String phone) {
  return phone.replaceAll(RegExp(r'[^0-9+]'), '');
}

String _generateUsername(String email) {
  var base = email.split('@').first;
  base = base.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  base = base.toLowerCase();

  if (nameToUserId.containsKey(base)) {
    var counter = 1;
    var newUsername = '$base$counter';
    while (nameToUserId.containsKey(newUsername)) {
      counter++;
      newUsername = '$base$counter';
    }
    return newUsername;
  }
  return base;
}

void _sendJson(HttpResponse response, Map<String, dynamic> data, [int status = 200]) {
  response
    ..statusCode = status
    ..headers.add('Access-Control-Allow-Origin', '*')
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(data))
    ..close();
}

// ============ DATABASE FUNCTIONS ============

Future<void> _createTables() async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      phone TEXT UNIQUE,
      email TEXT UNIQUE,
      username TEXT UNIQUE NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS profiles (
      user_id TEXT PRIMARY KEY,
      name TEXT,
      bio TEXT,
      avatar TEXT,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS settings (
      user_id TEXT PRIMARY KEY,
      last_seen TEXT DEFAULT 'everyone',
      chat_color TEXT DEFAULT '#7B2FBE',
      brightness TEXT DEFAULT 'light',
      phone TEXT,
      blocked_users TEXT DEFAULT '[]',
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS contacts (
      id SERIAL PRIMARY KEY,
      user_id TEXT NOT NULL,
      contact_phone TEXT NOT NULL,
      contact_name TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(user_id, contact_phone),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      chat_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      text TEXT,
      file_id TEXT,
      file_type TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      read BOOLEAN DEFAULT FALSE
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS groups (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_members (
      id SERIAL PRIMARY KEY,
      group_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (group_id) REFERENCES groups(id),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS files (
      id TEXT PRIMARY KEY,
      file_data TEXT NOT NULL,
      file_type TEXT NOT NULL,
      file_name TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  print('✅ Database tables created');
}

// ============ LOAD DATA FROM DATABASE ============

Future<void> _loadDataFromDatabase() async {
  print('📂 Loading data from database...');

  try {
    var usersResult = await db.execute('SELECT * FROM users');
    for (var row in usersResult) {
      if (row.length >= 4) {
        var userId = row[0].toString();
        var phone = row[1]?.toString() ?? '';
        var email = row[2]?.toString() ?? '';
        var username = row[3].toString();
        if (phone.isNotEmpty) registeredUsers[phone] = userId;
        if (email.isNotEmpty) googleUsers[email] = userId;
        userNames[userId] = username;
        nameToUserId[username] = userId;
      }
    }
    print('👤 Loaded ${registeredUsers.length} users');
  } catch (e) {
    print('⚠️ Could not load users: $e');
  }

  try {
    var profilesResult = await db.execute('SELECT * FROM profiles');
    for (var row in profilesResult) {
      if (row.length >= 4) {
        var userId = row[0].toString();
        var name = row[1]?.toString() ?? '';
        var bio = row[2]?.toString() ?? '';
        var avatar = row[3]?.toString() ?? '';
        userProfiles[userId] = {
          'name': name,
          'bio': bio,
          'avatar': avatar,
        };
      }
    }
    print('👤 Loaded ${userProfiles.length} profiles');
  } catch (e) {
    print('⚠️ Could not load profiles: $e');
  }

  try {
    var settingsResult = await db.execute('SELECT * FROM settings');
    for (var row in settingsResult) {
      if (row.length >= 6) {
        var userId = row[0].toString();
        var lastSeen = row[1]?.toString() ?? 'everyone';
        var chatColor = row[2]?.toString() ?? '#7B2FBE';
        var brightness = row[3]?.toString() ?? 'light';
        var phone = row[4]?.toString() ?? '';
        var blockedUsers = jsonDecode(row[5]?.toString() ?? '[]');
        userSettings[userId] = {
          'lastSeen': lastSeen,
          'chatColor': chatColor,
          'brightness': brightness,
          'phone': phone,
          'blockedUsers': blockedUsers,
        };
      }
    }
    print('⚙️ Loaded ${userSettings.length} settings');
  } catch (e) {
    print('⚠️ Could not load settings: $e');
  }

  try {
    var contactsResult = await db.execute('SELECT * FROM contacts');
    for (var row in contactsResult) {
      if (row.length >= 4) {
        var userId = row[1].toString();
        var contactPhone = row[2].toString();
        var contactName = row[3].toString();
        userContacts.putIfAbsent(userId, () => []);
        userContacts[userId]!.add({
          'phone': contactPhone,
          'name': contactName,
        });
      }
    }
    print('📱 Loaded contacts');
  } catch (e) {
    print('⚠️ Could not load contacts: $e');
  }

  try {
    var messagesResult = await db.execute(
      'SELECT * FROM messages ORDER BY created_at ASC'
    );
    for (var row in messagesResult) {
      if (row.length >= 7) {
        var msgId = row[0].toString();
        var chatId = row[1].toString();
        var userId = row[2].toString();
        var text = row[3]?.toString() ?? '';
        var fileId = row[4]?.toString();
        var fileType = row[5]?.toString();
        var createdAt = row[6].toString();

        messages.putIfAbsent(chatId, () => []);
        messages[chatId]!.add({
          'id': msgId,
          'userId': userId,
          'text': text,
          'fileId': fileId,
          'fileType': fileType,
          'time': createdAt,
          'read': false,
        });
      }
    }
    print('💬 Loaded messages');
  } catch (e) {
    print('⚠️ Could not load messages: $e');
  }

  try {
    var groupsResult = await db.execute('SELECT * FROM groups');
    for (var row in groupsResult) {
      if (row.length >= 2) {
        var groupId = row[0].toString();
        var groupName = row[1].toString();
        groupNames[groupId] = groupName;
      }
    }
  } catch (e) {
    print('⚠️ Could not load groups: $e');
  }

  try {
    var membersResult = await db.execute('SELECT * FROM group_members');
    for (var row in membersResult) {
      if (row.length >= 3) {
        var groupId = row[1].toString();
        var userId = row[2].toString();
        groupMembers.putIfAbsent(groupId, () => []);
        groupMembers[groupId]!.add(userId);
      }
    }
  } catch (e) {
    print('⚠️ Could not load group members: $e');
  }

  try {
    var filesResult = await db.execute('SELECT * FROM files');
    for (var row in filesResult) {
      if (row.length >= 4) {
        var fileId = row[0].toString();
        var fileData = row[1].toString();
        var fileType = row[2].toString();
        var fileName = row[3].toString();
        fileStorage[fileId] = {
          'data': fileData,
          'type': fileType,
          'name': fileName,
        };
      }
    }
  } catch (e) {
    print('⚠️ Could not load files: $e');
  }

  print('✅ Data loaded from database');
}