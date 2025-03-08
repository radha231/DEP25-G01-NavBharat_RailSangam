import 'package:classico/chatting/model/user.dart';

class Message {
  final User sender;
  final String
  time; // Would usually be type DateTime or Firebase Timestamp in production apps
  final String text;
  final bool isLiked;
  final bool unread;

  Message({
    required this.sender,
    required this.time,
    required this.text,
    required this.isLiked,
    required this.unread,
  });
}

// YOU - current user
final User currentUser = User(
  id: 0,
  name: 'Current User',
  avatar: 'https://randomuser.me/api/portraits/men/21.jpg',
);

// USERS
final User greg = User(
  id: 1,
  name: 'Anirudh',
  avatar: 'assets/images/olivia.jpeg',
);
final User james = User(
  id: 2,
  name: 'Krishna',
  avatar: 'assets/images/james.jpeg',
);
final User john = User(
  id: 3,
  name: 'Mudit',
  avatar: 'assets/images/john.jpeg',
);
final User olivia = User(
  id: 4,
  name: 'Radha',
  avatar: 'assets/images/greg.jpeg',
);
final User sam = User(
  id: 5,
  name: 'Nishant',
  avatar: 'assets/images/james.jpeg',
);
final User sophia = User(
  id: 6,
  name: 'Khushboo',
  avatar: 'assets/images/sophia.jpeg',
);
final User steven = User(
  id: 7,
  name: 'Rakshit',
  avatar: 'assets/images/steven.jpeg',
);

// FAVORITE CONTACTS
List<User> favorites = [sam, steven, olivia, john, greg];

// EXAMPLE CHATS ON HOME SCREEN
List<Message> chats = [
  Message(
    sender: james,
    time: '5:30 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: true,
  ),
  Message(
    sender: olivia,
    time: '4:30 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: true,
  ),
  Message(
    sender: john,
    time: '3:30 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: false,
  ),
  Message(
    sender: sophia,
    time: '2:30 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: true,
  ),
  Message(
    sender: steven,
    time: '1:30 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: false,
  ),
  Message(
    sender: sam,
    time: '12:30 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: false,
  ),
  Message(
    sender: greg,
    time: '11:30 AM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: false,
  ),
];

// EXAMPLE MESSAGES IN CHAT SCREEN
List<Message> messages = [
  Message(
    sender: james,
    time: '5:30 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: true,
    unread: true,
  ),
  Message(
    sender: currentUser,
    time: '4:30 PM',
    text: 'Just walked my doge. She was super duper cute. The best pupper!!',
    isLiked: false,
    unread: true,
  ),
  Message(
    sender: james,
    time: '3:45 PM',
    text: 'How\'s the doggo?',
    isLiked: false,
    unread: true,
  ),
  Message(
    sender: james,
    time: '3:15 PM',
    text: 'All the food',
    isLiked: true,
    unread: true,
  ),
  Message(
    sender: currentUser,
    time: '2:30 PM',
    text: 'Nice! What kind of food did you eat?',
    isLiked: false,
    unread: true,
  ),
  Message(
    sender: james,
    time: '2:00 PM',
    text: 'I ate so much food today.',
    isLiked: false,
    unread: true,
  ),
];







// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../utils.dart';
//
// class MessageField {
//   static const String createdAt = 'createdAt';
// }
//
// class Message {
//   final String idUser;
//   final String urlAvatar;
//   final String username;
//   final String message;
//   final DateTime createdAt;
//
//   Message({
//     required this.idUser,
//     required this.urlAvatar,
//     required this.username,
//     required this.message,
//     required this.createdAt,
//   });
//
//   factory Message.fromJson(Map<String, dynamic> json) {
//     return Message(
//       idUser: json['idUser'],
//       urlAvatar: json['urlAvatar'],
//       username: json['username'],
//       message: json['message'],
//       createdAt: (json['createdAt'] as Timestamp).toDate(),
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'idUser': idUser,
//       'urlAvatar': urlAvatar,
//       'username': username,
//       'message': message,
//       'createdAt': createdAt,
//     };
//   }
// }
