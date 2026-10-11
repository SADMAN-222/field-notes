import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/auth_cubit.dart';
import '../../features/authentication/login_screen.dart';
import '../../features/authentication/register_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/customers/customer_details_screen.dart';
import '../../features/customers/customer_form_screen.dart';
import '../../features/sites/sites_screen.dart';
import '../../features/sites/site_details_screen.dart';
import '../../features/sites/site_form_screen.dart';
import '../../features/field_notes/notes_screen.dart';
import '../../features/field_notes/note_details_screen.dart';
import '../../features/field_notes/note_form_screen.dart';
import '../../features/field_notes/photo_view_screen.dart';
import '../../features/search/global_search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/synchronization/sync_screen.dart';

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final authState = authCubit.state;
      final isAuth = authState is AuthAuthenticated;
      final location = state.matchedLocation;

      // Allow splash screen to perform initialization uninterrupted
      if (location == '/splash') return null;

      final isAuthRoute = location == '/login' || location == '/register';

      // If unauthenticated and not on auth route, go to login
      if (!isAuth && !isAuthRoute) return '/login';

      // If authenticated and on auth route, go to dashboard
      if (isAuth && isAuthRoute) return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/splash',
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
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
        builder: (context, state) => CustomerDetailsScreen(
          customerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/customers/:id/edit',
        builder: (context, state) => CustomerFormScreen(
          customerId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/sites',
        builder: (context, state) => SitesScreen(
          customerId: state.uri.queryParameters['customerId'],
        ),
      ),
      GoRoute(
        path: '/sites/new',
        builder: (context, state) => SiteFormScreen(
          customerId: state.uri.queryParameters['customerId'],
        ),
      ),
      GoRoute(
        path: '/sites/:id',
        builder: (context, state) => SiteDetailsScreen(
          siteId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/sites/:id/edit',
        builder: (context, state) => SiteFormScreen(
          siteId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) => NotesScreen(
          siteId: state.uri.queryParameters['siteId'],
        ),
      ),
      GoRoute(
        path: '/notes/new',
        builder: (context, state) => NoteFormScreen(
          siteId: state.uri.queryParameters['siteId'],
        ),
      ),
      GoRoute(
        path: '/notes/:id',
        builder: (context, state) => NoteDetailsScreen(
          noteId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/notes/:id/edit',
        builder: (context, state) => NoteFormScreen(
          noteId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: '/sync',
        builder: (context, state) => const SyncScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/photo-viewer',
        builder: (context, state) => PhotoViewScreen(
          photoPath: (state.extra as String?) ?? '',
        ),
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

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
