import 'package:cloud_firestore/cloud_firestore.dart';

class UserQuestModel {
  const UserQuestModel({
    required this.questId,
    required this.status,
    this.progress = 0,
    this.distance = 0,
    this.steps = 0,
    this.startedAt,
    this.completedAt,
  });

  final String questId;
  final String status;
  final double progress;
  final double distance;
  final int steps;
  final DateTime? startedAt;
  final DateTime? completedAt;

  factory UserQuestModel.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return UserQuestModel(
      questId: documentId,
      status: data['status'] as String? ?? 'available',
      progress: (data['progress'] as num?)?.toDouble() ?? 0,
      distance: (data['distance'] as num?)?.toDouble() ?? 0,
      steps: (data['steps'] as num?)?.toInt() ?? 0,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}
