import 'package:classico/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'globals.dart';

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
                            "NavBharat RailSangam",
                            style: TextStyle(
                              fontSize: 24, // Increased from 22
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.7), // Increased shadow opacity
                                  offset: const Offset(1.5, 1.5), // Slightly larger offset
                                  blurRadius: 40, // Increased blur radius
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
                              "Stations with Stories, Journeys with Meaning.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14, // Increased from 15
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
                          const SizedBox(height: 13), // Increased from 12
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
                                'From: ${Globals.from_station}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                'To: ${Globals.to_station}',
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
        widget.selectedTrain.stations.isEmpty
            ? StopCard(
          name: 'Destination Reached',
          time: '',
          distance: '',
          isCurrentStop: false,
        )
            : ListView.builder(
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
        )


        ,
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
