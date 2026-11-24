import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pogetit/data/repositories/user_quest_repository.dart';

void main() {
  test(
    'repository sends the callable contract and parses successful result',
    () async {
      Map<String, dynamic>? sentRequest;
      final repository = UserQuestRepository(
        validationInvoker: (request) async {
          sentRequest = request;
          return {
            'success': true,
            'rewardXP': 80,
            'distanceToCafeMeters': 12.5,
          };
        },
      );

      final result = await repository.validateQuest(
        questId: 'CAFE-01',
        evidence: {'latitude': 1.0, 'longitude': 2.0},
      );

      expect(sentRequest, {
        'questId': 'CAFE-01',
        'evidence': {'latitude': 1.0, 'longitude': 2.0},
      });
      expect(result.success, isTrue);
      expect(result.rewardXP, 80);
      expect(result.distanceToCafeMeters, 12.5);
    },
  );

  test('repository maps backend requirement failures for display', () async {
    final repository = UserQuestRepository(
      validationInvoker: (_) async => {
        'success': false,
        'failures': ['insufficient-distance', 'insufficient-steps'],
      },
    );

    final result = await repository.validateQuest(
      questId: 'RUN-01',
      evidence: {'distance': 10, 'steps': 2},
    );

    expect(result.success, isFalse);
    expect(result.failureMessage, contains('required distance'));
    expect(result.failureMessage, contains('required steps'));
  });

  test('repository converts callable exceptions to helpful messages', () async {
    final repository = UserQuestRepository(
      validationInvoker: (_) async {
        throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Backend auth detail',
        );
      },
    );

    await expectLater(
      repository.validateQuest(questId: 'CAFE-01', evidence: {}),
      throwsA(
        isA<QuestValidationException>().having(
          (error) => error.message,
          'message',
          contains('sign in'),
        ),
      ),
    );
  });
}
