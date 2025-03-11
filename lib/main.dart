import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:math';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import './notificationPage.dart';
import 'splashscreen.dart'; // Import the new splash screen
import 'login_screen.dart'; // Import login screen
import 'package:classico/chatting/page/chat_page.dart';
import 'package:classico/chatting/page/chats_page.dart';
import 'package:classico/chatting/model/user.dart';
import 'package:classico/chatting/model/user.dart';
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
  runApp(const TrainSocialApp());
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
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
                      CustomTextField(
                        label: 'Your Interests',
                        prefixIcon: Icons.interests,
                        hint: 'e.g., Photography, History, Food',
                      ),
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
                                print('coaches:::');
                                print(coaches);
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
                                      : () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => HomePage(selectedTrain: selectedTrain!),
                                      ),
                                    );
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
  @override
  void initState() {
    super.initState();
    initNotifications();
  }

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
    return MaterialApp(
      navigatorKey: navigatorKey, // Set the navigator key
      title: 'Train Social',
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // Set SplashScreen as the initial route
      routes: {
        '/login': (context) => const LoginScreen(),
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
        ),
      ),
      // home: const LoginPage(),
    );
  }

  // Function to show the notification (this stays here)
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

  const HomePage({required this.selectedTrain, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  Timer? _locationTimer;
  int currentStationIndex = 0;
  double distanceRemaining =1000.0;

  @override
  void initState() {
    super.initState();
    _pages = [
      const TravelersPage(),
      LocationInfoPage(selectedTrain: widget.selectedTrain),
      HomeScreen(),
      const ProfilePage(),
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
  const TravelersPage({super.key});

  @override
  _TravelersPageState createState() => _TravelersPageState();
}

class _TravelersPageState extends State<TravelersPage> {
  // User's own data
  final Map<String, dynamic> currentUser = {
    'name': 'Puneet',
    'avatar': 'assets/images/sam.jpeg',
    'stories': [], // Initially empty
  };

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
  final List<Map<String, dynamic>> friends = [
    {
      'name': 'Rakshit',
      'avatar': 'assets/images/steven.jpeg',
      'stories': [
        {
          'image': 'assets/images/pic1.jpg',
          'caption': 'Amazing Train View',
          'likes': 25,
          'comments': 4,
        },
        {
          'image': 'assets/images/pic1.jpg',
          'caption': 'Sunset at the beach',
          'likes': 378,
          'comments': 62,
        }
      ]
    },
    {
      'name': 'Nishant',
      'avatar': 'assets/images/john.jpeg',
      'stories': [
        {
          'image': 'assets/images/pic1.jpg',
          'caption': 'Exploring new views from train',
          'likes': 41,
          'comments': 7,
        }
      ]
    },
    // Add more friends as needed
  ];

  // Hover state tracking
  bool _isAddStoryHovered = false;
  Map<String, bool> _friendHoverStates = {};

  @override
  void initState() {
    super.initState();
    // Initialize hover states for friends
    _friendHoverStates = {for (var friend in friends) friend['name']: false};
  }

  // Method to add a new story
  void _addNewStory() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add New Story',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildStoryOption(
                  icon: Icons.camera_alt,
                  title: 'Take Photo',
                  onTap: () {
                    // Implement camera functionality
                    Navigator.pop(context);
                  }
              ),
              _buildStoryOption(
                  icon: Icons.photo_library,
                  title: 'Choose from Gallery',
                  onTap: () {
                    // Implement gallery selection
                    Navigator.pop(context);
                  }
              ),
              _buildStoryOption(
                  icon: Icons.videocam,
                  title: 'Record Video',
                  onTap: () {
                    // Implement video recording
                    Navigator.pop(context);
                  }
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method for story options with hover effect
  Widget _buildStoryOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: ListTile(
          leading: Icon(icon, color: Color(0xFF4A89DC)),
          title: Text(title),
        ),
      ),
    );
  }

  // Method to show suggestions bottom sheet
  void _showSuggestionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Traveller Suggestions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildSuggestionTile(
                avatar: 'assets/images/sophia.jpeg',
                name: 'Radha',
                location: 'Haryana,India',
              ),
              _buildSuggestionTile(
                avatar: 'assets/images/greg.jpeg',
                name: 'Nitika',
                location: 'Noida,India',
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method for suggestion tiles with hover effect
  Widget _buildSuggestionTile({
    required String avatar,
    required String name,
    required String location
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: AssetImage(avatar),
        ),
        title: Text(name),
        subtitle: Text(location),
        trailing: ElevatedButton(
          onPressed: () {},
          child: Text('Follow'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4A89DC),
          ),
        ),
      ),
    );
  }

  // Method to show story viewer
  void _showStoryViewer(Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: 300,
            height: 500,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    itemCount: friend['stories'].length,
                    itemBuilder: (context, index) {
                      final story = friend['stories'][index];
                      return Image.asset(
                        story['image'],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    friend['name'] + "'s Stories",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  // Friend story builder with hover effects
  Widget _buildFriendStory(Map<String, dynamic> friend) {
    return MouseRegion(
      onEnter: (_) => setState(() => _friendHoverStates[friend['name']] = true),
      onExit: (_) => setState(() => _friendHoverStates[friend['name']] = false),
      child: GestureDetector(
        onTap: () => _showStoryViewer(friend),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: Matrix4.identity()..scale(_friendHoverStates[friend['name']] == true ? 1.1 : 1.0),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(friend['avatar']),
                    fit: BoxFit.cover,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _friendHoverStates[friend['name']] == true
                        ? Color(0xFF4A89DC).withOpacity(0.7)
                        : Color(0xFF4A89DC),
                    width: 2,
                  ),
                  boxShadow: _friendHoverStates[friend['name']] == true
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    )
                  ]
                      : [],
                ),
              ),
              SizedBox(height: 5),
              Text(
                friend['name'].split(' ')[0],
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: _friendHoverStates[friend['name']] == true
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Your Story builder with hover effects
  Widget _buildYourStory() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isAddStoryHovered = true),
      onExit: (_) => setState(() => _isAddStoryHovered = false),
      child: GestureDetector(
        onTap: _addNewStory,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: Matrix4.identity()..scale(_isAddStoryHovered ? 1.1 : 1.0),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(currentUser['avatar']),
                        fit: BoxFit.cover,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isAddStoryHovered
                            ? Color(0xFF4A89DC).withOpacity(0.7)
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: _isAddStoryHovered
                          ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        )
                      ]
                          : [],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF4A89DC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5),
              Text(
                'Your Story',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: _isAddStoryHovered ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // Widget to build a traveler's post card
  Widget _buildTravelerPostCard(Map<String, dynamic> friend, Map<String, dynamic> story) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Image
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            child: Image.asset(
              story['image'], // Replace with your actual image path
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
            ),
          ),
          // Post Details
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: AssetImage(friend['avatar']),
                      radius: 20,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '2 hours ago',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10),
                // Caption
                Text(
                  story['caption'],
                  style: TextStyle(
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                // Interactions
                Row(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          // Like functionality
                        },
                        child: Row(
                          children: [
                            Icon(Icons.favorite_border, color: Colors.grey),
                            SizedBox(width: 5),
                            Text('${story['likes']} Likes'),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          // Comment functionality
                        },
                        child: Row(
                          children: [
                            Icon(Icons.comment_outlined, color: Colors.grey),
                            SizedBox(width: 5),
                            Text('${story['comments']} Comments'),
                          ],
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
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildHoverableIconButton(
            icon: Icons.menu,
            color: Colors.black,
            onPressed: () {/* Menu functionality */}
        ),
        title: Text(
          'Travellers',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          _buildHoverableIconButton(
              icon: Icons.notifications_outlined,
              color: Colors.black,
              onPressed: () {/* Notifications functionality */}
          ),
          _buildHoverableIconButton(
              icon: Icons.chat_bubble_outline,
              color: Colors.black,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(),
                  ),
                );
              }
          ),
          _buildHoverableIconButton(
              icon: Icons.people_outline,
              color: Colors.black,
              onPressed: _showSuggestionsBottomSheet
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Friends Horizontal Scroll
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Your Story first
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _buildYourStory(),
                        ),
                        // Other friends stories
                        ...friends.map((friend) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _buildFriendStory(friend),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Travelers Feed Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Travellers Feed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return friend['stories'].isNotEmpty
                    ? _buildTravelerPostCard(friend, friend['stories'][0])
                    : SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _addNewStory,
      //   backgroundColor: Color(0xFF4A89DC),
      //   child: Icon(Icons.add, color: Colors.white),
      // ),
    );
  }

}



class TravelerCard extends StatelessWidget {
  final String name;
  final List<String> interests;
  final String destination;
  final VoidCallback onChat;

  const TravelerCard({
    required this.name,
    required this.interests,
    required this.destination,
    required this.onChat,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE94560),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name[0],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE94560),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE94560),
                        ),
                      ),
                      Text(
                        'Traveling to $destination',
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: const Color(0xFFE94560),
                  ),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interests.map((interest) {
                return Chip(
                  label: Text(
                    interest,
                    style: TextStyle(color: const Color(0xFFE94560)),
                  ),
                  backgroundColor: const Color(0xFF0F3460),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Start Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94560),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    Icons.favorite_border,
                    color: const Color(0xFFE94560),
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool showSettings = false;

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Edit Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                // Handle gallery selection
                Navigator.pop(context);
                // Add image picking logic here
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                // Handle camera selection
                Navigator.pop(context);
                // Add camera capture logic here
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showSettings) {
      return AccountSettingsScreen(
        onBack: () => setState(() => showSettings = false),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final profileImageHeight = screenHeight * 0.55; // Adjusted to take less space

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Top portion with profile image and controls
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Profile image container
              Container(
                height: profileImageHeight,
                width: double.infinity,
                child: Image.asset(
                  'assets/images/sam.jpeg',
                  fit: BoxFit.cover,
                ),
              ),

              // Settings button (top right)
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

              // Edit profile picture button
              Positioned(
                bottom: 10,
                right: 20,
                child: GestureDetector(
                  onTap: _showImageSourceOptions,
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
                      color: Colors.pink,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Profile information section - now BELOW the profile image
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dr. Puneet Goyal',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pink[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 8,
                                width: 8,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: Colors.pink[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.pink[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Occupation and location
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

                    // About section
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

                    // Interests section
                    const Text(
                      'Interests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Interest buttons
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildInterestButton('Teaching', Icons.star),
                        _buildInterestButton('Learning', Icons.book),
                        _buildInterestButton('Travel', Icons.flight),
                        _buildInterestButton('Technology', Icons.language),
                        _buildInterestButton('Education', Icons.design_services),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Sta
                    const SizedBox(height: 15),

                    // Stats display - fixed to use the correct method

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
  Widget _buildInterestButton(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.pink[400],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
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

  const AccountSettingsScreen({
    Key? key,
    required this.onBack,
  }) : super(key: key);

  @override
  _AccountSettingsScreenState createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // Changed to light blue
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ListView(
          children: [
            const SizedBox(height: 10),

            // Account section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Profile settings - using blue colors now
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.blue[400],
                ),
              ),
              title: const Text('Personal Information'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            // Privacy settings - using blue colors now
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  color: Colors.blue[600],
                ),
              ),
              title: const Text('Privacy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            // Account security - using blue colors now
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security,
                  color: Colors.blue[400],
                ),
              ),
              title: const Text('Security'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            const Divider(),

            // Notifications section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Notification toggle - changed to blue
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: Text(
                notificationsEnabled
                    ? 'You will receive notifications'
                    : 'You will not receive notifications',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              value: notificationsEnabled,
              activeColor: Colors.blue[600], // Changed to blue
              onChanged: (value) {
                setState(() {
                  notificationsEnabled = value;
                });
              },
            ),

            // Email notifications
            ListTile(
              title: const Text('Email Notifications'),
              subtitle: Text(
                'Manage email preferences',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            const Divider(),

            // Other settings section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Other',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Help and support - using blue colors now
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline,
                  color: Colors.blue[400],
                ),
              ),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            // About - using blue colors now
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.blue[600],
                ),
              ),
              title: const Text('About'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            const SizedBox(height: 10),
            const Divider(),

            // Logout button - kept red for better visibility
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: GestureDetector(
                onTap: () {
                  // Handle logout
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.logout,
                        color: Colors.red[400],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Log Out',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
