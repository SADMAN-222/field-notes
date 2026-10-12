import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/injection.dart' as di;
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'app/router.dart';
import 'features/authentication/auth_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabasePublishableKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization notice: $e');
  }

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
