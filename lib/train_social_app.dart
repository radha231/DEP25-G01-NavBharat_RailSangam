import 'dart:async';
import 'package:classico/splashscreen.dart';
import 'package:classico/theme_provider.dart';
import 'package:classico/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chats_page.dart';
import 'globals.dart';
import 'login_screen.dart';
import 'notificationPage.dart';

class MessageListenerService {
  StreamSubscription? _messageSubscription;

  void startListening(String currentUserEmail) {
    // Cancel any existing subscription first to prevent memory leaks
    _messageSubscription?.cancel();

    _messageSubscription = FirebaseFirestore.instance.collection('chats')
        .where('to_email', isEqualTo: currentUserEmail)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final message = change.doc.data() as Map<String, dynamic>;
          final senderEmail = message['from_email'];

          final senderDoc = await FirebaseFirestore.instance.collection('Users')
              .where('email_Id', isEqualTo: senderEmail)
              .get();

          if (senderDoc.docs.isNotEmpty) {
            final senderName = senderDoc.docs.first.get('Name');

            NotificationService.showNotification(
              title: 'New message from $senderName',
              body: message['message'],
              payload: senderEmail,
            );
          }
        }
      }
    });
  }

  void stopListening() {
    _messageSubscription?.cancel();
    _messageSubscription = null;  // Clear the subscription after cancelling
  }
}
class TrainSocialApp extends StatefulWidget {
  const TrainSocialApp({super.key});

  @override
  State<TrainSocialApp> createState() => TrainSocialAppState();
}

class TrainSocialAppState extends State<TrainSocialApp> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final MessageListenerService _listenerService = MessageListenerService();
  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.email != null) {
        _listenerService.startListening(user.email!);
      } else {
        _listenerService.stopListening();
      }
    });
    initNotifications();
  }
  @override
  void dispose() {
    _listenerService.stopListening();
    super.dispose();
  }

  // Future<void> updateUserDocuments() async {
  //   final QuerySnapshot snapshot = await firestore.collection('Users').get();
  //
  //   for (var doc in snapshot.docs) {
  //     await doc.reference.update({
  //       'train_no': '12058',
  //       'coach_number': 'C1',
  //       'travel_date': '18-3-2025',
  //     });
  //   }
  //
  //   print('Documents updated successfully!');
  // }

  // Future<void> requestNotificationPermission() async {
  //   var status = await Permission.notification.status;
  //   if (!status.isGranted) {
  //     status = await Permission.notification.request();
  //   }
  // }
  // final GlobalKey<NavigatorState> Globals.navigatorKey = GlobalKey<NavigatorState>();
  Future<void> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }
  Future<void> initNotifications() async {
    requestPermissions();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await Globals.flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          print('Jai shree Krishna!!');
          // Access Navigator using a Builder widget
          Navigator.push(
            Globals.navigatorKey.currentContext!, // Use the navigator key
            MaterialPageRoute(
              builder: (context) => NotificationPage(stationName: notificationResponse.payload!),
            ),
          );
        }
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    // Use Consumer to access the theme provider
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          builder: (context, child) {
            final textScaleFactor = Provider.of<ThemeProvider>(context).textScaleFactor;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaleFactor: textScaleFactor),
              child: child!,
            );
          },
          navigatorKey: Globals.navigatorKey, // Keep the navigator key
          title: 'Train Social',
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(), // Keep SplashScreen as the initial route
          routes: {
            '/login': (context) => const LoginScreen(),
          },
          // Use theme from ThemeProvider instead of hardcoded theme
          theme: themeProvider.currentTheme,
        );
      },
    );
  }

  // Keep this function unchanged
  Future<void> showNextStationNotification(Train selectedTrain) async {
    print('showNextStationNotification called');
    if (selectedTrain.stations.isNotEmpty) {
      String stationName = selectedTrain.stations[0];
      Globals.currentStation= selectedTrain.stations[0];
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'next_station_channel',
        'Next Station Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

      await Globals.flutterLocalNotificationsPlugin.show(
        0,
        'Approaching Next Station',
        'Next station will be: $stationName',
        platformChannelSpecifics,
        payload: stationName,
      );

      // Remove the first station from the list
      selectedTrain.stations.removeAt(0);

      /// RRRRRRRR
      final prefs = await SharedPreferences.getInstance();
      final emailId = prefs.getString('user_email') ?? "";
      String nextStation = selectedTrain.stations[0];
      print("mudit");
      print(nextStation);
      FirebaseFirestore.instance
          .collection('Journey')
          .where('email_id', isEqualTo: emailId)
          .get()
          .then((querySnapshot) {
        for (var doc in querySnapshot.docs) {
          doc.reference.update({'current_station': nextStation});
        }
      }).catchError((error) {
        print("Error updating current_station: $error");
      });
    }
  }
}