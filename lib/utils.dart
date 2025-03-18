import 'dart:math';

Map<String, double> parseCoordinates(String coordinates) {
  final parts = coordinates.split(',');
  return {
    'latitude': double.parse(parts[0]),
    'longitude': double.parse(parts[1]),
  };
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const p = 0.017453292519943295;
  final a = 0.5 -
      cos((lat2 - lat1) * p) / 2 +
      cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a));
}
