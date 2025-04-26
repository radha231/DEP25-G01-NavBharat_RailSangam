import 'dart:async';
import 'dart:math';
import 'package:classico/profile_page.dart';
import 'package:classico/train_social_app.dart';
import 'package:classico/travelers_page.dart';
import 'package:classico/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'chats_page.dart';
import 'globals.dart';
import 'location_info_page.dart';


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
    int fromIndex = widget.selectedTrain.stations.length;
    for (int i = 0; i < widget.selectedTrain.stations.length; i++) {
      if (widget.selectedTrain.stations[i] == Globals.currentStation) {
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
        widget.selectedTrain.coordinates.removeAt(0);
      }
      if(widget.selectedTrain.stations.isEmpty) {
        Globals.currentStation = 'End';
      } else {
        Globals.currentStation = widget.selectedTrain.stations[0];
      }
    }
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      print('KKKKKKK');
      final position = await LocationService.getCurrentLocation();
      print(position);
      if (position != null) {
        checkNearestStation(position);
      }
    });
  }

  void checkNearestStation(Position position) {
    print('check called');
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
    // print(currentStationIndex);
    // print()
    if (distanceRemaining < 15) {
      final trainSocialAppState = context.findAncestorStateOfType<TrainSocialAppState>();
      print("LLLL");
      if (trainSocialAppState != null) {
        currentStationIndex++;
        print("jhfkg");
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
