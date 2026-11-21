import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/quest_repository.dart';
import '../model/quest_model.dart';
import '../model/quest_state.dart';

class QuestViewModel extends ChangeNotifier {
  QuestViewModel(this._repository);

  final QuestRepository _repository;
  QuestState _state = const QuestState();
  StreamSubscription<List<QuestModel>>? _subscription;
  bool _disposed = false;

  QuestState get state => _state;

  void fetchQuests() {
    _state = _state.copyWith(
      status: QuestLoadingStatus.loading,
      clearErrorMessage: true,
    );
    notifyListeners();

    _subscription?.cancel();
    _subscription = _repository.getQuests().listen(
      (quests) {
        _state = _state.copyWith(
          status: QuestLoadingStatus.success,
          quests: quests,
          clearErrorMessage: true,
        );
        if (!_disposed) notifyListeners();
      },
      onError: (Object error) {
        _state = _state.copyWith(
          status: QuestLoadingStatus.error,
          errorMessage: error.toString(),
        );
        if (!_disposed) notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
