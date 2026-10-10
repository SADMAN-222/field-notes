import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/authentication/auth_cubit.dart';
import '../../features/authentication/login_screen.dart';
import '../../features/authentication/register_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/customers/customer_form_screen.dart';
import '../../features/sites/sites_screen.dart';
import '../../features/sites/site_form_screen.dart';
import '../../features/field_notes/notes_screen.dart';
import '../../features/field_notes/note_form_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/synchronization/sync_screen.dart';

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final authState = authCubit.state;
      final isAuth = authState is AuthAuthenticated;
      final isLoginRoute = state.matchedLocation == '/' || state.matchedLocation == '/register';

      if (!isAuth && !isLoginRoute) return '/';
      if (isAuth && isLoginRoute) return '/customers';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: '/customers/new',
        builder: (context, state) => const CustomerFormScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) => SitesScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customers/:id/sites/new',
        builder: (context, state) => SiteFormScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/sites/:id',
        builder: (context, state) => NotesScreen(siteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/sites/:id/notes/new',
        builder: (context, state) => NoteFormScreen(siteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/sync',
        builder: (context, state) => const SyncScreen(),
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

