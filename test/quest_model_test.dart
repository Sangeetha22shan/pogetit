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

  test('uses safe defaults for missing optional Firestore fields', () {
    final quest = QuestModel.fromFirestore('RUN-01', {
      'title': 'Beginner Jog',
      'rewardXP': 100,
      'isActive': true,
    });

    expect(quest.description, isEmpty);
    expect(quest.targetDistanceMeters, 0);
    expect(quest.targetSteps, 0);
    expect(quest.cafeLatitude, isNull);
    expect(quest.cafeLongitude, isNull);
  });
}
