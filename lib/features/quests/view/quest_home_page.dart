import 'package:flutter/material.dart';

import '../../../data/repositories/quest_repository.dart';
import '../../../data/repositories/user_quest_repository.dart';
import '../model/quest_model.dart';
import '../model/quest_state.dart';
import '../model/user_quest_model.dart';
import '../viewmodel/quest_view_model.dart';

class QuestHomePage extends StatefulWidget {
  const QuestHomePage({
    super.key,
    required this.userId,
    required this.repository,
    required this.userQuestRepository,
  });

  final String userId;
  final QuestRepository repository;
  final UserQuestRepository userQuestRepository;

  @override
  State<QuestHomePage> createState() => _QuestHomePageState();
}

class _QuestHomePageState extends State<QuestHomePage> {
  late final QuestViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = QuestViewModel(
      widget.repository,
      widget.userQuestRepository,
      widget.userId,
    )..fetchQuests();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PoGetIt – Quest Dashboard')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => _buildBody(_viewModel.state),
        ),
      ),
    );
  }

  Widget _buildBody(QuestState state) {
    if (state.status == QuestLoadingStatus.loading ||
        state.status == QuestLoadingStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == QuestLoadingStatus.error) {
      return _ErrorMessage(
        message: state.errorMessage ?? 'Unable to load quest data.',
        onRetry: _viewModel.fetchQuests,
      );
    }
    if (state.quests.isEmpty) {
      return const Center(child: Text('No quests are currently available.'));
    }

    final userQuests = {
      for (final quest in state.userQuests) quest.questId: quest,
    };
    UserQuestModel progressFor(QuestModel quest) =>
        userQuests[quest.id] ??
        UserQuestModel(questId: quest.id, status: 'available');
    bool hasStatus(QuestModel quest, String status) =>
        progressFor(quest).status == status;
    final availableCount = state.quests
        .where((quest) => hasStatus(quest, 'available'))
        .length;
    final ongoingCount = state.quests
        .where((quest) => hasStatus(quest, 'ongoing'))
        .length;
    final completedCount = state.quests
        .where((quest) => hasStatus(quest, 'completed'))
        .length;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Total XP',
                    value: '${state.profile.totalXP} XP',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Active quests',
                    value: '$ongoingCount',
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            tabs: [
              Tab(text: 'Available ($availableCount)'),
              Tab(text: 'Ongoing ($ongoingCount)'),
              Tab(text: 'Completed ($completedCount)'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _questList(state, userQuests, 'available'),
                _questList(state, userQuests, 'ongoing'),
                _questList(state, userQuests, 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questList(
    QuestState state,
    Map<String, UserQuestModel> userQuests,
    String status,
  ) {
    final quests = state.quests.where((quest) {
      return (userQuests[quest.id]?.status ?? 'available') == status;
    }).toList();

    if (quests.isEmpty) {
      return Center(child: Text('No ${status.toLowerCase()} quests.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: quests.map((quest) {
        final userQuest =
            userQuests[quest.id] ??
            UserQuestModel(questId: quest.id, status: 'available');
        return _QuestCard(
          quest: quest,
          userQuest: userQuest,
          onStart: () => _startQuest(quest.id),
        );
      }).toList(),
    );
  }

  Future<void> _startQuest(String questId) async {
    try {
      await _viewModel.startQuest(questId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not start quest: $error')));
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.userQuest,
    required this.onStart,
  });

  final QuestModel quest;
  final UserQuestModel userQuest;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    quest.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '+${quest.rewardXP} XP',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(quest.id, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Text(quest.description),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: userQuest.progress.clamp(0, 1)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(userQuest.progress.clamp(0, 1) * 100).round()}% completed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (userQuest.isAvailable)
                  TextButton(
                    onPressed: onStart,
                    child: const Text('Start quest'),
                  ),
                if (userQuest.isOngoing)
                  Text(
                    '${userQuest.steps} steps • ${userQuest.distance.round()} m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (userQuest.isCompleted) const Chip(label: Text('Completed')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Could not load quests: $message'),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
