import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Train {
  final String name;
  final List<String> stations;
  final List<String> coordinates;
  final List<String> coaches;
  final String train_no;
  Train({required this.name, required this.stations, required this.coordinates, required this.coaches, required this.train_no});
}

// Add this class to handle location services
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