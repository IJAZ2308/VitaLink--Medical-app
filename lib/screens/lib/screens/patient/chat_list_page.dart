// lib/screens/chat/chat_full.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Chat module using Firebase Realtime Database + FCM
/// - chatRooms/{roomId}/messages/{msgId}
/// - users/{uid}/fcmToken
/// - doctors/{uid} (profile)
/// - typing/{roomId}/{uid} = true/false

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
    _saveFcmTokenIfNeeded();
  }

  Future<void> _saveFcmTokenIfNeeded() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final fcm = FirebaseMessaging.instance;
    final token = await fcm.getToken(); // may be null in emulator
    if (token != null) {
      await _db.child('users/${user.uid}/fcmToken').set(token);
    }
    // handle token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _db.child('users/${user.uid}/fcmToken').set(newToken);
    });
  }

  Future<void> _loadUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final docSnap = await _db.child('doctors/$uid').get();
    if (docSnap.exists) {
      final data = Map<String, dynamic>.from(docSnap.value as Map);
      setState(() {
        _role = data['role'] as String? ?? 'doctor';
        _displayName =
            (data['firstName'] ?? data['name'] ?? data['fullName']) as String?;
      });
      return;
    }

    final userSnap = await _db.child('users/$uid').get();
    if (userSnap.exists) {
      final data = Map<String, dynamic>.from(userSnap.value as Map);
      setState(() {
        _role = data['role'] as String? ?? 'patient';
        _displayName =
            (data['firstName'] ?? data['name'] ?? data['fullName']) as String?;
      });
      return;
    }

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
                Expanded(child: ChatListPage(role: _role!)),
              ],
            ),
    );
  }
}

/// ---------------- Chat List ----------------
class ChatListPage extends StatefulWidget {
  final String role;
  const ChatListPage({super.key, required this.role});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _roomsRef = FirebaseDatabase.instance.ref().child(
    'chatRooms',
  );
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child(
    'users',
  );
  final DatabaseReference _doctorsRef = FirebaseDatabase.instance.ref().child(
    'doctors',
  );

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    // stream all rooms and filter locally for simplicity
    return StreamBuilder<DatabaseEvent>(
      stream: _roomsRef.onValue,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Error loading chats'));
        }
        if (!snap.hasData || snap.data!.snapshot.value == null) {
          return const Center(child: Text('No chats yet'));
        }

        final all = Map<dynamic, dynamic>.from(
          snap.data!.snapshot.value as Map,
        );
        final List<_RoomPreview> myRooms = [];

        all.forEach((roomId, roomValue) {
          final room = Map<dynamic, dynamic>.from(roomValue);
          final participants = Map<dynamic, dynamic>.from(
            room['participants'] ?? {},
          );
          if (participants.containsKey(user.uid)) {
            final lastMessage = room['lastMessage'] as String? ?? '';
            final lastTimestamp = room['lastTimestamp'] as int? ?? 0;
            myRooms.add(
              _RoomPreview(
                id: roomId,
                participants: participants.keys.cast<String>().toList(),
                lastMessage: lastMessage,
                lastTimestamp: lastTimestamp,
              ),
            );
          }
        });

        myRooms.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
        if (myRooms.isEmpty) return const Center(child: Text('No chats yet'));

        return ListView.builder(
          itemCount: myRooms.length,
          itemBuilder: (context, i) {
            final r = myRooms[i];
            final otherId = r.participants.firstWhere((p) => p != user.uid);
            return FutureBuilder<_CompanionData>(
              future: _fetchCompanion(otherId),
              builder: (context, compSnap) {
                final display = compSnap.data?.displayName ?? otherId;
                final subtitle = r.lastMessage.isNotEmpty
                    ? r.lastMessage
                    : 'No messages yet';
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      display.isNotEmpty ? display[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(display),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_formatTimestamp(r.lastTimestamp)),
                      const SizedBox(height: 6),
                      FutureBuilder<int>(
                        future: _getUnreadCount(r.id, user.uid),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) =>
                            ChatDetailPage(roomId: r.id, otherId: otherId),
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

  Future<int> _getUnreadCount(String roomId, String myUid) async {
    final msgsSnap = await _roomsRef.child(roomId).child('messages').get();
    if (!msgsSnap.exists) return 0;
    final msgs = Map<dynamic, dynamic>.from(msgsSnap.value as Map);
    int cnt = 0;
    msgs.forEach((k, v) {
      final m = Map<dynamic, dynamic>.from(v);
      final seenBy = List<dynamic>.from(m['seenBy'] ?? []);
      if (!seenBy.contains(myUid)) cnt++;
    });
    return cnt;
  }

  Future<_CompanionData> _fetchCompanion(String id) async {
    final docSnap = await _doctorsRef.child(id).get();
    if (docSnap.exists) {
      final data = Map<String, dynamic>.from(docSnap.value as Map);
      final name =
          (data['firstName'] ?? data['name'] ?? data['fullName'] ?? '')
              as String;
      final spec = (data['specialization'] ?? '') as String;
      return _CompanionData(displayName: name, subtitle: spec);
    }
    final userSnap = await _usersRef.child(id).get();
    if (userSnap.exists) {
      final data = Map<String, dynamic>.from(userSnap.value as Map);
      final name =
          (data['firstName'] ?? data['name'] ?? data['fullName'] ?? '')
              as String;
      final email = (data['email'] ?? '') as String;
      return _CompanionData(displayName: name, subtitle: email);
    }
    return _CompanionData(displayName: id, subtitle: '');
  }

  String _formatTimestamp(int tsMillis) {
    if (tsMillis <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(tsMillis);
    final today = DateTime.now();
    if (dt.year == today.year &&
        dt.month == today.month &&
        dt.day == today.day) {
      return DateFormat.Hm().format(dt);
    }
    return DateFormat('dd MMM').format(dt);
  }
}

class _RoomPreview {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final int lastTimestamp;
  _RoomPreview({
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

/// ---------------- Doctor Selection ----------------
class DoctorSelectionPage extends StatefulWidget {
  const DoctorSelectionPage({super.key});
  @override
  State<DoctorSelectionPage> createState() => _DoctorSelectionPageState();
}

class _DoctorSelectionPageState extends State<DoctorSelectionPage> {
  final DatabaseReference _doctorsRef = FirebaseDatabase.instance.ref().child(
    'doctors',
  );
  final DatabaseReference _roomsRef = FirebaseDatabase.instance.ref().child(
    'chatRooms',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> _createOrGetRoom(String otherId) async {
    final uid = _auth.currentUser!.uid;
    final snap = await _roomsRef.get();
    if (snap.exists) {
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      for (var entry in data.entries) {
        final id = entry.key;
        final room = Map<dynamic, dynamic>.from(entry.value);
        final participants = Map<dynamic, dynamic>.from(
          room['participants'] ?? {},
        );
        if (participants.containsKey(uid) &&
            participants.containsKey(otherId)) {
          return id;
        }
      }
    }
    final newRef = _roomsRef.push();
    final now = DateTime.now().millisecondsSinceEpoch;
    await newRef.set({
      'participants': {uid: true, otherId: true},
      'lastMessage': '',
      'lastTimestamp': now,
      'createdAt': now,
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
            itemBuilder: (context, i) {
              final docId = items[i].key;
              final doc = Map<dynamic, dynamic>.from(items[i].value);
              final name =
                  doc['firstName'] ??
                  doc['name'] ??
                  doc['fullName'] ??
                  'Doctor';
              final spec = doc['specialization'] ?? '';
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: Text(spec),
                onTap: () async {
                  final roomId = await _createOrGetRoom(docId);
                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
                  Navigator.pushReplacement(
                    // ignore: use_build_context_synchronously
                    context,
                    MaterialPageRoute(
                      builder: (c) =>
                          ChatDetailPage(roomId: roomId, otherId: docId),
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

/// ---------------- Chat Detail ----------------
class ChatDetailPage extends StatefulWidget {
  final String roomId;
  final String otherId; // other participant id (doctor or patient)
  const ChatDetailPage({
    super.key,
    required this.roomId,
    required this.otherId,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final DatabaseReference _roomsRef = FirebaseDatabase.instance.ref().child(
    'chatRooms',
  );
  final DatabaseReference _doctorsRef = FirebaseDatabase.instance.ref().child(
    'doctors',
  );
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child(
    'users',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final String myUid;
  bool _otherTyping = false;
  StreamSubscription<DatabaseEvent>? _typingSub;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    myUid = _auth.currentUser!.uid;
    _listenTyping();
    // mark read initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllSeen();
      _scrollToBottomDelayed();
    });
  }

  @override
  void dispose() {
    _typingSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _setTyping(false);
    super.dispose();
  }

  void _listenTyping() {
    _typingSub = FirebaseDatabase.instance
        .ref()
        .child('typing')
        .child(widget.roomId)
        .onValue
        .listen((event) {
          if (event.snapshot.value == null) {
            setState(() => _otherTyping = false);
            return;
          }
          final tmap = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          final val = tmap[widget.otherId];
          setState(() => _otherTyping = val == true);
        });
  }

  Future<void> _setTyping(bool val) async {
    await FirebaseDatabase.instance
        .ref()
        .child('typing')
        .child(widget.roomId)
        .update({myUid: val});
  }

  Future<void> _markAllSeen() async {
    final msgsSnap = await _roomsRef
        .child(widget.roomId)
        .child('messages')
        .get();
    if (!msgsSnap.exists) return;
    final msgs = Map<dynamic, dynamic>.from(msgsSnap.value as Map);
    for (var e in msgs.entries) {
      final key = e.key;
      final m = Map<dynamic, dynamic>.from(e.value);
      final seenBy = List<dynamic>.from(m['seenBy'] ?? []);
      if (!seenBy.contains(myUid)) {
        seenBy.add(myUid);
        await _roomsRef
            .child(widget.roomId)
            .child('messages')
            .child(key)
            .update({'seenBy': seenBy});
      }
    }
    // also update lastRead timestamp for user (optional)
    await _roomsRef
        .child(widget.roomId)
        .child('lastRead')
        .child(myUid)
        .set(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final msgRef = _roomsRef.child(widget.roomId).child('messages').push();
    final payload = {
      'senderId': myUid,
      'receiverId': widget.otherId,
      'text': text,
      'timestamp': ts,
      'type': 'text',
      'seenBy': [myUid], // sender already read
    };
    await msgRef.set(payload);
    await _roomsRef.child(widget.roomId).update({
      'lastMessage': text,
      'lastTimestamp': ts,
    });
    _controller.clear();
    await _setTyping(false);
    _scrollToBottomDelayed();
    // no client-side FCM sending here; Cloud Function will observe the new message and send push.
  }

  void _onTextChanged(String v) {
    _setTyping(true);
    Timer(const Duration(seconds: 2), () {
      _setTyping(false);
    });
  }

  void _scrollToBottomDelayed() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<_CompanionData> _fetchCompanion() async {
    final docSnap = await _doctorsRef.child(widget.otherId).get();
    if (docSnap.exists) {
      final data = Map<String, dynamic>.from(docSnap.value as Map);
      final name =
          (data['firstName'] ?? data['name'] ?? data['fullName'] ?? '')
              as String;
      final spec = (data['specialization'] ?? '') as String;
      return _CompanionData(displayName: name, subtitle: spec);
    }
    final userSnap = await _usersRef.child(widget.otherId).get();
    if (userSnap.exists) {
      final data = Map<String, dynamic>.from(userSnap.value as Map);
      final name =
          (data['firstName'] ?? data['name'] ?? data['fullName'] ?? '')
              as String;
      final email = (data['email'] ?? '') as String;
      return _CompanionData(displayName: name, subtitle: email);
    }
    return _CompanionData(displayName: widget.otherId, subtitle: '');
  }

  @override
  Widget build(BuildContext context) {
    final stream = _roomsRef.child(widget.roomId).onValue;
    return FutureBuilder<_CompanionData>(
      future: _fetchCompanion(),
      builder: (context, compSnap) {
        final companionName = compSnap.data?.displayName ?? 'Chat';
        final companionSubtitle = compSnap.data?.subtitle ?? '';
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
                    Text(
                      companionSubtitle,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: stream,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(child: Text('Error'));
                    }
                    if (!snap.hasData || snap.data!.snapshot.value == null) {
                      return const Center(child: Text('No messages yet'));
                    }
                    final room = Map<String, dynamic>.from(
                      snap.data!.snapshot.value as Map,
                    );
                    final msgsMap =
                        room['messages'] as Map<dynamic, dynamic>? ?? {};
                    final msgs =
                        msgsMap.entries.map((e) {
                          final m = Map<String, dynamic>.from(e.value as Map);
                          m['id'] = e.key;
                          return m;
                        }).toList()..sort(
                          (a, b) => (a['timestamp'] as int).compareTo(
                            b['timestamp'] as int,
                          ),
                        );

                    // mark seen after getting new data
                    _markAllSeen();

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: msgs.length,
                      itemBuilder: (context, i) {
                        final m = msgs[i];
                        final isMe = m['senderId'] == myUid;
                        final txt = m['text'] ?? '';
                        final ts = m['timestamp'] as int? ?? 0;
                        final seenBy = List<dynamic>.from(m['seenBy'] ?? []);
                        final seenByOther = seenBy.contains(widget.otherId);
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
                                child: Text(txt),
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
                                      seenByOther ? Icons.done_all : Icons.done,
                                      size: 14,
                                      color: seenByOther
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
              if (_otherTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${compSnap.data?.displayName ?? ''} is typing...',
                    ),
                  ),
                ),
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

  // ignore: unused_element
}
