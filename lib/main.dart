import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/photo_library_service.dart';
import 'data/screenshot_sync_service.dart';
import 'data/shelf_store.dart';
import 'data/shot_image_store.dart';
import 'data/shot_repository.dart';
import 'models/shot.dart';
import 'theme/app_theme.dart';
import 'ui/import_picker_sheet.dart';
import 'ui/label_shot_sheet.dart';
import 'ui/phone_frame.dart';
import 'ui/shot_image.dart';
import 'ui/shot_preview_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await createDefaultShotRepository();
  final shelves = ShelfStore();
  await shelves.init();
  final photos = PhotoLibraryService();
  runApp(
    SnapShelfApp(
      repository: repo,
      photos: photos,
      shelves: shelves,
      sync: ScreenshotSyncService(repository: repo, photos: photos),
    ),
  );
}

class SnapShelfApp extends StatefulWidget {
  const SnapShelfApp({
    super.key,
    required this.repository,
    required this.photos,
    this.shelves,
    this.sync,
  });

  final ShotRepository repository;
  final PhotoLibraryService photos;

  /// Nullable so hot reload of an older running app doesn't crash on new fields.
  final ShelfStore? shelves;
  final ScreenshotSyncService? sync;

  @override
  State<SnapShelfApp> createState() => _SnapShelfAppState();
}

class _SnapShelfAppState extends State<SnapShelfApp> {
  ShelfStore? _shelves;
  ScreenshotSyncService? _sync;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant SnapShelfApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recover if hot reload injected null deps.
    if (_shelves == null || _sync == null || !_ready) {
      _prepare();
    }
  }

  Future<void> _prepare() async {
    final shelves = widget.shelves ?? _shelves ?? ShelfStore();
    if (widget.shelves == null && _shelves == null) {
      await shelves.init();
    }
    final sync = widget.sync ??
        _sync ??
        ScreenshotSyncService(
          repository: widget.repository,
          photos: widget.photos,
        );
    if (!mounted) return;
    setState(() {
      _shelves = shelves;
      _sync = sync;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapShelf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        return PhoneFrame(
          child: AppBackdrop(child: child ?? const SizedBox.shrink()),
        );
      },
      home: !_ready || _shelves == null || _sync == null
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : HomeShell(
              repository: widget.repository,
              photos: widget.photos,
              shelves: _shelves!,
              sync: _sync!,
            ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.photos,
    required this.shelves,
    required this.sync,
  });

  final ShotRepository repository;
  final PhotoLibraryService photos;
  final ShelfStore shelves;
  final ScreenshotSyncService sync;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  List<Shot> _allShots = [];
  List<Shot> _visibleShots = [];
  String _query = '';
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    try {
      widget.sync.stopWatching();
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runSync(importAllMissing: false, quiet: true);
    }
  }

  Future<void> _bootstrap() async {
    await _reload();
    final didInitial = await widget.sync.didInitialImport;
    await _runSync(importAllMissing: !didInitial, quiet: didInitial);
    widget.sync.startWatching(() {
      _reload();
    });
  }

  Future<void> _runSync({
    required bool importAllMissing,
    bool quiet = false,
  }) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final result = await widget.sync.syncNew(importAllMissing: importAllMissing);
    if (!mounted) return;
    setState(() => _syncing = false);
    if (result.imported > 0 || (!quiet && result.message.isNotEmpty)) {
      if (result.imported > 0 || !quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    }
    if (result.imported > 0) await _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final all = await widget.repository.getAll();
      final visible = _query.trim().isEmpty
          ? all
          : await widget.repository.search(_query);
      if (!mounted) return;
      setState(() {
        _allShots = all;
        _visibleShots = visible;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addShot() async {
    final draft = await showImportPicker(context, photos: widget.photos);
    if (draft == null || !mounted) return;

    final result = await showLabelShotSheet(
      context,
      draft: draft,
      photos: widget.photos,
      shelves: widget.shelves,
    );
    if (result == null) return;

    await widget.repository.upsert(result.shot);
    if (!mounted) return;
    final shot = result.shot;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shot.needsLabel
              ? 'Saved to Unlabeled — label anytime.'
              : shot.linkedToPhotos
                  ? 'Shelved “${shot.label}” (Photos-linked).'
                  : 'Shelved “${shot.label}” (app-only).',
        ),
      ),
    );
    await _reload();
  }

  Future<void> _deleteShot(Shot shot, {bool confirm = true}) async {
    if (confirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Yeet this shot?'),
            content: Text(
              shot.linkedToPhotos
                  ? 'Removes it from SnapShelf and tries to delete the Photos/MediaStore asset.'
                  : 'Removes it from SnapShelf only. There is no Photos library link for this item.',
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
          );
        },
      );
      if (confirmed != true) return;
    }

    final result = await widget.photos.deleteFromLibrary(shot);
    await widget.repository.delete(shot.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    await _reload();
  }

  void _openShot(Shot shot) {
    openShotPreview(
      context,
      shot: shot,
      images: widget.photos.images,
      shelves: widget.shelves,
      photos: widget.photos,
      onDelete: (s) => _deleteShot(s, confirm: false),
      onChanged: (s) async {
        await widget.repository.upsert(s);
        await _reload();
      },
    );
  }

  void _openShelf(String shelf) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShelfDetailScreen(
          shelf: shelf,
          repository: widget.repository,
          photos: widget.photos,
          shelves: widget.shelves,
          onChanged: _reload,
        ),
      ),
    );
  }

  Future<void> _createShelfFromShelvesTab() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New shelf'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(hintText: 'e.g. MTB, Taxes'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null) return;
    final ok = await widget.shelves.addCustom(name);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create shelf (empty or duplicate).')),
      );
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_index == 0 ? 'Inbox' : 'Shelves'),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Sync screenshots',
              onPressed: () => _runSync(importAllMissing: true, quiet: false),
              icon: const Icon(Icons.sync),
            ),
          if (_index == 1)
            IconButton(
              tooltip: 'New shelf',
              onPressed: _createShelfFromShelvesTab,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
        ],
      ),
      body: _index == 0
          ? InboxView(
              shots: _visibleShots,
              loading: _loading,
              query: _query,
              permissionCopy: widget.photos.permissionRealityCopy,
              photos: widget.photos,
              onQueryChanged: (q) {
                _query = q;
                _reload();
              },
              onDelete: _deleteShot,
              onOpen: _openShot,
            )
          : ShelvesView(
              shelves: widget.shelves.all,
              shots: _allShots,
              onOpenShelf: _openShelf,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Shelves',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addShot,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add shot'),
      ),
    );
  }
}

class InboxView extends StatelessWidget {
  const InboxView({
    super.key,
    required this.shots,
    required this.loading,
    required this.query,
    required this.permissionCopy,
    required this.photos,
    required this.onQueryChanged,
    required this.onDelete,
    required this.onOpen,
  });

  final List<Shot> shots;
  final bool loading;
  final String query;
  final String permissionCopy;
  final PhotoLibraryService photos;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function(Shot shot) onDelete;
  final ValueChanged<Shot> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SnapShelf',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Label later is fine. Unlabeled stays on top until you name it.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.62),
                    ),
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search labels',
                  isDense: true,
                ),
                onChanged: onQueryChanged,
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : shots.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      children: [
                        _EmptyPanel(
                          title: query.trim().isEmpty
                              ? 'Nothing shelved yet'
                              : 'No labels match “${query.trim()}”',
                          body: query.trim().isEmpty
                              ? '$permissionCopy\n\nAdd shot manually, or sync the Screenshots album on a phone. Label later is fine — Unlabeled is the default.'
                              : 'Try another word, or clear the search.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: shots.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Text(
                            '${shots.length} shot${shots.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.5),
                                ),
                          );
                        }
                        final shot = shots[index - 1];
                        return ShotTile(
                          shot: shot,
                          photos: photos,
                          onOpen: () => onOpen(shot),
                          onDelete: () => onDelete(shot),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.photo_library_outlined, color: AppTheme.sea, size: 28),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.65),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class ShelvesView extends StatelessWidget {
  const ShelvesView({
    super.key,
    required this.shelves,
    required this.shots,
    required this.onOpenShelf,
  });

  final List<String> shelves;
  final List<Shot> shots;
  final ValueChanged<String> onOpenShelf;

  int _countFor(String shelf) =>
      shots.where((s) => s.shelves.contains(shelf)).length;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: shelves.length,
      itemBuilder: (context, index) {
        final shelf = shelves[index];
        final count = _countFor(shelf);
        return Material(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onOpenShelf(shelf),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.seaSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _shelfIcon(shelf),
                      color: AppTheme.sea,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(shelf, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$count shot${count == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.55),
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _shelfIcon(String shelf) {
    switch (shelf) {
      case ShelfCatalog.unlabeled:
        return Icons.schedule_outlined;
      case 'Bug':
        return Icons.bug_report_outlined;
      case 'Work':
        return Icons.work_outline;
      case 'Receipt':
        return Icons.receipt_long_outlined;
      case 'Meme':
        return Icons.mood_outlined;
      case 'Keep':
        return Icons.bookmark_border;
      default:
        return Icons.folder_outlined;
    }
  }
}

class ShelfDetailScreen extends StatefulWidget {
  const ShelfDetailScreen({
    super.key,
    required this.shelf,
    required this.repository,
    required this.photos,
    required this.shelves,
    required this.onChanged,
  });

  final String shelf;
  final ShotRepository repository;
  final PhotoLibraryService photos;
  final ShelfStore shelves;
  final Future<void> Function() onChanged;

  @override
  State<ShelfDetailScreen> createState() => _ShelfDetailScreenState();
}

class _ShelfDetailScreenState extends State<ShelfDetailScreen> {
  List<Shot> _shots = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shots = await widget.repository.byShelf(widget.shelf);
      if (!mounted) return;
      setState(() {
        _shots = shots;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this shelf.';
      });
    }
  }

  Future<void> _delete(Shot shot, {bool confirm = true}) async {
    if (confirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Yeet this shot?'),
          content: Text(
            shot.linkedToPhotos
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
      if (confirmed != true) return;
    }
    final result = await widget.photos.deleteFromLibrary(shot);
    await widget.repository.delete(shot.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    await _reload();
    await widget.onChanged();
  }

  void _open(Shot shot) {
    openShotPreview(
      context,
      shot: shot,
      images: widget.photos.images,
      shelves: widget.shelves,
      photos: widget.photos,
      onDelete: (s) => _delete(s, confirm: false),
      onChanged: (s) async {
        await widget.repository.upsert(s);
        await _reload();
        await widget.onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(widget.shelf),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _shots.isEmpty
                    ? const Center(child: Text('Nothing on this shelf yet.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: _shots.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final shot = _shots[index];
                          return ShotTile(
                            shot: shot,
                            photos: widget.photos,
                            onOpen: () => _open(shot),
                            onDelete: () => _delete(shot),
                          );
                        },
                      ),
      ),
    );
  }
}

class ShotTile extends StatelessWidget {
  const ShotTile({
    super.key,
    required this.shot,
    required this.photos,
    required this.onOpen,
    required this.onDelete,
  });

  final Shot shot;
  final PhotoLibraryService photos;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: [
              ShotThumb(shot: shot, images: photos.images),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shot.displayLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontStyle: shot.needsLabel
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: shot.needsLabel
                                ? AppTheme.ink.withValues(alpha: 0.55)
                                : null,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        shot.shelves.join(' · '),
                        shot.linkedToPhotos ? 'Photos-linked' : 'App-only',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.ink.withValues(alpha: 0.55),
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: AppTheme.coral),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShotThumb extends StatefulWidget {
  const ShotThumb({super.key, required this.shot, required this.images});

  final Shot shot;
  final ShotImageStore images;

  @override
  State<ShotThumb> createState() => _ShotThumbState();
}

class _ShotThumbState extends State<ShotThumb> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ShotThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shot.id != widget.shot.id) {
      _loaded = false;
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.images.loadBytes(
        widget.shot.id,
        localPath: widget.shot.localPath,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: !_loaded && kIsWeb
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : ShotImage(shot: widget.shot, bytes: _bytes, fit: BoxFit.cover),
      ),
    );
  }
}
