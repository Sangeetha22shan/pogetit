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

  factory QuestModel.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final cafeLocation = data['cafeLocation'];
    final location = cafeLocation is Map<String, dynamic>
        ? cafeLocation
        : const <String, dynamic>{};

    return QuestModel(
      id: documentId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? '',
      targetDistanceMeters:
          (data['targetDistanceMeters'] as num?)?.toDouble() ?? 0,
      targetSteps: (data['targetSteps'] as num?)?.toInt() ?? 0,
      targetRadiusMeters: (data['targetRadiusMeters'] as num?)?.toDouble() ?? 0,
      cafeLatitude: (location['latitude'] as num?)?.toDouble(),
      cafeLongitude: (location['longitude'] as num?)?.toDouble(),
      rewardXP: (data['rewardXP'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? false,
    );
  }
}
