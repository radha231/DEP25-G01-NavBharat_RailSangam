import 'package:classico/settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';


class ProfilePage extends StatefulWidget {
  final String emailId;
  final VoidCallback? onProfileUpdated; // Add this callback

  const ProfilePage({
    Key? key,
    required this.emailId,
    this.onProfileUpdated, // Add this parameter
  }) : super(key: key);

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

      if (snapshot.docs.isEmpty) return;

      final DocumentSnapshot document = snapshot.docs.first;
      final userData = document.data() as Map<String, dynamic>? ?? {};

      // Use setState to ensure UI updates
      setState(() {
        name = userData['Name']?.toString() ?? 'User';
        interests = List<String>.from(userData['Interests'] ?? ['Add your interests']);
            currentAvatarUrl = userData['avatarUrl']?.toString() ?? 'assets/images/default_avatar.svg';
        followers = List<String>.from(userData['followers'] ?? []);
        following = List<String>.from(userData['following'] ?? []);
        profession = userData['Profession']?.toString();
        ageGroup = userData['Age Group']?.toString();
        gender = userData['Gender']?.toString();
      });
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _setupProfileListener(); // Add this
  }

  void _setupProfileListener() {
    FirebaseFirestore.instance
        .collection('Users')
        .where('email_Id', isEqualTo: emailId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final userData = snapshot.docs.first.data();
        if (mounted) {
          setState(() {
            name = userData['Name']?.toString() ?? 'User';
            // Update other fields similarly...
          });
        }
      }
    });
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
                        // In the build method where settings button is:
                        onPressed: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccountSettingsScreen(
                                onBack: () => Navigator.pop(context, true),
                                onLogout: () {},
                              ),
                            ),
                          );

                          if (updated == true) {
                            await _fetchUserData(); // Force refresh
                          }
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
                              // Container(height: 30, width: 1, color: Colors.grey[400]),
                              _buildFollowItem(
                                count: following.length,
                                label: 'Connections',
                                onTap: () => _showUserListDialog('Connections', following),
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
