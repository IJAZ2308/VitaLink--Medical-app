// lib/screens/chat/chat_full.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Full Chat Module (Option B)
/// - ChatHomePage: decides role & shows appropriate entry (doctor sees chats, patient sees doctors/chat list)
/// - ChatListPage: unified chat list for both roles (last message, unread count, timestamp)
/// - DoctorSelectionPage: patient selects doctor to start chat
/// - ChatDetailPage: real-time chat, typing indicator, read receipts

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? _role;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // Try doctors node first
    final DataSnapshot docSnap = await _db.child('doctors/$uid').get();
    if (docSnap.exists) {
      final data = Map<String, dynamic>.from(docSnap.value as Map);
      setState(() {
        _role = data['role'] as String? ?? 'doctor';
        _displayName =
            (data['firstName'] ?? data['name'] ?? data['name']) as String?;
      });
      return;
    }

    // Try users node
    final DataSnapshot userSnap = await _db.child('users/$uid').get();
    if (userSnap.exists) {
      final data = Map<String, dynamic>.from(userSnap.value as Map);
      setState(() {
        _role = data['role'] as String? ?? 'patient';
        _displayName =
            (data['firstName'] ?? data['name'] ?? data['fullName']) as String?;
      });
      return;
    }

    // Default to patient if unknown
    setState(() {
      _role = 'patient';
      _displayName = user.email;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: _role == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with role
                Container(
                  width: double.infinity,
                  color: Colors.blueGrey[50],
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Text(
                    // ignore: unnecessary_brace_in_string_interps
                    'Signed in as: ${_displayName ?? _auth.currentUser!.email}  (${_role})',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

                // Buttons / actions
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      if (_role == 'patient') ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const DoctorSelectionPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Find Doctor'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: Container()),
                      IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadUserRole,
                      ),
                    ],
                  ),
                ),

                // Chat list
                Expanded(child: ChatListPage(role: _role!)),
              ],
            ),
    );
  }
}

/// ------------------- Chat List Page -------------------
/// Shows all chats for the current user (both roles).
/// Displays last message, timestamp, unread count, companion's name & avatar.
class ChatListPage extends StatefulWidget {
  final String role;
  const ChatListPage({super.key, required this.role});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _chatsRef = FirebaseDatabase.instance.ref().child(
    'chats',
  );
  final DatabaseReference _doctorsRef = FirebaseDatabase.instance.ref().child(
    'doctors',
  );
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child(
    'users',
  );

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    // Stream entire chats node - we will filter client-side to keep structure simple.
    return StreamBuilder<DatabaseEvent>(
      stream: _chatsRef.onValue,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Error loading chats'));
        }
        if (!snap.hasData || snap.data!.snapshot.value == null) {
          return const Center(child: Text('No chats yet'));
        }

        final allChats = Map<dynamic, dynamic>.from(
          snap.data!.snapshot.value as Map,
        );
        final List<_ChatPreview> myChats = [];

        allChats.forEach((chatId, chatValue) {
          final chat = Map<dynamic, dynamic>.from(chatValue);
          final participants = List<dynamic>.from(chat['participants'] ?? []);
          if (participants.contains(user.uid)) {
            final lastMessage = chat['lastMessage'] as String? ?? '';
            final lastTimestamp =
                chat['lastTimestamp'] as int? ??
                (chat['lastMessageAt'] != null
                    ? int.tryParse(chat['lastMessageAt'].toString())
                    : null) ??
                0;
            myChats.add(
              _ChatPreview(
                id: chatId,
                participants: participants,
                lastMessage: lastMessage,
                lastTimestamp: lastTimestamp,
              ),
            );
          }
        });

        // Sort by lastTimestamp desc
        myChats.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));

        if (myChats.isEmpty) return const Center(child: Text('No chats yet'));

        return ListView.builder(
          itemCount: myChats.length,
          itemBuilder: (context, index) {
            final c = myChats[index];
            final otherId = c.participants.firstWhere((p) => p != user.uid);
            return FutureBuilder<_CompanionData>(
              future: _fetchCompanionData(otherId),
              builder: (context, compSnap) {
                final name = compSnap.hasData
                    ? compSnap.data!.displayName
                    : otherId;
                final subtitle = c.lastMessage.isNotEmpty
                    ? c.lastMessage
                    : 'No messages yet';
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      name != null && name.length > 0
                          ? name[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(name ?? 'Unknown'),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_formatTimestamp(c.lastTimestamp)),
                      const SizedBox(height: 6),
                      // Unread count indicator
                      FutureBuilder<int>(
                        future: _getUnreadCount(c.id, user.uid),
                        builder: (context, unreadSnap) {
                          final unread = unreadSnap.data ?? 0;
                          return unread > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    // Open chat
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChatDetailPage(chatId: c.id, doctorId: otherId),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<_CompanionData> _fetchCompanionData(String id) async {
    // Try doctors node then users node
    final DataSnapshot docSnap = await _doctorsRef.child(id).get();
    if (docSnap.exists) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        docSnap.value as Map,
      );
      final name =
          (data['firstName'] ?? data['name'] ?? data['fullName'] ?? '')
              as String;
      final specialization = (data['specialization'] ?? '') as String;
      return _CompanionData(displayName: name, subtitle: specialization);
    }

    final DataSnapshot userSnap = await _usersRef.child(id).get();
    if (userSnap.exists) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        userSnap.value as Map,
      );
      final name =
          (data['firstName'] ?? data['name'] ?? data['fullName'] ?? '')
              as String;
      final subtitle = (data['email'] ?? '') as String;
      return _CompanionData(displayName: name, subtitle: subtitle);
    }

    return _CompanionData(displayName: id, subtitle: '');
  }

  Future<int> _getUnreadCount(String chatId, String myUid) async {
    final DataSnapshot snap = await _chatsRef
        .child(chatId)
        .child('messages')
        .get();
    if (!snap.exists) return 0;
    final Map<dynamic, dynamic> msgs = Map<dynamic, dynamic>.from(
      snap.value as Map,
    );
    int unread = 0;
    msgs.forEach((k, v) {
      final msg = Map<dynamic, dynamic>.from(v);
      final readBy = List<dynamic>.from(msg['readBy'] ?? []);
      if (!readBy.contains(myUid)) unread++;
    });
    return unread;
  }

  String _formatTimestamp(int tsMillis) {
    if (tsMillis <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(tsMillis);
    final today = DateTime.now();
    if (dt.year == today.year &&
        dt.month == today.month &&
        dt.day == today.day) {
      return DateFormat.Hm().format(dt); // 13:24
    }
    return DateFormat('dd MMM').format(dt); // 01 Dec
  }
}

class _ChatPreview {
  final String id;
  final List<dynamic> participants;
  final String lastMessage;
  final int lastTimestamp;
  _ChatPreview({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastTimestamp,
  });
}

class _CompanionData {
  final String? displayName;
  final String? subtitle;
  _CompanionData({this.displayName, this.subtitle});
}

/// ------------------- Doctor Selection Page -------------------
/// Patients will use this to pick a doctor and start chat
class DoctorSelectionPage extends StatefulWidget {
  const DoctorSelectionPage({super.key});

  @override
  State<DoctorSelectionPage> createState() => _DoctorSelectionPageState();
}

class _DoctorSelectionPageState extends State<DoctorSelectionPage> {
  final DatabaseReference _doctorsRef = FirebaseDatabase.instance.ref().child(
    'doctors',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _chatsRef = FirebaseDatabase.instance.ref().child(
    'chats',
  );

  Future<String> _createOrGetChat(String otherId) async {
    final uid = _auth.currentUser!.uid;

    // Search existing chats where participants include both uids
    final DataSnapshot snap = await _chatsRef.get();
    if (snap.exists) {
      final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
        snap.value as Map,
      );
      for (var entry in data.entries) {
        final chatId = entry.key;
        final chat = Map<dynamic, dynamic>.from(entry.value);
        final participants = List<dynamic>.from(chat['participants'] ?? []);
        if (participants.contains(uid) && participants.contains(otherId)) {
          return chatId;
        }
      }
    }

    // Create new chat
    final newRef = _chatsRef.push();
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    await newRef.set({
      'participants': [uid, otherId],
      'lastMessage': '',
      'lastTimestamp': createdAt,
      'createdAt': createdAt,
      'typing': {}, // typing map
    });
    return newRef.key!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Doctor')),
      body: StreamBuilder<DatabaseEvent>(
        stream: _doctorsRef.onValue,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error loading doctors'));
          }
          if (!snap.hasData || snap.data!.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final doctors = Map<dynamic, dynamic>.from(
            snap.data!.snapshot.value as Map,
          );
          final items = doctors.entries.toList();

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final docId = items[index].key;
              final doc = Map<dynamic, dynamic>.from(items[index].value);
              final name =
                  doc['firstName'] ??
                  doc['name'] ??
                  doc['fullName'] ??
                  'Doctor';
              final specialization = doc['specialization'] ?? '';

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: Text(specialization),
                onTap: () async {
                  final chatId = await _createOrGetChat(docId);
                  Navigator.pushReplacement(
                    // ignore: use_build_context_synchronously
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ChatDetailPage(chatId: chatId, doctorId: docId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// ------------------- Chat Detail Page -------------------
/// Handles message send/read/typing
class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String
  doctorId; // other participant id (doctor). For doctor view, patient id is the other side

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.doctorId,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final DatabaseReference _chatsRef = FirebaseDatabase.instance.ref().child(
    'chats',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final String myUid;
  late final String otherId; // other participant id

  StreamSubscription<DatabaseEvent>? _typingSub;
  bool _otherTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    myUid = _auth.currentUser!.uid;
    otherId = widget.doctorId;
    _markMessagesRead();
    _setupTypingListener();
  }

  @override
  void dispose() {
    _typingSub?.cancel();
    _typingTimer?.cancel();
    _setTyping(false);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setupTypingListener() async {
    _typingSub = _chatsRef.child(widget.chatId).child('typing').onValue.listen((
      event,
    ) {
      if (event.snapshot.value == null) {
        setState(() => _otherTyping = false);
        return;
      }
      final Map<dynamic, dynamic> typingMap = Map<dynamic, dynamic>.from(
        event.snapshot.value as Map,
      );
      // Consider other typing true if there's an entry for otherId === true
      final val = typingMap[otherId];
      setState(() => _otherTyping = val == true);
    });
  }

  Future<void> _setTyping(bool typing) async {
    // Set typing map under chatId/typing/{myUid} = true/false
    await _chatsRef.child(widget.chatId).child('typing').update({
      myUid: typing,
    });
  }

  Future<void> _markMessagesRead() async {
    // Mark all messages as read by adding myUid to readBy
    final messagesSnap = await _chatsRef
        .child(widget.chatId)
        .child('messages')
        .get();
    if (!messagesSnap.exists) return;
    final msgs = Map<dynamic, dynamic>.from(messagesSnap.value as Map);
    for (var entry in msgs.entries) {
      final key = entry.key;
      final msg = Map<dynamic, dynamic>.from(entry.value);
      final readBy = List<dynamic>.from(msg['readBy'] ?? []);
      if (!readBy.contains(myUid)) {
        readBy.add(myUid);
        await _chatsRef
            .child(widget.chatId)
            .child('messages')
            .child(key)
            .update({'readBy': readBy});
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final msgRef = _chatsRef.child(widget.chatId).child('messages').push();

    await msgRef.set({
      'senderId': myUid,
      'text': text,
      'timestamp': timestamp,
      'readBy': [myUid], // sender already read it
    });

    // Update last message on chat
    await _chatsRef.child(widget.chatId).update({
      'lastMessage': text,
      'lastTimestamp': timestamp,
    });

    _controller.clear();
    _setTyping(false);

    // auto-scroll
    await Future.delayed(const Duration(milliseconds: 120));
    _scrollToBottom();
  }

  void _onTextChanged(String text) {
    // set typing true and set a short timer to clear
    _setTyping(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTyping(false);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<_CompanionData> _fetchCompanion() async {
    final doctorsRef = FirebaseDatabase.instance.ref().child('doctors');
    final usersRef = FirebaseDatabase.instance.ref().child('users');

    final docSnap = await doctorsRef.child(otherId).get();
    if (docSnap.exists) {
      final data = Map<String, dynamic>.from(docSnap.value as Map);
      final name =
          (data['firstName'] ?? data['name'] ?? data['fullName'] ?? '')
              as String;
      final subtitle = data['specialization'] ?? '';
      return _CompanionData(displayName: name, subtitle: subtitle);
    }

    final userSnap = await usersRef.child(otherId).get();
    if (userSnap.exists) {
      final data = Map<String, dynamic>.from(userSnap.value as Map);
      final name =
          (data['firstName'] ?? data['name'] ?? data['fullName'] ?? '')
              as String;
      final subtitle = data['email'] ?? '';
      return _CompanionData(displayName: name, subtitle: subtitle);
    }

    return _CompanionData(displayName: otherId, subtitle: '');
  }

  String _formatTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final chatStream = _chatsRef.child(widget.chatId).onValue;

    return FutureBuilder<_CompanionData>(
      future: _fetchCompanion(),
      builder: (context, compSnap) {
        final companionName = compSnap.data?.displayName ?? 'Chat';
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(companionName, style: const TextStyle(fontSize: 16)),
                    if (_otherTyping)
                      const Text('typing...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: chatStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error'));
                    }
                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return const Center(child: Text('No messages yet'));
                    }

                    final chatMap = Map<String, dynamic>.from(
                      snapshot.data!.snapshot.value as Map,
                    );
                    final msgsMap =
                        chatMap['messages'] as Map<dynamic, dynamic>? ?? {};

                    final messages =
                        msgsMap.entries.map((e) {
                          final m = Map<String, dynamic>.from(e.value as Map);
                          m['id'] = e.key;
                          return m;
                        }).toList()..sort(
                          (a, b) => (a['timestamp'] as int).compareTo(
                            b['timestamp'] as int,
                          ),
                        );

                    // Mark unread as read for current user
                    _markMessagesRead();

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        final isMe = m['senderId'] == myUid;
                        final text = m['text'] ?? '';
                        final ts = m['timestamp'] as int? ?? 0;
                        final readBy = List<dynamic>.from(m['readBy'] ?? []);
                        final bool isReadByOther = readBy.contains(otherId);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.green[200]
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(text),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(ts),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (isMe)
                                    Icon(
                                      isReadByOther
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 14,
                                      color: isReadByOther
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Typing indicator placeholder area
              if (_otherTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${compSnap.data?.displayName ?? ''} is typing...',
                    ),
                  ),
                ),

              // Input box
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onChanged: _onTextChanged,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        mini: true,
                        onPressed: _sendMessage,
                        child: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
