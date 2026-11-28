import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_models.dart';
import '../models/owner_dashboard_models.dart';

/// Encrypted offline cache for Pet Medical Cards, Rx records, and owner
/// dashboard snapshots.
///
/// Decrypted blockchain receipts are intentionally excluded. Legacy plaintext
/// cache keys are removed during secure cache writes and sign-out cleanup.
class OfflineCache {
  OfflineCache({
    FlutterSecureStorage? storage,
    this._preferences,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyPrefix = 'hw_offline_';
  static const String _cardsPrefix = '${_keyPrefix}pet_cards_owner_';
  static const String _rxPrefix = '${_keyPrefix}rx_owner_';
  static const String _dashboardPrefix = '${_keyPrefix}owner_dashboard_';
  static const String _savedAtPrefix = '${_keyPrefix}saved_at_owner_';

  final FlutterSecureStorage _storage;
  SharedPreferences? _preferences;

  Future<SharedPreferences> _legacyPrefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  /// Saves all Pet Medical Cards for [ownerId] for offline viewing.
  Future<void> savePetMedicalCards(
    int ownerId,
    List<OfflinePetMedicalCard> cards,
  ) async {
    final encoded = jsonEncode(cards.map((card) => card.toJson()).toList());
    await _storage.write(key: '$_cardsPrefix$ownerId', value: encoded);
    await _markSavedAt(ownerId);
    await _removeLegacyOwnerKeys(ownerId);
  }

  /// Inserts or replaces a single Pet Medical Card for [ownerId].
  Future<void> upsertPetMedicalCard(
    int ownerId,
    OfflinePetMedicalCard card,
  ) async {
    final existing = await readPetMedicalCards(ownerId);
    final next = <OfflinePetMedicalCard>[
      for (final item in existing)
        if (item.pet.petId != card.pet.petId) item,
      card,
    ];
    await savePetMedicalCards(ownerId, next);
  }

  /// Reads all cached Pet Medical Cards for [ownerId].
  Future<List<OfflinePetMedicalCard>> readPetMedicalCards(int ownerId) async {
    final raw = await _storage.read(key: '$_cardsPrefix$ownerId');
    if (raw == null || raw.trim().isEmpty) {
      return const <OfflinePetMedicalCard>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <OfflinePetMedicalCard>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => OfflinePetMedicalCard.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return const <OfflinePetMedicalCard>[];
    }
  }

  /// Reads a single cached Pet Medical Card by [petId] for [ownerId].
  Future<OfflinePetMedicalCard?> readPetMedicalCard(
    int ownerId,
    int petId,
  ) async {
    final cards = await readPetMedicalCards(ownerId);
    for (final card in cards) {
      if (card.pet.petId == petId) {
        return card;
      }
    }
    return null;
  }

  /// Saves prescription (Rx) records for [ownerId] for offline viewing.
  Future<void> saveRxRecords(
    int ownerId,
    List<OfflineRxRecord> records,
  ) async {
    final encoded = jsonEncode(records.map((item) => item.toJson()).toList());
    await _storage.write(key: '$_rxPrefix$ownerId', value: encoded);
    await _markSavedAt(ownerId);
    await _removeLegacyOwnerKeys(ownerId);
  }

  /// Reads all cached prescription (Rx) records for [ownerId].
  Future<List<OfflineRxRecord>> readRxRecords(int ownerId) async {
    final raw = await _storage.read(key: '$_rxPrefix$ownerId');
    if (raw == null || raw.trim().isEmpty) {
      return const <OfflineRxRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <OfflineRxRecord>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => OfflineRxRecord.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return const <OfflineRxRecord>[];
    }
  }

  /// Reads cached prescription (Rx) records filtered to a specific [petId].
  Future<List<OfflineRxRecord>> readRxForPet(int ownerId, int petId) async {
    final all = await readRxRecords(ownerId);
    return all.where((item) => item.petId == petId).toList(growable: false);
  }

  /// Saves the latest [OwnerDashboardResponse] snapshot for [ownerId] and
  /// ensures each active pet has a baseline offline medical card entry.
  Future<void> saveOwnerDashboard(
    int ownerId,
    OwnerDashboardResponse dashboard,
  ) async {
    await _storage.write(
      key: '$_dashboardPrefix$ownerId',
      value: jsonEncode(dashboard.toJson()),
    );

    final existingCards = await readPetMedicalCards(ownerId);
    final byPetId = <int, OfflinePetMedicalCard>{
      for (final card in existingCards) card.pet.petId: card,
    };
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final mergedCards = dashboard.activePets.map((pet) {
      final previous = byPetId[pet.petId];
      return OfflinePetMedicalCard(
        pet: pet,
        description: previous?.description,
        pastConditions: previous?.pastConditions,
        currentAilment: previous?.currentAilment,
        currentMedications: previous?.currentMedications,
        prescriptions: previous?.prescriptions ?? const <OfflineRxRecord>[],
        cachedAt: nowIso,
      );
    }).toList(growable: false);

    await _storage.write(
      key: '$_cardsPrefix$ownerId',
      value: jsonEncode(mergedCards.map((c) => c.toJson()).toList()),
    );
    await _markSavedAt(ownerId);
    await _removeLegacyOwnerKeys(ownerId);
  }

  /// Reads the cached [OwnerDashboardResponse] for [ownerId], or null if none.
  Future<OwnerDashboardResponse?> readOwnerDashboard(int ownerId) async {
    final raw = await _storage.read(key: '$_dashboardPrefix$ownerId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return OwnerDashboardResponse.fromJson(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } on FormatException {
      return null;
    }
  }

  /// Returns the UTC ISO-8601 timestamp when [ownerId]'s cache was last saved.
  Future<String?> lastSavedAt(int ownerId) async {
    return _storage.read(key: '$_savedAtPrefix$ownerId');
  }

  /// Removes cached Pet Medical Cards, Rx records, and dashboard for [ownerId].
  Future<void> clearOwnerCache(int ownerId) async {
    await Future.wait([
      _storage.delete(key: '$_cardsPrefix$ownerId'),
      _storage.delete(key: '$_rxPrefix$ownerId'),
      _storage.delete(key: '$_dashboardPrefix$ownerId'),
      _storage.delete(key: '$_savedAtPrefix$ownerId'),
    ]);
    await _removeLegacyOwnerKeys(ownerId);
  }

  /// Removes all HealthWing offline cache entries from secure storage.
  Future<void> clearAll() async {
    final values = await _storage.readAll();
    await Future.wait(
      values.keys.toList()
          .where((key) => key.startsWith(_keyPrefix))
          .map((key) => _storage.delete(key: key)),
    );

    final prefs = await _legacyPrefs();
    final legacyKeys =
        prefs.getKeys().where((key) => key.startsWith(_keyPrefix));
    await Future.wait(legacyKeys.map(prefs.remove));
  }

  Future<void> _markSavedAt(int ownerId) {
    return _storage.write(
      key: '$_savedAtPrefix$ownerId',
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> _removeLegacyOwnerKeys(int ownerId) async {
    final prefs = await _legacyPrefs();
    await Future.wait([
      prefs.remove('$_cardsPrefix$ownerId'),
      prefs.remove('$_rxPrefix$ownerId'),
      prefs.remove('$_dashboardPrefix$ownerId'),
      prefs.remove('$_savedAtPrefix$ownerId'),
    ]);
  }
}
