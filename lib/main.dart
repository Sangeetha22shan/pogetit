import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  const useFirebaseEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );
  if (useFirebaseEmulators) {
    const emulatorHost = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '10.0.2.2',
    );
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
  }

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
