import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/quests/model/user_quest_model.dart';

typedef QuestValidationInvoker =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);

class QuestValidationResult {
  const QuestValidationResult({
    required this.success,
    this.rewardXP = 0,
    this.failures = const [],
    this.alreadyCompleted = false,
    this.distanceToCafeMeters,
  });

  final bool success;
  final int rewardXP;
  final List<String> failures;
  final bool alreadyCompleted;
  final double? distanceToCafeMeters;

  String get failureMessage {
    if (alreadyCompleted) return 'This quest has already been completed.';
    if (failures.isEmpty) return 'Quest requirements were not met.';
    return failures
        .map((failure) {
          switch (failure) {
            case 'outside-café-radius':
              return 'You are outside the café quest area.';
            case 'insufficient-distance':
              return 'Walk the required distance before validating.';
            case 'insufficient-steps':
              return 'Record the required steps before validating.';
            default:
              return 'Quest requirements were not met.';
          }
        })
        .join(' ');
  }

  factory QuestValidationResult.fromMap(Map<String, dynamic> data) {
    final success = data['success'];
    if (success is! bool) {
      throw const FormatException('Validation response has no success status.');
    }

    final rawFailures = data['failures'];
    if (rawFailures != null &&
        (rawFailures is! List ||
            rawFailures.any((failure) => failure is! String))) {
      throw const FormatException('Validation response has invalid failures.');
    }

    final rawReward = data['rewardXP'];
    if (rawReward != null && rawReward is! num) {
      throw const FormatException('Validation response has invalid reward XP.');
    }
    final rawCafeDistance = data['distanceToCafeMeters'];
    if (rawCafeDistance != null && rawCafeDistance is! num) {
      throw const FormatException(
        'Validation response has invalid café distance.',
      );
    }

    return QuestValidationResult(
      success: success,
      rewardXP: (rawReward as num?)?.toInt() ?? 0,
      failures: (rawFailures as List<dynamic>?)?.cast<String>() ?? const [],
      alreadyCompleted: data['alreadyCompleted'] == true,
      distanceToCafeMeters: (rawCafeDistance as num?)?.toDouble(),
    );
  }
}

class QuestValidationException implements Exception {
  const QuestValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserQuestRepository {
  UserQuestRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    QuestValidationInvoker? validationInvoker,
  }) : _firestoreInstance = firestore,
       _functions = functions,
       _validationInvoker = validationInvoker;

  final FirebaseFirestore? _firestoreInstance;
  final FirebaseFunctions? _functions;
  final QuestValidationInvoker? _validationInvoker;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  Future<QuestValidationResult> validateQuest({
    required String questId,
    required Map<String, dynamic> evidence,
  }) async {
    final request = {'questId': questId, 'evidence': evidence};
    try {
      final response = _validationInvoker != null
          ? await _validationInvoker(request)
          : await _invokeValidation(request);
      return QuestValidationResult.fromMap(response);
    } on FirebaseFunctionsException catch (error) {
      throw QuestValidationException(_validationErrorMessage(error));
    } on FormatException catch (error) {
      throw QuestValidationException(error.message);
    }
  }

  Future<Map<String, dynamic>> _invokeValidation(
    Map<String, dynamic> request,
  ) async {
    final result = await (_functions ?? FirebaseFunctions.instance)
        .httpsCallable('validateQuest')
        .call(request);
    final data = result.data;
    if (data is! Map) {
      throw const FormatException('Validation response is not an object.');
    }
    return Map<String, dynamic>.from(data);
  }

  String _validationErrorMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please sign in before validating this quest.';
      case 'permission-denied':
        return 'You do not have permission to validate this quest.';
      case 'not-found':
        return 'This quest could not be found.';
      case 'failed-precondition':
        return error.message ?? 'This quest is not ready to be validated.';
      case 'invalid-argument':
        return error.message ?? 'The quest validation data is invalid.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Quest validation is temporarily unavailable. Check your connection.';
      default:
        return error.message ?? 'Quest validation failed. Please try again.';
    }
  }

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
      if (!snapshot.exists) {
        throw StateError('Quest progress has not been initialized.');
      }

      final status = snapshot.data()?['status'];
      if (status != 'ongoing') {
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
