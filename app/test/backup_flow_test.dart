import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uncloud/l10n/locale_controller.dart';
import 'package:uncloud/main.dart';
import 'package:uncloud/ui/settings/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> openHome(WidgetTester tester) async {
    final locale = LocaleController();
    await locale.load();
    await tester.pumpWidget(UncloudApp(localeController: locale));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  /// Demo sends and snackbars use timers, which [WidgetTester.pumpAndSettle]
  /// does not advance once the current frame has settled.
  Future<void> elapse(WidgetTester tester, Duration total) async {
    final steps = total.inMilliseconds ~/ 200;
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('timeline shows the local sample library', (tester) async {
    await openHome(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Demo mode — sample data'), findsOneWidget);
    expect(
      find.text('Auto-backup is on — new photos sync to Desktop PC'),
      findsOneWidget,
    );
  });

  testWidgets('backup sends only the gap, then reports the library caught up', (
    tester,
  ) async {
    await openHome(tester);
    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desktop PC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup now'));
    await tester.pump();

    expect(find.text('Backing up 3 items to Desktop PC'), findsOneWidget);

    // Let the three simulated sends finish and the snackbar leave the queue.
    await elapse(tester, const Duration(seconds: 6));

    await tester.tap(find.text('Transfers'));
    await tester.pumpAndSettle();
    expect(find.text('VID_0.mp4'), findsOneWidget);

    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desktop PC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup now'));
    await tester.pump();
    expect(find.text('Nothing new to back up'), findsOneWidget);
  });

  testWidgets('duplicate search groups an exact copy on device', (
    tester,
  ) async {
    await openHome(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final duplicates = find.text('Find duplicates');
    await tester.scrollUntilVisible(
      duplicates,
      300,
      scrollable: find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(duplicates);
    await tester.pumpAndSettle();

    expect(find.text('Exact copies'), findsOneWidget);
    expect(find.text('IMG_20_copy.jpg'), findsOneWidget);
    expect(find.textContaining('Looks similar'), findsOneWidget);
  });
}
