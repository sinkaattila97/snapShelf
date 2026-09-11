import 'package:shared_preferences/shared_preferences.dart';

import '../models/shot.dart';

/// Built-in shelves plus user-created ones (local-only).
class ShelfStore {
  static const _customKey = 'snapshelf_custom_shelves_v1';

  List<String> _custom = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _custom = prefs.getStringList(_customKey) ?? [];
  }

  List<String> get custom => List.unmodifiable(_custom);

  List<String> get all {
    final merged = <String>[...ShelfCatalog.builtins];
    for (final name in _custom) {
      if (!merged.contains(name)) merged.add(name);
    }
    return merged;
  }

  Future<bool> addCustom(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return false;
    if (name.length > 32) return false;
    if (all.any((s) => s.toLowerCase() == name.toLowerCase())) {
      return false;
    }
    _custom = [..._custom, name];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customKey, _custom);
    return true;
  }
}
