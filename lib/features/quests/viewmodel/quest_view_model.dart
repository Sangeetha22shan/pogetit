import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/repositories/quest_repository.dart';
import '../../../data/repositories/user_quest_repository.dart';
import '../../../data/services/location_service.dart';
import '../model/quest_model.dart';
import '../model/quest_state.dart';

class QuestViewModel extends ChangeNotifier {
  QuestViewModel(this._repository, this._userQuestRepository, this._userId);

  final QuestRepository _repository;
  final UserQuestRepository _userQuestRepository;
  final String _userId;
  final LocationService _locationService = LocationService();
  QuestState _state = const QuestState();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _disposed = false;
  String? _initializedQuestIds;

  QuestState get state => _state;

  Future<Position> getCurrentLocation() {
    return _locationService.getCurrentLocation();
  }

  Future<double> checkQuestDistance(QuestModel quest) {
    final latitude = quest.cafeLatitude;
    final longitude = quest.cafeLongitude;
    final radius = quest.targetRadiusMeters;

    if (latitude == null || longitude == null) {
      throw StateError(
        'Quest ${quest.id} does not have café coordinates.',
      );
    }

    if (radius <= 0) {
      throw StateError(
        'Quest ${quest.id} has an invalid geofence radius.',
      );
    }

    return _locationService.calculateDistance(
      targetLatitude: latitude,
      targetLongitude: longitude,
    );
  }

  void fetchQuests() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _initializedQuestIds = null;
    _state = _state.copyWith(
      status: QuestLoadingStatus.loading,
      clearErrorMessage: true,
    );
    notifyListeners();

    _subscriptions.add(
      _repository.getQuests().listen((quests) {
        _state = _state.copyWith(
          status: QuestLoadingStatus.success,
          quests: quests,
          clearErrorMessage: true,
        );
        _notifyListeners();
        _initializeMissingUserData(quests);
      }, onError: _handleError),
    );
    _subscriptions.add(
      _userQuestRepository.watchUserQuests(_userId).listen((userQuests) {
        _state = _state.copyWith(userQuests: userQuests);
        _notifyListeners();
      }, onError: _handleError),
    );
    _subscriptions.add(
      _userQuestRepository.watchProfile(_userId).listen((profile) {
        _state = _state.copyWith(profile: profile);
        _notifyListeners();
      }, onError: _handleError),
    );
  }

  Future<void> startQuest(String questId) {
    return _userQuestRepository.startQuest(_userId, questId);
  }

  Future<void> saveProgress({
    required String questId,
    required double progress,
    required double distance,
    required int steps,
  }) {
    return _userQuestRepository.saveProgress(
      userId: _userId,
      questId: questId,
      progress: progress,
      distance: distance,
      steps: steps,
    );
  }

  void _initializeMissingUserData(List<QuestModel> quests) {
    final questIds = quests.map((quest) => quest.id).toList()..sort();
    final key = questIds.join(',');
    if (_initializedQuestIds == key) return;
    _initializedQuestIds = key;
    _initializeUserData(questIds);
  }

  Future<void> _initializeUserData(List<String> questIds) async {
    try {
      await _userQuestRepository.initializeUserData(_userId, questIds);
    } catch (error) {
      _handleError(error);
    }
  }

  void _handleError(Object error) {
    _state = _state.copyWith(
      status: QuestLoadingStatus.error,
      errorMessage: error.toString(),
    );
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
