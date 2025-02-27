
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // For opening URLs
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPage extends StatefulWidget {
  final String stationName;

  NotificationPage({Key? key, required this.stationName}) : super(key: key);

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late Future<Map<String, dynamic>> _stationDataFuture;

  @override
  void initState() {
    super.initState();
    _stationDataFuture = getStationData(widget.stationName);
  }

  Future<Map<String, dynamic>> getStationData(String stationName) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot snapshot = await firestore
        .collection('stations')
        .where('Station', isEqualTo: stationName)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data() as Map<String, dynamic>;
    } else {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _stationDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No data available'));
          } else {
            final data = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Header
                  Stack(
                    children: [
                      Container(
                        height: 250,
                        width: double.infinity,
                        child: Image.network(
                          data['image_url'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(child: Text('Failed to load image'));
                          },
                        ),
                      ),
                      Positioned(
                        top: 40,
                        left: 10,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: 10,
                        child: IconButton(
                          icon: Icon(Icons.bookmark_border, color: Colors.white),
                          onPressed: () {
                            // Handle save/bookmark action
                          },
                        ),
                      ),
                    ],
                  ),
                  // Title Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stationName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          data['historical_significance'] ?? 'No description available',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final Uri uri = Uri.parse(data['url'] ?? '');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              print("Cannot launch URL");
                            }
                          },
                          child: Text('Learn More'),
                        ),
                      ],
                    ),
                  ),
                  // You can add more content here as needed
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
