import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'dart:math';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import './notificationPage.dart';
import 'splashscreen.dart'; // Import the new splash screen
import 'login_screen.dart'; // Import login screen
import 'package:classico/chatting/page/chat_page.dart';
import 'package:classico/chatting/page/chats_page.dart';
import 'package:classico/chatting/model/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart'; // Make sure this path is correct
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


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
  @override
  void initState() {
    super.initState();
  }
  String trainNumberInput = "";
  String errorMessage = "";

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
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: (selectedCoach == null || (travelDate?.isEmpty ?? true))
                                      ? null
                                      : () async {
                                    // Get Firestore instance
                                    FirebaseFirestore firestore = FirebaseFirestore.instance;

                                    // Add data to Journey collection
                                    await firestore.collection('Journey').add({
                                      'train_no': trainNumberInput, // Ensure this holds the train number
                                      'email_id': emailId,
                                      'travel_date': travelDate,
                                      'coach_number': selectedCoach,
                                      'timestamp': FieldValue.serverTimestamp(), // To track entry time
                                    }).then((_) {
                                      // Navigate to Home Page after successful Firestore entry
                                      print('Navigating to LoginPage');
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HomePage(selectedTrain: selectedTrain!, emailId: emailId, travelDate: travelDate!, selectedCoach: selectedCoach!, trainNo: trainNumberInput,),
                                        ),
                                      );
                                      print('Successfully Navigated to LoginPage');
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

class TrainSocialApp extends StatefulWidget {
  const TrainSocialApp({super.key});

  @override
  State<TrainSocialApp> createState() => _TrainSocialAppState();
}

class _TrainSocialAppState extends State<TrainSocialApp> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  @override
  void initState() {
    super.initState();
    initNotifications();
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


  Future<void> initNotifications() async {
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

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  const HomePage({required this.selectedTrain,required this.emailId,required this.travelDate,required this.selectedCoach,required this.trainNo, super.key});

  @override
  State<HomePage> createState() => _HomePageState(emailId: this.emailId, travelDate: travelDate, selectedCoach: selectedCoach, trainNo: trainNo);
}

class _HomePageState extends State<HomePage> {
  final String emailId;
  final String travelDate;
  final String selectedCoach;
  final String trainNo;
  _HomePageState({required this.emailId, required this.travelDate, required this.selectedCoach, required this.trainNo});
  int _selectedIndex = 0;
  late List<Widget> _pages;
  Timer? _locationTimer;
  int currentStationIndex = 0;
  double distanceRemaining =1000.0;

  @override
  void initState() {
    super.initState();
    _pages = [
      TravelersPage(emailId: emailId, travelDate: travelDate, selectedCoach: selectedCoach, trainNo: trainNo,),
      LocationInfoPage(selectedTrain: widget.selectedTrain),
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
    _locationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        checkNearestStation(position);
      }
    });
  }

  void checkNearestStation(Position position) {

    String coordinates = widget.selectedTrain.coordinates[currentStationIndex];
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
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
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

  const LocationInfoPage({required this.selectedTrain, super.key});

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
                              Text(
                                'Train ID: ${widget.selectedTrain ?? 'N/A'}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                'Status: On Time',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
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
  const TravelersPage({required this.emailId, required this.travelDate, required this.selectedCoach, required this.trainNo,super.key});

  @override
  _TravelersPageState createState() => _TravelersPageState(emailId: emailId, travelDate: travelDate, selectedCoach: selectedCoach, trainNo: trainNo);
}

class _TravelersPageState extends State<TravelersPage> {
  final String emailId;
  final String travelDate;
  final String selectedCoach;
  final String trainNo;
  _TravelersPageState({required this.emailId, required this.travelDate, required this.selectedCoach, required this.trainNo});
  // User's own data


  Map<String, dynamic> currentUser = {
    'name': 'Loading...',
    'avatar': 'assets/images/sam.jpeg',
    'stories': [],
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

        // Return the current user's details (without 'stories')
        return {
          'name': userData['Name'] ?? 'Unknown',
          'avatar': userData['avatar'] ?? 'assets/images/sam.jpeg',
        };
      } else {
        throw Exception('Current user document not found: $emailId');
      }
    } catch (e) {
      print('Error fetching current user details: $e');
      return {
        'name': 'Unknown',
        'avatar': 'assets/images/sam.jpeg',
      };
    }
  }
  // Bluish gradient colors
  final Gradient buttonGradient = LinearGradient(
    colors: [
      Color(0xFF5D9CEC),
      Color(0xFF4A89DC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Sample data for friends


  List<Map<String, dynamic>> _allSuggestedUsers = []; // Original list

  // Hover state tracking
  List<dynamic> following =[];
  final Map<String, bool> _followRequestStates = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> suggestedUsers = [];
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    // Initialize hover states for friends
    _fetchCurrentUserDetails().then((userDetails) {
      setState(() {
        currentUser = userDetails; // Update the currentUser map
      });
    });
    _fetchSuggestedUsers();
    _removeOverlappingRejectedRequests(emailId);
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;



  String? selectedProfession;
  String? selectedAgeGroup;
  String? selectedGender;

  // Define lists for dropdown options
  final List<String> professions = ['Engineer', 'Doctor', 'Teacher', 'Artist', 'Student'];
  final List<String> ageGroups = ['18-25', '26-35', '36-45', '46+'];
  final List<String> genders = ['Male', 'Female', 'Other'];

  // Add a method to build the filter row
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        children: [
          // Profession Dropdown
          Expanded(
            child: DropdownButton<String>(
              value: selectedProfession,
              hint: Text('Profession'),
              onChanged: (String? newValue) {
                setState(() {
                  selectedProfession = newValue;
                });
              },
              items: professions.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          SizedBox(width: 10),
          // Age Group Dropdown
          Expanded(
            child: DropdownButton<String>(
              value: selectedAgeGroup,
              hint: Text('Age Group'),
              onChanged: (String? newValue) {
                setState(() {
                  selectedAgeGroup = newValue;
                });
              },
              items: ageGroups.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          SizedBox(width: 10),
          // Gender Dropdown
          Expanded(
            child: DropdownButton<String>(
              value: selectedGender,
              hint: Text('Gender'),
              onChanged: (String? newValue) {
                setState(() {
                  selectedGender = newValue;
                });
              },
              items: genders.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Add a method to build the search and clear filter buttons
  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _applyFilters();
              },
              child: Text('Search'),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _clearFilters();
              },
              child: Text('Clear Filters'),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      // Filter the original list (_allSuggestedUsers) based on selected criteria
      suggestedUsers = _allSuggestedUsers.where((user) {
        bool matchesProfession = selectedProfession == null || user['Profession'] == selectedProfession;
        bool matchesAgeGroup = selectedAgeGroup == null || user['AgeGroup'] == selectedAgeGroup;
        bool matchesGender = selectedGender == null || user['Gender'] == selectedGender;

        // Debug logs
        print('User: ${user['email_id']}');
        print('Profession: ${user['Profession']}, Selected: $selectedProfession, Matches: $matchesProfession');
        print('AgeGroup: ${user['AgeGroup']}, Selected: $selectedAgeGroup, Matches: $matchesAgeGroup');
        print('Gender: ${user['Gender']}, Selected: $selectedGender, Matches: $matchesGender');
        print('---');

        return matchesProfession && matchesAgeGroup && matchesGender;
      }).toList();
    });

    // Debug log to check the filtered list
    print('Filtered Users: ${suggestedUsers.length}');
  }

  // Add a method to clear filters
  void _clearFilters() {
    setState(() {
      selectedProfession = null;
      selectedAgeGroup = null;
      selectedGender = null;
      suggestedUsers = List.from(_allSuggestedUsers); // Reset to the original list
    });
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

      // Get the current user's pendingApprovals list
      final List<dynamic> pendingApprovals = currentUserData['pendingApprovals'] ?? [];
      following = currentUserData['following'] ?? [];
      // Fetch all users in the same journey (train, coach, and date)
      final QuerySnapshot journeySnapshot = await _firestore
          .collection('Journey')
          .where('train_no', isEqualTo: trainNo.trim())
          .where('coach_number', isEqualTo: selectedCoach.trim())
          .where('travel_date', isEqualTo: travelDate.trim())
          .get();

      final Set<String> uniqueEmails = {}; // To store unique email_ids
      final List<Map<String, dynamic>> users = [];

      for (var doc in journeySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Exclude the current user and users already in the following list
        if (data['email_id'] != emailId &&
            !following.contains(data['email_id']) &&
            !uniqueEmails.contains(data['email_id'])) {
          uniqueEmails.add(data['email_id']); // Add email_id to the set
          users.add(data);
        }
      }

      // Initialize follow request states
      for (var user in users) {
        _followRequestStates[user['email_id']] = pendingApprovals.contains(user['email_id']);
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

  // Accept follow request
  Future<void> _acceptFollowRequest(String requesterEmail) async {
    try {
      // Get the current user's email
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

      // Fetch the requester's document
      final QuerySnapshot requesterSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: requesterEmail)
          .get();

      if (requesterSnapshot.docs.isEmpty) {
        throw Exception('Requester document not found: $requesterEmail');
      }

      final requesterDoc = requesterSnapshot.docs.first;

      // Update the current user's document
      await _firestore.collection('Users').doc(currentUserDoc.id).update({
        'followRequests': FieldValue.arrayRemove([requesterEmail]), // Remove from followRequests
        'followers': FieldValue.arrayUnion([requesterEmail]), // Add to acceptedRequests
      });

      // Update the requester's document
      await _firestore.collection('Users').doc(requesterDoc.id).update({
        'pendingApprovals': FieldValue.arrayRemove([currentUserEmail]), // Remove from pendingApprovals
        'following': FieldValue.arrayUnion([currentUserEmail]), // Add to fol
        'acceptedRequests': FieldValue.arrayUnion([currentUserEmail]), // Add to acceptedRequests// lowing
        'notifications': FieldValue.arrayUnion([
          '$currentUserEmail has accepted your follow request! You are now following $currentUserEmail. ($formattedTimestamp)',
        ]), // Add notification to the requester's list
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow request accepted from $requesterEmail')),
      );

      // Refresh the follow requests list
      await _removeOverlappingRejectedRequests(requesterEmail);
      _showFollowRequests();
    } catch (e) {
      print('[DEBUG] Error accepting follow request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting follow request: $e')),
      );
    }
  }

  void _showNotifications() async {
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

      // Get the notifications, acceptedRequests, and rejectedRequests lists
      final List<dynamic> notifications = currentUserData['notifications'] ?? [];
      final List<dynamic> acceptedRequests = currentUserData['acceptedRequests'] ?? [];
      final List<dynamic> rejectedRequests = currentUserData['rejectedRequests'] ?? [];

      // Use a Set to store valid notifications (automatically handles duplicates)
      final Set<String> validNotificationsSet = {};

      // Filter notifications to only show those related to accepted or rejected requests
      for (final notification in notifications) {
        // Extract the email from the notification message
        final emailMatch = RegExp(r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})').firstMatch(notification);
        if (emailMatch != null) {
          final email = emailMatch.group(0);

          // Check if the email is in acceptedRequests or rejectedRequests
          if (acceptedRequests.contains(email) || rejectedRequests.contains(email)) {
            validNotificationsSet.add(notification); // Add to the Set (duplicates are ignored)
          }
        }
      }

      // Convert the Set back to a List for display
      final List<String> validNotifications = validNotificationsSet.toList();

      // Show the notifications in a modal bottom sheet
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                if (validNotifications.isEmpty)
                  Text('No new notifications.'),
                ...validNotifications.map((notification) {
                  return ListTile(
                    title: Text(notification),
                  );
                }).toList(),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('[DEBUG] Error showing notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing notifications: $e')),
      );
    }
  }



  // Reject follow request
  Future<void> _rejectFollowRequest(String requesterEmail) async {
    try {
      // Get the current user's email
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

      // Fetch the requester's document
      final QuerySnapshot requesterSnapshot = await _firestore
          .collection('Users')
          .where('email_Id', isEqualTo: requesterEmail)
          .get();

      if (requesterSnapshot.docs.isEmpty) {
        throw Exception('Requester document not found: $requesterEmail');
      }

      final requesterDoc = requesterSnapshot.docs.first;

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
        ]), // Add notification
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow request rejected from $requesterEmail')),
      );

      // Refresh the follow requests list
      await _removeOverlappingRejectedRequests(currentUserEmail);
      _showFollowRequests();
    } catch (e) {
      print('[DEBUG] Error rejecting follow request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting follow request: $e')),
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
            'avatar': requesterData['avatar'],
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
  void _showFollowRequests() async {
    try {
      // Fetch users with pending follow requests
      final List<Map<String, dynamic>> followRequests = await _fetchFollowRequests();

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

      // Get the acceptedRequests and rejectedRequests lists
      final List<dynamic> acceptedRequests = currentUserData['acceptedRequests'] ?? [];
      final List<dynamic> rejectedRequests = currentUserData['rejectedRequests'] ?? [];

      // Remove overlapping entries (acceptedRequests takes precedence)
      final cleanedRejectedRequests = rejectedRequests.where((email) => !acceptedRequests.contains(email)).toList();

      // Show the follow requests in a modal bottom sheet
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Follow Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                if (followRequests.isEmpty && acceptedRequests.isEmpty && cleanedRejectedRequests.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No pending follow requests.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ...followRequests.map((user) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['avatar'] != null
                          ? AssetImage(user['avatar'])
                          : AssetImage('assets/images/sam.jpeg'),
                    ),
                    title: Text(user['name'] ?? 'Unknown'),
                    subtitle: Text(user['email']),
                    trailing: Row(
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
                  );
                }).toList(),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('[DEBUG] Error showing follow requests: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing follow requests: $e')),
      );
    }
  }
  // Hover effect for app bar icons
  Widget _buildHoverableIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isToggled = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isToggled ? Colors.grey.shade200 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
      ),
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

        // Return the user details
        return {
          'Name': userData['Name'],
          'avatar': userData['avatar'],
        };
      } else {
        return {}; // Return empty map if no user is found
      }
    } catch (e) {
      print('Error fetching user details: $e');
      return {}; // Return empty map if an error occurs
    }
  }



  // Helper method for suggestion tiles
  Widget _buildSuggestionTile({
    required String? avatar,
    required String? name,
    required String? email,
  }) {
    if (email == null) {
      return ListTile(
        title: Text('Invalid user'),
      );
    }

    final isRequestSent = _followRequestStates[email] ?? false;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatar != null
            ? AssetImage(avatar)
            : AssetImage('assets/images/sam.jpeg'),
      ),
      title: Text(name ?? 'Unknown'),
      subtitle: Text(email),
      trailing: ElevatedButton(
        onPressed: isRequestSent
            ? null // Disable the button if the request is sent
            : () {
          _sendFollowRequest(email);
        },
        child: Text(isRequestSent ? 'Request Sent' : 'Follow'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildHoverableIconButton(
          icon: Icons.menu,
          color: Colors.black,
          onPressed: () {
            // Menu functionality
          },
        ),
        title: Text(
          'Travellers',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Existing bell icon for notifications
          _buildHoverableIconButton(
            icon: Icons.add_alert_rounded,
            color: Colors.black,
            onPressed: () {
              // Show notifications
              _showNotifications();
            },
          ),
          // New icon for follow requests
          _buildHoverableIconButton(
            icon: Icons.account_box_rounded,
            color: Colors.black,
            onPressed: () {
              // Show follow requests
              _showFollowRequests();
            },
          ),
          // New icon for pending approvals
          _buildHoverableIconButton(
            icon: Icons.pending_actions, // Use an appropriate icon
            color: Colors.black,
            onPressed: () {
              // Show pending approvals
              _showPendingApprovals();
            },
          ),
          _buildHoverableIconButton(
            icon: Icons.chat_rounded,
            color: Colors.black,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(),
                ),
              );
            },
          ),
          // Suggestions icon has been removed
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current User and Following Users' Avatars
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Row(
              children: [
                // Current User's Avatar
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundImage: AssetImage(currentUser['avatar']),
                        radius: 30,
                      ),
                      SizedBox(height: 5),
                      Text(
                        currentUser['name'] ?? 'You', // Display current user's name
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                              return CircularProgressIndicator();
                            } else if (snapshot.hasError) {
                              return Icon(Icons.error);
                            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Icon(Icons.person);
                            } else {
                              final userDetails = snapshot.data!;
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () {
                                    // Redirect to chat page (HomeScreen)
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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Circular Avatar
                                      CircleAvatar(
                                        backgroundImage: userDetails['avatar'] != null
                                            ? AssetImage(userDetails['avatar'])
                                            : AssetImage('assets/images/sam.jpeg'),
                                        radius: 30,
                                      ),
                                      SizedBox(height: 5), // Add some spacing
                                      // User's Name
                                      Text(
                                        userDetails['Name'] ?? 'Unknown', // Display the name
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
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
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Travellers Suggestions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          // Add the filter row
          _buildFilterRow(),

          // Add the filter buttons
          _buildFilterButtons(),

          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: suggestedUsers.length,
              itemBuilder: (context, index) {
                final user = suggestedUsers[index];
                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchUserDetails(user['email_id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
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
                        avatar: userDetails['avatar'] as String?,
                        name: userDetails['Name'] as String?,
                        email: user['email_id'] as String?,
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPendingApprovals() async {
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

      // Get the pendingApprovals list
      final List<dynamic> pendingApprovals = currentUserData['pendingApprovals'] ?? [];

      // Show the pending approvals in a modal bottom sheet
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pending Approvals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                if (pendingApprovals.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No pending approvals.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                // Show pending approvals
                ...pendingApprovals.map((email) {
                  return FutureBuilder<Map<String, dynamic>>(
                    future: _fetchUserDetails(email),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator();
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
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userDetails['avatar'] != null
                                ? AssetImage(userDetails['avatar'])
                                : AssetImage('assets/images/sam.jpeg'),
                          ),
                          title: Text(userDetails['Name'] ?? 'Unknown'),
                          subtitle: Text(email),
                        );
                      }
                    },
                  );
                }).toList(),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('[DEBUG] Error showing pending approvals: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing pending approvals: $e')),
      );
    }
  }
}



// class HistoryCard extends StatelessWidget {
//   const HistoryCard({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.history, color: Colors.blue[900]),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Historical Significance',
//                   style: Theme.of(context).textTheme.titleLarge,
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'AI-generated historical information will appear here...',
//               style: Theme.of(context).textTheme.bodyLarge,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }




// class ChatListPage extends StatefulWidget {
//   const ChatListPage({super.key});
//
//   @override
//   _ChatListPageState createState() => _ChatListPageState();
// }

// class _ChatListPageState extends State<ChatListPage> {
//   // Story data (same as previous implementation)
//   final List<Map<String, dynamic>> stories = [
//     {
//       'type': 'add',
//       'name': 'Add Story',
//       'avatar': null,
//     },
//     {
//       'type': 'user',
//       'name': 'Yoga',
//       'avatar': 'https://randomuser.me/api/portraits/men/50.jpg',
//     },
//     {
//       'type': 'user',
//       'name': 'Dono',
//       'avatar': 'https://randomuser.me/api/portraits/men/51.jpg',
//     },
//     {
//       'type': 'user',
//       'name': 'Doni',
//       'avatar': 'https://randomuser.me/api/portraits/men/52.jpg',
//     },
//     {
//       'type': 'user',
//       'name': 'Random',
//       'avatar': 'https://randomuser.me/api/portraits/men/53.jpg',
//     },
//   ];
//
//   // Chat data
//   final List<Map<String, dynamic>> chats = [
//     {
//       'name': 'Rehan Wangsaff',
//       'avatar': 'https://randomuser.me/api/portraits/men/1.jpg',
//       'lastMessage': 'Ur Welcome!',
//       'time': '00.21',
//       'unread': false,
//     },
//     {
//       'name': 'Peter Parker',
//       'avatar': 'https://randomuser.me/api/portraits/men/2.jpg',
//       'lastMessage': 'Can You Come Here Today?',
//       'time': '00.21',
//       'unread': true,
//     },
//     {
//       'name': 'Bebeb',
//       'avatar': 'https://randomuser.me/api/portraits/women/1.jpg',
//       'lastMessage': 'What You Doing?',
//       'time': '00.21',
//       'unread': false,
//     },
//     {
//       'name': 'Yoga',
//       'avatar': 'https://randomuser.me/api/portraits/men/3.jpg',
//       'lastMessage': 'Sokin Sin Ngab',
//       'time': '00.21',
//       'unread': false,
//     },
//   ];
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.transparent, // Make background transparent
//       body: Stack(
//         children: [
//           // Dimmed background (optional)
//           Positioned.fill(
//             child: Container(
//               color: Colors.black.withOpacity(0.7),
//             ),
//           ),
//
//           // Main Chat UI
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.black,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // App Bar
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 16.0,
//                         vertical: 10
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Welcome Oji 👋',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.notifications_outlined, color: Colors.white),
//                           onPressed: () {
//                             // Notification functionality
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // Story Section
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Story',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                           ),
//                         ),
//                         Text(
//                           'See All',
//                           style: TextStyle(
//                             color: Colors.white54,
//                             fontSize: 14,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // Story Horizontal Scroll
//                   SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     padding: EdgeInsets.symmetric(horizontal: 16),
//                     child: Row(
//                       children: stories.map((story) {
//                         return Padding(
//                           padding: const EdgeInsets.only(right: 10),
//                           child: Column(
//                             children: [
//                               Container(
//                                 width: 60,
//                                 height: 60,
//                                 decoration: BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   color: story['type'] == 'add'
//                                       ? Colors.grey[800]
//                                       : Colors.white,
//                                   border: Border.all(
//                                     color: story['type'] == 'add'
//                                         ? Colors.transparent
//                                         : Colors.white,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 child: story['type'] == 'add'
//                                     ? Icon(Icons.add, color: Colors.white, size: 30)
//                                     : CircleAvatar(
//                                   backgroundImage: NetworkImage(story['avatar']),
//                                 ),
//                               ),
//                               SizedBox(height: 5),
//                               Text(
//                                 story['name'],
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         );
//                       }).toList(),
//                     ),
//                   ),
//
//                   // Chat Section
//                   Container(
//                     margin: EdgeInsets.only(top: 20),
//                     height: MediaQuery.of(context).size.height * 0.5, // Half screen height
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
//                     ),
//                     child: Column(
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 16.0,
//                             vertical: 16,
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 'Recent Chat',
//                                 style: TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 18,
//                                 ),
//                               ),
//                               TextButton.icon(
//                                 onPressed: () {
//                                   // Archive chat functionality
//                                 },
//                                 icon: Icon(Icons.archive_outlined, color: Colors.black),
//                                 label: Text(
//                                   'Archive Chat',
//                                   style: TextStyle(color: Colors.black),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Expanded(
//                           child: ListView.builder(
//                             itemCount: chats.length,
//                             itemBuilder: (context, index) {
//                               final chat = chats[index];
//                               return ListTile(
//                                 leading: CircleAvatar(
//                                   backgroundImage: NetworkImage(chat['avatar']),
//                                   backgroundColor: Colors.grey[200],
//                                 ),
//                                 title: Text(
//                                   chat['name'],
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 subtitle: Text(
//                                   chat['lastMessage'],
//                                   style: TextStyle(
//                                     color: Colors.grey,
//                                   ),
//                                 ),
//                                 trailing: Column(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   crossAxisAlignment: CrossAxisAlignment.end,
//                                   children: [
//                                     Text(
//                                       chat['time'],
//                                       style: TextStyle(
//                                         color: Colors.grey,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                     if (chat['unread'])
//                                       Container(
//                                         margin: EdgeInsets.only(top: 4),
//                                         width: 10,
//                                         height: 10,
//                                         decoration: BoxDecoration(
//                                           color: Colors.blue,
//                                           shape: BoxShape.circle,
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                                 onTap: () {
//                                   // Navigate to chat detail
//                                 },
//                               );
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//           // Close Button
//           Positioned(
//             top: 40,
//             right: 16,
//             child: IconButton(
//               icon: Icon(Icons.close, color: Colors.white, size: 30),
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
// class ChatDetailPage extends StatefulWidget {
//   final String name;
//   final String avatar;
//
//   const ChatDetailPage({
//     super.key,
//     required this.name,
//     required this.avatar,
//   });
//
//   @override
//   _ChatDetailPageState createState() => _ChatDetailPageState();
// }

// class _ChatDetailPageState extends State<ChatDetailPage> {
//   final List<Map<String, dynamic>> messages = [
//     {
//       'text': 'Hi, I\'m heading to the mall this afternoon',
//       'isMe': false,
//       'time': '01.12',
//     },
//     {
//       'text': 'Do you wanna join with me?',
//       'isMe': false,
//       'time': '01.12',
//     },
//     {
//       'text': 'its look awesome!',
//       'isMe': true,
//       'time': '01.23',
//     },
//     {
//       'text': 'But can I bring my girlfriend? They want to go to the mall',
//       'isMe': true,
//       'time': '01.23',
//     },
//     {
//       'text': 'of course, just him',
//       'isMe': false,
//       'time': '01.34',
//     },
//     {
//       'text': 'Thanks Rehan',
//       'isMe': true,
//       'time': '01.35',
//     },
//     {
//       'text': 'Ur Welcome!',
//       'isMe': false,
//       'time': '01.38',
//     },
//   ];
//
//   final TextEditingController _messageController = TextEditingController();
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Row(
//           children: [
//             CircleAvatar(
//               backgroundImage: NetworkImage(widget.avatar),
//               radius: 20,
//             ),
//             SizedBox(width: 10),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   widget.name,
//                   style: TextStyle(
//                     color: Colors.black,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Text(
//                   'Online',
//                   style: TextStyle(
//                     color: Colors.green,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.more_vert, color: Colors.black),
//             onPressed: () {
//               // More options functionality
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[200],
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     'Today',
//                     style: TextStyle(
//                       color: Colors.grey,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: ListView.builder(
//               reverse: true,
//               padding: EdgeInsets.all(16),
//               itemCount: messages.length,
//               itemBuilder: (context, index) {
//                 final message = messages[messages.length - 1 - index];
//                 return Align(
//                   alignment: message['isMe']
//                       ? Alignment.centerRight
//                       : Alignment.centerLeft,
//                   child: Container(
//                     margin: EdgeInsets.symmetric(vertical: 5),
//                     padding: EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color: message['isMe']
//                           ? Colors.blue[100]
//                           : Colors.grey[200],
//                       borderRadius: BorderRadius.circular(20).copyWith(
//                         bottomRight: message['isMe']
//                             ? Radius.zero
//                             : Radius.circular(20),
//                         bottomLeft: message['isMe']
//                             ? Radius.circular(20)
//                             : Radius.zero,
//                       ),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.end,
//                       children: [
//                         Text(
//                           message['text'],
//                           style: TextStyle(
//                             color: message['isMe']
//                                 ? Colors.blue[900]
//                                 : Colors.black,
//                           ),
//                         ),
//                         SizedBox(height: 4),
//                         Text(
//                           message['time'],
//                           style: TextStyle(
//                             fontSize: 10,
//                             color: message['isMe']
//                                 ? Colors.blue[700]
//                                 : Colors.grey[600],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           // Message Input Area
//           Container(
//             padding: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.2),
//                   spreadRadius: 1,
//                   blurRadius: 5,
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.mic, color: Colors.blue),
//                   onPressed: () {
//                     // Voice message functionality
//                   },
//                 ),
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: InputDecoration(
//                       hintText: 'Message...',
//                       border: InputBorder.none,
//                       contentPadding: EdgeInsets.symmetric(horizontal: 10),
//                     ),
//                   ),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.send, color: Colors.blue),
//                   onPressed: () {
//                     // Send message functionality
//                     if (_messageController.text.isNotEmpty) {
//                       setState(() {
//                         messages.insert(0, {
//                           'text': _messageController.text,
//                           'isMe': true,
//                           'time': DateTime.now().toString().substring(11, 16),
//                         });
//                         _messageController.clear();
//                       });
//                     }
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class ProfilePage extends StatefulWidget {
  final String emailId;
  const ProfilePage({Key? key, required this.emailId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState(emailId: emailId);
}

class _ProfilePageState extends State<ProfilePage> {
  final String emailId;
  String? currentAvatarUrl;

  _ProfilePageState({required this.emailId});

  String? name;
  List<String>? interests;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final QuerySnapshot snapshot = await firestore
        .collection('Users')
        .where('email_Id', isEqualTo: emailId)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final DocumentSnapshot document = snapshot.docs.first;
      setState(() {
        name = document['Name'];
        interests = List<String>.from(document['Interests']);
        currentAvatarUrl = document['avatar'];
      });
    } else {
      print('No user found with email: $emailId');
    }
  }

  bool showSettings = false;

  Future<String> _fetchAvatar(String identifier) async {
    final response = await http.get(
      Uri.parse('https://api.multiavatar.com/$identifier.png'),
      headers: {
        'User-Agent': 'YourAppName/1.0', // Add a User-Agent header
      },
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load avatar: ${response.statusCode}');
    }
  }

  void _showAvatarSelectionDialog() {
    final List<String> indianNames = [
      'Aarav', 'Vihaan', 'Arjun', 'Rohan', 'Kabir', 'Dhruv', 'Krish', 'Pranav',
      'Aanya', 'Ananya', 'Diya', 'Kavya', 'Myra', 'Riya', 'Saanvi', 'Tara',
    ];


    final List<String> avatarUrls = indianNames.map((name) => 'https://api.multiavatar.com/$name.png').toList();


    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _updateProfilePicture(avatarUrls[index]);
                    Navigator.pop(context);
                  },
                  child: Image.network(
                    avatarUrls[index],
                    fit: BoxFit.cover,
                    headers: {
                      'User-Agent': 'YourAppName/1.0', // Add a User-Agent header
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.error, color: Colors.red);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateProfilePicture(String avatarUrl) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final QuerySnapshot snapshot = await firestore
        .collection('Users')
        .where('email_Id', isEqualTo: emailId)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final DocumentSnapshot document = snapshot.docs.first;
      await document.reference.update({
        'avatar': avatarUrl,
      });

      setState(() {
        currentAvatarUrl = avatarUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showSettings) {
      return AccountSettingsScreen(
        onBack: () => setState(() => showSettings = false),
        onLogout: () {
          // Add your logout logic here
        },
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final profileImageHeight = screenHeight * 0.55;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
        Container(
        height: profileImageHeight,
        width: double.infinity,
        child: currentAvatarUrl != null
            ? Image.network(
          currentAvatarUrl!,
          fit: BoxFit.cover,
          headers: {
            'User-Agent': 'YourAppName/1.0', // Add a User-Agent header
          },
          errorBuilder: (context, error, stackTrace) {
            // Fallback widget if the image fails to load
            return Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.person,
                size: 100,
                color: Colors.grey[600],
              ),
            );
          },
        )
            : Container(
          color: Colors.grey[300],
          child: Icon(
            Icons.person,
            size: 100,
            color: Colors.grey[600],
          ),
        ),
      ),
              Positioned(
                top: 40,
                right: 16,
                child: GestureDetector(
                  onTap: () => setState(() => showSettings = true),
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
                    child: const Icon(
                      Icons.settings,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 20,
                child: GestureDetector(
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
                    child: const Icon(
                      Icons.edit,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$name',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 8,
                                width: 8,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: Colors.blue[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Professor',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'India',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'I am an Associate Professor (CSE, AI) & PMRF Coordinator at IIT Ropar.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'Interests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: interests
                          ?.map((interest) => _buildInterestButton(interest))
                          ?.toList() ??
                          [],
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for creating interest buttons with icons
  Widget _buildInterestButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[400],
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

  // Helper method for creating stat items
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,

          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,

          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
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
            onPressed: () {
              // TODO: Add password change logic here
              // Validate passwords match and handle the change
              Navigator.pop(context);
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
            onPressed: () {
              // TODO: Implement account deletion logic
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
                'John Doe', // Replace with actual user name
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                'john.doe@example.com', // Replace with actual user email
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
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.purple[900] : Colors.purple[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storage,
                  color: isDarkMode ? Colors.purple[300] : Colors.purple[600],
                ),
              ),
              title: Text(
                'Data Management',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: const Text('Download or delete your data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement data management screen
              },
            ),

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
