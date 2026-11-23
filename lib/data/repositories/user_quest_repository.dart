import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/quests/model/user_quest_model.dart';

class UserQuestRepository {
  UserQuestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profileReference(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('summary');

  CollectionReference<Map<String, dynamic>> _questsReference(String userId) =>
      _firestore.collection('users').doc(userId).collection('quests');

  Stream<UserProfileModel> watchProfile(String userId) {
    return _profileReference(userId).snapshots().map(
      (snapshot) => UserProfileModel.fromFirestore(snapshot.data()),
    );
  }

  Stream<List<UserQuestModel>> watchUserQuests(String userId) {
    return _questsReference(userId).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => UserQuestModel.fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> initializeUserData(String userId, List<String> questIds) async {
    final profile = _profileReference(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(profile);
      if (!snapshot.exists) {
        transaction.set(profile, {'totalXP': 0, 'completedQuests': 0});
      }
    });

    for (final questId in questIds) {
      final quest = _questsReference(userId).doc(questId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(quest);
        if (!snapshot.exists) {
          transaction.set(quest, {
            'status': 'available',
            'progress': 0,
            'distance': 0,
            'steps': 0,
          });
        }
      });
    }
  }

  Future<void> startQuest(String userId, String questId) async {
    final quest = _questsReference(userId).doc(questId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(quest);
      if (!snapshot.exists) {
        throw StateError('Quest progress has not been initialized.');
      }

      final status = snapshot.data()?['status'] as String? ?? 'available';
      if (status == 'ongoing') return;
      if (status != 'available') {
        throw StateError('Only available quests can be started.');
      }

      transaction.update(quest, {
        'status': 'ongoing',
        'startedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> saveProgress({
    required String userId,
    required String questId,
    required double progress,
    required double distance,
    required int steps,
  }) async {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw ArgumentError.value(
        progress,
        'progress',
        'Must be between 0 and 1.',
      );
    }
    if (!distance.isFinite || distance < 0) {
      throw ArgumentError.value(distance, 'distance', 'Must not be negative.');
    }
    if (steps < 0) {
      throw ArgumentError.value(steps, 'steps', 'Must not be negative.');
    }

    final quest = _questsReference(userId).doc(questId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(quest);
      if (!snapshot.exists || snapshot.data()?['status'] != 'ongoing') {
        throw StateError('Progress can only be saved for an ongoing quest.');
      }

      transaction.update(quest, {
        'progress': progress,
        'distance': distance,
        'steps': steps,
      });
    });
  }
}
