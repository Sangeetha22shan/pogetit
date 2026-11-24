import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/repositories/quest_repository.dart';
import '../../../data/repositories/user_quest_repository.dart';
import '../../../data/services/health_service.dart';
import '../../../data/services/location_service.dart';
import '../model/quest_model.dart';
import '../model/quest_state.dart';
import '../model/user_quest_model.dart';

class QuestViewModel extends ChangeNotifier {
  QuestViewModel(
    this._repository,
    this._userQuestRepository,
    this._userId, {
    LocationService? locationService,
    HealthService? healthService,
  }) : _locationService = locationService ?? LocationService(),
       _healthService = healthService ?? HealthService();

  static const double _maximumGpsAccuracyMeters = 25;
  static const double _maximumWalkingSpeedMetersPerSecond = 3;

  final QuestRepository _repository;
  final UserQuestRepository _userQuestRepository;
  final String _userId;
  final HealthService _healthService;
  final LocationService _locationService;
  QuestState _state = const QuestState();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _validatingQuestIds = {};
  bool _disposed = false;
  String? _initializedQuestIds;
  StreamSubscription<Position>? _trackingSubscription;
  Timer? _stepRefreshTimer;
  Position? _previousPosition;
  QuestModel? _trackingQuest;
  DateTime? _trackingStartedAt;
  int _stepsAtTrackingStart = 0;
  int _trackedSteps = 0;
  bool _refreshingSteps = false;
  double _trackedDistance = 0;
  Future<void> _progressSaveQueue = Future<void>.value();

  QuestState get state => _state;
  bool get isTracking => _trackingSubscription != null;
  bool isTrackingQuest(String questId) =>
      isTracking && _trackingQuest?.id == questId;
  bool isValidatingQuest(String questId) =>
      _validatingQuestIds.contains(questId);

  Future<Position> getCurrentLocation() {
    return _locationService.getCurrentLocation();
  }

  Future<double> checkQuestDistance(QuestModel quest) {
    final latitude = quest.cafeLatitude;
    final longitude = quest.cafeLongitude;
    final radius = quest.targetRadiusMeters;

    if (latitude == null || longitude == null) {
      throw StateError('Quest ${quest.id} does not have café coordinates.');
    }

    if (radius <= 0) {
      throw StateError('Quest ${quest.id} has an invalid geofence radius.');
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

  Future<void> startTracking(QuestModel quest) async {
    if (!quest.targetDistanceMeters.isFinite ||
        quest.targetDistanceMeters <= 0) {
      throw StateError('Quest ${quest.id} has an invalid target distance.');
    }

    final userQuest = _state.userQuests
        .where((userQuest) => userQuest.questId == quest.id)
        .firstOrNull;
    if (userQuest == null || !userQuest.isOngoing) {
      throw StateError('Quest ${quest.id} must be ongoing to track distance.');
    }

    await stopTracking();
    final trackingStartedAt = DateTime.now();
    await _locationService.checkLocationPermission();
    if (quest.targetSteps > 0 && !await _healthService.requestPermissions()) {
      throw StateError('Health Connect step permissions were not granted.');
    }

    _trackingQuest = quest;
    _trackedDistance = userQuest.distance;
    _trackedSteps = userQuest.steps;
    _stepsAtTrackingStart = userQuest.steps;
    _trackingStartedAt = trackingStartedAt;
    _previousPosition = null;
    _trackingSubscription = _locationService.trackLocation().listen(
      _handleTrackingPosition,
      onError: _handleTrackingError,
    );
    if (quest.targetSteps > 0) {
      _stepRefreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_refreshTrackedSteps()),
      );
      unawaited(_refreshTrackedSteps());
    }
    _notifyListeners();
  }

  Future<void> stopTracking() async {
    final subscription = _trackingSubscription;
    _stepRefreshTimer?.cancel();
    _stepRefreshTimer = null;
    _trackingSubscription = null;
    _trackingQuest = null;
    _trackingStartedAt = null;
    _previousPosition = null;
    _notifyListeners();
    await subscription?.cancel();
    await _progressSaveQueue;
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

  Future<QuestValidationResult> validateQuest(QuestModel quest) async {
    if (isValidatingQuest(quest.id)) {
      throw StateError('Quest validation is already in progress.');
    }

    final userQuest = _state.userQuests
        .where((item) => item.questId == quest.id)
        .firstOrNull;
    if (userQuest == null || !userQuest.isOngoing) {
      throw StateError('Only ongoing quests can be validated.');
    }

    _validatingQuestIds.add(quest.id);
    _notifyListeners();
    try {
      await _progressSaveQueue;
      final latestUserQuest =
          _state.userQuests
              .where((item) => item.questId == quest.id)
              .firstOrNull ??
          userQuest;

      final type = quest.validationType;
      final evidence = <String, dynamic>{
        'distance': latestUserQuest.distance,
        'steps': latestUserQuest.steps,
      };

      if (type == 'cafe_visit' || type == 'cafe_walk') {
        final position = await _locationService.getCurrentLocation();
        if (!position.accuracy.isFinite ||
            position.accuracy > _maximumGpsAccuracyMeters) {
          throw StateError(
            'GPS accuracy is too low to validate. Move outdoors and retry.',
          );
        }
        evidence['latitude'] = position.latitude;
        evidence['longitude'] = position.longitude;
        if (type == 'cafe_walk') {
          evidence['distance'] = isTrackingQuest(quest.id)
              ? _trackedDistance
              : latestUserQuest.distance;
        }
      } else if (type == 'run' || type == 'running') {
        if (quest.targetSteps > 0) {
          if (!await _healthService.requestPermissions()) {
            throw StateError(
              'Health Connect step permission is required to validate this quest.',
            );
          }
          final stepsStart = isTrackingQuest(quest.id)
              ? _trackingStartedAt
              : latestUserQuest.startedAt;
          if (stepsStart != null) {
            final currentSteps = await _healthService.getSteps(
              startTime: stepsStart,
              endTime: DateTime.now(),
            );
            evidence['steps'] = isTrackingQuest(quest.id)
                ? math.max(_trackedSteps, _stepsAtTrackingStart + currentSteps)
                : math.max(latestUserQuest.steps, currentSteps);
          }
        }
        evidence['distance'] = isTrackingQuest(quest.id)
            ? _trackedDistance
            : latestUserQuest.distance;

        if (isTrackingQuest(quest.id)) {
          _trackedSteps = evidence['steps'] as int;
          _queueProgressSave(quest);
          await _progressSaveQueue;
        }
      } else {
        throw StateError(
          'Quest type "${quest.type}" is not supported for validation.',
        );
      }

      final result = await _userQuestRepository.validateQuest(
        questId: quest.id,
        evidence: evidence,
      );
      if ((result.success || result.alreadyCompleted) &&
          isTrackingQuest(quest.id)) {
        await stopTracking();
      }
      return result;
    } finally {
      _validatingQuestIds.remove(quest.id);
      _notifyListeners();
    }
  }

  void _handleTrackingPosition(Position position) {
    if (!position.accuracy.isFinite ||
        position.accuracy > _maximumGpsAccuracyMeters) {
      return;
    }

    final previousPosition = _previousPosition;
    if (previousPosition == null) {
      _previousPosition = position;
      return;
    }

    final elapsedSeconds =
        position.timestamp
            .difference(previousPosition.timestamp)
            .inMilliseconds /
        1000;
    if (!elapsedSeconds.isFinite || elapsedSeconds <= 0) return;

    final segmentDistance = Geolocator.distanceBetween(
      previousPosition.latitude,
      previousPosition.longitude,
      position.latitude,
      position.longitude,
    );
    if (!segmentDistance.isFinite ||
        segmentDistance / elapsedSeconds >
            _maximumWalkingSpeedMetersPerSecond) {
      return;
    }

    _previousPosition = position;
    _trackedDistance += segmentDistance;
    final quest = _trackingQuest;
    if (quest == null) return;

    _queueProgressSave(quest);
  }

  Future<void> _refreshTrackedSteps() async {
    final quest = _trackingQuest;
    final startedAt = _trackingStartedAt;
    if (quest == null || startedAt == null || _refreshingSteps) return;

    _refreshingSteps = true;
    try {
      final sessionSteps = await _healthService.getSteps(
        startTime: startedAt,
        endTime: DateTime.now(),
      );
      if (_trackingQuest?.id != quest.id || _trackingStartedAt != startedAt) {
        return;
      }
      _trackedSteps = math.max(
        _trackedSteps,
        _stepsAtTrackingStart + sessionSteps,
      );
      _queueProgressSave(quest);
    } catch (error) {
      _handleError(error);
    } finally {
      _refreshingSteps = false;
    }
  }

  void _queueProgressSave(QuestModel quest) {
    final distance = _trackedDistance;
    final steps = _trackedSteps;
    final progress = quest.progressFor(distance: distance, steps: steps);
    _progressSaveQueue = _progressSaveQueue
        .then<void>((_) async {
          await saveProgress(
            questId: quest.id,
            progress: progress,
            distance: distance,
            steps: steps,
          );
          _updateLocalProgress(quest.id, progress, distance, steps);
        })
        .catchError((Object error) {
          _handleError(error);
        });
  }

  void _updateLocalProgress(
    String questId,
    double progress,
    double distance,
    int steps,
  ) {
    final quests = _state.userQuests;
    final index = quests.indexWhere((item) => item.questId == questId);
    if (index < 0) return;

    final current = quests[index];
    if (!current.isOngoing) return;
    final updated = List<UserQuestModel>.of(quests);
    updated[index] = UserQuestModel(
      questId: current.questId,
      status: current.status,
      progress: progress,
      distance: distance,
      steps: steps,
      startedAt: current.startedAt,
      completedAt: current.completedAt,
    );
    _state = _state.copyWith(userQuests: updated);
    _notifyListeners();
  }

  void _handleTrackingError(Object error) {
    _handleError(error);
    unawaited(stopTracking());
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
    _stepRefreshTimer?.cancel();
    _trackingSubscription?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
