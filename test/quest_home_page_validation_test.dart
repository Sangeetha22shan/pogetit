import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pogetit/features/quests/model/user_quest_model.dart';
import 'package:pogetit/features/quests/view/quest_home_page.dart';

import 'support/quest_fakes.dart';

void main() {
  testWidgets('validation shows loading state and ignores duplicate taps', (
    tester,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    final userQuests = FakeUserQuestRepository(
      initialQuest: const UserQuestModel(
        questId: 'CAFE-01',
        status: 'available',
      ),
      onValidate: (_) => response.future,
    );
    addTearDown(userQuests.close);

    await tester.pumpWidget(
      MaterialApp(
        home: QuestHomePage(
          userId: 'test-user',
          repository: FakeQuestRepository([createCafeQuest()]),
          userQuestRepository: userQuests,
          locationService: FakeLocationService(),
          healthService: FakeHealthService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept Quest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongoing (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Validate Quest'));
    await tester.pump();

    expect(find.text('Validating...'), findsOneWidget);
    expect(userQuests.validationCalls, 1);
    await tester.tap(find.text('Validating...'));
    await tester.pump();
    expect(userQuests.validationCalls, 1);

    response.complete({
      'success': true,
      'rewardXP': 80,
      'distanceToCafeMeters': 12,
    });
    await tester.pumpAndSettle();

    expect(find.text('+80 XP earned!'), findsOneWidget);
    expect(userQuests.validationCalls, 1);
  });

  testWidgets('validation displays unmet requirement feedback', (tester) async {
    final userQuests = FakeUserQuestRepository(
      initialQuest: const UserQuestModel(questId: 'CAFE-01', status: 'ongoing'),
      onValidate: (_) async => {
        'success': false,
        'failures': ['outside-café-radius'],
      },
    );
    addTearDown(userQuests.close);

    await tester.pumpWidget(
      MaterialApp(
        home: QuestHomePage(
          userId: 'test-user',
          repository: FakeQuestRepository([createCafeQuest()]),
          userQuestRepository: userQuests,
          locationService: FakeLocationService(),
          healthService: FakeHealthService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ongoing (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Validate Quest'));
    await tester.pumpAndSettle();

    expect(find.text('You are outside the café quest area.'), findsOneWidget);
    expect(userQuests.validationCalls, 1);
  });
}
