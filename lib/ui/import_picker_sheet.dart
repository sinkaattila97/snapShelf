import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/photo_library_service.dart';

/// Pick a library asset (mobile) or fall back to file picker.
Future<ImportDraft?> showImportPicker(
  BuildContext context, {
  required PhotoLibraryService photos,
}) async {
  if (!photos.supportsLibraryLink) {
    return photos.draftFromImagePicker();
  }

  return showModalBottomSheet<ImportDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: _LibraryImportSheet(photos: photos),
      );
    },
  );
}

class _LibraryImportSheet extends StatefulWidget {
  const _LibraryImportSheet({required this.photos});

  final PhotoLibraryService photos;

  @override
  State<_LibraryImportSheet> createState() => _LibraryImportSheetState();
}

class _LibraryImportSheetState extends State<_LibraryImportSheet> {
  late Future<_ImportLoadResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ImportLoadResult> _load() async {
    final ps = await widget.photos.requestAccess();
    if (!ps.hasAccess) {
      return _ImportLoadResult.denied(ps);
    }
    final assets = await widget.photos.loadRecentAssets();
    return _ImportLoadResult.ok(assets, ps);
  }

  Future<void> _pickFileFallback() async {
    final draft = await widget.photos.draftFromImagePicker();
    if (!mounted) return;
    Navigator.of(context).pop(draft);
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    final draft = await widget.photos.draftFromAsset(asset);
    if (!mounted) return;
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Import shot',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: _pickFileFallback,
                  child: const Text('File pick'),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Pick from Photos to keep a library link (needed to delete later). '
              'File pick works without a link.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<_ImportLoadResult>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final result = snapshot.data;
                if (result == null) {
                  return const Center(child: Text('Could not load Photos.'));
                }
                if (!result.hasAccess) {
                  return _DeniedBody(
                    detail: result.permissionHint,
                    onRetry: () => setState(() => _future = _load()),
                    onFilePick: _pickFileFallback,
                  );
                }
                if (result.assets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No images found in Photos.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _pickFileFallback,
                          child: const Text('Use file pick instead'),
                        ),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: result.assets.length,
                  itemBuilder: (context, index) {
                    final asset = result.assets[index];
                    return _AssetThumb(
                      asset: asset,
                      onTap: () => _selectAsset(asset),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportLoadResult {
  _ImportLoadResult._({
    required this.hasAccess,
    required this.assets,
    required this.permissionHint,
  });

  factory _ImportLoadResult.ok(List<AssetEntity> assets, PermissionState ps) {
    return _ImportLoadResult._(
      hasAccess: true,
      assets: assets,
      permissionHint: ps.toString(),
    );
  }

  factory _ImportLoadResult.denied(PermissionState ps) {
    final hint = ps == PermissionState.limited
        ? 'Limited Photos access — pick from the allowed set, or use File pick (no delete link).'
        : 'Photos access denied. Use File pick (app-only; no library delete), or enable access in Settings.';
    return _ImportLoadResult._(
      hasAccess: false,
      assets: const [],
      permissionHint: hint,
    );
  }

  final bool hasAccess;
  final List<AssetEntity> assets;
  final String permissionHint;
}

class _DeniedBody extends StatelessWidget {
  const _DeniedBody({
    required this.detail,
    required this.onRetry,
    required this.onFilePick,
  });

  final String detail;
  final VoidCallback onRetry;
  final VoidCallback onFilePick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(detail, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          const SizedBox(height: 8),
          TextButton(onPressed: onFilePick, child: const Text('File pick instead')),
        ],
      ),
    );
  }
}

class _AssetThumb extends StatelessWidget {
  const _AssetThumb({required this.asset, required this.onTap});

  final AssetEntity asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: FutureBuilder<Widget>(
        future: _thumb(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            );
          }
          return snapshot.data!;
        },
      ),
    );
  }

  Future<Widget> _thumb() async {
    final data = await asset.thumbnailDataWithSize(
      const ThumbnailSize.square(200),
    );
    if (data == null) {
      return const ColoredBox(
        color: Colors.black12,
        child: Icon(Icons.broken_image_outlined),
      );
    }
    return Image.memory(data, fit: BoxFit.cover);
  }
}
