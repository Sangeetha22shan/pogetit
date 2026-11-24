import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class QuestModel {
  const QuestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.targetDistanceMeters = 0,
    this.targetSteps = 0,
    this.targetRadiusMeters = 0,
    this.cafeLatitude,
    this.cafeLongitude,
    required this.rewardXP,
    required this.isActive,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final double targetDistanceMeters;
  final int targetSteps;
  final double targetRadiusMeters;
  final double? cafeLatitude;
  final double? cafeLongitude;
  final int rewardXP;
  final bool isActive;

  String get validationType {
    final normalizedType = type.trim().toLowerCase().replaceAll('-', '_');
    switch (normalizedType) {
      case 'cafe':
      case 'café':
      case 'cafe_location':
      case 'cafe_stop':
      case 'cafe_visit':
        return _hasWalkingDistanceRequirement ? 'cafe_walk' : 'cafe_visit';
      case 'cafe_walk':
      case 'cafe_walking':
      case 'walk_to_cafe':
        return 'cafe_walk';
      case 'run':
      case 'running':
        return 'running';
      default:
        if (_hasCafeGeofence) {
          return _hasWalkingDistanceRequirement ? 'cafe_walk' : 'cafe_visit';
        }
        return type.trim().toLowerCase();
    }
  }

  bool get _hasCafeGeofence =>
      cafeLatitude != null &&
      cafeLongitude != null &&
      targetRadiusMeters.isFinite &&
      targetRadiusMeters > 0;

  bool get _hasWalkingDistanceRequirement =>
      targetDistanceMeters.isFinite && targetDistanceMeters > 0;

  double progressFor({required double distance, required int steps}) {
    final distanceProgress = (distance / targetDistanceMeters).clamp(0.0, 1.0);
    if (targetSteps <= 0) return distanceProgress;

    final stepProgress = (steps / targetSteps).clamp(0.0, 1.0);
    return math.min(distanceProgress, stepProgress);
  }

  bool hasMetRequirements({required double distance, required int steps}) {
    return targetSteps > 0 &&
        distance >= targetDistanceMeters &&
        steps >= targetSteps;
  }

  factory QuestModel.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final cafeLocation = data['cafeLocation'];
    double? latitude;
    double? longitude;

    if (cafeLocation is GeoPoint) {
      latitude = cafeLocation.latitude;
      longitude = cafeLocation.longitude;
    } else if (cafeLocation is Map<String, dynamic>) {
      latitude = (cafeLocation['latitude'] as num?)?.toDouble();
      longitude = (cafeLocation['longitude'] as num?)?.toDouble();
    }

    return QuestModel(
      id: documentId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? '',
      targetDistanceMeters:
          (data['targetDistanceMeters'] as num?)?.toDouble() ?? 0,
      targetSteps: (data['targetSteps'] as num?)?.toInt() ?? 0,
      targetRadiusMeters: (data['targetRadiusMeters'] as num?)?.toDouble() ?? 0,
      cafeLatitude: latitude,
      cafeLongitude: longitude,
      rewardXP: (data['rewardXP'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? false,
    );
  }
}
