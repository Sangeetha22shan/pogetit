import 'package:flutter/material.dart';

import '../../../data/repositories/quest_repository.dart';
import '../model/quest_model.dart';
import '../model/quest_state.dart';
import '../viewmodel/quest_view_model.dart';

class QuestHomePage extends StatefulWidget {
  const QuestHomePage({
    super.key,
    required this.repository,
    required this.onSignOut,
  });

  final QuestRepository repository;
  final VoidCallback onSignOut;

  @override
  State<QuestHomePage> createState() => _QuestHomePageState();
}

class _QuestHomePageState extends State<QuestHomePage> {
  late final QuestViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = QuestViewModel(widget.repository)..fetchQuests();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PoGetIt – Quest Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => _buildBody(context, _viewModel.state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, QuestState state) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Welcome to your quests',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: _SummaryCard(label: 'Total XP', value: '0 XP'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(label: 'Active quests', value: '0'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available quests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${state.quests.length} quests'),
          ],
        ),
        const SizedBox(height: 12),
        if (state.status == QuestLoadingStatus.loading ||
            state.status == QuestLoadingStatus.initial)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.status == QuestLoadingStatus.error)
          _ErrorMessage(
            message: state.errorMessage ?? 'Unable to load quests.',
            onRetry: _viewModel.fetchQuests,
          )
        else if (state.quests.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No quests are currently available.')),
          )
        else
          ...state.quests.map((quest) => _QuestCard(quest: quest)),
        const SizedBox(height: 12),
      ],
    );
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
  const _QuestCard({required this.quest});

  final QuestModel quest;

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
            const LinearProgressIndicator(value: 0),
            const SizedBox(height: 6),
            Text('0% completed', style: Theme.of(context).textTheme.bodySmall),
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
