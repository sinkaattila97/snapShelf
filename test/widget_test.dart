import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snapshelf/data/photo_library_service.dart';
import 'package:snapshelf/data/screenshot_sync_service.dart';
import 'package:snapshelf/data/shelf_store.dart';
import 'package:snapshelf/data/shot_repository.dart';
import 'package:snapshelf/main.dart';
import 'package:snapshelf/models/shot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SnapShelfApp> buildApp(ShotRepository repo) async {
    final shelves = ShelfStore();
    await shelves.init();
    final photos = PhotoLibraryService();
    return SnapShelfApp(
      repository: repo,
      photos: photos,
      shelves: shelves,
      sync: ScreenshotSyncService(repository: repo, photos: photos),
    );
  }

  testWidgets('SnapShelf shows inbox shell', (WidgetTester tester) async {
    final repo = MemoryShotRepository();
    await repo.init();
    await tester.pumpWidget(await buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('SnapShelf'), findsWidgets);
    expect(find.text('Add shot'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('search filters by label', (WidgetTester tester) async {
    final repo = MemoryShotRepository();
    await repo.init();
    await repo.upsert(
      Shot(
        id: '1',
        label: 'login crash',
        shelves: const [ShelfCatalog.unlabeled, 'Bug'],
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await repo.upsert(
      Shot(
        id: '2',
        label: 'gym PR',
        shelves: const [ShelfCatalog.unlabeled, 'Keep'],
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );

    await tester.pumpWidget(await buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('login crash'), findsOneWidget);
    expect(find.text('gym PR'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'gym');
    await tester.pumpAndSettle();

    expect(find.text('gym PR'), findsOneWidget);
    expect(find.text('login crash'), findsNothing);
  });

  test('custom shelf store and unlabeled sort', () async {
    final shelves = ShelfStore();
    await shelves.init();
    expect(await shelves.addCustom('MTB'), isTrue);
    expect(shelves.all.contains('MTB'), isTrue);

    final repo = MemoryShotRepository();
    await repo.init();
    await repo.upsert(
      Shot(
        id: 'labeled',
        label: 'later',
        shelves: const ['Keep'],
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await repo.upsert(
      Shot(
        id: 'need',
        label: '',
        shelves: const [ShelfCatalog.unlabeled],
        createdAt: DateTime.utc(2026, 1, 2),
        photoAssetId: 'asset-1',
      ),
    );
    final all = await repo.getAll();
    expect(all.first.id, 'need');
    expect(all.first.needsLabel, isTrue);
    expect(await repo.linkedPhotoAssetIds(), {'asset-1'});
  });
}
