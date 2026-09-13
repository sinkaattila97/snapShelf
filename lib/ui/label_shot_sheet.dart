import 'package:flutter/material.dart';

import '../data/photo_library_service.dart';
import '../data/shelf_store.dart';
import '../models/shot.dart';
import '../theme/app_theme.dart';

class LabelShotResult {
  const LabelShotResult({required this.shot, this.createdShelf});

  final Shot shot;
  final String? createdShelf;
}

/// Label is optional — empty label shelves into Unlabeled for later.
Future<LabelShotResult?> showLabelShotSheet(
  BuildContext context, {
  required ImportDraft draft,
  required PhotoLibraryService photos,
  required ShelfStore shelves,
  Shot? existing,
}) {
  return showModalBottomSheet<LabelShotResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _LabelShotForm(
          draft: draft,
          photos: photos,
          shelfStore: shelves,
          existing: existing,
        ),
      );
    },
  );
}

class _LabelShotForm extends StatefulWidget {
  const _LabelShotForm({
    required this.draft,
    required this.photos,
    required this.shelfStore,
    this.existing,
  });

  final ImportDraft draft;
  final PhotoLibraryService photos;
  final ShelfStore shelfStore;
  final Shot? existing;

  @override
  State<_LabelShotForm> createState() => _LabelShotFormState();
}

class _LabelShotFormState extends State<_LabelShotForm> {
  late final TextEditingController _labelController;
  late final Set<String> _selected;
  String? _error;
  bool _saving = false;
  late List<String> _shelfOptions;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _labelController = TextEditingController(text: existing?.label ?? '');
    _selected = {
      ...(existing?.shelves ?? const [ShelfCatalog.unlabeled]),
    };
    if (_selected.isEmpty) {
      _selected.add(ShelfCatalog.unlabeled);
    }
    _shelfOptions = widget.shelfStore.all;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _createShelf() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New shelf'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(
            hintText: 'e.g. MTB, Taxes, WoW',
          ),
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
    final ok = await widget.shelfStore.addCustom(name);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'Could not create that shelf (empty or duplicate).');
      return;
    }
    final created = name.trim();
    setState(() {
      _shelfOptions = widget.shelfStore.all;
      _selected.add(created);
      _error = null;
    });
  }

  Future<void> _save({required bool labelLater}) async {
    final label = labelLater ? '' : _labelController.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final shelves = (_selected.isEmpty
          ? <String>[ShelfCatalog.unlabeled]
          : _selected.toList())
        ..sort();
      if (labelLater && !shelves.contains(ShelfCatalog.unlabeled)) {
        shelves.insert(0, ShelfCatalog.unlabeled);
      }

      final Shot shot;
      if (widget.existing != null) {
        shot = widget.existing!.copyWith(label: label, shelves: shelves);
      } else {
        shot = await widget.photos.buildShot(
          draft: widget.draft,
          label: label,
          shelves: shelves,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(LabelShotResult(shot: shot));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not shelf this shot. Try a smaller image.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editing = widget.existing != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              editing ? 'Edit shot' : 'Shelf this shot',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Label is optional — skip and it stays in Unlabeled until you have time.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.62),
                  ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: widget.draft.bytes.isEmpty
                    ? ColoredBox(
                        color: scheme.surfaceContainer,
                        child: const Center(
                          child: Icon(Icons.image_outlined, size: 40),
                        ),
                      )
                    : Image.memory(
                        widget.draft.bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => ColoredBox(
                          color: scheme.surfaceContainer,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              autofocus: !editing,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_saving) _save(labelLater: false);
              },
              decoration: InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g. talent tree, login error, gym PR',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Shelves', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: _saving ? null : _createShelf,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('New shelf'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final shelf in _shelfOptions)
                  FilterChip(
                    label: Text(shelf),
                    selected: _selected.contains(shelf),
                    onSelected: _saving
                        ? null
                        : (v) {
                            setState(() {
                              if (v) {
                                _selected.add(shelf);
                              } else {
                                _selected.remove(shelf);
                                if (_selected.isEmpty) {
                                  _selected.add(ShelfCatalog.unlabeled);
                                }
                              }
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                if (!editing)
                  TextButton(
                    onPressed: _saving ? null : () => _save(labelLater: true),
                    child: const Text('Label later'),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saving ? null : () => _save(labelLater: false),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(editing ? 'Save' : 'Shelf it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
