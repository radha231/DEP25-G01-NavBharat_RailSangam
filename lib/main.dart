// First, add these dependencies to pubspec.yaml:
// geolocator: ^10.1.0
// firebase_core: ^2.24.2
// firebase_database: ^10.4.0
// dropdown_button2: ^2.3.9

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Update the main function to initialize Firebase
// Future<void> addSampleUsers() async {
//   final users = FirebaseFirestore.instance.collection('Coordinates');
//   print("Data Entered");
//
//   final sampleData = [
//     {"Station": "Kalka", "Coordinates": "30.8390°N, 76.9395°E"},
//     {"Station": "Chandigarh", "Coordinates": "30.7046°N, 76.7179°E"},
//     {"Station": "Ambala Cantt", "Coordinates": "30.3752°N, 76.7821°E"},
//     {"Station": "Ambala", "Coordinates": "30.3782°N, 76.7767°E"},
//     {"Station": "Kurukshetra", "Coordinates": "29.9695°N, 76.8783°E"},
//     {"Station": "Panipat", "Coordinates": "29.3901°N, 76.9635°E"},
//     {"Station": "Delhi", "Coordinates": "28.6139°N, 77.2090°E"},
//     {"Station": "Mathura", "Coordinates": "27.4924°N, 77.6737°E"},
//     {"Station": "Kota", "Coordinates": "25.2138°N, 75.8648°E"},
//     {"Station": "Ratlam", "Coordinates": "23.3300°N, 75.0403°E"},
//     {"Station": "Vadodara", "Coordinates": "22.3072°N, 73.1812°E"},
//     {"Station": "Mumbai Central", "Coordinates": "18.9710°N, 72.8194°E"},
//     {"Station": "Saharanpur", "Coordinates": "29.9640°N, 77.5460°E"},
//     {"Station": "Moradabad", "Coordinates": "28.8386°N, 78.7733°E"},
//     {"Station": "Lucknow", "Coordinates": "26.8467°N, 80.9462°E"},
//     {"Station": "Prayagraj", "Coordinates": "25.4358°N, 81.8463°E"},
//     {"Station": "Bareilly", "Coordinates": "28.3670°N, 79.4304°E"},
//     {"Station": "Kanpur", "Coordinates": "26.4499°N, 80.3319°E"},
//     {"Station": "Agra", "Coordinates": "27.1767°N, 78.0081°E"},
//     {"Station": "Nagpur", "Coordinates": "21.1458°N, 79.0882°E"},
//     {"Station": "Vijayawada", "Coordinates": "16.5062°N, 80.6480°E"},
//     {"Station": "Ernakulam", "Coordinates": "9.9816°N, 76.2999°E"},
//     {"Station": "Kochuveli", "Coordinates": "8.5215°N, 76.9006°E"},
//     {"Station": "Ludhiana", "Coordinates": "30.9005°N, 75.8462°E"},
//     {"Station": "Jalandhar", "Coordinates": "31.3260°N, 75.5762°E"},
//     {"Station": "Amritsar", "Coordinates": "31.6340°N, 74.8723°E"},
//     {"Station": "Gorakhpur", "Coordinates": "26.7606°N, 83.3732°E"},
//     {"Station": "Guwahati", "Coordinates": "26.1445°N, 91.7362°E"},
//     {"Station": "Dibrugarh", "Coordinates": "27.4728°N, 94.9110°E"},
//     {"Station": "Bandra Terminus", "Coordinates": "19.0544°N, 72.8402°E"},
//     {"Station": "Jaipur", "Coordinates": "26.9124°N, 75.7873°E"},
//     {"Station": "Gurgaon", "Coordinates": "28.4595°N, 77.0266°E"},
//     {"Station": "Rewari", "Coordinates": "28.1970°N, 76.6170°E"},
//     {"Station": "Nangal Dam", "Coordinates": "31.3891°N, 76.3755°E"},
//     {"Station": "Ropar", "Coordinates": "30.9671°N, 76.5231°E"},
//     {"Station": "Morinda", "Coordinates": "30.7890°N, 76.4977°E"},
//     {"Station": "Una", "Coordinates": "31.4640°N, 76.2708°E"},
//     {"Station": "Amb Andaura", "Coordinates": "31.6410°N, 76.2160°E"},
//   ];
//
//   for (var station in sampleData) {
//     await users.add(station);
//   }
//   print("Data Added Successfully");
// }


// Future<void> deleteAllData() async {
//   try {
//
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     // Specify the names of the collections you want to delete
//     final collectionNames = ['Trains']; // Replace with your actual collection names
//
//     for (String collectionName in collectionNames) {
//       final collectionRef = firestore.collection(collectionName);
//       // Get all documents in the collection
//       final snapshot = await collectionRef.get();
//       for (var doc in snapshot.docs) {
//         // Delete each document
//         await doc.reference.delete();
//       }
//     }
//
//     print('All data deleted successfully.');
//   } catch (e) {
//     print('Error deleting data: $e');
//   }
// }
Future<Position?> getLiveLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Check if GPS is enabled
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print("Location services are disabled.");
    return null;
  }

  // Request location permissions
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print("Location permissions are denied.");
      return null;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    print("Location permissions are permanently denied.");
    return null;
  }

  // Get live location updates
  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    name: 'classico-dc2a9',
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // addSampleUsers();
  Position? position = await getLiveLocation();
  if (position != null) {
    print("Latitude: ${position.latitude}, Longitude: ${position.longitude}");
  } else {
    print("Failed to fetch location.");
  }
  runApp(const TrainSocialApp());
}

// Add this class to store train data
class Train {
  final String name;
  final List<String> stations;

  Train({required this.name, required this.stations});
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
  String? selectedTrain;
  List<Train> trains = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTrains();
  }

  Future<void> loadTrains() async {
    try {
      // Reference to the 'Trains' collection
      final trainCollection = FirebaseFirestore.instance.collection('Trains');
      final snapshot = await trainCollection.get();

      // Convert snapshot documents to Train objects
      trains = snapshot.docs.map((doc) {
        final data = doc.data();

        // Safely cast the 'Stops' field to a List<String>
        List<String> stations = List<String>.from(data['Stops'] ?? []);

        // Return Train object with name and stops
        return Train(
          name: data['Train Name'] ?? 'Unnamed Train',
          stations: stations,
        );
      }).toList();

      // Update the UI
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading trains: $e');
      setState(() => isLoading = false);
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
                        label: 'PNR Number',
                        prefixIcon: Icons.confirmation_number,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Full Name',
                        prefixIcon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      if (isLoading)
                        const CircularProgressIndicator()
                      else
                        DropdownButtonFormField2(
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          hint: const Text('Select your train'),
                          value: selectedTrain,
                          items: trains
                              .map((train) => DropdownMenuItem(
                            value: train.name,
                            child: Text(train.name),
                          ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedTrain = value as String;
                            });
                          },
                        ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Your Interests',
                        prefixIcon: Icons.interests,
                        hint: 'e.g., Photography, History, Food',
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: selectedTrain == null
                              ? null
                              : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HomePage(
                                  selectedTrain: trains.firstWhere(
                                          (train) =>
                                      train.name == selectedTrain),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.blue[900],
                          ),
                          child: const Text(
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
        ),
      ),
    );
  }
}

// Update HomePage to handle location tracking
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

  @override
  void initState() {
    super.initState();
    _pages = [
      const TravelersPage(),
      LocationInfoPage(selectedTrain: widget.selectedTrain),
      const ChatListPage(),
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
    print('MMMMMMMMM');
    _locationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        print('position: ');
        print(position);
        checkNearestStation(position);
      }
    });
  }

  void checkNearestStation(Position position) {
    // This is a simplified example. In a real app, you would:
    // 1. Store station coordinates in your database
    // 2. Calculate actual distances to next few stations
    // 3. Use more sophisticated logic to determine the next station

    if (currentStationIndex < widget.selectedTrain.stations.length - 1) {
      showNextStationNotification(widget.selectedTrain.stations[currentStationIndex + 1]);
    }
  }

  void showNextStationNotification(String stationName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approaching Next Station'),
        content: Text('Next station will be: $stationName'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rest of the HomePage build method remains the same
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Travelers',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Location',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Update LocationInfoPage to show selected train information
class LocationInfoPage extends StatelessWidget {
  final Train selectedTrain;

  const LocationInfoPage({required this.selectedTrain, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(selectedTrain.name),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue[900]!,
                      Colors.blue[700]!,
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.train,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const HistoryCard(),
                const SizedBox(height: 16),
                Text(
                  'Upcoming Stops',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedTrain.stations.length,
                  itemBuilder: (context, index) {
                    return StopCard(
                      name: selectedTrain.stations[index],
                      time: 'Estimated',
                      distance: 'Calculating...',
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

class TrainSocialApp extends StatelessWidget {
  const TrainSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Train Social',
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
      home: const LoginPage(),
    );
  }
}


class CustomTextField extends StatelessWidget {
  final String label;
  final IconData prefixIcon;
  final String? hint;

  const CustomTextField({
    required this.label,
    required this.prefixIcon,
    this.hint,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon),
      ),
    );
  }
}


class TravelersPage extends StatelessWidget {
  const TravelersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fellow Travelers'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) {
          return TravelerCard(
            name: 'Traveler ${index + 1}',
            interests: ['Photography', 'History', 'Food'],
            destination: 'Mumbai',
            onChat: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(userId: index.toString()),
                ),
              );
            },
          );
        },
      ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    name[0],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Traveling to $destination',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interests.map((interest) {
                return Chip(
                  label: Text(interest),
                  backgroundColor: Colors.blue[50],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Start Chat'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.blue[900]),
                const SizedBox(width: 8),
                Text(
                  'Historical Significance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'AI-generated historical information will appear here...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class StopCard extends StatelessWidget {
  final String name;
  final String time;
  final String distance;

  const StopCard({
    required this.name,
    required this.time,
    required this.distance,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.train),
        ),
        title: Text(name),
        subtitle: Text('Arrival: $time'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              distance,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'ahead',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              child: Text('U${index + 1}'),
            ),
            title: Text('Chat ${index + 1}'),
            subtitle: const Text('Last message...'),
            trailing: const Text('2:30 PM'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(userId: index.toString()),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  final String userId;

  const ChatPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                'U$userId',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User $userId'),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
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
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: 10,
              itemBuilder: (context, index) {
                final bool isMe = index % 2 == 0;
                return MessageBubble(
                  message: 'This is message $index',
                  isMe: isMe,
                  time: '2:30 PM',
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey,
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.attach_file),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue[900],
                  child: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                    onPressed: () {},
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

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;

  const MessageBubble({
    required this.message,
    required this.isMe,
    required this.time,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue[900] : Colors.grey[200],
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomRight: isMe ? Radius.zero : Radius.circular(20),
              bottomLeft: isMe ? Radius.circular(20) : Radius.zero,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: isMe ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('John Doe'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue[900]!,
                      Colors.blue[700]!,
                    ],
                  ),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      'JD',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const JourneyCard(),
                const SizedBox(height: 16),
                const InterestsCard(),
                const SizedBox(height: 16),
                const SettingsCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class JourneyCard extends StatelessWidget {
  const JourneyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Journey',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const InfoRow(
              icon: Icons.confirmation_number,
              label: 'PNR',
              value: '1234567890',
            ),
            const Divider(height: 24),
            const InfoRow(
              icon: Icons.location_on,
              label: 'From',
              value: 'Delhi',
            ),
            const Divider(height: 24),
            const InfoRow(
              icon: Icons.location_on_outlined,
              label: 'To',
              value: 'Mumbai',
            ),
          ],
        ),
      ),
    );
  }
}

class InterestsCard extends StatelessWidget {
  const InterestsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Interests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Photography',
                'History',
                'Food',
                'Culture',
                'Architecture',
                'Nature',
              ].map((interest) {
                return Chip(
                  label: Text(interest),
                  backgroundColor: Colors.blue[50],
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {},
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add Interest'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: Switch(
              value: true,
              onChanged: (value) {},
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red[700]),
            title: Text(
              'Logout',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
