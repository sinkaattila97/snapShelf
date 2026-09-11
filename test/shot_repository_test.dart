import 'package:flutter_test/flutter_test.dart';
import 'package:snapshelf/data/shot_repository.dart';
import 'package:snapshelf/models/shot.dart';

void main() {
  test('MemoryShotRepository search and shelf filter', () async {
    final repo = MemoryShotRepository();
    await repo.init();
    await repo.upsert(
      Shot(
        id: 'a',
        label: 'Auth timeout',
        shelves: const [ShelfCatalog.unlabeled, 'Bug'],
        createdAt: DateTime.utc(2026, 3, 1),
        photoAssetId: 'asset-1',
      ),
    );
    await repo.upsert(
      Shot(
        id: 'b',
        label: 'Trail fork',
        shelves: const ['Keep'],
        createdAt: DateTime.utc(2026, 3, 2),
      ),
    );

    expect((await repo.search('auth')).single.id, 'a');
    expect((await repo.byShelf('Bug')).single.id, 'a');
    expect((await repo.byShelf('Keep')).single.id, 'b');

    await repo.delete('a');
    expect(await repo.getAll(), hasLength(1));
  });
}
