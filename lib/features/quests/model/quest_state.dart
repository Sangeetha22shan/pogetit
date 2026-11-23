import 'quest_model.dart';
import 'user_quest_model.dart';

enum QuestLoadingStatus { initial, loading, success, error }

class QuestState {
  const QuestState({
    this.status = QuestLoadingStatus.initial,
    this.quests = const [],
    this.userQuests = const [],
    this.profile = const UserProfileModel(),
    this.errorMessage,
  });

  final QuestLoadingStatus status;
  final List<QuestModel> quests;
  final List<UserQuestModel> userQuests;
  final UserProfileModel profile;
  final String? errorMessage;

  QuestState copyWith({
    QuestLoadingStatus? status,
    List<QuestModel>? quests,
    List<UserQuestModel>? userQuests,
    UserProfileModel? profile,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return QuestState(
      status: status ?? this.status,
      quests: quests ?? this.quests,
      userQuests: userQuests ?? this.userQuests,
      profile: profile ?? this.profile,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
