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

  test('uses the running targets configured in Firestore', () {
    final quest = QuestModel.fromFirestore('RUN-01', {
      'description': 'Walk 20 metres and complete 30 steps.',
      'targetDistanceMeters': 20,
      'targetSteps': 30,
      'rewardXP': 100,
      'isActive': true,
    });

    expect(quest.description, 'Walk 20 metres and complete 30 steps.');
    expect(quest.targetDistanceMeters, 20);
    expect(quest.targetSteps, 30);
  });

  test('does not invent running requirements when Firestore fields are missing', () {
    final quest = QuestModel.fromFirestore('RUN-01', {
      'title': 'Beginner Jog',
      'isActive': true,
    });

    expect(quest.targetDistanceMeters, 0);
    expect(quest.targetSteps, 0);
    expect(quest.rewardXP, 0);
  });

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

  test('infers café quest validation from its geofence configuration', () {
    final cafeQuest = QuestModel.fromFirestore('CAFE-01', {
      'type': 'coffee_stop',
      'targetRadiusMeters': 50,
      'cafeLocation': {'latitude': 11.0168, 'longitude': 76.9558},
    });
    final walkQuest = QuestModel.fromFirestore('CAFE-02', {
      'type': 'coffee_stop',
      'targetDistanceMeters': 500,
      'targetRadiusMeters': 50,
      'cafeLocation': {'latitude': 11.0168, 'longitude': 76.9558},
    });

    expect(cafeQuest.validationType, 'cafe_visit');
    expect(walkQuest.validationType, 'cafe_walk');
  });
}
