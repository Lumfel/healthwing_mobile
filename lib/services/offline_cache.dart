import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_models.dart';
import '../models/owner_dashboard_models.dart';
import '../models/receipt_models.dart';

/// Offline `shared_preferences` cache for Pet Medical Cards, Rx records,
/// owner dashboard snapshots, and verified receipts.
class OfflineCache {
  OfflineCache({this._preferences});

  static const String _keyPrefix = 'hw_offline_';
  static const String _cardsPrefix = '${_keyPrefix}pet_cards_owner_';
  static const String _rxPrefix = '${_keyPrefix}rx_owner_';
  static const String _dashboardPrefix = '${_keyPrefix}owner_dashboard_';
  static const String _receiptPrefix = '${_keyPrefix}receipt_';
  static const String _savedAtPrefix = '${_keyPrefix}saved_at_owner_';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  /// Saves all Pet Medical Cards for [ownerId] for offline viewing.
  Future<void> savePetMedicalCards(
    int ownerId,
    List<OfflinePetMedicalCard> cards,
  ) async {
    final prefs = await _prefs();
    final encoded = jsonEncode(cards.map((card) => card.toJson()).toList());
    await prefs.setString('$_cardsPrefix$ownerId', encoded);
    await _markSavedAt(prefs, ownerId);
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
    final prefs = await _prefs();
    final raw = prefs.getString('$_cardsPrefix$ownerId');
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
    final prefs = await _prefs();
    final encoded = jsonEncode(records.map((item) => item.toJson()).toList());
    await prefs.setString('$_rxPrefix$ownerId', encoded);
    await _markSavedAt(prefs, ownerId);
  }

  /// Reads all cached prescription (Rx) records for [ownerId].
  Future<List<OfflineRxRecord>> readRxRecords(int ownerId) async {
    final prefs = await _prefs();
    final raw = prefs.getString('$_rxPrefix$ownerId');
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
    final prefs = await _prefs();
    await prefs.setString(
      '$_dashboardPrefix$ownerId',
      jsonEncode(dashboard.toJson()),
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

    await prefs.setString(
      '$_cardsPrefix$ownerId',
      jsonEncode(mergedCards.map((c) => c.toJson()).toList()),
    );
    await _markSavedAt(prefs, ownerId);
  }

  /// Reads the cached [OwnerDashboardResponse] for [ownerId], or null if none.
  Future<OwnerDashboardResponse?> readOwnerDashboard(int ownerId) async {
    final prefs = await _prefs();
    final raw = prefs.getString('$_dashboardPrefix$ownerId');
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

  /// Caches a decrypted [VerifiedReceipt] by its `receipt_code`.
  Future<void> saveVerifiedReceipt(VerifiedReceipt receipt) async {
    final prefs = await _prefs();
    final key = '$_receiptPrefix${receipt.receiptCode}';
    await prefs.setString(key, jsonEncode(receipt.toJson()));
  }

  /// Reads a cached [VerifiedReceipt] by [receiptCode], or null if absent.
  Future<VerifiedReceipt?> readVerifiedReceipt(String receiptCode) async {
    final prefs = await _prefs();
    final raw = prefs.getString('$_receiptPrefix${receiptCode.trim()}');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return VerifiedReceipt.fromJson(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } on FormatException {
      return null;
    }
  }

  /// Returns the UTC ISO-8601 timestamp when [ownerId]'s cache was last saved.
  Future<String?> lastSavedAt(int ownerId) async {
    final prefs = await _prefs();
    return prefs.getString('$_savedAtPrefix$ownerId');
  }

  /// Removes cached Pet Medical Cards, Rx records, and dashboard for [ownerId].
  Future<void> clearOwnerCache(int ownerId) async {
    final prefs = await _prefs();
    await Future.wait([
      prefs.remove('$_cardsPrefix$ownerId'),
      prefs.remove('$_rxPrefix$ownerId'),
      prefs.remove('$_dashboardPrefix$ownerId'),
      prefs.remove('$_savedAtPrefix$ownerId'),
    ]);
  }

  /// Removes all HealthWing offline cache entries from `shared_preferences`.
  Future<void> clearAll() async {
    final prefs = await _prefs();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    await Future.wait(keys.map(prefs.remove));
  }

  Future<void> _markSavedAt(SharedPreferences prefs, int ownerId) {
    return prefs.setString(
      '$_savedAtPrefix$ownerId',
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}
