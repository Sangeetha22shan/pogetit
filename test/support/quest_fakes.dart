import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:pogetit/data/repositories/quest_repository.dart';
import 'package:pogetit/data/repositories/user_quest_repository.dart';
import 'package:pogetit/data/services/health_service.dart';
import 'package:pogetit/data/services/location_service.dart';
import 'package:pogetit/features/quests/model/quest_model.dart';
import 'package:pogetit/features/quests/model/user_quest_model.dart';

class FakeQuestRepository implements QuestRepository {
  FakeQuestRepository(this.quests);

  final List<QuestModel> quests;

  @override
  Stream<List<QuestModel>> getQuests() => Stream.value(quests);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserQuestRepository implements UserQuestRepository {
  FakeUserQuestRepository({
    required UserQuestModel initialQuest,
    required this.onValidate,
  }) : _questController = StreamController<List<UserQuestModel>>.broadcast(),
       _userQuest = initialQuest;

  final StreamController<List<UserQuestModel>> _questController;
  final QuestValidationInvoker onValidate;
  UserQuestModel _userQuest;
  int validationCalls = 0;

  void close() {
    _questController.close();
  }

  @override
  Future<void> initializeUserData(String userId, List<String> questIds) async {}

  @override
  Future<void> startQuest(String userId, String questId) async {
    _userQuest = UserQuestModel(
      questId: _userQuest.questId,
      status: 'ongoing',
      progress: _userQuest.progress,
      distance: _userQuest.distance,
      steps: _userQuest.steps,
    );
    _questController.add([_userQuest]);
  }

  @override
  Future<void> saveProgress({
    required String userId,
    required String questId,
    required double progress,
    required double distance,
    required int steps,
  }) async {}

  @override
  Future<QuestValidationResult> validateQuest({
    required String questId,
    required Map<String, dynamic> evidence,
  }) async {
    validationCalls++;
    return QuestValidationResult.fromMap(
      await onValidate({'questId': questId, 'evidence': evidence}),
    );
  }

  @override
  Stream<List<UserQuestModel>> watchUserQuests(String userId) async* {
    yield [_userQuest];
    yield* _questController.stream;
  }

  @override
  Stream<UserProfileModel> watchProfile(String userId) =>
      Stream.value(const UserProfileModel());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocationService extends LocationService {
  FakeLocationService({this.accuracy = 5});

  final double accuracy;

  @override
  Future<Position> getCurrentLocation() async => Position(
    longitude: 76.9558,
    latitude: 11.0168,
    timestamp: DateTime(2026),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class FakeHealthService extends HealthService {
  FakeHealthService({this.steps = 0, this.authorized = true});

  final int steps;
  final bool authorized;

  @override
  Future<bool> requestPermissions() async => authorized;

  @override
  Future<int> getSteps({
    required DateTime startTime,
    required DateTime endTime,
  }) async => steps;
}

QuestModel createCafeQuest() => const QuestModel(
  id: 'CAFE-01',
  title: 'Local Cafe Stop',
  description: 'Reach the café.',
  type: 'cafe_visit',
  targetRadiusMeters: 50,
  cafeLatitude: 11.0168,
  cafeLongitude: 76.9558,
  rewardXP: 80,
  isActive: true,
);
