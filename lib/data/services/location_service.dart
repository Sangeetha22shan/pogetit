import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<bool> checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
        'Please enable it in app settings.',
      );
    }

    return true;
  }

  Future<Position> getCurrentLocation() async {
    await checkLocationPermission();

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<double> calculateDistance({
    required double targetLatitude,
    required double targetLongitude,
  }) async {
    final position = await getCurrentLocation();

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLatitude,
      targetLongitude,
    );
  }

  Stream<Position> trackLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
}
