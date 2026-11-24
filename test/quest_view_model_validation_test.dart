import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pogetit/features/quests/model/quest_model.dart';
import 'package:pogetit/features/quests/model/user_quest_model.dart';
import 'package:pogetit/features/quests/viewmodel/quest_view_model.dart';

import 'support/quest_fakes.dart';

void main() {
  test(
    'view model submits fresh café GPS evidence and returns reward',
    () async {
      final cafeQuest = QuestModel(
        id: 'CAFE-01',
        title: 'Local Cafe Stop',
        description: 'Reach the café.',
        type: 'cafe',
        targetRadiusMeters: 50,
        cafeLatitude: 11.0168,
        cafeLongitude: 76.9558,
        rewardXP: 80,
        isActive: true,
      );
      final userQuests = FakeUserQuestRepository(
        initialQuest: const UserQuestModel(
          questId: 'CAFE-01',
          status: 'ongoing',
        ),
        onValidate: (request) async => {
          'success': true,
          'rewardXP': 80,
          'distanceToCafeMeters': 12,
        },
      );
      final viewModel = QuestViewModel(
        FakeQuestRepository([cafeQuest]),
        userQuests,
        'test-user',
        locationService: FakeLocationService(),
        healthService: FakeHealthService(),
      );
      addTearDown(() {
        viewModel.dispose();
        userQuests.close();
      });

      viewModel.fetchQuests();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final result = await viewModel.validateQuest(cafeQuest);

      expect(result.success, isTrue);
      expect(result.rewardXP, 80);
      expect(userQuests.validationCalls, 1);
      expect(viewModel.isValidatingQuest('CAFE-01'), isFalse);
    },
  );

  test('view model rejects inaccurate GPS before backend validation', () async {
    final userQuests = FakeUserQuestRepository(
      initialQuest: const UserQuestModel(questId: 'CAFE-01', status: 'ongoing'),
      onValidate: (_) async => {'success': true, 'rewardXP': 80},
    );
    final viewModel = QuestViewModel(
      FakeQuestRepository([createCafeQuest()]),
      userQuests,
      'test-user',
      locationService: FakeLocationService(accuracy: 30),
      healthService: FakeHealthService(),
    );
    addTearDown(() {
      viewModel.dispose();
      userQuests.close();
    });

    viewModel.fetchQuests();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await expectLater(
      viewModel.validateQuest(createCafeQuest()),
      throwsA(isA<StateError>()),
    );
    expect(userQuests.validationCalls, 0);
    expect(viewModel.isValidatingQuest('CAFE-01'), isFalse);
  });

  test('view model refreshes running quest steps before validation', () async {
    final quest = QuestModel(
      id: 'RUN-01',
      title: 'Beginner Run',
      description: 'Run and step.',
      type: 'running',
      targetDistanceMeters: 1000,
      targetSteps: 1200,
      rewardXP: 100,
      isActive: true,
    );
    Map<String, dynamic>? sentEvidence;
    final userQuests = FakeUserQuestRepository(
      initialQuest: UserQuestModel(
        questId: 'RUN-01',
        status: 'ongoing',
        distance: 1000,
        steps: 1000,
        startedAt: DateTime(2026),
      ),
      onValidate: (request) async {
        sentEvidence = request['evidence'] as Map<String, dynamic>;
        return {'success': true, 'rewardXP': 100};
      },
    );
    final viewModel = QuestViewModel(
      FakeQuestRepository([quest]),
      userQuests,
      'test-user',
      locationService: FakeLocationService(),
      healthService: FakeHealthService(steps: 1250),
    );
    addTearDown(() {
      viewModel.dispose();
      userQuests.close();
    });

    viewModel.fetchQuests();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final result = await viewModel.validateQuest(quest);

    expect(result.success, isTrue);
    expect(sentEvidence, {'distance': 1000.0, 'steps': 1250});
  });

  test('view model prevents simultaneous validation for one quest', () async {
    final completer = Completer<Map<String, dynamic>>();
    final userQuests = FakeUserQuestRepository(
      initialQuest: const UserQuestModel(questId: 'CAFE-01', status: 'ongoing'),
      onValidate: (_) => completer.future,
    );
    final viewModel = QuestViewModel(
      FakeQuestRepository([createCafeQuest()]),
      userQuests,
      'test-user',
      locationService: FakeLocationService(),
      healthService: FakeHealthService(),
    );
    addTearDown(() {
      viewModel.dispose();
      userQuests.close();
    });

    viewModel.fetchQuests();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final firstRequest = viewModel.validateQuest(createCafeQuest());
    expect(viewModel.isValidatingQuest('CAFE-01'), isTrue);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      viewModel.validateQuest(createCafeQuest()),
      throwsA(isA<StateError>()),
    );
    expect(userQuests.validationCalls, 1);

    completer.complete({
      'success': false,
      'failures': ['outside-café-radius'],
    });
    final result = await firstRequest;
    expect(result.success, isFalse);
    expect(viewModel.isValidatingQuest('CAFE-01'), isFalse);
  });
}
