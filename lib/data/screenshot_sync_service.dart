import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shot.dart';
import 'photo_library_service.dart';
import 'shot_repository.dart';

class SyncResult {
  const SyncResult({
    required this.imported,
    required this.message,
    this.supported = true,
  });

  final int imported;
  final String message;
  final bool supported;
}

/// Pulls the device Screenshots album into SnapShelf as Unlabeled.
///
/// Honest limits:
/// - Cannot hook the OS screenshot button/hotkey.
/// - Runs on app open / resume, and while foreground (library change notify).
/// - Web/desktop: not supported.
class ScreenshotSyncService {
  ScreenshotSyncService({
    required this.repository,
    required this.photos,
  });

  final ShotRepository repository;
  final PhotoLibraryService photos;

  static const _initialImportKey = 'snapshelf_initial_screenshot_import_v1';

  bool get isSupported => photos.supportsLibraryLink;

  void Function()? _onLibraryChanged;
  bool _watching = false;
  bool _syncing = false;

  Future<bool> get didInitialImport async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_initialImportKey) ?? false;
  }

  Future<void> markInitialImportDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_initialImportKey, true);
  }

  void startWatching(void Function() onChanged) {
    if (!isSupported || _watching) return;
    _onLibraryChanged = onChanged;
    PhotoManager.addChangeCallback(_handleChange);
    PhotoManager.startChangeNotify();
    _watching = true;
  }

  void stopWatching() {
    if (!_watching) return;
    PhotoManager.removeChangeCallback(_handleChange);
    PhotoManager.stopChangeNotify();
    _watching = false;
    _onLibraryChanged = null;
  }

  void _handleChange(MethodCall call) {
    syncNew(importAllMissing: false).then((result) {
      if (result.imported > 0) {
        _onLibraryChanged?.call();
      }
    });
  }

  Future<AssetPathEntity?> findScreenshotsAlbum() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );
    for (final path in paths) {
      final name = path.name.toLowerCase();
      if (name.contains('screenshot')) return path;
    }
    return null;
  }

  /// Import screenshots not yet linked in the local DB.
  Future<SyncResult> syncNew({required bool importAllMissing}) async {
    if (!isSupported) {
      return const SyncResult(
        imported: 0,
        supported: false,
        message:
            'Auto-import needs Android/iOS Photos access. Chrome/desktop stay manual (Add shot).',
      );
    }
    if (_syncing) {
      return const SyncResult(imported: 0, message: 'Sync already running.');
    }
    _syncing = true;
    try {
      final ps = await photos.requestAccess();
      if (!ps.hasAccess) {
        return const SyncResult(
          imported: 0,
          message:
              'Photos permission needed to pull screenshots into Unlabeled.',
        );
      }

      final album = await findScreenshotsAlbum();
      if (album == null) {
        await markInitialImportDone();
        return const SyncResult(
          imported: 0,
          message:
              'No Screenshots album found. Use Add shot, or check that the phone stores screenshots in a Screenshots album.',
        );
      }

      final known = await repository.linkedPhotoAssetIds();
      final total = await album.assetCountAsync;
      if (total == 0) {
        await markInitialImportDone();
        return const SyncResult(
          imported: 0,
          message: 'Screenshots album is empty.',
        );
      }

      final pageSize = importAllMissing ? 80 : 40;
      final maxPages =
          importAllMissing ? ((total / pageSize).ceil().clamp(1, 50)) : 1;

      var imported = 0;
      for (var page = 0; page < maxPages; page++) {
        final assets =
            await album.getAssetListPaged(page: page, size: pageSize);
        if (assets.isEmpty) break;
        for (final asset in assets) {
          if (known.contains(asset.id)) continue;
          final draft = await photos.draftFromAsset(asset);
          if (draft == null) continue;
          final shot = await photos.buildShot(
            draft: draft,
            label: '',
            shelves: const [ShelfCatalog.unlabeled],
            createdAt: asset.createDateTime.toUtc(),
          );
          await repository.upsert(shot);
          known.add(asset.id);
          imported++;
        }
        if (!importAllMissing) break;
      }

      await markInitialImportDone();
      if (imported == 0) {
        return SyncResult(
          imported: 0,
          message: importAllMissing
              ? 'Screenshots album already indexed (or empty).'
              : 'No new screenshots.',
        );
      }
      return SyncResult(
        imported: imported,
        message:
            'Pulled $imported screenshot${imported == 1 ? '' : 's'} into Unlabeled. Label anytime.',
      );
    } finally {
      _syncing = false;
    }
  }
}
