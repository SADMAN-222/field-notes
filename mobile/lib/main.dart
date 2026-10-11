import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/config/injection.dart' as di;
import 'core/theme/app_theme.dart';
import 'app/router.dart';
import 'features/authentication/auth_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  
  runApp(const FieldNotesApp());
}

class FieldNotesApp extends StatelessWidget {
  const FieldNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(authRepository: di.sl())..checkAuth(),
      child: Builder(
        builder: (context) {
          final authCubit = context.read<AuthCubit>();
          final router = createRouter(authCubit);
          
          return MaterialApp.router(
            title: 'Field Notes',
            theme: AppTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}

