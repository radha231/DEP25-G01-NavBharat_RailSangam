import 'package:flutter/material.dart';
import 'package:classico/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './globals.dart';
import 'home_page.dart';

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
                Globals.currentStation = journeyData['current_station'] as String?;
                Globals.from_station = journeyData['from_station'] as String?;
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
                  // Globals.currentStation = stations[0];
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
                    // print("jai shree krishna");
                    // print(coordinates);
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
                                      'current_station' : selectedFromStation,
                                      'to_station': selectedToStation,
                                      'timestamp': FieldValue.serverTimestamp(),
                                      'expiryDate': Timestamp.fromDate(expiryDate!), // Firestore timestamp
                                    }).then((_) {
                                      // Save email to shared preferences
                                      SharedPreferences.getInstance().then((prefs) {
                                        prefs.setString('user_email', emailId);
                                      });
                                      Globals.currentStation = selectedFromStation;
                                      Globals.from_station = selectedFromStation;
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