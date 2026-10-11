import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes_test/core/theme/app_colors.dart';
import 'package:field_notes_test/core/theme/app_theme.dart';
import 'package:field_notes_test/core/widgets/common_widgets.dart';

void main() {
  group('Design System & AppTheme Tests', () {
    test('App theme uses Material 3 and brand colors', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, true);
      expect(theme.primaryColor, AppColors.primary);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });
  });

  group('Common Widgets Tests', () {
    testWidgets('EmptyStateView renders icon, title, message, and executes action', (WidgetTester tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'No Customers Found',
              message: 'Try adjusting your search criteria.',
              actionLabel: 'Clear Search',
              onAction: () {
                actionTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('No Customers Found'), findsOneWidget);
      expect(find.text('Try adjusting your search criteria.'), findsOneWidget);
      expect(find.text('Clear Search'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);

      await tester.tap(find.text('Clear Search'));
      expect(actionTapped, isTrue);
    });

    testWidgets('StatusBadge renders appropriate label and colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(status: 'DRAFT'),
                StatusBadge(status: 'SUBMITTED'),
                StatusBadge(status: 'COMPLETED'),
                StatusBadge(status: 'FLAGGED'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.text('SUBMITTED'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('FLAGGED'), findsOneWidget);
    });

    testWidgets('AppCard renders child and triggers onTap callback', (WidgetTester tester) async {
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              onTap: () {
                cardTapped = true;
              },
              child: const Text('Test Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Card Content'), findsOneWidget);
      await tester.tap(find.text('Test Card Content'));
      expect(cardTapped, isTrue);
    });
  });
}
