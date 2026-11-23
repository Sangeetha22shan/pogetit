import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/quest_repository.dart';
import 'data/repositories/user_quest_repository.dart';
import 'features/authentication/view/auth_gate.dart';
import 'features/authentication/viewmodel/auth_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const PoGetItApp());
}

class PoGetItApp extends StatelessWidget {
  const PoGetItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => AuthRepository(),
      child: RepositoryProvider(
        create: (_) => QuestRepository(),
        child: RepositoryProvider(
          create: (_) => UserQuestRepository(),
          child: ChangeNotifierProvider(
            create: (context) =>
                AuthViewModel(context.read<AuthRepository>())..initialize(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'PoGetIt',
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
              ),
              home: Builder(
                builder: (context) => AuthGate(
                  viewModel: context.read<AuthViewModel>(),
                  questRepository: context.read<QuestRepository>(),
                  userQuestRepository: context.read<UserQuestRepository>(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
