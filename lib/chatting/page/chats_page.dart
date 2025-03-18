import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserEmail();
  }

  void _fetchCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserEmail = prefs.getString('user_email');
      print('Current user BBBBBBB:');
      print(_currentUserEmail);
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
    final users = await firestore.collection('Users').get();
    final userOptions = users.docs.map((doc) {
      return {
        'email': doc.get('email_Id'),
        'name': doc.get('Name'),
      };
    }).toList();

    final selectedUser = await showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Select User'),
          children: userOptions.map((user) => SimpleDialogOption(
            child: Text(user['name']),
            onPressed: () {
              Navigator.of(context).pop(user);
            },
          )).toList(),
        );
      },
    );

    if (selectedUser != null) {
      final messageController = TextEditingController();
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Send Message'),
            content: TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final message = messageController.text;
                  if (message.isNotEmpty) {
                    await _sendMessage(selectedUser['email'], message);
                    Navigator.of(context).pop();
                  }
                },
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
        title: Text('Chatting section'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _showMessageDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMessageDialog,
        child: Icon(Icons.message),
      ),
      backgroundColor: Colors.white,
      body: _currentUserEmail == null
          ? Center(child: CircularProgressIndicator())
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
                    uniqueUsers.add(chat['from_email'] == _currentUserEmail ? chat['to_email'] : chat['from_email']);
                  }
                  return ListView(
                    children: uniqueUsers.map((userEmail) {
                      return FutureBuilder(
                        future: firestore.collection('Users').where('email_Id', isEqualTo: userEmail).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.hasData) {
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
                                  return ListTile(
                                    title: Text(userName, style: TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Unread: $unreadCount'),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      child: Text(userName[0]),
                                    ),
                                    trailing: unreadCount > 0
                                        ? CircleAvatar(
                                      backgroundColor: Colors.red,
                                      radius: 10,
                                      child: Text(unreadCount.toString(), style: TextStyle(fontSize: 12)),
                                    )
                                        : null,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatDetailScreen(
                                            userEmail: userEmail,
                                            userName: userName,
                                            currentUserEmail: _currentUserEmail!,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                } else {
                                  return ListTile(
                                    title: Text(userName, style: TextStyle(fontWeight: FontWeight.bold)),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      child: Text(userName[0]),
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatDetailScreen(
                                            userEmail: userEmail,
                                            userName: userName,
                                            currentUserEmail: _currentUserEmail!,
                                          ),
                                        ),
                                      );
                                    },
                                  );
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
                  return Center(child: CircularProgressIndicator());
                }
              },
            );
          } else {
            return Center(child: CircularProgressIndicator());
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
    required this.currentUserEmail,
  });

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();

  Future<void> _sendMessage(String message) async {
    await FirebaseFirestore.instance.collection('chats').add({
      'from_email': widget.currentUserEmail,
      'to_email': widget.userEmail,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('chats').snapshots(),
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                // Filter messages where either the current user is the sender or receiver.
                final messages = snapshot.data!.docs.where((doc) =>
                (doc['from_email'] == widget.currentUserEmail &&
                    doc['to_email'] == widget.userEmail) ||
                    (doc['from_email'] == widget.userEmail &&
                        doc['to_email'] == widget.currentUserEmail)).toList();

                // Sort messages by timestamp, handling missing timestamps.
                messages.sort((a, b) {
                  final timestampA = a['timestamp'] ?? Timestamp.now();
                  final timestampB = b['timestamp'] ?? Timestamp.now();
                  return timestampB.compareTo(timestampA);
                });

                // Update read status when the screen opens
                for (var message in messages) {
                  if (message['to_email'] == widget.currentUserEmail && !message['read']) {
                    FirebaseFirestore.instance.collection('chats').doc(message.id).update({
                      'read': true,
                    });
                  }
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    bool isMe =
                        message['from_email'] == widget.currentUserEmail;

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin:
                        EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding:
                        EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color:
                          isMe ? Colors.blueAccent : Colors.grey.shade300,
                          borderRadius:
                          BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          message['message'],
                          style: TextStyle(
                            fontSize: 16,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Type a message',
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () async {
                          if (_messageController.text.isNotEmpty) {
                            await _sendMessage(_messageController.text);
                          }
                        },
                      ),
                    ),
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
