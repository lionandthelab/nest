import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NestCache {
  NestCache._();

  static SharedPreferences? _prefs;
  static const int _schemaVersion = 1;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String _key(String userId, String homeschoolId, String collection) =>
      'nest.cache.$userId.$homeschoolId.$collection';

  static String _metaKey(String userId, String homeschoolId) =>
      'nest.cache.$userId.$homeschoolId._meta';

  /// Save a list of items to local cache.
  static Future<void> saveCollection<T>({
    required String userId,
    required String homeschoolId,
    required String collection,
    required List<T> items,
    required Map<String, dynamic> Function(T) toMap,
  }) async {
    final prefs = _prefs;
    if (prefs == null) return;

    final envelope = jsonEncode({
      'v': _schemaVersion,
      'ts': DateTime.now().toUtc().toIso8601String(),
      'data': items.map(toMap).toList(),
    });

    await prefs.setString(_key(userId, homeschoolId, collection), envelope);
  }

  /// Load a cached collection. Returns null if not found or schema mismatch.
  static List<T>? loadCollection<T>({
    required String userId,
    required String homeschoolId,
    required String collection,
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    final prefs = _prefs;
    if (prefs == null) return null;

    final raw = prefs.getString(_key(userId, homeschoolId, collection));
    if (raw == null) return null;

    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      if (envelope['v'] != _schemaVersion) return null;

      final data = envelope['data'] as List;
      return data
          .cast<Map<String, dynamic>>()
          .map(fromMap)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Save a map (e.g. familyGuardianUserIdsByFamily) to local cache.
  static Future<void> saveStringListMap({
    required String userId,
    required String homeschoolId,
    required String collection,
    required Map<String, List<String>> data,
  }) async {
    final prefs = _prefs;
    if (prefs == null) return;

    final envelope = jsonEncode({
      'v': _schemaVersion,
      'ts': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    });

    await prefs.setString(_key(userId, homeschoolId, collection), envelope);
  }

  /// Load a cached string-list map. Returns null if not found.
  static Map<String, List<String>>? loadStringListMap({
    required String userId,
    required String homeschoolId,
    required String collection,
  }) {
    final prefs = _prefs;
    if (prefs == null) return null;

    final raw = prefs.getString(_key(userId, homeschoolId, collection));
    if (raw == null) return null;

    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      if (envelope['v'] != _schemaVersion) return null;

      final data = envelope['data'] as Map<String, dynamic>;
      return data.map(
        (key, value) => MapEntry(key, (value as List).cast<String>()),
      );
    } catch (_) {
      return null;
    }
  }

  /// Save controller metadata (selected IDs, role, etc.).
  static Future<void> saveMeta({
    required String userId,
    required String homeschoolId,
    String? selectedTermId,
    String? selectedClassGroupId,
    String? currentRole,
    String? parentViewTargetUserId,
    String? teacherViewTargetProfileId,
  }) async {
    final prefs = _prefs;
    if (prefs == null) return;

    final meta = jsonEncode({
      'v': _schemaVersion,
      'homeschoolId': homeschoolId,
      'selectedTermId': selectedTermId,
      'selectedClassGroupId': selectedClassGroupId,
      'currentRole': currentRole,
      'parentViewTargetUserId': parentViewTargetUserId,
      'teacherViewTargetProfileId': teacherViewTargetProfileId,
    });

    await prefs.setString(_metaKey(userId, homeschoolId), meta);
  }

  /// Load cached metadata. Returns null if not found.
  static Map<String, dynamic>? loadMeta({
    required String userId,
    required String homeschoolId,
  }) {
    final prefs = _prefs;
    if (prefs == null) return null;

    final raw = prefs.getString(_metaKey(userId, homeschoolId));
    if (raw == null) return null;

    try {
      final meta = jsonDecode(raw) as Map<String, dynamic>;
      if (meta['v'] != _schemaVersion) return null;
      return meta;
    } catch (_) {
      return null;
    }
  }

  /// Save the last selected homeschool ID for a user.
  static Future<void> saveLastHomeschoolId({
    required String userId,
    required String homeschoolId,
  }) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString('nest.cache.$userId._lastHomeschool', homeschoolId);
  }

  /// Load the last selected homeschool ID for a user.
  static String? loadLastHomeschoolId({required String userId}) {
    final prefs = _prefs;
    if (prefs == null) return null;
    return prefs.getString('nest.cache.$userId._lastHomeschool');
  }

  /// Save the selected child ID for a parent user.
  static Future<void> saveSelectedChildId({
    required String userId,
    required String childId,
  }) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString('nest.cache.$userId._selectedChild', childId);
  }

  /// Load the selected child ID for a parent user.
  static String? loadSelectedChildId({required String userId}) {
    final prefs = _prefs;
    if (prefs == null) return null;
    return prefs.getString('nest.cache.$userId._selectedChild');
  }

  /// Clear all cache (e.g. on logout).
  static Future<void> clearAll() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final keys = prefs.getKeys().where((k) => k.startsWith('nest.cache.'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
