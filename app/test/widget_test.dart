import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uncloud/l10n/locale_controller.dart';
import 'package:uncloud/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Fresh, empty local store for every test.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('App boots into onboarding in English', (tester) async {
    final locale = LocaleController();
    await locale.load();

    await tester.pumpWidget(UncloudApp(localeController: locale));
    await tester.pumpAndSettle();

    // First launch → onboarding, English by default.
    expect(find.text('Your data stays yours'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Onboarding next advances to page 2', (tester) async {
    final locale = LocaleController();
    await locale.load();

    await tester.pumpWidget(UncloudApp(localeController: locale));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Direct phone-PC link'), findsOneWidget);
  });

  testWidgets('Chinese locale renders Chinese strings', (tester) async {
    final locale = LocaleController();
    await locale.setMode('zh');

    await tester.pumpWidget(UncloudApp(localeController: locale));
    await tester.pumpAndSettle();

    expect(find.text('数据只属于你'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);
  });
}
