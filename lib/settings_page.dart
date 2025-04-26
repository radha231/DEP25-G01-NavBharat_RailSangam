import 'package:audioplayers/audioplayers.dart';
import 'package:classico/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
import 'login_screen.dart';

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




  void _showRatingDialog() async {
    double rating = 0;
    double previousRating = 0;

    // Step 1: Fetch previous rating (if any)
    CollectionReference feedbackCollection = FirebaseFirestore.instance.collection('Feedback');
    try {
      QuerySnapshot querySnapshot = await feedbackCollection
          .where('email_id', isEqualTo: emailId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Previous rating exists
        previousRating = querySnapshot.docs.first['Rating']?.toDouble() ?? 0;
        rating = previousRating;
      }
    } catch (e) {
      // Optional: Show error or log it silently
      debugPrint('Failed to fetch previous rating: $e');
    }

    // Step 2: Show the rating dialog with the previous rating
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
              initialRating: previousRating,
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
            onPressed: () async {
              // Play sound when submitting
              String soundPath = 'assets/sounds/rating.mp3';
              _audioPlayer.play(AssetSource(soundPath));

              try {
                // Check again in case of race condition
                QuerySnapshot querySnapshot = await feedbackCollection
                    .where('email_id', isEqualTo: emailId)
                    .limit(1)
                    .get();

                if (querySnapshot.docs.isNotEmpty) {
                  await querySnapshot.docs.first.reference.update({
                    'Rating': rating.toInt(),
                  });
                } else {
                  await feedbackCollection.add({
                    'email_id': emailId,
                    'Rating': rating.toInt(),
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Thanks for rating us ${rating.toInt()} stars!'),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error submitting feedback: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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
  void _showFeedbackDialog() async {
    // Step 1: Clear any previous input
    _feedbackController.clear();

    // Step 2: Try to fetch previous feedback
    CollectionReference feedbackCollection = FirebaseFirestore.instance.collection('Feedback');

    try {
      QuerySnapshot querySnapshot = await feedbackCollection
          .where('email_id', isEqualTo: emailId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final previousFeedback = querySnapshot.docs.first['feedback'];
        if (previousFeedback != null && previousFeedback is String) {
          _feedbackController.text = previousFeedback;
        }
      }
    } catch (e) {
      debugPrint('Failed to load previous feedback: $e');
      // Optional: Show a toast/snackbar or ignore silently
    }

    // Step 3: Show the dialog with the controller now prefilled
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
            onPressed: () async {
              final String feedbackText = _feedbackController.text.trim();

              if (feedbackText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Feedback cannot be empty.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                QuerySnapshot querySnapshot = await feedbackCollection
                    .where('email_id', isEqualTo: emailId)
                    .limit(1)
                    .get();

                if (querySnapshot.docs.isNotEmpty) {
                  await querySnapshot.docs.first.reference.update({
                    'feedback': feedbackText,
                  });
                } else {
                  await feedbackCollection.add({
                    'email_id': emailId,
                    'feedback': feedbackText,
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your feedback!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _feedbackController.clear();
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error submitting feedback: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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
    // final TextEditingController professionController = TextEditingController();

    // Values for dropdowns
    String? selectedGender;
    String? selectedAgeGroup;
    String? selectedProfession;
    // Options for dropdowns
    final List<String> genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
    final List<String> ageGroupOptions = ['18-24', '25-34', '35-44', '45-54', '55+'];
    final List<String> professionOptions = ['Student', 'Engineer', 'Doctor', 'Artist', 'Other'];

    // Track if at least one field is filled
    bool isAtLeastOneFieldFilled() {
      return nameController.text.trim().isNotEmpty ||
          selectedProfession != null ||
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

                    Text('Profession:'),
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: Text('Select Profession'),
                      value: selectedProfession,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedProfession = newValue;
                          canSubmit = isAtLeastOneFieldFilled();
                        });
                      },
                      items: professionOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canSubmit ? () async {
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

                      if (selectedProfession != null) {
                        updatedData['Profession'] = selectedProfession;
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

                      Navigator.pop(context, true); // Return true for success
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Profile updated successfully!'))
                      );
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
        // In AppBar of AccountSettingsScreen
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            widget.onBack(); // This will trigger the refresh
            Navigator.pop(context, true); // Return true to indicate possible changes
          },
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
            //
            // // Theme toggle - now connected to ThemeProvider
            // SwitchListTile(
            //   title: Text(
            //     'Dark Mode',
            //     style: TextStyle(
            //       color: isDarkMode ? Colors.white : Colors.black,
            //     ),
            //   ),
            //   subtitle: Text(
            //     isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
            //     style: TextStyle(
            //       color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            //       fontSize: 13,
            //     ),
            //   ),
            //   value: isDarkMode,
            //   activeColor: Colors.blue[600],
            //   onChanged: (value) {
            //     // Toggle theme using the provider
            //     themeProvider.toggleTheme();
            //   },
            // ),

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
            // ListTile(
            //   leading: Container(
            //     padding: const EdgeInsets.all(8),
            //     decoration: BoxDecoration(
            //       color: isDarkMode ? Colors.teal[900]! : Colors.teal[50]!, // Added ! to handle nullable
            //       shape: BoxShape.circle,
            //     ),
            //     child: Icon(
            //       Icons.language,
            //       color: isDarkMode ? Colors.teal[300]! : Colors.teal[600]!, // Added ! to handle nullable
            //     ),
            //   ),
            //   title: Text(
            //     'Language', // Will be replaced with translation later
            //     style: TextStyle(
            //       color: isDarkMode ? Colors.white : Colors.black,
            //     ),
            //   ),
            //   subtitle: Text(
            //     'English', // Placeholder for current language
            //     style: TextStyle(
            //       color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!, // Added ! to handle nullable
            //       fontSize: 13,
            //     ),
            //   ),
            //   trailing: const Icon(Icons.chevron_right),
            //   onTap: () {
            //     // Show language selection UI when tapped
            //     showModalBottomSheet(
            //       context: context,
            //       isScrollControlled: true,
            //       backgroundColor: Colors.transparent,
            //       builder: (context) => Container(
            //         height: MediaQuery.of(context).size.height * 0.7,
            //         decoration: BoxDecoration(
            //           color: isDarkMode ? const Color(0xFF202020) : Colors.white,
            //           borderRadius: const BorderRadius.only(
            //             topLeft: Radius.circular(20),
            //             topRight: Radius.circular(20),
            //           ),
            //           boxShadow: [
            //             BoxShadow(
            //               color: Colors.black.withOpacity(0.2),
            //               blurRadius: 10,
            //               spreadRadius: 0,
            //             )
            //           ],
            //         ),
            //         child: Column(
            //           children: [
            //             // Handle bar
            //             Container(
            //               margin: const EdgeInsets.only(top: 12),
            //               height: 4,
            //               width: 40,
            //               decoration: BoxDecoration(
            //                 color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!, // Added ! to handle nullable
            //                 borderRadius: BorderRadius.circular(2),
            //               ),
            //             ),
            //             // Title
            //             Padding(
            //               padding: const EdgeInsets.all(16.0),
            //               child: Text(
            //                 'Select Language',
            //                 style: TextStyle(
            //                   fontSize: 22,
            //                   fontWeight: FontWeight.bold,
            //                   color: isDarkMode ? Colors.white : Colors.black,
            //                 ),
            //               ),
            //             ),
            //             // Language Grid
            //             Expanded(
            //               child: Padding(
            //                 padding: const EdgeInsets.symmetric(horizontal: 16.0),
            //                 child: GridView.builder(
            //                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            //                     crossAxisCount: 2,
            //                     childAspectRatio: 1.5,
            //                     crossAxisSpacing: 16,
            //                     mainAxisSpacing: 16,
            //                   ),
            //                   itemCount: 6, // Six languages
            //                   itemBuilder: (context, index) {
            //                     // Define language options inline
            //                     String code = '', name = '', nativeName = '';
            //
            //                     switch(index) {
            //                       case 0:
            //                         code = 'en';
            //                         name = 'English';
            //                         nativeName = 'English';
            //                         break;
            //                       case 1:
            //                         code = 'hi';
            //                         name = 'Hindi';
            //                         nativeName = 'हिन्दी';
            //                         break;
            //                       case 2:
            //                         code = 'bn';
            //                         name = 'Bengali';
            //                         nativeName = 'বাংলা';
            //                         break;
            //                       case 3:
            //                         code = 'pa';
            //                         name = 'Punjabi';
            //                         nativeName = 'ਪੰਜਾਬੀ';
            //                         break;
            //                       case 4:
            //                         code = 'te';
            //                         name = 'Telugu';
            //                         nativeName = 'తెలుగు';
            //                         break;
            //                       case 5:
            //                         code = 'mr';
            //                         name = 'Marathi';
            //                         nativeName = 'मराठी';
            //                         break;
            //                     }
            //
            //                     final isSelected = code == 'en'; // Placeholder logic
            //
            //                     return AnimatedContainer(
            //                       duration: const Duration(milliseconds: 200),
            //                       decoration: BoxDecoration(
            //                         color: isSelected
            //                             ? isDarkMode ? Colors.teal[900]! : Colors.teal[50]! // Added ! to handle nullable
            //                             : isDarkMode ? const Color(0xFF303030) : Colors.grey[100]!, // Added ! to handle nullable
            //                         borderRadius: BorderRadius.circular(12),
            //                         border: Border.all(
            //                           color: isSelected
            //                               ? Colors.teal
            //                               : isDarkMode ? Colors.grey[700]! : Colors.grey[300]!, // Added ! to handle nullable
            //                           width: 2,
            //                         ),
            //                       ),
            //                       child: InkWell(
            //                         onTap: () {
            //                           // Just close the sheet for now
            //                           Navigator.pop(context);
            //                         },
            //                         borderRadius: BorderRadius.circular(12),
            //                         child: Column(
            //                           mainAxisAlignment: MainAxisAlignment.center,
            //                           children: [
            //                             Text(
            //                               nativeName,
            //                               style: TextStyle(
            //                                 fontSize: 18,
            //                                 fontWeight: FontWeight.bold,
            //                                 color: isSelected
            //                                     ? isDarkMode ? Colors.teal[200]! : Colors.teal[800]! // Added ! to handle nullable
            //                                     : isDarkMode ? Colors.white : Colors.black,
            //                               ),
            //                             ),
            //                             const SizedBox(height: 4),
            //                             Text(
            //                               name,
            //                               style: TextStyle(
            //                                 fontSize: 14,
            //                                 color: isSelected
            //                                     ? isDarkMode ? Colors.teal[200]! : Colors.teal[800]! // Added ! to handle nullable
            //                                     : isDarkMode ? Colors.grey[400]! : Colors.grey[600]!, // Added ! to handle nullable
            //                               ),
            //                             ),
            //                             if (isSelected)
            //                               Icon(
            //                                 Icons.check_circle,
            //                                 color: isDarkMode ? Colors.teal[200]! : Colors.teal[800]!, // Added ! to handle nullable
            //                                 size: 20,
            //                               ),
            //                           ],
            //                         ),
            //                       ),
            //                     );
            //                   },
            //                 ),
            //               ),
            //             ),
            //             // Cancel button
            //             Padding(
            //               padding: const EdgeInsets.all(16.0),
            //               child: ElevatedButton(
            //                 onPressed: () => Navigator.pop(context),
            //                 style: ElevatedButton.styleFrom(
            //                   minimumSize: const Size(double.infinity, 50),
            //                   backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!, // Added ! to handle nullable
            //                   foregroundColor: isDarkMode ? Colors.white : Colors.black,
            //                   shape: RoundedRectangleBorder(
            //                     borderRadius: BorderRadius.circular(12),
            //                   ),
            //                 ),
            //                 child: const Text('Cancel'),
            //               ),
            //             ),
            //           ],
            //         ),
            //       ),
            //     );
            //   },
            // ),


            // Feedback and support section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Feedback',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),

            // Help and support with app guide and contact info
            // ListTile(
            //   leading: Container(
            //     padding: const EdgeInsets.all(8),
            //     decoration: BoxDecoration(
            //       color: isDarkMode ? Colors.blueGrey[700] : Colors.blue[50],
            //       shape: BoxShape.circle,
            //     ),
            //     child: Icon(
            //       Icons.help_outline,
            //       color: isDarkMode ? Colors.blue[300] : Colors.blue[400],
            //     ),
            //   ),
            //   title: Text(
            //     'Help & Support',
            //     style: TextStyle(
            //       color: isDarkMode ? Colors.white : Colors.black,
            //     ),
            //   ),
            //   subtitle: const Text('App guide and contact information'),
            //   trailing: const Icon(Icons.chevron_right),
            //   onTap: () {
            //     // Show help dialog
            //     showDialog(
            //       context: context,
            //       builder: (context) => AlertDialog(
            //         title: const Text('Help & Support'),
            //         content: Column(
            //           mainAxisSize: MainAxisSize.min,
            //           crossAxisAlignment: CrossAxisAlignment.start,
            //           children: const [
            //             Text('Need help with Classico?'),
            //             SizedBox(height: 8),
            //             Text('Email: support@classico.app'),
            //             Text('Phone: +1 (555) 123-4567'),
            //             SizedBox(height: 16),
            //             Text('App Version: 1.0.0'),
            //           ],
            //         ),
            //         actions: [
            //           TextButton(
            //             onPressed: () => Navigator.pop(context),
            //             child: const Text('CLOSE'),
            //           ),
            //         ],
            //       ),
            //     );
            //   },
            // ),

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
