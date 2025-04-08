import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final String? selectedUserEmail;
  final String? selectedUserName;

  HomeScreen({this.selectedUserEmail, this.selectedUserName});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? _currentUserEmail;

  // Sample messages to suggest when chat is empty
  final List<String> sampleMessages = [
    "Hello, I noticed we're traveling on the same train.",
    "Would you be interested in sharing a taxi upon arrival?",
    "Do you happen to know if this train has pantry service?",
    "Could I ask you to briefly watch my luggage?",
    "Excuse me, do you know our expected arrival time?",
    "Hello, would you mind if I charge my phone here?",
    "Good day, do you know if WiFi is available onboard?",
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserEmail();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedUserEmail != null && widget.selectedUserName != null) {
        _showMessageDialogRedirectedFromTravelersPage(widget.selectedUserEmail!, widget.selectedUserName!);
      }
    });
  }

  void _showMessageDialogRedirectedFromTravelersPage(String recipientEmail, String recipientName) async {
    final messageController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Send Message to $recipientName',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: TextStyle(color: Colors.blue.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Show sample messages if the text field is empty
              if (messageController.text.isEmpty) ...[
                Text('Suggestions:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sampleMessages.map((msg) => GestureDetector(
                    onTap: () {
                      messageController.text = msg;
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(msg,
                          style: TextStyle(color: Colors.blue.shade800, fontSize: 13)),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final message = messageController.text;
                if (message.isNotEmpty) {
                  await _sendMessage(recipientEmail, message);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _fetchCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserEmail = prefs.getString('user_email');
    });
  }

  Future<void> _sendMessage(String recipientEmail, String message) async {
    await firestore.collection('chats').add({
      'from_email': _currentUserEmail,
      'to_email': recipientEmail,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  void _showMessageDialog() async {
    final currentUserJourney = await firestore.collection('Journey')
        .where('email_id', isEqualTo: _currentUserEmail)
        .limit(1)
        .get();

    if (currentUserJourney.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No journey details found for current user')),
      );
      return;
    }

    final journeyData = currentUserJourney.docs.first.data();
    final trainNo = journeyData['train_no'];
    final coachNo = journeyData['coach_number'];
    final travelDate = journeyData['travel_date'];

    final sameJourneyUsers = await firestore.collection('Journey')
        .where('train_no', isEqualTo: trainNo)
        .where('coach_number', isEqualTo: coachNo)
        .where('travel_date', isEqualTo: travelDate)
        .get();

    if (sameJourneyUsers.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fellow travelers found')),
      );
      return;
    }

    final userEmails = sameJourneyUsers.docs
        .map((doc) => doc['email_id'] as String)
        .where((email) => email != _currentUserEmail)
        .toSet()
        .toList();

    if (userEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No other travelers in your coach')),
      );
      return;
    }

    final usersSnapshot = await firestore.collection('Users')
        .where('email_Id', whereIn: userEmails)
        .get();

    final userOptions = usersSnapshot.docs.map((doc) {
      return {
        'email': doc.get('email_Id'),
        'name': doc.get('Name'),
        'avatar': doc.get('avatarUrl'),
      };
    }).toList();

    final selectedUser = await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Travel Companion',
            style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
        children: [
          if (userOptions.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('No travelers found in your coach'),
            )
          else
            ...userOptions.map((user) => SimpleDialogOption(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: user['avatar'] != null
                          ? NetworkImage(user['avatar'])
                          : null,
                      child: user['avatar'] == null
                          ? Text(user['name'][0].toUpperCase(),
                          style: TextStyle(color: Colors.blue.shade800))
                          : null,
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['name'],
                            style: TextStyle(fontSize: 16)),
                        Text(user['email'],
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(user);
              },
            )),
        ],
      ),
    );

    if (selectedUser != null) {
      final messageController = TextEditingController();
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            title: Text('Message ${selectedUser['name']}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    labelStyle: TextStyle(color: Colors.blue.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Show sample messages if the text field is empty
                if (messageController.text.isEmpty) ...[
                  Text('Suggestions:',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sampleMessages.map((msg) => GestureDetector(
                      onTap: () {
                        messageController.text = msg;
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Text(msg,
                            style: TextStyle(color: Colors.blue.shade800, fontSize: 13)),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final message = messageController.text;
                  if (message.isNotEmpty) {
                    await _sendMessage(selectedUser['email'], message);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Send'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 90,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade700, Colors.blue.shade500],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Messages',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                letterSpacing: 0.5,
                color: Colors.white.withOpacity(0.9),
                height: 1.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Stay connected with travellers',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
                height: 1.3,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit, size: 22, color: Colors.white),
              ),
              onPressed: _showMessageDialog,
            ),
          )
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 50),
        child: FloatingActionButton(
          onPressed: _showMessageDialog,
          backgroundColor: Colors.blue.shade600,
          child: Icon(Icons.message, color: Colors.white, size: 28),
          elevation: 4,
        ),
      ),
      backgroundColor: Colors.grey.shade50,
      body: _currentUserEmail == null
          ? Center(child: CircularProgressIndicator(color: Colors.blue))
          : StreamBuilder(
        stream: firestore.collection('chats')
            .where('from_email', isEqualTo: _currentUserEmail)
            .snapshots(),
        builder: (context, fromEmailSnapshot) {
          if (fromEmailSnapshot.hasData) {
            final fromEmailChats = fromEmailSnapshot.data as QuerySnapshot;
            return StreamBuilder(
              stream: firestore.collection('chats')
                  .where('to_email', isEqualTo: _currentUserEmail)
                  .snapshots(),
              builder: (context, toEmailSnapshot) {
                if (toEmailSnapshot.hasData) {
                  final toEmailChats = toEmailSnapshot.data as QuerySnapshot;
                  final allChats = [...fromEmailChats.docs, ...toEmailChats.docs];
                  Set<String> uniqueUsers = {};
                  for (var chat in allChats) {
                    uniqueUsers.add(chat['from_email'] == _currentUserEmail
                        ? chat['to_email']
                        : chat['from_email']);
                  }

                  if (uniqueUsers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.message_outlined, size: 80, color: Colors.blue.shade200),
                          SizedBox(height: 16),
                          Text("No conversations yet",
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                          SizedBox(height: 12),
                          Text("Start messaging by tapping the button below",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    children: uniqueUsers.map((userEmail) {
                      return FutureBuilder(
                        future: firestore.collection('Users')
                            .where('email_Id', isEqualTo: userEmail).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                            final userName = userSnapshot.data?.docs.first.get('Name');
                            return FutureBuilder(
                              future: firestore.collection('chats')
                                  .where('from_email', isEqualTo: userEmail)
                                  .where('to_email', isEqualTo: _currentUserEmail)
                                  .where('read', isEqualTo: false)
                                  .get(),
                              builder: (context, unreadSnapshot) {
                                if (unreadSnapshot.hasData) {
                                  final unreadCount = unreadSnapshot.data?.docs.length ?? 0;

                                  return FutureBuilder(
                                      future: firestore.collection('chats')
                                          .where(
                                        Filter.or(
                                          Filter.and(
                                            Filter('from_email', isEqualTo: userEmail),
                                            Filter('to_email', isEqualTo: _currentUserEmail),
                                          ),
                                          Filter.and(
                                            Filter('from_email', isEqualTo: _currentUserEmail),
                                            Filter('to_email', isEqualTo: userEmail),
                                          ),
                                        ),
                                      )
                                          .orderBy('timestamp', descending: true)
                                          .limit(1)
                                          .get(),
                                      builder: (context, lastMessageSnapshot) {
                                        String lastMessage = "";
                                        String timeAgo = "";

                                        if (lastMessageSnapshot.hasData &&
                                            lastMessageSnapshot.data!.docs.isNotEmpty) {
                                          var doc = lastMessageSnapshot.data!.docs.first;
                                          lastMessage = doc['message'];

                                          if (doc['timestamp'] != null) {
                                            final timestamp = doc['timestamp'] as Timestamp;
                                            final now = DateTime.now();
                                            final messageTime = timestamp.toDate();
                                            final difference = now.difference(messageTime);

                                            if (difference.inDays > 0) {
                                              timeAgo = '${difference.inDays}d';
                                            } else if (difference.inHours > 0) {
                                              timeAgo = '${difference.inHours}h';
                                            } else if (difference.inMinutes > 0) {
                                              timeAgo = '${difference.inMinutes}m';
                                            } else {
                                              timeAgo = 'Just now';
                                            }
                                          }
                                        }

                                        return Card(
                                          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          elevation: unreadCount > 0 ? 2 : 0.5,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ChatDetailScreen(
                                                    userEmail: userEmail,
                                                    userName: userName,
                                                    currentUserEmail: _currentUserEmail!,
                                                    sampleMessages: sampleMessages,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 16,
                                              ),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Stack(
                                                    children: [
                                                      Container(
                                                        width: 60,
                                                        height: 60,
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                            colors: unreadCount > 0
                                                                ? [Colors.blue.shade600, Colors.blue.shade400]
                                                                : [Colors.blue.shade300, Colors.blue.shade200],
                                                          ),
                                                          shape: BoxShape.circle,
                                                          boxShadow: unreadCount > 0
                                                              ? [
                                                            BoxShadow(
                                                              color: Colors.blue.withOpacity(0.3),
                                                              blurRadius: 8,
                                                              offset: Offset(0, 3),
                                                            )
                                                          ]
                                                              : [],
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            userName[0].toUpperCase(),
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 24,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      if (unreadCount > 0)
                                                        Positioned(
                                                          right: 0,
                                                          bottom: 0,
                                                          child: Container(
                                                            width: 16,
                                                            height: 16,
                                                            decoration: BoxDecoration(
                                                              color: Colors.green,
                                                              shape: BoxShape.circle,
                                                              border: Border.all(
                                                                color: Colors.white,
                                                                width: 2,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Text(
                                                              userName,
                                                              style: TextStyle(
                                                                fontWeight: unreadCount > 0
                                                                    ? FontWeight.bold
                                                                    : FontWeight.w600,
                                                                fontSize: 16,
                                                                color: Colors.black87,
                                                              ),
                                                            ),
                                                            Text(
                                                              timeAgo,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: unreadCount > 0
                                                                    ? Colors.blue.shade700
                                                                    : Colors.grey.shade500,
                                                                fontWeight: unreadCount > 0
                                                                    ? FontWeight.bold
                                                                    : FontWeight.normal,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 5),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                lastMessage.isNotEmpty
                                                                    ? lastMessage.length > 40
                                                                    ? lastMessage.substring(0, 40) + '...'
                                                                    : lastMessage
                                                                    : "Start a conversation",
                                                                style: TextStyle(
                                                                  color: unreadCount > 0
                                                                      ? Colors.black87
                                                                      : Colors.grey.shade600,
                                                                  fontSize: 14,
                                                                  fontWeight: unreadCount > 0
                                                                      ? FontWeight.w500
                                                                      : FontWeight.normal,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            if (unreadCount > 0)
                                                              Container(
                                                                margin: EdgeInsets.only(left: 8),
                                                                padding: EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 2,
                                                                ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.blue.shade600,
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Text(
                                                                  unreadCount.toString(),
                                                                  style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                  );
                                } else {
                                  return SizedBox.shrink();
                                }
                              },
                            );
                          } else {
                            return SizedBox.shrink();
                          }
                        },
                      );
                    }).toList(),
                  );
                } else {
                  return Center(child: CircularProgressIndicator(color: Colors.blue));
                }
              },
            );
          } else {
            return Center(child: CircularProgressIndicator(color: Colors.blue));
          }
        },
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String currentUserEmail;

  ChatDetailScreen({
    required this.userEmail,
    required this.userName,
    required this.currentUserEmail, required List<String> sampleMessages,
  });

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Mark messages as read when the chat is opened
  Future<void> _markMessagesAsRead() async {
    // Get all unread messages sent to current user from the other user
    final unreadMessages = await firestore.collection('chats')
        .where('from_email', isEqualTo: widget.userEmail)
        .where('to_email', isEqualTo: widget.currentUserEmail)
        .where('read', isEqualTo: false)
        .get();

    // Update each message to mark as read
    for (var doc in unreadMessages.docs) {
      await firestore.collection('chats').doc(doc.id).update({'read': true});
    }
  }

  @override
  void initState() {
    super.initState();
    // Mark messages as read when screen opens
    _markMessagesAsRead();
  }

  Future<void> _sendMessage(String message) async {
    await firestore.collection('chats').add({
      'from_email': widget.currentUserEmail,
      'to_email': widget.userEmail,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
    _messageController.clear();

    // Scroll to bottom after sending message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade700, Colors.blue.shade500],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.userName[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                image: DecorationImage(
                  image: AssetImage('assets/chat_background.png'),
                  fit: BoxFit.cover,
                  opacity: 0.05,
                ),
              ),
              child: StreamBuilder(
                stream: firestore.collection('chats')
                    .where(
                  Filter.or(
                    Filter.and(
                      Filter('from_email', isEqualTo: widget.currentUserEmail),
                      Filter('to_email', isEqualTo: widget.userEmail),
                    ),
                    Filter.and(
                      Filter('from_email', isEqualTo: widget.userEmail),
                      Filter('to_email', isEqualTo: widget.currentUserEmail),
                    ),
                  ),
                )
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: Colors.blue));
                  }

                  final messages = snapshot.data!.docs;

                  // Mark messages as read when viewed
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markMessagesAsRead();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message['from_email'] == widget.currentUserEmail;
                      final timestamp = message['timestamp'] as Timestamp?;
                      String timeString = '';

                      if (timestamp != null) {
                        final time = timestamp.toDate();
                        final hour = time.hour.toString().padLeft(2, '0');
                        final minute = time.minute.toString().padLeft(2, '0');
                        timeString = '$hour:$minute';
                      }

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(
                            bottom: 8,
                            left: isMe ? 80 : 0,
                            right: isMe ? 0 : 80,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue.shade600 : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                message['message'],
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeString,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white.withOpacity(0.8)
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isMe)
                                    Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        message['read'] ? Icons.done_all : Icons.done,
                                        size: 14,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      maxLines: null, // Allow multiple lines
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade500, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send),
                    color: Colors.white,
                    onPressed: () {
                      if (_messageController.text.trim().isNotEmpty) {
                        _sendMessage(_messageController.text.trim());
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
