import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/photo_library_service.dart';
import '../data/shelf_store.dart';
import '../data/shot_image_store.dart';
import '../models/shot.dart';
import '../theme/app_theme.dart';
import 'label_shot_sheet.dart';
import 'shot_image.dart';

Future<void> openShotPreview(
  BuildContext context, {
  required Shot shot,
  required ShotImageStore images,
  required ShelfStore shelves,
  required PhotoLibraryService photos,
  required Future<void> Function(Shot shot) onDelete,
  required Future<void> Function(Shot shot) onChanged,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ShotPreviewScreen(
        shot: shot,
        images: images,
        shelves: shelves,
        photos: photos,
        onDelete: onDelete,
        onChanged: onChanged,
      ),
    ),
  );
}

class ShotPreviewScreen extends StatefulWidget {
  const ShotPreviewScreen({
    super.key,
    required this.shot,
    required this.images,
    required this.shelves,
    required this.photos,
    required this.onDelete,
    required this.onChanged,
  });

  final Shot shot;
  final ShotImageStore images;
  final ShelfStore shelves;
  final PhotoLibraryService photos;
  final Future<void> Function(Shot shot) onDelete;
  final Future<void> Function(Shot shot) onChanged;

  @override
  State<ShotPreviewScreen> createState() => _ShotPreviewScreenState();
}

class _ShotPreviewScreenState extends State<ShotPreviewScreen> {
  late Shot _shot;
  Uint8List? _bytes;
  bool _loading = true;
  bool _missingImage = false;

  @override
  void initState() {
    super.initState();
    _shot = widget.shot;
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.images.loadBytes(
        _shot.id,
        localPath: _shot.localPath,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _missingImage = bytes == null && (kIsWeb || _shot.localPath == null);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _missingImage = true;
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    final result = await showLabelShotSheet(
      context,
      draft: ImportDraft(
        bytes: _bytes ?? Uint8List(0),
        photoAssetId: _shot.photoAssetId,
      ),
      photos: widget.photos,
      shelves: widget.shelves,
      existing: _shot,
    );
    if (result == null || !mounted) return;
    setState(() => _shot = result.shot);
    await widget.onChanged(result.shot);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeet this shot?'),
        content: Text(
          _shot.linkedToPhotos
              ? 'Removes from SnapShelf + tries Photos delete.'
              : 'Removes from SnapShelf only (no Photos link).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onDelete(_shot);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(_shot.displayLabel),
        actions: [
          IconButton(
            tooltip: _shot.needsLabel ? 'Add label' : 'Edit',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFFB4A2)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: _missingImage
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No preview stored for this shot.\nRe-add or re-sync to keep a thumbnail.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ShotImage(
                              shot: _shot,
                              bytes: _bytes,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
          ),
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _shot.displayLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontStyle: _shot.needsLabel
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        _shot.shelves.join(' · '),
                        _shot.linkedToPhotos ? 'Photos-linked' : 'App-only',
                        _formatWhen(_shot.createdAt),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.ink.withValues(alpha: 0.55),
                          ),
                    ),
                    if (_shot.needsLabel) ...[
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _edit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.ink,
                        ),
                        child: const Text('Add label'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWhen(DateTime utc) {
    final local = utc.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
