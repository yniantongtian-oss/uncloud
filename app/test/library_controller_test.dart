import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uncloud/controllers/library_controller.dart';
import 'package:uncloud/l10n/app_localizations.dart';
import 'package:uncloud/models/media_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('english and chinese catalogs have the same keys', () {
    expect(AppLocalizations.mismatchedTranslationKeys(), isEmpty);
    const english = AppLocalizations('en');
    const chinese = AppLocalizations('zh');
    expect(english.devicesBackupStarted(2, 'PC'), 'Backing up 2 items to PC');
    expect(chinese.devicesBackupNone, isNot(english.devicesBackupNone));
    expect(chinese.transferCancelled, isNot('transferCancelled'));
  });

  test('acknowledgements move forward and survive a reload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final item = MediaItem(
      id: 'photo',
      path: '/photos/a.jpg',
      type: MediaType.photo,
      sizeBytes: 100,
      createdAt: DateTime.utc(2026, 1, 2),
      contentHash: 'abc',
    );
    final controller = LibraryController(demo: false, seed: [item]);
    addTearDown(controller.dispose);
    await controller.ready;

    expect(controller.planFor('pc').items.single.resumeFrom, 0);
    await controller.acknowledge('photo', 'pc', 40);
    expect(controller.planFor('pc').items.single.resumeFrom, 40);
    await controller.acknowledge('photo', 'pc', 10);
    expect(controller.planFor('pc').items.single.resumeFrom, 40);
    await controller.acknowledge('photo', 'pc', 100);
    expect(controller.planFor('pc').isEmpty, isTrue);

    final reloaded = LibraryController(demo: false);
    addTearDown(reloaded.dispose);
    await reloaded.ready;
    expect(reloaded.planFor('pc').isEmpty, isTrue);
    expect(reloaded.items.single.acknowledgedBytes['pc'], 100);
  });
}
