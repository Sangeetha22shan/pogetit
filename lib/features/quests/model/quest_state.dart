import 'quest_model.dart';

enum QuestLoadingStatus { initial, loading, success, error }

class QuestState {
  const QuestState({
    this.status = QuestLoadingStatus.initial,
    this.quests = const [],
    this.errorMessage,
  });

  final QuestLoadingStatus status;
  final List<QuestModel> quests;
  final String? errorMessage;

  QuestState copyWith({
    QuestLoadingStatus? status,
    List<QuestModel>? quests,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return QuestState(
      status: status ?? this.status,
      quests: quests ?? this.quests,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
