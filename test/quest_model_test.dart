import 'package:flutter_test/flutter_test.dart';
import 'package:pogetit/features/quests/model/quest_model.dart';

void main() {
  test('reads Firestore numeric values and café coordinates', () {
    final quest = QuestModel.fromFirestore('CAFE-02', {
      'title': 'Walk for Your Coffee',
      'description': 'Walk 500 metres and reach the predefined café.',
      'type': 'cafe_walk',
      'targetDistanceMeters': 500,
      'targetRadiusMeters': 50.0,
      'cafeLocation': {'latitude': 11.0168, 'longitude': 76.9558},
      'rewardXP': 120,
      'isActive': true,
    });

    expect(quest.id, 'CAFE-02');
    expect(quest.targetDistanceMeters, 500.0);
    expect(quest.targetRadiusMeters, 50.0);
    expect(quest.cafeLatitude, 11.0168);
    expect(quest.cafeLongitude, 76.9558);
    expect(quest.rewardXP, 120);
    expect(quest.isActive, isTrue);
  });

  test(
    'uses known running quest targets when Firestore fields are missing',
    () {
      final quest = QuestModel.fromFirestore('RUN-01', {
        'title': 'Beginner Jog',
        'rewardXP': 100,
        'isActive': true,
      });

      expect(quest.description, isEmpty);
      expect(quest.targetDistanceMeters, 1000);
      expect(quest.targetSteps, 1200);
      expect(quest.rewardXP, 100);
      expect(quest.cafeLatitude, isNull);
      expect(quest.cafeLongitude, isNull);

      final secondQuest = QuestModel.fromFirestore('RUN-02', {});
      expect(secondQuest.targetDistanceMeters, 2000);
      expect(secondQuest.targetSteps, 2500);
      expect(secondQuest.rewardXP, 150);
    },
  );

  test('running quest progress requires distance and steps', () {
    final quest = QuestModel.fromFirestore('RUN-01', {
      'targetDistanceMeters': 1000,
      'targetSteps': 1200,
      'rewardXP': 100,
      'isActive': true,
    });

    expect(quest.progressFor(distance: 1000, steps: 600), 0.5);
    expect(quest.hasMetRequirements(distance: 1000, steps: 1199), isFalse);
    expect(quest.hasMetRequirements(distance: 999, steps: 1200), isFalse);
    expect(quest.hasMetRequirements(distance: 1000, steps: 1200), isTrue);
  });

  test('normalizes café quest type aliases for validation', () {
    final cafeQuest = QuestModel.fromFirestore('CAFE-01', {'type': 'cafe'});
    final walkQuest = QuestModel.fromFirestore('CAFE-02', {
      'type': 'cafe-walking',
    });

    expect(cafeQuest.validationType, 'cafe_visit');
    expect(walkQuest.validationType, 'cafe_walk');
  });
}
