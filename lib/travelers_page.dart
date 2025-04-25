import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chats_page.dart';
import 'globals.dart';
import 'notificationPage.dart';

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


  // Add these variables to track filter changes
  bool _filtersChanged = false;
  Map<String, String?> _currentFilters = {
    'profession': null,
    'ageGroup': null,
    'gender': null,
    'interest': null,
  };


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
          if(response.payload == Globals.currentStation){
            print("AAAAA");
            // Globals.currentStation = widget.
            Navigator.push(
              Globals.navigatorKey.currentContext!, // Use the navigator key
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
          // In the _fetchSuggestedUsers method, modify the users.add part:
          users.add({
            ...userData,
            'email_Id': userData['email_Id'],
            'Name': userData['Name'],
            'Profession': userData['Profession'],
            'avatarUrl': userData['avatarUrl'],
          });
        }
      }

      // Initialize follow request states
      for (var user in users) {
        _followRequestStates[user['email_Id']] = pendingApprovals.contains(user['email_Id']);
      }

      users.sort((a, b) {
        final aEmail = a['email_Id'];
        final bEmail = b['email_Id'];
        final aIsConnected = following.contains(aEmail);
        final bIsConnected = following.contains(bEmail);

        if (aIsConnected && !bIsConnected) return -1;
        if (!aIsConnected && bIsConnected) return 1;
        return 0;
      });

      setState(() {
        suggestedUsers = users;
        _allSuggestedUsers = List.from(users);
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

      setState(() {
        _followRequestStates[targetEmail] = true; // Mark request as sent
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
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
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
              // First Row - Profession and Age Group
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
                      filterKey: 'profession',
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
                      filterKey: 'ageGroup',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              // Second Row - Gender and Interest
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
                      filterKey: 'gender',
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
                      filterKey: 'interest',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              // Third Row - Search and Clear Buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        gradient: _filtersChanged
                            ? LinearGradient(colors: [Colors.orange, Colors.deepOrange])
                            : buttonGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: (_filtersChanged ? Colors.orange : Color(0xFF4A89DC)).withOpacity(0.3),
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
                          _filtersChanged ? 'Apply Filters' : 'Search',
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
            ],
          ),
        );
      },
    );
  }

// Remove the separate _buildFilterButtons() method since we've moved it into _buildFilterRow()
  Widget _buildFilterDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
    required String filterKey,
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
        onChanged: (newValue) {
          // Only update the current filters without triggering a rebuild
          _currentFilters[filterKey] = newValue;
          _filtersChanged = true;
          // Update the dropdown value without setState
          onChanged(newValue);
        },
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }
  void _applyFilters() {
    if (!_filtersChanged &&
        selectedProfession == null &&
        selectedAgeGroup == null &&
        selectedGender == null &&
        selectedInterest == null) {
      return; // No filters selected and no changes made
    }

    setState(() {
      _isLoading = true;
      suggestedUsers = _allSuggestedUsers.where((user) {
        bool matchesProfession = _currentFilters['profession'] == null ||
            user['Profession'] == _currentFilters['profession'];
        bool matchesAgeGroup = _currentFilters['ageGroup'] == null ||
            user['Age Group'] == _currentFilters['ageGroup'];
        bool matchesGender = _currentFilters['gender'] == null ||
            user['Gender'] == _currentFilters['gender'];
        bool matchesInterest = _currentFilters['interest'] == null ||
            (user['Interests'] != null &&
                (user['Interests'] as List).contains(_currentFilters['interest']));

        return matchesProfession && matchesAgeGroup && matchesGender && matchesInterest;
      }).toList();
      _filtersChanged = false;
      _isLoading = false;
    });
  }
// Add a method to clear filters
  void _clearFilters() {
    setState(() {
      selectedProfession = null;
      selectedAgeGroup = null;
      selectedGender = null;
      selectedInterest = null;
      _currentFilters = {
        'profession': null,
        'ageGroup': null,
        'gender': null,
        'interest': null,
      };
      suggestedUsers = List.from(_allSuggestedUsers);
      _filtersChanged = false;
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

    // Check if user is already connected
    final isConnected = following.contains(email);
    final isRequestSent = _followRequestStates[email] ?? false;

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
        onPressed: isConnected || isRequestSent
            ? null
            : () => _sendFollowRequest(email),
        style: ElevatedButton.styleFrom(
          backgroundColor: isConnected
              ? Colors.green
              : (isRequestSent ? Colors.grey : Colors.blue),
        ),
        child: Text(
          isConnected
              ? 'Connected'
              : (isRequestSent ? 'Request Sent' : 'Connect'),
          style: TextStyle(color: Colors.white),
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
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 16),
          child: Text(
            'Travellers',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        centerTitle: false,
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

          // Divider with subtle styling
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(
              color: Colors.grey[300],
              thickness: 1,
              height: 1,
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
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
              _buildFilterRow(), // Original unchanged
            ],
          ),
          // User list with NotificationListener to prevent unnecessary rebuilds
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemCount: suggestedUsers.length,
                itemBuilder: (context, index) {
                  final user = suggestedUsers[index];
                  return _buildUserGridCard(user);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildUserGridCard(Map<String, dynamic> user) {
    final email = user['email_Id'];
    final isConnected = following.contains(email);
    final isRequestSent = _followRequestStates[email] ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                  ),
                  child: ClipOval(
                    child: user['avatarUrl'] != null && user['avatarUrl'].isNotEmpty
                        ? SvgPicture.network(
                      user['avatarUrl'],
                      fit: BoxFit.cover,
                      placeholderBuilder: (context) => Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                        : Icon(Icons.person, size: 35),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  user['Name'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  user['Profession'] ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isConnected || isRequestSent
                    ? null
                    : () => _sendFollowRequest(email),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected
                      ? Colors.green
                      : (isRequestSent ? Colors.grey : Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  isConnected
                      ? 'Connected'
                      : (isRequestSent ? 'Request Sent' : 'Connect'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
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
        'following': FieldValue.arrayUnion([requesterEmail]), // Add to following
      });

      // Update the requester's document
      await _firestore.collection('Users').doc(requesterDoc.id).update({
        'pendingApprovals': FieldValue.arrayRemove([currentUserEmail]), // Remove from pendingApprovals
        'following': FieldValue.arrayUnion([currentUserEmail]), // Add to following
        'followers': FieldValue.arrayUnion([currentUserEmail]), // Add to followers
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
      setState(() {
        following.add(requesterEmail);
        _followRequestStates.remove(requesterEmail);
      });
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
