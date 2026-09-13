import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';

import '../models/shot.dart';
import '../util/image_shrink.dart';
import '../util/io_bridge.dart' as io;
import 'shot_image_store.dart';

enum LibraryDeleteOutcome {
  /// App record (+ local copy) removed; Photos asset also deleted.
  removedFromAppAndPhotos,

  /// App record removed; Photos asset was never linked (desktop/web or file pick).
  removedFromAppOnlyUnlinked,

  /// App record removed; Photos permission missing or OS refused delete.
  removedFromAppPhotosDenied,
}

class DeleteShotResult {
  const DeleteShotResult({
    required this.outcome,
    required this.message,
  });

  final LibraryDeleteOutcome outcome;
  final String message;
}

class ImportDraft {
  const ImportDraft({
    required this.bytes,
    this.photoAssetId,
    this.suggestedName,
  });

  final Uint8List bytes;
  final String? photoAssetId;
  final String? suggestedName;
}

/// Picks images and deletes Photos assets when the OS allows it.
class PhotoLibraryService {
  PhotoLibraryService({
    ImagePicker? picker,
    ShotImageStore? images,
  })  : _picker = picker ?? ImagePicker(),
        _images = images;

  final ImagePicker _picker;
  ShotImageStore? _images;
  final _uuid = const Uuid();

  /// Lazy so hot-reload / partial reinits never leave a null store.
  ShotImageStore get images => _images ??= ShotImageStore();

  bool get supportsLibraryLink => !kIsWeb && io.isMobileOs;

  /// Honest one-liner for empty states / onboarding.
  String get permissionRealityCopy {
    if (kIsWeb || !io.isMobileOs) {
      return 'Chrome/desktop: Add shot is manual. Auto-pull from the Screenshots album needs Android or iOS.';
    }
    if (io.isIOS) {
      return 'iOS cannot intercept the screenshot buttons. SnapShelf imports the Screenshots album when you open the app (Photos Read & Write). Label later is fine — new shots land in Unlabeled.';
    }
    return 'Android: SnapShelf watches the Screenshots album while the app is open/resumed. It cannot hook the system screenshot gesture itself. New shots land in Unlabeled until you label them.';
  }

  Future<PermissionState> requestAccess() {
    return PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
  }

  /// Recent library assets for the mobile import grid. Empty if no access.
  Future<List<AssetEntity>> loadRecentAssets({int limit = 80}) async {
    if (!supportsLibraryLink) return const [];
    final ps = await requestAccess();
    if (!ps.hasAccess) return const [];

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return const [];
    return paths.first.getAssetListPaged(page: 0, size: limit);
  }

  Future<ImportDraft?> draftFromAsset(AssetEntity asset) async {
    final file = await asset.originFile ?? await asset.file;
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return ImportDraft(
      bytes: bytes,
      photoAssetId: asset.id,
      suggestedName: asset.title,
    );
  }

  /// File / gallery pick for web, Windows, and as a mobile fallback.
  /// Does **not** create a Photos library link — delete will be app-only.
  Future<ImportDraft?> draftFromImagePicker() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return ImportDraft(
      bytes: bytes,
      photoAssetId: null,
      suggestedName: file.name,
    );
  }

  Future<String?> persistLocalCopy(Uint8List bytes, {String? id}) async {
    if (kIsWeb) return null;
    final dir = await getApplicationDocumentsDirectory();
    final name = '${id ?? _uuid.v4()}.jpg';
    final outPath = p.join(dir.path, 'shots', name);
    await io.writeBytesToFile(outPath, bytes);
    return outPath;
  }

  Future<Shot> buildShot({
    required ImportDraft draft,
    required String label,
    required List<String> shelves,
    DateTime? createdAt,
  }) async {
    final id = _uuid.v4();
    final storedBytes = await shrinkForStorage(draft.bytes);
    final path = await persistLocalCopy(storedBytes, id: id);
    try {
      await images.saveBytes(id, storedBytes);
    } catch (e) {
      debugPrint('SnapShelf: image persist failed: $e');
    }
    final resolvedShelves = shelves.isEmpty
        ? <String>[ShelfCatalog.unlabeled]
        : List<String>.from(shelves);
    return Shot(
      id: id,
      label: label.trim(),
      shelves: resolvedShelves,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      localPath: path,
      photoAssetId: draft.photoAssetId,
    );
  }

  Future<void> deleteLocalCopy(String? localPath) async {
    if (localPath == null || kIsWeb) return;
    await io.deleteFileIfExists(localPath);
  }

  Future<DeleteShotResult> deleteFromLibrary(Shot shot) async {
    await deleteLocalCopy(shot.localPath);
    await images.delete(shot.id);

    if (!shot.linkedToPhotos) {
      return const DeleteShotResult(
        outcome: LibraryDeleteOutcome.removedFromAppOnlyUnlinked,
        message:
            'Removed from SnapShelf. This shot was not linked to the Photos library (file import / desktop), so nothing was deleted there.',
      );
    }

    if (!supportsLibraryLink) {
      return const DeleteShotResult(
        outcome: LibraryDeleteOutcome.removedFromAppOnlyUnlinked,
        message:
            'Removed from SnapShelf. Photos library delete is not available on this platform.',
      );
    }

    try {
      final ps = await requestAccess();
      if (!ps.hasAccess) {
        return const DeleteShotResult(
          outcome: LibraryDeleteOutcome.removedFromAppPhotosDenied,
          message:
              'Removed from SnapShelf. Photos permission missing — delete the original manually in Photos.',
        );
      }

      final deleted =
          await PhotoManager.editor.deleteWithIds([shot.photoAssetId!]);
      if (deleted.contains(shot.photoAssetId)) {
        return const DeleteShotResult(
          outcome: LibraryDeleteOutcome.removedFromAppAndPhotos,
          message: 'Yeeted from SnapShelf and Photos.',
        );
      }

      return const DeleteShotResult(
        outcome: LibraryDeleteOutcome.removedFromAppPhotosDenied,
        message:
            'Removed from SnapShelf. The OS did not confirm Photos delete (permission or user cancel). Check Photos.',
      );
    } catch (_) {
      return const DeleteShotResult(
        outcome: LibraryDeleteOutcome.removedFromAppPhotosDenied,
        message:
            'Removed from SnapShelf. Photos delete failed — finish in the Photos app.',
      );
    }
  }
}
