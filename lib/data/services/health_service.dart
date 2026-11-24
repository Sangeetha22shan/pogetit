import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  final Health _health = Health();
  bool _isConfigured = false;

  Future<bool> requestPermissions() async {
    if (!await _health.isHealthConnectAvailable()) {
      throw StateError(
        'Health Connect is unavailable. Install or update Health Connect and try again.',
      );
    }

    if (!_isConfigured) {
      await _health.configure();
      _isConfigured = true;
    }

    final activityPermission = await Permission.activityRecognition.request();
    if (!activityPermission.isGranted) return false;

    final alreadyAuthorized = await _health.hasPermissions(
      [HealthDataType.STEPS],
      permissions: [HealthDataAccess.READ],
    );
    if (alreadyAuthorized == true) return true;

    return _health.requestAuthorization(
      [HealthDataType.STEPS],
      permissions: [HealthDataAccess.READ],
    );
  }

  Future<int> getSteps({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (endTime.isBefore(startTime)) {
      throw ArgumentError.value(
        endTime,
        'endTime',
        'Must not precede startTime.',
      );
    }

    final steps = await _health.getTotalStepsInInterval(startTime, endTime);
    if (steps == null) {
      throw StateError('Health Connect could not read step data.');
    }
    return steps;
  }
}
