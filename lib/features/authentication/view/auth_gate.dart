import 'package:flutter/material.dart';

import '../../../data/repositories/quest_repository.dart';
import '../../quests/view/quest_home_page.dart';
import '../model/auth_state.dart';
import '../viewmodel/auth_view_model.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.viewModel,
    required this.questRepository,
  });

  final AuthViewModel viewModel;
  final QuestRepository questRepository;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        return switch (state.status) {
          AuthStatus.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          AuthStatus.authenticated => QuestHomePage(
            repository: questRepository,
            onSignOut: viewModel.signOut,
          ),
          AuthStatus.unauthenticated => const Scaffold(
            body: Center(child: Text('You are signed out.')),
          ),
          AuthStatus.error => Scaffold(
            body: Center(
              child: Text(state.errorMessage ?? 'Authentication failed.'),
            ),
          ),
        };
      },
    );
  }
}
