import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import './notificationPage.dart';
import 'splashscreen.dart'; // Import the new splash screen
import 'login_screen.dart'; // Import login screen
import 'package:classico/chatting/page/chats_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart'; // Make sure this path is correct
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
String? __currentStation;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// late List<String> all_stations;


Map<String, double> parseCoordinates(String coordinates) {
  // Regular expression to extract numeric values and directions
  final RegExp regex = RegExp(r'([\d.]+)°([NS]),\s*([\d.]+)°([EW])');
  final match = regex.firstMatch(coordinates);

  if (match == null) {
    throw FormatException("Invalid coordinate format");
  }

  double latitude = double.parse(match.group(1)!);
  double longitude = double.parse(match.group(3)!);

  // Adjust sign based on N/S and E/W
  if (match.group(2) == 'S') latitude = -latitude;
  if (match.group(4) == 'W') longitude = -longitude;

  return {'latitude': latitude, 'longitude': longitude};
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double R = 6371.0; // Earth's radius in kilometers

  // Convert degrees to radians
  double toRadians(double degree) => degree * pi / 180.0;

  double dLat = toRadians(lat2 - lat1);
  double dLon = toRadians(lon2 - lon1);

  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(toRadians(lat1)) * cos(toRadians(lat2)) *
          sin(dLon / 2) * sin(dLon / 2);

  double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c; // Distance in kilometers
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    name: 'classico-dc2a9',
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // await _initializeUsersIfEmpty();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (context) => ThemeProvider(),
        ),
        // Add any other providers your app uses
      ],
      child: TrainSocialApp(), // Add this child widget - your root app widget
    ),
  );
}
// Method to initialize users if the collection is empty
// Future<void> _initializeUsersIfEmpty() async {
//   final firebaseApi = FirebaseApi();
//
//   final initialUsers = [
//     User(
//       idUser: '', // Will be auto-generated
//       name: 'John Doe',
//       urlAvatar: 'https://example.com/avatar1.jpg',
//       lastMessageTime: DateTime.now(),
//       email: 'john.doe@example.com',
//     ),
//     User(
//       idUser: '', // Will be auto-generated
//       name: 'Jane Smith',
//       urlAvatar: 'https://example.com/avatar2.jpg',
//       lastMessageTime: DateTime.now(),
//       email: 'jane.smith@example.com',
//     ),
//   ];
//
//   await FirebaseApi.addInitialUsers(initialUsers);
// }
// Add this class to store train data
class Train {
  final String name;
  final List<String> stations;
  final List<String> coordinates;
  final List<String> coaches;
  final String train_no;
  Train({required this.name, required this.stations, required this.coordinates, required this.coaches, required this.train_no});
}

// Add this class to handle location services
class LocationService {
  static Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  static Future<Position?> getCurrentLocation() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return null;
    return await Geolocator.getCurrentPosition();
  }
}

// Modify the LoginPage to include train selection
class LoginPage extends StatefulWidget {
  final String emailId;
  const LoginPage({Key? key, required this.emailId}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState(emailId: this.emailId);
}

class _LoginPageState extends State<LoginPage> {
  final String emailId;

  _LoginPageState({required this.emailId});
  Train? selectedTrain;
  List<Train> trains = [];
  bool isLoading = false;
  bool showCoachDropdown = false;
  String? selectedCoach;
  String? travelDate;
  DateTime? expiryDate;

  // Added for station selection
  String? selectedFromStation;
  String? selectedToStation;
  List<String> availableToStations = [];

  @override
  void initState() {
    super.initState();
    // Check for existing journey immediately when the page loads
    checkExistingJourney();
  }

  String trainNumberInput = "";
  String errorMessage = "";

  // New function to check for existing journeys
  Future<void> checkExistingJourney() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get user email from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');

      if (userEmail != null) {
        // Get current date in the format "dd-MM-yyyy"
        final now = DateTime.now();
        final today = "${now.day}-${now.month}-${now.year}";

        // Query Firestore for journeys with this email and valid travel date
        final querySnapshot = await FirebaseFirestore.instance
            .collection('Journey')
            .where('email_id', isEqualTo: userEmail)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Check if any journey has a travel date >= today
          for (var doc in querySnapshot.docs) {
            final journeyData = doc.data();
            final journeyDate = journeyData['travel_date'] as String?;

            if (journeyDate != null) {
              // Parse dates for comparison
              final List<int> journeyDateParts = journeyDate.split('-')
                  .map((part) => int.parse(part))
                  .toList();
              final journeyDateTime = DateTime(
                  journeyDateParts[2], journeyDateParts[1], journeyDateParts[0]);

              if (journeyDateTime.isAfter(now) ||
                  (journeyDateTime.day == now.day &&
                      journeyDateTime.month == now.month &&
                      journeyDateTime.year == now.year)) {

                // Get train details for navigation
                final trainNo = journeyData['train_no'] as String;
                final coachNumber = journeyData['coach_number'] as String;
                final fromStation = journeyData['from_station'] as String?;
                final toStation = journeyData['to_station'] as String?;

                // Fetch train details
                final trainSnapshot = await FirebaseFirestore.instance
                    .collection('Trains')
                    .where('Train no', isEqualTo: trainNo)
                    .limit(1)
                    .get();

                if (trainSnapshot.docs.isNotEmpty) {
                  final trainData = trainSnapshot.docs.first.data();

                  // Create Train object for navigation
                  final List<String> stations = List<String>.from(trainData['Stops'] ?? []);

                  final List<String> coordinates = [];
                  for (String station in stations) {
                    // all_stations.add(station);
                    QuerySnapshot query = await FirebaseFirestore.instance
                        .collection('Coordinates')
                        .where('Station', isEqualTo: station)
                        .get();

                    String? coordinate;
                    if (query.docs.isNotEmpty) {
                      coordinate = query.docs.first['Coordinates'];
                    }
                    coordinates.add(coordinate ?? "Unknown");
                  }

                  final List<String> coaches = List<String>.from(trainData['Coaches'] ?? []);

                  final train = Train(
                    name: trainData['Train Name'] ?? 'Unnamed Train',
                    train_no: trainData['Train no'] ?? 'Unknown Train Number',
                    stations: stations,
                    coordinates: coordinates,
                    coaches: coaches,
                  );

                  // Navigate to HomePage
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(
                          selectedTrain: train,
                          emailId: userEmail,
                          travelDate: journeyDate,
                          selectedCoach: coachNumber,
                          trainNo: trainNo,
                          fromStation: fromStation,
                          toStation: toStation,
                        ),
                      ),
                    );
                  }

                  // Exit early after navigation
                  return;
                }
              }
            }
          }
        }
      }

      // If we get here, no valid journey was found
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error checking existing journey: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Update To station options based on From station selection
  void updateToStationOptions() {
    if (selectedFromStation != null && selectedTrain != null) {
      final fromIndex = selectedTrain!.stations.indexOf(selectedFromStation!);
      if (fromIndex != -1 && fromIndex < selectedTrain!.stations.length - 1) {
        // Get all stations that come after the selected From station
        setState(() {
          availableToStations = selectedTrain!.stations.sublist(fromIndex + 1);
          selectedToStation = null; // Reset the To station when From changes
        });
      } else {
        setState(() {
          availableToStations = [];
          selectedToStation = null;
        });
      }
    } else {
      setState(() {
        availableToStations = [];
        selectedToStation = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Welcome to\nTrain Social',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        spreadRadius: 5,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Login Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        label: 'Train Number',
                        prefixIcon: Icons.confirmation_number,
                        onChanged: (value) {
                          setState(() {
                            trainNumberInput = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // CustomTextField(
                      //   label: 'Your Interests',
                      //   prefixIcon: Icons.interests,
                      //   hint: 'e.g., Photography, History, Food',
                      // ),
                      if (errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            errorMessage,
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (trainNumberInput.isEmpty) {
                              setState(() {
                                errorMessage = 'Please enter a train number';
                              });
                              return;
                            }

                            setState(() {
                              isLoading = true;
                              errorMessage = '';
                            });

                            try {
                              final querySnapshot = await FirebaseFirestore.instance
                                  .collection('Trains')
                                  .where('Train no', isEqualTo: trainNumberInput)
                                  .limit(1)
                                  .get();
                              print(trainNumberInput);
                              if (querySnapshot.docs.isNotEmpty) {
                                final data = querySnapshot.docs.first.data();

                                final List<String> stations = List<String>.from(data['Stops'] ?? []);
                                final List<String> coordinates = [];
                                for (String station in stations) {
                                  QuerySnapshot query = await FirebaseFirestore.instance
                                      .collection('Coordinates')
                                      .where('Station', isEqualTo: station)
                                      .get();

                                  String? coordinate;
                                  if (query.docs.isNotEmpty) {
                                    coordinate = query.docs.first['Coordinates'];
                                  }
                                  coordinates.add(coordinate ?? "Unknown");
                                }

                                final List<String> coaches = List<String>.from(data['Coaches'] ?? []);
                                // print('coaches:::');
                                // print(coaches);
                                setState(() {
                                  selectedTrain = Train(
                                    name: data['Train Name'] ?? 'Unnamed Train',
                                    train_no: data['Train no'] ?? 'Unknown Train Number',
                                    stations: stations,
                                    coordinates: coordinates,
                                    coaches: coaches,
                                  );
                                  isLoading = false;
                                  showCoachDropdown = true;

                                  // Reset station selections
                                  selectedFromStation = null;
                                  selectedToStation = null;
                                  availableToStations = [];
                                });
                              } else {
                                setState(() {
                                  errorMessage = 'Train number not found. Please check again.';
                                  isLoading = false;
                                });
                              }
                            } catch (e) {
                              setState(() {
                                errorMessage = 'Error fetching train data. Please try again.';
                                isLoading = false;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.blue[900],
                          ),
                          child: isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text(
                            'Get Coaches',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (showCoachDropdown && selectedTrain != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            children: [
                              // From Station Dropdown
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'From Station',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: Icon(Icons.train),
                                ),
                                items: selectedTrain!.stations
                                    .map((station) => DropdownMenuItem(
                                  value: station,
                                  child: Text(station),
                                ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedFromStation = value;
                                  });
                                  updateToStationOptions();
                                },
                              ),
                              const SizedBox(height: 16),

                              // To Station Dropdown
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'To Station',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: Icon(Icons.location_on),
                                ),
                                items: availableToStations
                                    .map((station) => DropdownMenuItem(
                                  value: station,
                                  child: Text(station),
                                ))
                                    .toList(),
                                onChanged: selectedFromStation == null
                                    ? null
                                    : (value) {
                                  setState(() {
                                    selectedToStation = value;
                                  });
                                },
                                hint: Text(selectedFromStation == null
                                    ? 'Select From station first'
                                    : 'Select destination station'),
                              ),
                              const SizedBox(height: 16),

                              // Coach Selection
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Select Your Coach',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: selectedTrain!.coaches
                                    .map((coach) => DropdownMenuItem(
                                  value: coach,
                                  child: Text(coach),
                                ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedCoach = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // Travel Date Selection
                              TextField(
                                controller: TextEditingController(text: travelDate),
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Select Date of Travel',
                                  prefixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onTap: () async {
                                  DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2100),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      travelDate = "${pickedDate.day}-${pickedDate.month}-${pickedDate.year}";
                                      DateTime travelDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
                                      // Calculate expiryDate (end of the next day)
                                      expiryDate = travelDateTime.add(Duration(days: 1));
                                      if (expiryDate != null) {
                                        DateTime localExpiryDate = expiryDate!;
                                        expiryDate = DateTime(
                                            localExpiryDate.year,
                                            localExpiryDate.month,
                                            localExpiryDate.day,
                                            23, 59, 59, 999
                                        );
                                      }
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              // Start Journey Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: (selectedCoach == null ||
                                      (travelDate?.isEmpty ?? true) ||
                                      selectedFromStation == null ||
                                      selectedToStation == null)
                                      ? null
                                      : () async {
                                    // Get Firestore instance
                                    FirebaseFirestore.instance
                                        .collection('Journey')
                                        .where('expiryDate', isLessThan: Timestamp.now())
                                        .get()
                                        .then((snapshot) {
                                      for (var doc in snapshot.docs) {
                                        doc.reference.delete(); // Manually delete expired docs
                                      }
                                    });

                                    FirebaseFirestore firestore = FirebaseFirestore.instance;
                                    await firestore.collection('Journey').add({
                                      'train_no': trainNumberInput,
                                      'email_id': emailId,
                                      'travel_date': travelDate,
                                      'coach_number': selectedCoach,
                                      'from_station': selectedFromStation,
                                      'to_station': selectedToStation,
                                      'timestamp': FieldValue.serverTimestamp(),
                                      'expiryDate': Timestamp.fromDate(expiryDate!), // Firestore timestamp
                                    }).then((_) {
                                      // Save email to shared preferences
                                      SharedPreferences.getInstance().then((prefs) {
                                        prefs.setString('user_email', emailId);
                                      });

                                      // Navigate to Home Page after successful Firestore entry
                                      print('Navigating to HomePage');
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HomePage(
                                            selectedTrain: selectedTrain!,
                                            emailId: emailId,
                                            travelDate: travelDate!,
                                            selectedCoach: selectedCoach!,
                                            trainNo: trainNumberInput,
                                            fromStation: selectedFromStation,
                                            toStation: selectedToStation,
                                          ),
                                        ),
                                      );
                                      print('Successfully Navigated to HomePage');
                                    }).catchError((error) {
                                      // Handle errors if the Firestore entry fails
                                      print("Failed to add journey: $error");
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                  child: Text(
                                    'Start Journey',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class MessageListenerService {
  StreamSubscription? _messageSubscription;

  void startListening(String currentUserEmail) {
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
  }
}
class TrainSocialApp extends StatefulWidget {
  const TrainSocialApp({super.key});

  @override
  State<TrainSocialApp> createState() => _TrainSocialAppState();
}

class _TrainSocialAppState extends State<TrainSocialApp> {
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
  // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
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

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          print('Jai shree Krishna!!');
          // Access Navigator using a Builder widget
          Navigator.push(
            navigatorKey.currentContext!, // Use the navigator key
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
          navigatorKey: navigatorKey, // Keep the navigator key
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
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'next_station_channel',
        'Next Station Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        0,
        'Approaching Next Station',
        'Next station will be: $stationName',
        platformChannelSpecifics,
        payload: stationName,
      );

      // Remove the first station from the list
      selectedTrain.stations.removeAt(0);
    }
  }
}


class HomePage extends StatefulWidget {
  final Train selectedTrain;
  final String emailId;
  final String travelDate;
  final String selectedCoach;
  final String trainNo;
  final String? fromStation;
  final String? toStation;

  const HomePage({required this.selectedTrain,required this.emailId,required this.travelDate,required this.selectedCoach,required this.trainNo, required this.fromStation, required this.toStation, super.key});

  @override
  State<HomePage> createState() => _HomePageState(emailId: this.emailId, travelDate: travelDate, selectedCoach: selectedCoach, trainNo: trainNo, fromStation:fromStation, toStation: toStation );
}

class _HomePageState extends State<HomePage> {
  final String emailId;
  final String travelDate;
  final String selectedCoach;
  final String trainNo;
  final String? fromStation;
  final String? toStation;
  _HomePageState({required this.emailId, required this.travelDate, required this.selectedCoach, required this.trainNo, required this.fromStation, required this.toStation});
  int _selectedIndex = 0;
  late List<Widget> _pages;
  Timer? _locationTimer;
  int currentStationIndex = 0;
  double distanceRemaining =1000.0;

  @override
  void initState() {
    super.initState();
    _pages = [
      TravelersPage(emailId: emailId, travelDate: travelDate, selectedCoach: selectedCoach, trainNo: trainNo, fromStation: fromStation, toStation: toStation),
      LocationInfoPage(selectedTrain: widget.selectedTrain, fromStation: fromStation, toStation: toStation),
      HomeScreen(),
      ProfilePage(emailId : this.emailId),
    ];
    startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void startLocationTracking() {
    /////////////////////////////////
    int fromIndex = -1;
    for (int i = 0; i < widget.selectedTrain.stations.length; i++) {
      if (widget.selectedTrain.stations[i] == fromStation) {
        fromIndex = i;
        break;
      }
    }
    print("Fromindex::");
    print(fromIndex);
    // If found, remove all stations before it
    if (fromIndex != -1) {
      for (int i = 0; i < fromIndex; i++) {
        widget.selectedTrain.stations.removeAt(0); // Always remove the first element
      }
    }
    _locationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        checkNearestStation(position);
      }
    });
  }

  void checkNearestStation(Position position) {

    String coordinates = widget.selectedTrain.coordinates[currentStationIndex];
    __currentStation = widget.selectedTrain.stations[0];
    Map<String, double> result = parseCoordinates(coordinates);
    print("Flag..............");
    print(result["latitude"]);
    print(result["longitude"]);
    print(position.latitude);
    print(position.longitude);
    double distance = calculateDistance(position.latitude, position.longitude, result["latitude"]!, result["longitude"]!);
    if(distance> distanceRemaining){
      // currentStationIndex++;
      distanceRemaining = 1000;
    }
    else{
      distanceRemaining = distance;
    }
    print("Distance");
    print(distanceRemaining);
    if (currentStationIndex < widget.selectedTrain.stations.length - 1 && distanceRemaining < 15) {
      final trainSocialAppState = context.findAncestorStateOfType<_TrainSocialAppState>();

      if (trainSocialAppState != null) {
        currentStationIndex++;
        trainSocialAppState.showNextStationNotification(widget.selectedTrain);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate sizes based on screen width for better responsiveness
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / 4; // Width allocated for each nav item
    final selectorSize = 50.0; // Size of our squircle selector

    // Calculate the left position of the selector
    final selectorLeft = (itemWidth * _selectedIndex) + (itemWidth / 2) - (selectorSize / 2);

    return Scaffold(
      body: _pages[_selectedIndex],
      extendBody: true,
      bottomNavigationBar: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(2),
          ),
        ),
        margin: EdgeInsets.zero, // Remove all margins
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Floating selector "squircle" (between square and circle)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCirc,
              left: selectorLeft,
              top: 5,
              child: Container(
                height: selectorSize,
                width: selectorSize,
                decoration: BoxDecoration(
                  color: Color(0xFFE8935E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Icon(
                    _getSelectedIcon(_selectedIndex),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),

            // Row of icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.group_outlined, 'Travellers'),
                _buildNavItem(1, Icons.location_on_outlined, 'Location'),
                _buildNavItem(2, Icons.chat_bubble_outline, 'Chats'),
                _buildNavItem(3, Icons.person_outline, 'Profile'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          height: 60,
          color: Colors.transparent,
          child: Center(
            child: _selectedIndex == index
                ? SizedBox(width: 20)
                : Icon(
              icon,
              color: Colors.grey,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getSelectedIcon(int index) {
    switch (index) {
      case 0:
        return Icons.group;
      case 1:
        return Icons.location_on;
      case 2:
        return Icons.chat_bubble;
      case 3:
        return Icons.person;
      default:
        return Icons.group;
    }
  }
}

// Update LocationInfoPage to show selected train information
class LocationInfoPage extends StatefulWidget {
  final Train selectedTrain;
  final String? fromStation;
  final String? toStation;
  const LocationInfoPage({required this.selectedTrain, super.key, required this.fromStation, required this.toStation});

  @override
  State<LocationInfoPage> createState() => _LocationInfoPageState();
}

class _LocationInfoPageState extends State<LocationInfoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue[800]!,
                      Colors.blue[600]!,
                      Colors.blue[400]!,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Train tracks pattern
                    Positioned.fill(
                      child: CustomPaint(
                        painter: TrainTrackPainter(),
                      ),
                    ),
                    // Simple decorative elements
                    Positioned(
                      top: 40,
                      right: 30,
                      child: Icon(
                        Icons.location_on,
                        size: 35,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    Positioned(
                      bottom: 60,
                      left: 20,
                      child: Icon(
                        Icons.train_rounded,
                        size: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    Positioned(
                      top: 80,
                      left: 120,
                      child: Icon(
                        Icons.public,
                        size: 30,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    // TrainAssist quote
                    // In the FlexibleSpaceBar background section, update the Positioned widget for the TrainAssist quote
                    Positioned(
                      top: 70,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            "TrainAssist",
                            style: TextStyle(
                              fontSize: 24, // Increased from 22
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.7), // Increased shadow opacity
                                  offset: const Offset(1.5, 1.5), // Slightly larger offset
                                  blurRadius: 4, // Increased blur radius
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12), // Increased from 10
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            // Add a semi-transparent background for better readability
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Journey smoother, destinations closer",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16, // Increased from 15
                                fontWeight: FontWeight.w500, // Added medium weight
                                fontStyle: FontStyle.italic,
                                color: Colors.white, // Full opacity instead of 0.9
                                letterSpacing: 0.5,
                                // shadows: [
                                //   Shadow(
                                //     color: Colors.black.withOpacity(0.6), // Increased shadow opacity
                                //     offset: const Offset(1, 1),
                                //     blurRadius: 3, // Increased blur
                                //   ),
                                // ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14), // Increased from 12
                          Container(
                            width: 60, // Slightly wider
                            height: 3, // Slightly thicker
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8), // Increased opacity
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Train name and info card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blue[700],
                              child: const Icon(
                                Icons.train_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.selectedTrain.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.departure_board, color: Colors.blue[700], size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Journey Information',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'From: ${widget.selectedTrain.stations.first}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                'To: ${widget.selectedTrain.stations.last}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              // Text(
                              //   'Train ID: ${widget.selectedTrain ?? 'N/A'}',
                              //   style: const TextStyle(fontSize: 13),
                              // ),
                              // Text(
                              //   'Status: On Time',
                              //   style: TextStyle(
                              //     color: Colors.green[700],
                              //     fontWeight: FontWeight.bold,
                              //     fontSize: 13,
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Upcoming Stops',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.selectedTrain.stations.length,
                  itemBuilder: (context, index) {
                    return StopCard(
                      name: widget.selectedTrain.stations[index],
                      time: index == 0 ? 'Current Stop' : '',
                      distance: index == 0 ? 'Now' : '',
                      isCurrentStop: index == 0,
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for train track pattern
class TrainTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dashWidth = 10.0;
    final dashSpace = 10.0;
    final startY = size.height * 0.35;
    final endY = size.height * 0.65;

    // Draw two parallel lines
    final path1 = Path();
    path1.moveTo(0, startY);
    path1.lineTo(size.width, startY);

    final path2 = Path();
    path2.moveTo(0, endY);
    path2.lineTo(size.width, endY);

    // Draw the dashed lines
    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);

    // Draw vertical connectors
    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      canvas.drawLine(
        Offset(i, startY),
        Offset(i, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StopCard extends StatelessWidget {
  final String name;
  final String time;
  final String distance;
  final bool isCurrentStop;

  const StopCard({
    required this.name,
    required this.time,
    required this.distance,
    this.isCurrentStop = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentStop ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isCurrentStop
            ? BorderSide(color: Colors.blue[700]!, width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isCurrentStop ? Colors.blue[700] : Colors.grey[300],
            child: Icon(
              isCurrentStop ? Icons.train : Icons.train_outlined,
              size: 14,
              color: isCurrentStop ? Colors.white : Colors.grey[700],
            ),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: isCurrentStop ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            'Arrival: $time',
            style: TextStyle(
              color: isCurrentStop ? Colors.blue[700] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isCurrentStop ? Colors.blue[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distance,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isCurrentStop ? Colors.blue[700] : Colors.black87,
                  ),
                ),
                Text(
                  isCurrentStop ? '' : '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class CustomTextField extends StatelessWidget {
  final String label;
  final IconData prefixIcon;
  final String? hint;
  final Function(String)? onChanged; // Added onChanged callback

  const CustomTextField({
    required this.label,
    required this.prefixIcon,
    this.hint,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: onChanged, // Added onChanged to handle user input
    );
  }
}


class TravelersPage extends StatefulWidget {
  final String emailId;
  final String travelDate;
  final String selectedCoach;
  final String trainNo;
  final String? fromStation;
  final String? toStation;
  const TravelersPage({required this.emailId, required this.travelDate, required this.selectedCoach, required this.trainNo,super.key, required this.fromStation, required this.toStation});

  @override
  _TravelersPageState createState() => _TravelersPageState(emailId: emailId, travelDate: travelDate, selectedCoach: selectedCoach, trainNo: trainNo, fromStation:fromStation, toStation: toStation);
}

class _TravelersPageState extends State<TravelersPage> {
// ... (keep all your existing variables and methods)
  final String emailId;
  final String travelDate;
  final String selectedCoach;
  final String trainNo;
  final String? fromStation;
  final String? toStation;
  _TravelersPageState({required this.emailId, required this.travelDate, required this.selectedCoach, required this.trainNo, required this.fromStation, required this.toStation});
// User's own data

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Map<String, dynamic> currentUser = {
    'name': 'Loading...',
    'avatar': 'assets/images/sam.png',
  };

  Future<Map<String, dynamic>> _fetchCurrentUserDetails() async {
    try {
      final QuerySnapshot userSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final userDoc = userSnapshot.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>;

        // Ensure we have a valid avatar URL or use default
        String avatarUrl = userData['avatarUrl']?.toString() ?? '';
        print("\n\n\n\n\\n\n\n\n\n\n avatar of cuureent user is: $avatarUrl\n\n\n\n\n\n");
        if (avatarUrl.isEmpty) {
          avatarUrl = 'assets/images/sam.png';
        }

        return {
          'name': userData['Name'] ?? 'Unknown',
          'avatarUrl': avatarUrl, // Use consistent field name
        };
      } else {
        throw Exception('Current user document not found: $emailId');
      }
    } catch (e) {
      print('Error fetching current user details: $e');
      return {
        'name': 'Unknown',
        'avatarUrl': 'assets/images/sam.png',
      };
    }
  }
// Sample data for friends


  List<Map<String, dynamic>> _allSuggestedUsers = []; // Original list

// Hover state tracking
  List<dynamic> following =[];
  final Map<String, bool> _followRequestStates = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> suggestedUsers = [];
  bool _isLoading = false;
  bool _isFirstLoad = true;
  late SharedPreferences _prefs;



  @override
  void initState() {
    super.initState();
    _initSharedPrefs().then((_) {
      _initializeNotifications();
      if (_isFirstLoad) {
        _checkForPendingNotifications();
        _clearOldNotifications();
      }
    });
    _fetchCurrentUserDetails().then((userDetails) {
      setState(() {
        currentUser = userDetails;
      });
    });
    _fetchSuggestedUsers();
    _removeOverlappingRejectedRequests(emailId);
  }

  Future<void> _clearOldNotifications() async {
    try {
      final currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId)
          .get();

      if (currentUserSnapshot.docs.isNotEmpty) {
        await _firestore.collection('Users')
            .doc(currentUserSnapshot.docs.first.id)
            .update({
          'notifications': [],
        });
      }
    } catch (e) {
      print('Error clearing old notifications: $e');
    }
  }


  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<void> _initSharedPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final lastLoginTime = _prefs.getInt('lastLoginTime') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // Consider it a new login if last login was more than 30 minutes ago
    if (currentTime - lastLoginTime > 30 * 60 * 1000) {
      await _prefs.setInt('lastLoginTime', currentTime);
      _checkForPendingNotifications();
    }

    _isFirstLoad = false;
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(

      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {

        if (response.payload != null) {
          print("CCC");
          // print(all_stations);
          if(response.payload == __currentStation){
            print("AAAAA");
            Navigator.push(
              navigatorKey.currentContext!, // Use the navigator key
              MaterialPageRoute(
                builder: (context) => NotificationPage(stationName: response.payload!),
              ),
            );
          }
          else{
            print("BBB");
            // print(all_stations);
            _handleNotificationTap_Traveller(response.payload!);
          }

        }
        else{
          print("BB");
        }
      },
    );
  }

  Future<String?> _getAvatarForNotification(String email) async {
    try {
      final userSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
        return userData['avatarUrl'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching avatar: $e');
      return null;
    }
  }


  String? selectedProfession;
  String? selectedAgeGroup;
  String? selectedGender;
  String? selectedInterest;
// Define lists for dropdown options
  final List<String> professions = ['Student', 'Engineer', 'Doctor', 'Artist', 'Other'];
  final List<String> ageGroups = ['18-24', '25-34', '35-44', '45-54', '55+'];
  final List<String> genders = ['Male', 'Female'];
  final List<String> interestList =['Reading',
    'Cooking',
    'Fitness',
    'Photography',
    'Travel',
    'Music',
    'Gaming',
    'Art',
    'Technology',
    'Outdoor Activities',
    'Other',];
// Updated gradient colors to match the reference image
  final Gradient appBarGradient = LinearGradient(
    colors: [
      Color(0xFF4A89DC),
      Color(0xFF5D9CEC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final Gradient buttonGradient = LinearGradient(
    colors: [
      Color(0xFF4A89DC),
      Color(0xFF5D9CEC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );


  Widget _buildSvgAvatar({
    required String? avatarUrl,
    double size = 56.0,
  }) {
    final String effectiveUrl = avatarUrl ?? 'assets/images/sam.png';

    try {
      return ClipOval(
        child: effectiveUrl.startsWith('http')
            ? (effectiveUrl.endsWith('.svg')
            ? SvgPicture.network(
          effectiveUrl,
          width: size,
          height: size,
          placeholderBuilder: (context) => _buildPlaceholder(size),
          fit: BoxFit.cover,
        )
            : Image.network(
          effectiveUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(size),
        ))
            : Image.asset(
          effectiveUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(size),
        ),
      );
    } catch (e) {
      return _buildPlaceholder(size);
    }
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Icon(Icons.person, size: size / 2),
    );
  }


  Future<void> _fetchSuggestedUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch the current user's document
      final QuerySnapshot currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId)
          .get();

      if (currentUserSnapshot.docs.isEmpty) {
        throw Exception('Current user document not found: $emailId');
      }

      final currentUserDoc = currentUserSnapshot.docs.first;
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;

      // Get the current user's pendingApprovals & following list
      final List<dynamic> pendingApprovals = currentUserData['pendingApprovals'] ?? [];
      following = currentUserData['following'] ?? [];

      // Fetch all users in the same journey (train, coach, and date)
      final QuerySnapshot journeySnapshot = await _firestore
          .collection('Journey')
          .where('train_no', isEqualTo: trainNo.trim())
          .where('coach_number', isEqualTo: selectedCoach.trim())
          .where('travel_date', isEqualTo: travelDate.trim())
          .get();

      final Set<String> uniqueEmails = {}; // Store unique email_ids

      for (var doc in journeySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Exclude the current user and already-followed users
        if (data['email_id'] != emailId &&
            !uniqueEmails.contains(data['email_id'])) {
          uniqueEmails.add(data['email_id']);
        }
      }

      // Fetch user details from "Users" collection for uniqueEmails
      List<Map<String, dynamic>> users = [];

      if (uniqueEmails.isNotEmpty) {
        final QuerySnapshot usersSnapshot = await _firestore
            .collection('Users')
            .where('email_Id', whereIn: uniqueEmails.toList())
            .get();

        for (var doc in usersSnapshot.docs) {
          final userData = doc.data() as Map<String, dynamic>;
          users.add(userData);
        }
      }

      // Initialize follow request states
      for (var user in users) {
        _followRequestStates[user['email_Id']] = pendingApprovals.contains(user['email_Id']);
      }

      setState(() {
        suggestedUsers = users;
        _allSuggestedUsers = List.from(users); // Store the original list
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching suggested users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching suggested users: $e')),
      );
    }
  }

// Send follow request
  Future<void> _sendFollowRequest(String targetEmail) async {
    try {
      // Disable the button and update the state
      setState(() {
        _followRequestStates[targetEmail] = true; // Mark request as sent
      });

      // Get the current user's email
      final currentUserEmail = emailId;

      // Fetch the target user's document
      final QuerySnapshot targetUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: targetEmail.trim())
          .get();

      if (targetUserSnapshot.docs.isEmpty) {
        throw Exception('Target user document not found: $targetEmail');
      }

      final targetUserDocId = targetUserSnapshot.docs.first.id;

      // Fetch the current user's document
      final QuerySnapshot currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: currentUserEmail.trim())
          .get();

      if (currentUserSnapshot.docs.isEmpty) {
        throw Exception('Current user document not found: $currentUserEmail');
      }

      final currentUserDocId = currentUserSnapshot.docs.first.id;

      // Add target user to current user's pendingApprovals
      await _firestore.collection('Users').doc(currentUserDocId).update({
        'pendingApprovals': FieldValue.arrayUnion([targetEmail]),
      });

      // Add current user to target user's followRequests
      await _firestore.collection('Users').doc(targetUserDocId).update({
        'followRequests': FieldValue.arrayUnion([currentUserEmail]),
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow request sent to $targetEmail')),
      );
    } catch (e) {
      print('Error sending follow request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send follow request: $e')),
      );

      // Re-enable the button if there's an error
      setState(() {
        _followRequestStates[targetEmail] = false;
      });
    }
  }

  Future<void> _removeOverlappingRejectedRequests(String currentUserEmail) async {
    try {
      // Fetch the current user's document
      final QuerySnapshot currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: currentUserEmail)
          .get();

      if (currentUserSnapshot.docs.isEmpty) {
        throw Exception('Current user document not found: $currentUserEmail');
      }

      final currentUserDoc = currentUserSnapshot.docs.first;
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;

      // Get the acceptedRequests and rejectedRequests lists
      final List<dynamic> acceptedRequests = currentUserData['acceptedRequests'] ?? [];
      final List<dynamic> rejectedRequests = currentUserData['rejectedRequests'] ?? [];

      // Find overlapping entries
      final List<dynamic> overlappingEntries = rejectedRequests
          .where((email) => acceptedRequests.contains(email))
          .toList();

      // If there are overlapping entries, remove them from rejectedRequests
      if (overlappingEntries.isNotEmpty) {
        await _firestore.collection('Users').doc(currentUserDoc.id).update({
          'rejectedRequests': FieldValue.arrayRemove(overlappingEntries),
        });

        print('[DEBUG] Removed overlapping entries from rejectedRequests: $overlappingEntries');
      }
    } catch (e) {
      print('[DEBUG] Error removing overlapping rejected requests: $e');
    }
  }



// Updated hoverable icon button with better styling
  Widget _buildHoverableIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isToggled = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isToggled ? Colors.white.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

// Updated modal card style for notifications, follow requests, etc.
  Widget _buildModalCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Color(0xFFE8F0FE),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 60,
              height: 5,
              margin: EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A89DC),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildUserAvatar({
    required String? avatarUrl,
    required String? name,
    required String email,
    double size = 56.0,
    VoidCallback? onTap,
  }) {
    final String effectiveUrl = avatarUrl ?? 'assets/images/sam.png';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SVG Avatar Circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200], // Background color
            ),
            child: ClipOval(
              child: effectiveUrl.startsWith('http')
                  ? SvgPicture.network(
                effectiveUrl,
                width: size,
                height: size,
                placeholderBuilder: (context) => Center(
                  child: CircularProgressIndicator(),
                ),
                fit: BoxFit.cover,
              )
                  : Image.asset(
                effectiveUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            name ?? 'Unknown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  ImageProvider _getAvatarImageProvider(String url) {
    if (url.startsWith('http')) {
      return NetworkImage(url);
    } else if (url.startsWith('assets/')) {
      return AssetImage(url);
    } else {
      return AssetImage('assets/images/sam.png');
    }
  }

// Updated filter row with better styling
  Widget _buildFilterRow() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: selectedProfession,
                  hint: 'Profession',
                  items: professions,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedProfession = newValue;
                    });
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _buildFilterDropdown(
                  value: selectedAgeGroup,
                  hint: 'Age Group',
                  items: ageGroups,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedAgeGroup = newValue;
                    });
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: selectedGender,
                  hint: 'Gender',
                  items: genders,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedGender = newValue;
                    });
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _buildFilterDropdown(
                  value: selectedInterest,
                  hint: 'Interest',
                  items: interestList,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedInterest = newValue;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint, style: TextStyle(color: Colors.grey[600])),
        isExpanded: true,
        underline: SizedBox(),
        icon: Icon(Icons.arrow_drop_down, color: Color(0xFF4A89DC)),
        style: TextStyle(color: Colors.black87, fontSize: 14),
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }

  // Updated filter buttons with better styling
  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                gradient: buttonGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4A89DC).withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _applyFilters,
                child: Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFF4A89DC)),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _clearFilters,
                child: Text(
                  'Clear Filters',
                  style: TextStyle(
                    color: Color(0xFF4A89DC),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      suggestedUsers = _allSuggestedUsers.where((user) {
        bool matchesProfession = selectedProfession == null || user['Profession'] == selectedProfession;
        bool matchesAgeGroup = selectedAgeGroup == null || user['Age Group'] == selectedAgeGroup;
        bool matchesGender = selectedGender == null || user['Gender'] == selectedGender;

        // Interest filter: check if selectedInterest exists in user's Interests list
        bool matchesInterest = selectedInterest == null ||
            (user['Interests'] != null && (user['Interests'] as List).contains(selectedInterest));

        // Debug logs
        print('User: ${user['email_id']}');
        print('Profession: ${user['Profession']}, Selected: $selectedProfession, Matches: $matchesProfession');
        print('AgeGroup: ${user['Age Group']}, Selected: $selectedAgeGroup, Matches: $matchesAgeGroup');
        print('Gender: ${user['Gender']}, Selected: $selectedGender, Matches: $matchesGender');
        print('Interests: ${user['Interests']}, Selected: $selectedInterest, Matches: $matchesInterest');
        print('---');

        return matchesProfession && matchesAgeGroup && matchesGender && matchesInterest;
      }).toList();
    });

    print('Filtered Users: ${suggestedUsers.length}');
  }
// Add a method to clear filters
  void _clearFilters() {
    setState(() {
      selectedProfession = null;
      selectedAgeGroup = null;
      selectedGender = null;
      selectedInterest = null;
      suggestedUsers = List.from(_allSuggestedUsers); // Reset to the original list
    });
  }


  Widget _buildSuggestionTile({
    required String? avatarUrl,
    required String? name,
    required String? email,
  }) {
    if (email == null) {
      return ListTile(
        title: Text('Invalid user'),
      );
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('Users')
          .where('email_Id', isEqualTo: emailId)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Center(child: CircularProgressIndicator()),
            ),
            title: Text(name ?? 'Unknown'),
            subtitle: Text(email),
            trailing: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return ListTile(
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Icon(Icons.error),
            ),
            title: Text(name ?? 'Unknown'),
            subtitle: Text(email),
            trailing: Text('Error'),
          );
        }

        final userData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final List<dynamic> pendingApprovals = userData['pendingApprovals'] ?? [];
        final List<dynamic> following = userData['following'] ?? [];

        String buttonText;
        VoidCallback? onPressed;

        if (pendingApprovals.contains(email)) {
          buttonText = 'Request Sent';
          onPressed = null;
        } else if (following.contains(email)) {
          buttonText = 'Following';
          onPressed = null;
        } else {
          buttonText = 'Follow';
          onPressed = () {
            _sendFollowRequest(email);
          };
        }

        return ListTile(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? SvgPicture.network(
                avatarUrl,
                fit: BoxFit.cover,
                placeholderBuilder: (context) => Center(
                  child: CircularProgressIndicator(),
                ),
              )
                  : Icon(Icons.person, size: 28),
            ),
          ),
          title: Text(name ?? 'Unknown'),
          subtitle: Text(email),
          trailing: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: onPressed == null ? Colors.grey : Colors.blue,
            ),
            child: Text(
              buttonText,
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }


  Future<Map<String, dynamic>> _fetchUserDetails(String emailId) async {
    try {
      final QuerySnapshot userSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId.trim())
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final userDoc = userSnapshot.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>;

        // Get the avatar URL from database
        String avatarUrl = userData['avatarUrl']?.toString() ?? '';

        // If URL is empty or invalid, use default
        if (avatarUrl.isEmpty) {
          avatarUrl = 'assets/images/sam.png';
        }
        // If it's an SVG URL, convert to PNG if from DiceBear
        else if (avatarUrl.contains('dicebear.com') && avatarUrl.contains('.svg')) {
          avatarUrl = avatarUrl.replaceFirst('.svg', '.png');
        }

        return {
          'Name': userData['Name'] ?? 'Unknown',
          'avatarUrl': avatarUrl,
        };
      } else {
        return {
          'Name': 'Unknown',
          'avatarUrl': 'assets/images/sam.png',
        };
      }
    } catch (e) {
      print('Error fetching user details: $e');
      return {
        'Name': 'Unknown',
        'avatarUrl': 'assets/images/sam.png',
      };
    }
  }


  Widget _buildUniversalAvatar({
    required String imageUrl,
    required String name,
    double radius = 28,
  }) {
    if (imageUrl.startsWith('assets/')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(imageUrl),
      );
    }

    if (imageUrl.endsWith('.svg')) {
      return SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: SvgPicture.network(
            imageUrl,
            placeholderBuilder: (context) => CircleAvatar(
              radius: radius,
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        imageBuilder: (context, imageProvider) => Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[200],
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[200],
          child: Icon(Icons.person, size: radius),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: appBarGradient,
          ),
        ),
        title: Container(
          alignment: Alignment.centerLeft, // Align title to the left
          padding: EdgeInsets.only(left: 16), // Add left padding
          child: Text(
            'Travellers',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        centerTitle: false, // Disable center alignment
        actions: [
          _buildHoverableIconButton(
            icon: Icons.notifications,
            onPressed: _showNotifications,
          ),
          _buildHoverableIconButton(
            icon: Icons.group_add,
            onPressed: _showFollowRequests,
          ),
          _buildHoverableIconButton(
            icon: Icons.pending_actions,
            onPressed: _showPendingApprovals,
          ),
          SizedBox(width: 10),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current User and Following Users' Avatars
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Connections',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    // Current User's Avatar
                    Padding(
                      padding: const EdgeInsets.only(right: 15),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildUserAvatar(
                            avatarUrl: currentUser['avatarUrl'],
                            name: currentUser['name'] ?? 'You',
                            email: emailId,
                          )
                        ],
                      ),
                    ),
                    // Following Users' Avatars
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: following.map((email) {
                            return FutureBuilder<Map<String, dynamic>>(
                              future: _fetchUserDetails(email),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: CircleAvatar(radius: 30, backgroundColor: Colors.grey[200]),
                                  );
                                } else if (snapshot.hasError) {
                                  return Icon(Icons.error);
                                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: _buildUserAvatar(
                                        avatarUrl: currentUser['avatarUrl'],
                                        name: currentUser['name'] ?? 'You',
                                        email: emailId,
                                      )
                                  );
                                } else {
                                  final userDetails = snapshot.data!;
                                  return Padding(
                                    padding: EdgeInsets.only(right: 15),
                                    child: _buildUserAvatar(
                                      avatarUrl: userDetails['avatarUrl'],
                                      name: userDetails['Name'],
                                      email: email,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => HomeScreen(
                                              selectedUserEmail: email,
                                              selectedUserName: userDetails['Name'],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Travellers Suggestions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          // Add the filter row
          _buildFilterRow(),

          // Add the filter buttons
          _buildFilterButtons(),

          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('Users')
                  .where('email_Id', isEqualTo: emailId) // Fetch the current user's data
                  .limit(1)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Error loading user data'));
                }

                final userData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                final List<dynamic> following = userData['following'] ?? [];
                final List<dynamic> pendingApprovals = userData['pendingApprovals'] ?? [];

                // Sort the suggestedUsers list
                suggestedUsers.sort((a, b) {
                  final aEmail = a['email_Id'];
                  final bEmail = b['email_Id'];

                  bool aFollowing = following.contains(aEmail);
                  bool bFollowing = following.contains(bEmail);
                  bool aPending = pendingApprovals.contains(aEmail);
                  bool bPending = pendingApprovals.contains(bEmail);

                  if (aFollowing && !bFollowing) return -1; // a should come first
                  if (!aFollowing && bFollowing) return 1;  // b should come first
                  if (aPending && !bPending) return -1;     // a should come first
                  if (!aPending && bPending) return 1;      // b should come first
                  return 0; // Keep original order if all conditions are equal
                });

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: suggestedUsers.length,
                  itemBuilder: (context, index) {
                    final user = suggestedUsers[index];
                    return FutureBuilder<Map<String, dynamic>>(
                      future: _fetchUserDetails(user['email_Id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return ListTile(
                            title: Text('Error loading user details'),
                          );
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return ListTile(
                            title: Text('User details not found'),
                          );
                        } else {
                          final userDetails = snapshot.data!;
                          return _buildSuggestionTile(
                            avatarUrl: userDetails['avatarUrl'] as String?,
                            name: userDetails['Name'] as String?,
                            email: user['email_Id'] as String?,
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          )
          ,
        ],
      ),
    );
  }
  void _showNotifications() async {
    try {
      final QuerySnapshot currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId)
          .get();

      if (currentUserSnapshot.docs.isEmpty) return;

      final currentUserDoc = currentUserSnapshot.docs.first;
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final List<dynamic> notifications = currentUserData['notifications'] ?? [];
      final List<dynamic> notif = currentUserData['notifs'] ?? [];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _buildModalCard(
            title: 'Notifications',
            children: [
              if (notif.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No notifications.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ...notif.reversed.map((notification) { // Show newest first
                return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    notification.toString(),
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
            ],
          );
        },
      );

      // DON'T clear notifications here - they should persist
      // Only mark as shown in SharedPreferences for push notifications
      final List<dynamic> shownNotifications = _prefs.getStringList('shownNotifications') ?? [];
      await _prefs.setStringList(
        'shownNotifications',
        [...shownNotifications, ...notifications.map((n) => n.toString())],
      );

    } catch (e) {
      print('Error showing notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing notifications: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFollowRequests() async {
    try {
      // Get the current user's email
      final currentUserEmail = emailId;

      // Fetch the current user's document using a query
      final QuerySnapshot currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: currentUserEmail)
          .get();

      if (currentUserSnapshot.docs.isEmpty) {
        throw Exception('Current user document not found: $currentUserEmail');
      }

      // Get the current user's document
      final currentUserDoc = currentUserSnapshot.docs.first;
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;

      // Get the followRequests list
      final List<dynamic> followRequests = currentUserData['followRequests'] ?? [];

      // List to store users with pending follow requests
      final List<Map<String, dynamic>> usersWithRequests = [];

      // Fetch details of users in the followRequests list
      for (final requesterEmail in followRequests) {
        final requesterSnapshot = await _firestore
            .collection('Users')
            .where('email_Id', isEqualTo: requesterEmail)
            .get();

        if (requesterSnapshot.docs.isNotEmpty) {
          final requesterData = requesterSnapshot.docs.first.data() as Map<String, dynamic>;
          usersWithRequests.add({
            'email': requesterEmail,
            'name': requesterData['Name'],
            'avatar': requesterData['avatarUrl'],
          });
        }
      }

      print('[DEBUG] Users with follow requests: $usersWithRequests');
      return usersWithRequests;
    } catch (e) {
      print('[DEBUG] Error fetching follow requests: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching follow requests: $e')),
      );
      return [];
    }
  }

  Future<void> _acceptFollowRequest(String requesterEmail) async {
    try {
      // Get the current user's email (this is the user who is accepting the request)
      final currentUserEmail = emailId;

      // Fetch the current user's document
      final QuerySnapshot currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: currentUserEmail)
          .get();

      if (currentUserSnapshot.docs.isEmpty) {
        throw Exception('Current user document not found: $currentUserEmail');
      }

      final currentUserDoc = currentUserSnapshot.docs.first;
      final timestamp = DateTime.now();
      final formattedTimestamp = "${timestamp.hour}:${timestamp.minute} ${timestamp.day}/${timestamp.month}/${timestamp.year}";
      final currentUserData=currentUserDoc.data() as Map<String, dynamic>;;
      final currentUserName = currentUserData['Name'] ?? 'User';

      // Fetch the requester's document (this is the user who sent the request)
      final QuerySnapshot requesterSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: requesterEmail)
          .get();

      if (requesterSnapshot.docs.isEmpty) {
        throw Exception('Requester document not found: $requesterEmail');
      }

      final requesterDoc = requesterSnapshot.docs.first;
      final requesterData = requesterDoc.data() as Map<String, dynamic>;
      final requesterName = requesterData['Name'] ?? 'User';

      // Update the current user's document
      await _firestore.collection('Users').doc(currentUserDoc.id).update({
        'followRequests': FieldValue.arrayRemove([requesterEmail]), // Remove from followRequests
        'followers': FieldValue.arrayUnion([requesterEmail]), // Add to followers
      });

      // Update the requester's document
      await _firestore.collection('Users').doc(requesterDoc.id).update({
        'pendingApprovals': FieldValue.arrayRemove([currentUserEmail]), // Remove from pendingApprovals
        'following': FieldValue.arrayUnion([currentUserEmail]), // Add to following
        'notifications': FieldValue.arrayUnion([
          '$currentUserEmail has accepted your follow request! You are now following $currentUserEmail. ($formattedTimestamp)',
        ]), // Add notification to the requester's list
        'notifs':FieldValue.arrayUnion([
          '$currentUserEmail has accepted your follow request! You are now following $currentUserEmail. ($formattedTimestamp)',
        ]), // Add notification to the requester's list
      });

      // Show a success message to the current user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow request accepted from $requesterEmail')),
      );

      // Refresh the follow requests list
      await _removeOverlappingRejectedRequests(requesterEmail);
      _showFollowRequests();

      // Show notification to the requester (not the current user)
      await _showNotification(
        message: 'You have accepted $requesterName\'s follow request!',
        email: currentUserEmail, // This is the sender (current user)
        targetEmail: requesterEmail, // This is who should receive the notification
      );
    } catch (e) {
      print('[DEBUG] Error accepting follow request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting follow request: $e')),
      );
    }
  }
  Future<void> _rejectFollowRequest(String requesterEmail) async {
    try {
      // Get the current user's email (this is the user who is rejecting the request)
      final currentUserEmail = emailId;

      // Fetch the current user's document
      final QuerySnapshot currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: currentUserEmail)
          .get();

      if (currentUserSnapshot.docs.isEmpty) {
        throw Exception('Current user document not found: $currentUserEmail');
      }

      final currentUserDoc = currentUserSnapshot.docs.first;
      final timestamp = DateTime.now();
      final formattedTimestamp = "${timestamp.hour}:${timestamp.minute} ${timestamp.day}/${timestamp.month}/${timestamp.year}";

      // Fetch the requester's document (this is the user who sent the request)
      final QuerySnapshot requesterSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: requesterEmail)
          .get();

      if (requesterSnapshot.docs.isEmpty) {
        throw Exception('Requester document not found: $requesterEmail');
      }

      final requesterDoc = requesterSnapshot.docs.first;
      final requesterData = requesterDoc.data() as Map<String, dynamic>;
      final requesterName = requesterData['Name'] ?? 'User';

      // Update the current user's document
      await _firestore.collection('Users').doc(currentUserDoc.id).update({
        'followRequests': FieldValue.arrayRemove([requesterEmail]), // Remove from followRequests
      });

      // Update the requester's document
      await _firestore.collection('Users').doc(requesterDoc.id).update({
        'pendingApprovals': FieldValue.arrayRemove([currentUserEmail]), // Remove from pendingApprovals
        'rejectedRequests': FieldValue.arrayUnion([currentUserEmail]), // Add to rejectedRequests
        'notifications': FieldValue.arrayUnion([
          '$currentUserEmail has rejected your follow request. You can send a new request from suggestions. ($formattedTimestamp)',
        ]), // Add notification to the requester's list
        'notifs':FieldValue.arrayUnion([
          '$currentUserEmail has rejected your follow request. You can send a new request from suggestions. ($formattedTimestamp)',
        ]), // Add notification to the requester's list

      });

      // Show a success message to the current user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow request rejected from $requesterEmail')),
      );

      // Refresh the follow requests list
      await _removeOverlappingRejectedRequests(currentUserEmail);
      _showFollowRequests();

      // Show notification to the requester (not the current user)
      await _showNotification(
        message: 'You have rejected $requesterName\'s follow request.',
        email: currentUserEmail, // This is the sender (current user)
        targetEmail: requesterEmail, // This is who should receive the notification
      );
    } catch (e) {
      print('[DEBUG] Error rejecting follow request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting follow request: $e')),
      );
    }
  }

  Future<void> _showNotification({
    required String message,
    required String email,
    required String targetEmail,
  }) async {
    try {
      if (targetEmail != emailId) {
        print('Notification intended for $targetEmail, current user is $emailId');
        return;
      }

      // Check if this exact message was already shown
      final shownMessages = _prefs.getStringList('shownMessages') ?? [];
      if (shownMessages.contains(message)) {
        return;
      }

      // Android notification details
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'follow_requests_channel',
        'Follow Requests',
        channelDescription: 'Notifications for social interactions',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );

      // iOS notification details
      final darwinPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: darwinPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'New Notification',
        message,
        platformChannelSpecifics,
        payload: email,
      );

      // Mark this message as shown
      await _prefs.setStringList(
        'shownMessages',
        [...shownMessages, message],
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }


// Future<void> _showNotification({
//   required String message,
//   required String email,
//   required String targetEmail,
// }) async {
//   try {
//     if (targetEmail != emailId) {
//       print('Notification intended for $targetEmail, current user is $emailId');
//       return;
//     }
//     // Remove timestamp from message if present
//     final cleanMessage = message.replaceAll(RegExp(r'\(.*\)$'), '').trim();
//
//     // Android notification details
//     final androidPlatformChannelSpecifics = AndroidNotificationDetails(
//       'follow_requests_channel',
//       'Follow Requests',
//       channelDescription: 'Notifications for social interactions',
//       importance: Importance.max,
//       priority: Priority.high,
//       ticker: 'ticker',
//       styleInformation: BigTextStyleInformation(
//         contentTitle: 'Tap to see the notification!!',
//         cleanMessage,
//         htmlFormatBigText: true,
//         summaryText: 'New notification',
//       ),
//     );
//
//     // iOS notification details
//     final darwinPlatformChannelSpecifics = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//       badgeNumber: 1,
//       subtitle: cleanMessage,
//       threadIdentifier: 'follow_requests',
//     );
//
//     final platformChannelSpecifics = NotificationDetails(
//       android: androidPlatformChannelSpecifics,
//       iOS: darwinPlatformChannelSpecifics,
//     );
//
//     if (targetEmail == emailId) {
//       await flutterLocalNotificationsPlugin.show(
//         DateTime
//             .now()
//             .millisecondsSinceEpoch ~/ 1000,
//         'Tap to see the notification!!',
//         cleanMessage,
//         platformChannelSpecifics,
//         payload: email,
//       );
//     }
//   } catch (e) {
//     print('Error showing notification: $e');
//   }
// }
  void _handleNotificationTap_Traveller(String payload) {
    print("Flag..............RK");
    // payload contains the email of the user who sent the notification
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          selectedUserEmail: payload,
          selectedUserName: payload.split('@')[0],
        ),
      ),
    );
  }

  Future<void> _checkForPendingNotifications() async {
    try {
      final currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId)
          .get();

      if (currentUserSnapshot.docs.isEmpty) return;

      final currentUserDoc = currentUserSnapshot.docs.first;
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      List<dynamic> notifications = currentUserData['notifications'] ?? [];

      if (notifications.isEmpty) return;

      // Get the last shown notification timestamp from SharedPreferences
      final lastShownTimestamp = _prefs.getInt('lastNotificationShown') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Only show notifications if it's been a while since last check
      if (currentTime - lastShownTimestamp > 30000*60) { // 30 seconds cooldown
        // Show all current notifications
        for (final notification in notifications) {
          final notificationStr = notification.toString();
          String? otherUserEmail;
          final emailMatch = RegExp(r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})')
              .firstMatch(notificationStr);
          if (emailMatch != null) {
            otherUserEmail = emailMatch.group(0);
          }



          await _showNotification(
            message: notificationStr.replaceAll(RegExp(r'\(.*\)$'), '').trim(),
            email: otherUserEmail ?? 'system',
            targetEmail: emailId,
          );
        }

        // Clear all notifications after showing them
        await _firestore.collection('Users').doc(currentUserDoc.id).update({
          'notifications': [],
        });

        // Update last shown timestamp
        await _prefs.setInt('lastNotificationShown', currentTime);
      }
    } catch (e) {
      print('Error checking for notifications: $e');
    }
  }

// Future<void> _checkForPendingNotifications() async {
//   try {
//     final currentUserSnapshot = await _firestore
//         .collection('Users')
//         .where('email_Id', isEqualTo: emailId)
//         .get();
//
//     if (currentUserSnapshot.docs.isEmpty) return;
//
//     final currentUserDoc = currentUserSnapshot.docs.first;
//     final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
//     final List<dynamic> notifications = currentUserData['notifications'] ?? [];
//     final List<dynamic> shownNotifications = _prefs.getStringList('shownNotifications') ?? [];
//
//     // Debug print to check what notifications we're working with
//     print('[DEBUG] All notifications for $emailId: $notifications');
//     print('[DEBUG] Already shown notifications: $shownNotifications');
//
//     // Find notifications that:
//     // 1. Are addressed to the current user (contain their email or are general notifications)
//     // 2. Haven't been shown yet
//     final newNotifications = notifications.where((notification) {
//
//       // Check if notification hasn't been shown yet
//       final notShownYet ;
//       if(shownNotifications.isEmpty){
//         notShownYet=true;
//       }
//       else{
//         notShownYet = !shownNotifications.contains(notification.toString());
//
//     }
//       return notShownYet;
//     }).toList();
//
//     print('[DEBUG] New notifications to show: $newNotifications');
//
//     if (newNotifications.isNotEmpty) {
//       // Show all new notifications (not just the most recent one)
//       for (final notification in newNotifications) {
//         final notificationStr = notification.toString();
//
//         // Try to extract the other user's email from the notification
//         String? otherUserEmail;
//         final emailMatch = RegExp(r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})')
//             .firstMatch(notificationStr);
//         if (emailMatch != null) {
//           otherUserEmail = emailMatch.group(0);
//         }
//
//         await _showNotification(
//           message: notificationStr.replaceAll(RegExp(r'\(.*\)$'), '').trim(),
//           email: otherUserEmail ?? 'system', // sender's email or 'system'
//           targetEmail: emailId, // always current user
//         );
//
//         // Mark as shown
//         shownNotifications.add(notificationStr);
//       }
//       // Store shown notifications in SharedPreferences
//       await _prefs.setStringList(
//           'shownNotifications',
//           [...shownNotifications, ...newNotifications]
//       );
//     }
//   } catch (e) {
//     print('Error checking for notifications: $e');
//   }
// }
//

// Updated follow requests modal
  void _showFollowRequests() async {
    try {
      final List<Map<String, dynamic>> followRequests = await _fetchFollowRequests();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _buildModalCard(
            title: 'Follow Requests',
            children: [
              if (followRequests.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No pending follow requests.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ...followRequests.map((user) {
                return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                        ),
                        child: ClipOval(
                          child: user['avatar'] != null
                              ? SvgPicture.network(
                            user['avatar'],
                            fit: BoxFit.cover,
                            placeholderBuilder: (context) => Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                              : Icon(Icons.person),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user['email'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () => _acceptFollowRequest(user['email']),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red),
                            onPressed: () => _rejectFollowRequest(user['email']),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing follow requests: $e')),
      );
    }
  }

// Updated pending approvals modal
  void _showPendingApprovals() async {
    try {
      final QuerySnapshot currentUserSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId)
          .get();

      if (currentUserSnapshot.docs.isEmpty) {
        throw Exception('Current user document not found: $emailId');
      }

      final currentUserDoc = currentUserSnapshot.docs.first;
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final List<dynamic> pendingApprovals = currentUserData['pendingApprovals'] ?? [];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _buildModalCard(
            title: 'Pending Approvals',
            children: [
              if (pendingApprovals.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No pending approvals.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ...pendingApprovals.map((email) {
                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchUserDetails(email),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Text('Error loading user details');
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Text('User details not found');
                    } else {
                      final userDetails = snapshot.data!;
                      return Container(
                        margin: EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                              ),
                              child: ClipOval(
                                child: userDetails['avatarUrl'] != null
                                    ? SvgPicture.network(
                                  userDetails['avatarUrl'],
                                  fit: BoxFit.cover,
                                  placeholderBuilder: (context) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                                    : Icon(Icons.person),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userDetails['Name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing pending approvals: $e')),
      );
    }
  }
}


class ProfilePage extends StatefulWidget {
  final String emailId;
  const ProfilePage({Key? key, required this.emailId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState(emailId: emailId);
}
class _ProfilePageState extends State<ProfilePage> {
  final String emailId;
  String? currentAvatarUrl;
  String? name;
  List<String>? interests;
  String? profession;
  String? ageGroup;
  String? gender;

  // String about = "Tell us about yourself";
  bool isEditingAbout = false;
  bool isAddingInterest = false;
  TextEditingController aboutController = TextEditingController();
  TextEditingController interestController = TextEditingController();
  List<String> followers = [];
  List<String> following = [];

  _ProfilePageState({required this.emailId});

  Future<void> _fetchUserData() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final QuerySnapshot snapshot = await firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId.trim().toLowerCase())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) {
        setState(() {
          name = 'New User';
          interests = ['Add your interests'];
          currentAvatarUrl = 'assets/images/default_avatar.svg';
          // about = 'Tell us about yourself';
          followers = [];
          following = [];
        });
        return;
      }

      final DocumentSnapshot document = snapshot.docs.first;
      final userData = document.data() as Map<String, dynamic>? ?? {};

      setState(() {
        name = userData['Name']?.toString() ?? 'User';
        interests = List<String>.from(userData['Interests'] ?? ['Add your interests']);
        currentAvatarUrl = userData['avatarUrl']?.toString() ?? 'assets/images/default_avatar.svg';
        // about = userData['about']?.toString() ?? 'Tell us about yourself';
        followers = List<String>.from(userData['followers'] ?? []);
        following = List<String>.from(userData['following'] ?? []);
        profession = userData['Profession']?.toString();
        ageGroup = userData['Age Group']?.toString();
        gender = userData['Gender']?.toString();
      });

    } catch (e) {
      setState(() {
        name = 'User';
        interests = ['Add your interests'];
        currentAvatarUrl = 'assets/images/default_avatar.svg';
        // about = 'Tell us about yourself';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    // aboutController.text = about;
  }

  Future<void> _showUserListDialog(String title, List<String> users) async {
    final firestore = FirebaseFirestore.instance;
    List<Map<String, dynamic>> userDetails = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      for (String userId in users) {
        final doc = await firestore.collection('Users').where('email_Id', isEqualTo: userId).get();
        if (doc.docs.isNotEmpty) {
          final userData = doc.docs.first.data();
          userDetails.add({
            'name': userData['Name'] ?? 'Unknown',
            'email': userId,
            'avatarUrl': userData['avatarUrl'] ?? '',
          });
        }
      }

      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: userDetails.length,
                    itemBuilder: (context, index) {
                      final user = userDetails[index];
                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                          ),
                          child: ClipOval(
                            child: user['avatarUrl'].isNotEmpty
                                ? SvgPicture.network(
                              user['avatarUrl'],
                              fit: BoxFit.cover,
                              placeholderBuilder: (context) => Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                                : Icon(Icons.person, size: 24),
                          ),
                        ),
                        title: Text(user['name']),
                        subtitle: Text(user['email']),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e')),
      );
    }
  }

  void _showAvatarSelectionDialog() {
    final List<String> avatarUrls = [
      "https://api.dicebear.com/9.x/micah/svg?seed=radha",
      "https://api.dicebear.com/9.x/micah/svg?seed=arav",
      "https://api.dicebear.com/9.x/micah/svg?seed=rrrrrrrr",
      "https://api.dicebear.com/9.x/micah/svg?seed=Jameson",
      "https://api.dicebear.com/9.x/micah/svg?seed=happya",
      "https://api.dicebear.com/9.x/micah/svg?seed=George",
      "https://api.dicebear.com/9.x/micah/svg?seed=liamaaaaaaaaaaaaaaaaaaa",
      "https://api.dicebear.com/7.x/micah/svg?seed=8&smile[]=happy",
      "https://api.dicebear.com/7.x/micah/svg?seed=9&smile[]=happy",
      "https://api.dicebear.com/9.x/micah/svg?seed=Masonaaaaaaaaaaaa",
      "https://api.dicebear.com/9.x/micah/svg?seed=Sawyerwwww",
      "https://api.dicebear.com/9.x/micah/svg?seed=Masonaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "https://api.dicebear.com/9.x/micah/svg?seed=Jaaaassssssi",
      "https://api.dicebear.com/9.x/micah/svg?seed=Jaaaa",
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose an Avatar'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: avatarUrls.length,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () {
                _updateProfilePicture(avatarUrls[index]);
                Navigator.pop(context);
              },
              child: SvgPicture.network(avatarUrls[index], fit: BoxFit.cover),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Future<void> _updateAbout() async {
  //   if (aboutController.text.isEmpty) return;
  //
  //   setState(() {
  //     isEditingAbout = false;
  //     about = aboutController.text;
  //   });
  //
  //   final firestore = FirebaseFirestore.instance;
  //   final snapshot = await firestore.collection('Users').where('email_Id', isEqualTo: emailId).get();
  //
  //   if (snapshot.docs.isNotEmpty) {
  //     await snapshot.docs.first.reference.update({'about': about});
  //   }
  // }

  void _addInterest(String newInterest) {
    if (newInterest.isNotEmpty && !interests!.contains(newInterest)) {
      setState(() {
        interests!.add(newInterest);
        // If needed, update in Firebase
        _updateInterestsInDatabase();
        isAddingInterest = false;
      });
    }
  }

  void _addCustomInterest(String customInterest) {
    if (customInterest.isNotEmpty && !interests!.contains(customInterest)) {
      setState(() {
        interests!.add(customInterest);
        // If needed, update in Firebase
        _updateInterestsInDatabase();
      });
    }
  }

  void _updateInterestsInDatabase() {
    // Update interests in Firebase
    FirebaseFirestore.instance
        .collection('Users')
        .where('email_Id', isEqualTo: emailId)
        .get()
        .then((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        querySnapshot.docs.first.reference.update({
          'Interests': interests,
        });
      }
    });
  }

  Future<void> _removeInterest(String interest) async {
    if (interests == null || interests!.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have at least one interest')),
      );
      return;
    }

    setState(() {
      interests?.remove(interest);
    });

    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('Users').where('email_Id', isEqualTo: emailId).get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update({'Interests': interests});
    }
  }

  Future<void> _updateProfilePicture(String avatarUrl) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final QuerySnapshot snapshot = await firestore.collection('Users').where('email_Id', isEqualTo: emailId).get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update({'avatarUrl': avatarUrl});
      setState(() => currentAvatarUrl = avatarUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
    }
  }

  Widget _buildFollowItem({required int count, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoItem({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade300, Colors.blue.shade700],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top profile section
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 100,
                                backgroundColor: Colors.white70,
                                child: currentAvatarUrl != null
                                    ? ClipOval(
                                  child: SvgPicture.network(
                                    currentAvatarUrl!,
                                    fit: BoxFit.cover,
                                    width: 190,
                                    height: 190,
                                    placeholderBuilder: (context) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                    errorBuilder: (context, error, stackTrace) => Image.asset(
                                      'assets/images/sam.png',
                                      fit: BoxFit.cover,
                                      width: 190,
                                      height: 190,
                                    ),
                                  ),
                                )
                                    : const Icon(Icons.person, size: 100, color: Colors.blue),
                              ),
                              GestureDetector(
                                onTap: _showAvatarSelectionDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.blue, size: 24),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            name ?? 'User Name',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccountSettingsScreen(
                                onBack: () => Navigator.pop(context),
                                onLogout: () {},
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Main content area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Followers/Following section
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade50, Colors.blue.shade100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildFollowItem(
                                count: followers.length,
                                label: 'Followers',
                                onTap: () => _showUserListDialog('Followers', followers),
                              ),
                              Container(height: 30, width: 1, color: Colors.grey[400]),
                              _buildFollowItem(
                                count: following.length,
                                label: 'Following',
                                onTap: () => _showUserListDialog('Following', following),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email with icon
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(Icons.email, color: Colors.grey[800], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                emailId,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Compact info row
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              if (profession != null) _buildCompactInfoItem(
                                icon: Icons.work_outline,
                                text: profession!,
                              ),
                              if (ageGroup != null) _buildCompactInfoItem(
                                icon: Icons.calendar_today_outlined,
                                text: ageGroup!,
                              ),
                              if (gender != null) _buildCompactInfoItem(
                                icon: Icons.person_outline,
                                text: gender!,
                              ),
                              _buildCompactInfoItem(
                                icon: Icons.location_on_outlined,
                                text: 'India',
                              ),
                            ],
                          ),
                        ),

                        // About section
                        // Container(
                        //   width: double.infinity,
                        //
                        //   padding: const EdgeInsets.all(16),
                        //   margin: const EdgeInsets.only(bottom: 16),
                        //   decoration: BoxDecoration(
                        //     color: Colors.blue.shade100,
                        //     borderRadius: BorderRadius.circular(12),
                        //     border: Border.all(color: Colors.grey.shade200),
                        //   ),
                        //   child: Column(
                        //     crossAxisAlignment: CrossAxisAlignment.start,
                        //     children: [
                        //       Row(
                        //         crossAxisAlignment: CrossAxisAlignment.start,
                        //         children: [
                        //           const Text(
                        //             'About',
                        //             style: TextStyle(
                        //               fontSize: 18,
                        //
                        //               fontWeight: FontWeight.bold,
                        //             ),
                        //           ),
                        //           const Spacer(),
                        //           if (!isEditingAbout)
                        //             IconButton(
                        //               icon: const Icon(Icons.edit, size: 18),
                        //               onPressed: () => setState(() => isEditingAbout = true),
                        //             ),
                        //         ],
                        //       ),
                        //       const SizedBox(height: 8),
                        //       isEditingAbout
                        //           ? Column(
                        //         children: [
                        //           TextField(
                        //             controller: aboutController,
                        //             maxLines: 3,
                        //             decoration: const InputDecoration(
                        //               border: OutlineInputBorder(),
                        //               hintText: 'Tell something about yourself',
                        //             ),
                        //           ),
                        //           const SizedBox(height: 10),
                        //           Row(
                        //             mainAxisAlignment: MainAxisAlignment.end,
                        //             children: [
                        //               TextButton(
                        //                 onPressed: () => setState(() {
                        //                   isEditingAbout = false;
                        //                   aboutController.text = about;
                        //                 }),
                        //                 child: const Text('Cancel'),
                        //               ),
                        //               const SizedBox(width: 10),
                        //               ElevatedButton(
                        //                 onPressed: _updateAbout,
                        //                 child: const Text('Save'),
                        //               ),
                        //             ],
                        //           ),
                        //         ],
                        //       )
                        //           : Text(
                        //         about,
                        //         style: const TextStyle(fontSize: 15, height: 1.4),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        const SizedBox(height: 12),

                        // Interests section
                        // ram ram
                        if (interests != null && interests!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Interests',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!isAddingInterest)
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => setState(() => isAddingInterest = true),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: interests!.map((interest) => InputChip(
                                    label: Text(interest),
                                    onDeleted: interests!.length > 1
                                        ? () => _removeInterest(interest)
                                        : null,
                                    deleteIcon: interests!.length > 1
                                        ? const Icon(Icons.close, size: 16)
                                        : null,
                                  )).toList(),
                                ),
                                if (isAddingInterest) ...[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      hintText: 'Select an interest',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    hint: Text('Select an interest'),
                                    value: null,
                                    items: [
                                      'Reading',
                                      'Cooking',
                                      'Fitness',
                                      'Photography',
                                      'Travel',
                                      'Music',
                                      'Gaming',
                                      'Art',
                                      'Technology',
                                      'Outdoor Activities',
                                      'Other'
                                    ].map((String interest) {
                                      return DropdownMenuItem<String>(
                                        value: interest,
                                        child: Text(interest),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue == 'Other') {
                                        // Show dialog to enter custom interest
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Add custom interest'),
                                            content: TextField(
                                              controller: interestController,
                                              decoration: InputDecoration(hintText: 'Enter your interest'),
                                              autofocus: true,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  if (interestController.text.trim().isNotEmpty) {
                                                    _addCustomInterest(interestController.text.trim());
                                                    interestController.clear();
                                                  }
                                                  Navigator.pop(context);
                                                },
                                                child: Text('Add'),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else if (newValue != null && !interests!.contains(newValue)) {
                                        _addInterest(newValue);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => setState(() => isAddingInterest = false),
                                        child: Text('Done'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// Keeping the rest of the classes unchanged
class InterestButton extends StatelessWidget {
  final String label;
  final Color? color;

  const InterestButton({
    Key? key,
    required this.label,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color ?? Colors.blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}
class AccountSettingsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLogout;

  const AccountSettingsScreen({
    Key? key,
    required this.onBack,
    required this.onLogout,
  }) : super(key: key);

  @override
  _AccountSettingsScreenState createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  // Controllers for password change
  String? name;
  String? emailId;
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Controller for feedback submission
  final TextEditingController _feedbackController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();


  @override
  void dispose() {
    _audioPlayer.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _feedbackController.dispose();
    super.dispose();

  }
  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // In your logout function:




  void _showRatingDialog() {
    double rating = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Our App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How would you rate your experience?'),
            const SizedBox(height: 20),
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (newRating) {
                rating = newRating;
                // Just store the rating, don't play sound yet
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              // Play sound when submitting based on rating
              String soundPath = 'assets/sounds/rating.mp3';
              _audioPlayer.play(AssetSource(soundPath));

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Thanks for rating us ${rating.toInt()} stars!'),
                  backgroundColor: Colors.green,
                ),
              );

              Navigator.pop(context);
            },
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }

  String _getTextSizeLabel(double value) {
    if (value <= 0.8) return 'Small';
    if (value <= 0.9) return 'Medium Small';
    if (value <= 1.0) return 'Normal';
    if (value <= 1.1) return 'Medium Large';
    return 'Large';
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate inputs
              if (_oldPasswordController.text.isEmpty ||
                  _newPasswordController.text.isEmpty ||
                  _confirmPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );
                return;
              }

              // Check if new password has at least 6 characters
              if (_newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New password must be at least 6 characters long')),
                );
                return;
              }

              // Check if new passwords match
              if (_newPasswordController.text != _confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match')),
                );
                return;
              }

              try {
                // Get reference to Firestore
                final FirebaseFirestore firestore = FirebaseFirestore.instance;

                // Query for the user document
                final QuerySnapshot userSnapshot = await firestore
                    .collection('Users')
                    .where('email_Id', isEqualTo: emailId)
                    .get();

                if (userSnapshot.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User not found')),
                  );
                  return;
                }

                // Get the user document
                final DocumentSnapshot userDoc = userSnapshot.docs.first;

                // Check if old password is correct
                if (userDoc['Password'] != _oldPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Current password is incorrect')),
                  );
                  return;
                }

                // Update password in Firestore
                await userDoc.reference.update({
                  'Password': _newPasswordController.text,
                });

                // Clear text fields
                _oldPasswordController.clear();
                _newPasswordController.clear();
                _confirmPasswordController.clear();

                Navigator.pop(context);

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed successfully')),
                );

              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error changing password: $e')),
                );
              }
            },
            child: const Text('CHANGE'),
          ),
        ],
      ),
    );
  }

  // Feedback submission dialog
  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We value your feedback! Please let us know how we can improve.'),
            const SizedBox(height: 16),
            TextField(
              controller: _feedbackController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Your feedback here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement feedback submission
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }
  void _editProfile() {
    // Controllers for text fields
    final TextEditingController nameController = TextEditingController();
    final TextEditingController professionController = TextEditingController();

    // Values for dropdowns
    String? selectedGender;
    String? selectedAgeGroup;

    // Options for dropdowns
    final List<String> genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
    final List<String> ageGroupOptions = ['18-24', '25-34', '35-44', '45-54', '55+'];

    // Track if at least one field is filled
    bool isAtLeastOneFieldFilled() {
      return nameController.text.trim().isNotEmpty ||
          professionController.text.trim().isNotEmpty ||
          selectedGender != null ||
          selectedAgeGroup != null;
    }

    // Variable to control button state
    bool canSubmit = false;

    // Show the edit profile dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Name'),
                      onChanged: (value) {
                        setState(() {
                          canSubmit = isAtLeastOneFieldFilled();
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    Text('Gender:'),
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: Text('Select Gender'),
                      value: selectedGender,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedGender = newValue;
                          canSubmit = isAtLeastOneFieldFilled();
                        });
                      },
                      items: genderOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),

                    Text('Age Group:'),
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: Text('Select Age Group'),
                      value: selectedAgeGroup,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedAgeGroup = newValue;
                          canSubmit = isAtLeastOneFieldFilled();
                        });
                      },
                      items: ageGroupOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),

                    TextField(
                      controller: professionController,
                      decoration: InputDecoration(labelText: 'Profession'),
                      onChanged: (value) {
                        setState(() {
                          canSubmit = isAtLeastOneFieldFilled();
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canSubmit ? () async {
                    // Show confirmation dialog
                    bool confirmChanges = await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Confirm Changes'),
                          content: Text('Are these changes correct?'),
                          actions: <Widget>[
                            TextButton(
                              child: Text('Cancel'),
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                            ),
                            TextButton(
                              child: Text('Confirm'),
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                            ),
                          ],
                        );
                      },
                    ) ?? false;

                    // If user confirmed, proceed with update
                    if (confirmChanges) {
                      // Create a map with only the fields that were changed
                      Map<String, dynamic> updatedData = {};

                      if (nameController.text.trim().isNotEmpty) {
                        // Fixed the issue with assignment to 'name'
                        updatedData['Name'] = nameController.text.trim();
                      }

                      if (professionController.text.trim().isNotEmpty) {
                        updatedData['Profession'] = professionController.text.trim();
                      }

                      if (selectedGender != null) {
                        updatedData['Gender'] = selectedGender;
                      }

                      if (selectedAgeGroup != null) {
                        updatedData['Age Group'] = selectedAgeGroup;
                      }

                      // Update the user document in Firestore
                      try {
                        await FirebaseFirestore.instance
                            .collection('Users')
                            .where('email_Id', isEqualTo: emailId)
                            .get()
                            .then((querySnapshot) {
                          if (querySnapshot.docs.isNotEmpty) {
                            querySnapshot.docs.first.reference.update(updatedData);
                          }
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Profile updated successfully!'))
                        );
                        Navigator.of(context).pop();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating profile: ${e.toString()}'))
                        );
                      }
                    }
                  } : null, // Disable button if no fields are filled
                  child: Text('Edit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete account confirmation dialog
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Warning: This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(color: Colors.red),
            ),
            SizedBox(height: 16),
            Text('Are you sure you want to delete your account?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              // TODO: Implement account deletion logic
              await deleteAccount();
              Navigator.pop(context);
              // After deletion, navigate to login screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginScreen()),
                    (Route<dynamic> route) => false,
              );
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
  Future<void> deleteAccount() async {
    print("Starting account deletion process");
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final FirebaseAuth auth = FirebaseAuth.instance;

    try {
      // Get current user
      User? user = auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception("User is not logged in or email is null.");
      }

      // Fetch user document to get stored password
      final QuerySnapshot snapshot = await firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId) // Make sure the field name matches exactly
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) {
        throw Exception("User document not found in Firestore.");
      }

      final DocumentSnapshot document = snapshot.docs.first;
      final userData = document.data() as Map<String, dynamic>? ?? {};
      final String _password = userData['Password'] ?? "";

      if (_password.isEmpty) {
        throw Exception("Password not found in user document.");
      }

      // Re-authenticate
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _password,
      );

      await user.reauthenticateWithCredential(credential);

      // Step 1: Remove email from other users' follow-related arrays
      print("Removing email from other users' follow lists");

      // Remove from followRequests arrays
      final followRequestsQuery = await firestore
          .collection('Users')
          .where('followRequests', arrayContains: emailId)
          .get();
      for (var doc in followRequestsQuery.docs) {
        await doc.reference.update({
          'followRequests': FieldValue.arrayRemove([emailId])
        });
      }

      // Remove from following arrays
      final followingQuery = await firestore
          .collection('Users')
          .where('following', arrayContains: emailId)
          .get();
      for (var doc in followingQuery.docs) {
        await doc.reference.update({
          'following': FieldValue.arrayRemove([emailId])
        });
      }

      // Remove from followers arrays
      final followersQuery = await firestore
          .collection('Users')
          .where('followers', arrayContains: emailId)
          .get();
      for (var doc in followersQuery.docs) {
        await doc.reference.update({
          'followers': FieldValue.arrayRemove([emailId])
        });
      }

      // Step 2: Delete from "Users" collection
      final usersQuery = await firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId)
          .get();
      for (var doc in usersQuery.docs) {
        await doc.reference.delete();
      }

      // Step 3: Delete from "chats"
      final chatsFromQuery = await firestore
          .collection('chats')
          .where('from_email', isEqualTo: emailId)
          .get();
      for (var doc in chatsFromQuery.docs) {
        await doc.reference.delete();
      }

      final chatsToQuery = await firestore
          .collection('chats')
          .where('to_email', isEqualTo: emailId)
          .get();
      for (var doc in chatsToQuery.docs) {
        await doc.reference.delete();
      }

      // Step 4: Delete from "Journey"
      final journeyQuery = await firestore
          .collection('Journey')
          .where('email_id', isEqualTo: emailId)
          .get();
      for (var doc in journeyQuery.docs) {
        await doc.reference.delete();
      }

      // Step 5: Delete Firebase Auth account
      await user.delete();

      print("Account deleted successfully.");
    } catch (e) {
      print("Error deleting account: $e");
      rethrow;
    }
  }


  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      emailId = prefs.getString('user_email') ?? "";
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final QuerySnapshot snapshot = await firestore
          .collection('Users')
          .where('email_Id', isEqualTo: emailId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      final DocumentSnapshot document = snapshot.docs.first;
      final userData = document.data() as Map<String, dynamic>? ?? {};

      setState(() {
        name = userData['Name']?.toString() ?? 'User';
      });

    } catch (e) {
      setState(() {
        name = 'User';
      });
    }
  }

  // Improved logout function
  void _handleLogout() async {
    // Clear authentication data
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Or clear specific keys related to authentication

    // Call the onLogout callback from parent
    widget.onLogout();

    // Navigate to login screen and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }
  Future<void> _handleDeleteJourney() async {
    try {
      // Get the user's email from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');

      if (userEmail == null) {
        print('Error: User email not found in SharedPreferences');
        return;
      }

      // Reference to Firestore
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Query for documents in the Journey collection where email_id matches userEmail
      final QuerySnapshot journeySnapshot = await firestore
          .collection('Journey')
          .where('email_id', isEqualTo: userEmail)
          .get();

      // Check if any documents were found
      if (journeySnapshot.docs.isEmpty) {
        print('No journey found for user: $userEmail');
        return;
      }

      // Create a batch to execute multiple deletions
      final WriteBatch batch = firestore.batch();

      // Add delete operations to the batch
      for (var doc in journeySnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();

      print('Successfully deleted ${journeySnapshot.docs.length} journey(s) for user: $userEmail');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage(emailId: userEmail)),
      );
    } catch (e) {
      print('Error deleting journey: $e');
      // Handle the error appropriately, perhaps show a snackbar or dialog
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blue[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: widget.onBack,
        ),
        title: Text(
          'Settings',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ListView(
          children: [
            const SizedBox(height: 10),

            // Profile section
            ListTile(
              leading: CircleAvatar(
                backgroundColor: isDarkMode ? Colors.blue[700] : Colors.blue[100],
                child: Icon(
                  Icons.person,
                  color: isDarkMode ? Colors.blue[200] : Colors.blue[600],
                ),
              ),
              title: Text(
                name ?? "Guest", // Replace with actual user name
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                emailId ?? "email", // Replace with actual user email
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.edit,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[600],
                ),
                onPressed: () {
                  //// jai shree krishna
                  _editProfile();
                  // TODO: Implement profile edit functionality
                },
              ),
            ),

            const SizedBox(height: 10),
            const Divider(),

            // Account section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),

            // Privacy settings with password change
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.blueGrey[700] : Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[600],
                ),
              ),
              title: Text(
                'Privacy & Password',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: const Text('Change your password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showChangePasswordDialog,
            ),

            // Data management
            // ListTile(
            //   leading: Container(
            //     padding: const EdgeInsets.all(8),
            //     decoration: BoxDecoration(
            //       color: isDarkMode ? Colors.purple[900] : Colors.purple[50],
            //       shape: BoxShape.circle,
            //     ),
            //     child: Icon(
            //       Icons.storage,
            //       color: isDarkMode ? Colors.purple[300] : Colors.purple[600],
            //     ),
            //   ),
            //   title: Text(
            //     'Data Management',
            //     style: TextStyle(
            //       color: isDarkMode ? Colors.white : Colors.black,
            //     ),
            //   ),
            //   subtitle: const Text('Download or delete your data'),
            //   trailing: const Icon(Icons.chevron_right),
            //   onTap: () {
            //     // TODO: Implement data management screen
            //   },
            // ),

            const Divider(),

            // App theme section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),

            // Theme toggle - now connected to ThemeProvider
            SwitchListTile(
              title: Text(
                'Dark Mode',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              value: isDarkMode,
              activeColor: Colors.blue[600],
              onChanged: (value) {
                // Toggle theme using the provider
                themeProvider.toggleTheme();
              },
            ),

            // Text size slider
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.amber[900] : Colors.amber[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.text_fields,
                  color: isDarkMode ? Colors.amber[300] : Colors.amber[600],
                ),
              ),
              title: Text(
                'Text Size',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Slider(
                value: themeProvider.textScaleFactor,
                min: 0.8,
                max: 1.2,
                divisions: 4,
                label: _getTextSizeLabel(themeProvider.textScaleFactor),
                activeColor: Colors.blue[600],
                onChanged: (double value) {
                  themeProvider.setTextScaleFactor(value);
                },
              ),
            ),

            const Divider(),

            // Language selection tile - with non-nullable colors
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.teal[900]! : Colors.teal[50]!, // Added ! to handle nullable
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.language,
                  color: isDarkMode ? Colors.teal[300]! : Colors.teal[600]!, // Added ! to handle nullable
                ),
              ),
              title: Text(
                'Language', // Will be replaced with translation later
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                'English', // Placeholder for current language
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!, // Added ! to handle nullable
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Show language selection UI when tapped
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF202020) : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 0,
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // Handle bar
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          height: 4,
                          width: 40,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!, // Added ! to handle nullable
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Title
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Select Language',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        // Language Grid
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.5,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: 6, // Six languages
                              itemBuilder: (context, index) {
                                // Define language options inline
                                String code = '', name = '', nativeName = '';

                                switch(index) {
                                  case 0:
                                    code = 'en';
                                    name = 'English';
                                    nativeName = 'English';
                                    break;
                                  case 1:
                                    code = 'hi';
                                    name = 'Hindi';
                                    nativeName = 'हिन्दी';
                                    break;
                                  case 2:
                                    code = 'bn';
                                    name = 'Bengali';
                                    nativeName = 'বাংলা';
                                    break;
                                  case 3:
                                    code = 'pa';
                                    name = 'Punjabi';
                                    nativeName = 'ਪੰਜਾਬੀ';
                                    break;
                                  case 4:
                                    code = 'te';
                                    name = 'Telugu';
                                    nativeName = 'తెలుగు';
                                    break;
                                  case 5:
                                    code = 'mr';
                                    name = 'Marathi';
                                    nativeName = 'मराठी';
                                    break;
                                }

                                final isSelected = code == 'en'; // Placeholder logic

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? isDarkMode ? Colors.teal[900]! : Colors.teal[50]! // Added ! to handle nullable
                                        : isDarkMode ? const Color(0xFF303030) : Colors.grey[100]!, // Added ! to handle nullable
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.teal
                                          : isDarkMode ? Colors.grey[700]! : Colors.grey[300]!, // Added ! to handle nullable
                                      width: 2,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      // Just close the sheet for now
                                      Navigator.pop(context);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          nativeName,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? isDarkMode ? Colors.teal[200]! : Colors.teal[800]! // Added ! to handle nullable
                                                : isDarkMode ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isSelected
                                                ? isDarkMode ? Colors.teal[200]! : Colors.teal[800]! // Added ! to handle nullable
                                                : isDarkMode ? Colors.grey[400]! : Colors.grey[600]!, // Added ! to handle nullable
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: isDarkMode ? Colors.teal[200]! : Colors.teal[800]!, // Added ! to handle nullable
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Cancel button
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!, // Added ! to handle nullable
                              foregroundColor: isDarkMode ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),


            // Feedback and support section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Support',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),

            // Help and support with app guide and contact info
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.blueGrey[700] : Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[400],
                ),
              ),
              title: Text(
                'Help & Support',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: const Text('App guide and contact information'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Show help dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Help & Support'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Need help with Classico?'),
                        SizedBox(height: 8),
                        Text('Email: support@classico.app'),
                        Text('Phone: +1 (555) 123-4567'),
                        SizedBox(height: 16),
                        Text('App Version: 1.0.0'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CLOSE'),
                      ),
                    ],
                  ),
                );
              },
            ),

            // NEW: App feedback submission
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.green[900] : Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.feedback,
                  color: isDarkMode ? Colors.green[300] : Colors.green[600],
                ),
              ),
              title: Text(
                'Submit Feedback',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: const Text('Help us improve your experience'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showFeedbackDialog,
            ),




// Widget list continues here
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.amber[900] : Colors.amber[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  color: isDarkMode ? Colors.amber[300] : Colors.amber[600],
                ),
              ),
              title: Text(
                'Rate Our App',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: const Text('Enjoying TrainSocial? Let us know!'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRatingDialog(),
            ),

            const SizedBox(height: 10),
            const Divider(),

// Account management section (Logout and Delete)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Account Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),

// Logout button - fixed implementation
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.orange[900] : Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout,
                  color: isDarkMode ? Colors.orange[300] : Colors.orange[600],
                ),
              ),
              title: Text(
                'Log Out',
                style: TextStyle(
                  color: isDarkMode ? Colors.orange[300] : Colors.orange[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => _handleLogout(),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.orange[900] : Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete,
                  color: isDarkMode ? Colors.orange[300] : Colors.orange[600],
                ),
              ),
              title: Text(
                'Delete Current Journey',
                style: TextStyle(
                  color: isDarkMode ? Colors.orange[300] : Colors.orange[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => _handleDeleteJourney(),
            ),
// NEW: Delete account option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.red[900] : Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever,
                  color: isDarkMode ? Colors.red[300] : Colors.red,
                ),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('Permanently remove your account and data'),
              onTap: () => _showDeleteAccountDialog(),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
