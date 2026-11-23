import 'package:flutter_test/flutter_test.dart';
import 'package:pogetit/features/quests/model/user_quest_model.dart';

void main() {
  test('reads persisted user profile totals', () {
    final profile = UserProfileModel.fromFirestore({
      'totalXP': 230,
      'completedQuests': 2,
    });

    expect(profile.totalXP, 230);
    expect(profile.completedQuests, 2);
  });

  test('defaults a missing profile to zero totals', () {
    final profile = UserProfileModel.fromFirestore(null);

    expect(profile.totalXP, 0);
    expect(profile.completedQuests, 0);
  });

  test('identifies user quest status', () {
    const quest = UserQuestModel(questId: 'RUN-01', status: 'ongoing');

    expect(quest.isAvailable, isFalse);
    expect(quest.isOngoing, isTrue);
    expect(quest.isCompleted, isFalse);
  });
}
