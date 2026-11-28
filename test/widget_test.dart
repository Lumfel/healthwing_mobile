import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthwing_mobile/main.dart';
import 'package:healthwing_mobile/models/models.dart';
import 'package:healthwing_mobile/screens/screens.dart';
import 'package:healthwing_mobile/services/services.dart';

class _MemoryAuthStorage extends AuthStorage {
  _MemoryAuthStorage([this._session]);

  AuthSession? _session;

  @override
  Future<void> saveSession(AuthSession session) async {
    _session = session;
  }

  @override
  Future<String?> readToken() async => _session?.token;

  @override
  Future<String?> readWsToken() async => _session?.wsToken;

  @override
  Future<int?> readUserId() async => _session?.userId;

  @override
  Future<String?> readUsername() async => _session?.username;

  @override
  Future<UserRole?> readRole() async => _session?.role;

  @override
  Future<String?> readPrcLicenseNo() async => _session?.prcLicenseNo;

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> clear() async {
    _session = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues(<String, String>{});

  Future<void> setMobileViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(408, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('unauthenticated startup routes to LoginScreen and owner login routes to OwnerHomeScreen', (tester) async {
    await setMobileViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final authStorage = _MemoryAuthStorage();
    final mockHttp = MockClient((request) async {
      if (request.url.path.endsWith('/auth.php') &&
          request.url.queryParameters['action'] == 'login') {
        return http.Response(
          jsonEncode({
            'success': true,
            'token': 'owner.jwt',
            'ws_token': 'owner.ws',
            'user': {
              'id': 1,
              'username': 'owner1',
              'role': 'owner',
              'first_name': 'Jane',
              'last_name': 'Doe',
              'email': 'jane@example.com',
              'contact': '09170000000',
              'prc_license_no': null,
            },
          }),
          200,
        );
      }

      return http.Response(
        jsonEncode({
          'success': true,
          'owner': {
            'id': 1,
            'username': 'owner1',
            'first_name': 'Jane',
            'last_name': 'Doe',
            'email': 'jane@example.com',
            'contact': '09170000000',
          },
          'active_pets': [
            {
              'pet_id': 1,
              'pet_name': 'Mochi',
              'pet_type': 'Dog',
              'species': 'Golden Retriever',
              'age': 3,
              'weight_kg': 24.5,
              'photo_path': null,
              'created_at': '2026-01-01 10:00:00',
            },
          ],
          'upcoming_schedules': [],
          'active_emergency_triage_status': [],
          'active_receipt_blocks': [],
          'meta': {
            'purged_expired_receipts': 0,
            'server_time': '2026-12-01 11:00:00',
          },
        }),
        200,
      );
    });

    final deps = AppDependencies(
      authStorage: authStorage,
      apiClient: ApiClient(authStorage: authStorage, httpClient: mockHttp),
    );

    await tester.pumpWidget(HealthWingApp(dependencies: deps));
    await tester.pumpAndSettle();

    expect(find.text('Account Sign In'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_username_field')),
      'owner1',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Jane'), findsOneWidget);
    expect(find.byKey(const Key('owner_quick_sos_button')), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);
  });

  testWidgets('RegisterScreen requires RA 10173 consent and shows PRC field for Vet Staff', (tester) async {
    await setMobileViewport(tester);
    final authStorage = _MemoryAuthStorage();
    final deps = AppDependencies(
      authStorage: authStorage,
      apiClient: ApiClient(
        authStorage: authStorage,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen(dependencies: deps)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('register_prc_license')), findsNothing);

    await tester.tap(find.text('Vet Staff'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('register_prc_license')), findsOneWidget);
    expect(find.byKey(const Key('register_privacy_consent')), findsOneWidget);
  });

  testWidgets('ReceiptViewerScreen toggles ScreenSecurity FLAG_SECURE on init and dispose', (tester) async {
    await setMobileViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final secureCalls = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenSecurity.defaultChannel, (call) async {
      final args = call.arguments as Map<dynamic, dynamic>;
      final enabled = args['enabled'] as bool;
      secureCalls.add(enabled);
      return enabled;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ScreenSecurity.defaultChannel, null);
    });

    final authStorage = _MemoryAuthStorage(
      const AuthSession(
        token: 'tok.sig',
        wsToken: 'ws.sig',
        userId: 1,
        username: 'owner1',
        role: UserRole.owner,
      ),
    );
    final mockHttp = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'receipt': {
            'block_id': 1,
            'block_index': 1,
            'receipt_code': 'RCPT-900',
            'owner_id': 1,
            'reference_type': 'schedule',
            'reference_id': 10,
            'service_summary': 'Wellness Care',
            'amount': 500.0,
            'currency': 'PHP',
            'status': 'ACTIVE',
            'issued_by': 'Dr. Camille Reyes',
            'created_at': '2026-12-01 10:30:00',
            'expires_at': '2027-12-01 10:30:00',
            'chain': {
              'block_hash': 'sha256-block',
              'prev_hash': 'sha256-prev',
              'merkle_root': 'sha256-merkle',
              'verified': true,
            },
            'attending_vet': {
              'veterinarian_id': 1,
              'name': 'Dr. Camille Reyes',
              'prc_license_no': 'PRC-VET-004821',
            },
            'payload': {
              'receipt_code': 'RCPT-900',
              'owner_name': 'Jane Doe',
              'pet_name': 'Mochi',
              'service_summary': 'Wellness Care',
              'amount': 500.0,
              'notes': 'All clear',
              'issued_by': 'Dr. Camille Reyes',
            },
          },
        }),
        200,
      );
    });

    final deps = AppDependencies(
      authStorage: authStorage,
      apiClient: ApiClient(authStorage: authStorage, httpClient: mockHttp),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptViewerScreen(
          dependencies: deps,
          args: const ReceiptViewerRouteArgs(initialReceiptCode: 'RCPT-900'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(secureCalls, <bool>[true]);
    expect(find.text('CHAIN VERIFIED'), findsOneWidget);
    expect(find.text('PRC-VET-004821'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(secureCalls, <bool>[true, false]);
  });

  testWidgets('VetClinicalScreen displays HTTP 403 boundary message on unassigned room toggle', (tester) async {
    await setMobileViewport(tester);

    final authStorage = _MemoryAuthStorage(
      const AuthSession(
        token: 'vet.jwt',
        wsToken: '',
        userId: 2,
        username: 'vetstaff2',
        role: UserRole.vetStaff,
        prcLicenseNo: 'PRC-VET-009999',
      ),
    );

    final mockHttp = MockClient((request) async {
      final action = request.url.queryParameters['action'];
      if (action == 'overview') {
        return http.Response(
          jsonEncode({
            'success': true,
            'action': 'overview',
            'cipher': 'AES-256-GCM',
            'current_vet': {
              'veterinarian_id': 2,
              'name': 'Dr. Marco Santos',
              'role': 'vet_staff',
              'prc_license_no': 'PRC-VET-009999',
            },
            'pets': [],
            'rooms': [
              {
                'Room_ID': 3,
                'Room_Name': 'Emergency Trauma Bay 1',
                'Room_Type': 'Emergency',
                'Status': 'idle',
              },
            ],
            'recent_checkups': [],
          }),
          200,
        );
      }

      return http.Response(
        jsonEncode({
          'success': false,
          'error': 'forbidden',
          'message':
              'Forbidden: Only a Head Veterinarian or the veterinarian assigned to this room may change its status.',
        }),
        403,
      );
    });

    final deps = AppDependencies(
      authStorage: authStorage,
      apiClient: ApiClient(authStorage: authStorage, httpClient: mockHttp),
    );

    await tester.pumpWidget(
      MaterialApp(home: VetClinicalScreen(dependencies: deps)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rooms'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Room Permission Restricted (HTTP 403)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Only a Head Veterinarian'),
      findsOneWidget,
    );
  });

  testWidgets('PetCardScreen falls back to OfflineCache when offline and BookingScreen handles 409 conflict', (tester) async {
    await setMobileViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final cache = OfflineCache();
    await cache.savePetMedicalCards(1, const [
      OfflinePetMedicalCard(
        pet: ActivePet(
          petId: 1,
          petName: 'Luna',
          petType: 'Cat',
          species: 'Persian',
          age: 2,
          weightKg: 4.1,
          createdAt: '2026-01-01 10:00:00',
        ),
        currentMedications: 'Oral probiotic once daily',
        prescriptions: [
          OfflineRxRecord(
            checkupId: 77,
            petId: 1,
            petName: 'Luna',
            checkupDate: '2026-11-20',
            diagnosis: 'Mild gastritis',
            prescription: 'Oral probiotic once daily for 7 days',
            attendingVetName: 'Dr. Camille Reyes',
            attendingVetPrc: 'PRC-VET-004821',
          ),
        ],
        cachedAt: '2026-11-20T10:00:00Z',
      ),
    ]);

    final authStorage = _MemoryAuthStorage(
      const AuthSession(
        token: 'owner.jwt',
        wsToken: '',
        userId: 1,
        username: 'owner1',
        role: UserRole.owner,
      ),
    );

    final offlineHttp = MockClient((request) async {
      if (request.url.path.endsWith('/booking.php')) {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'booking_failed',
            'message':
                'Selected appointment slot was just taken. Please pick another time.',
          }),
          409,
        );
      }
      throw http.ClientException('Connection refused');
    });

    final deps = AppDependencies(
      authStorage: authStorage,
      offlineCache: cache,
      apiClient: ApiClient(authStorage: authStorage, httpClient: offlineHttp),
    );

    await tester.pumpWidget(
      MaterialApp(home: PetCardScreen(dependencies: deps)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline Cache'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);
    expect(
      find.textContaining('Oral probiotic once daily for 7 days'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BookingScreen(
          dependencies: deps,
          initialPets: const [
            ActivePet(
              petId: 1,
              petName: 'Luna',
              petType: 'Cat',
              createdAt: '2026-01-01 10:00:00',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('booking_submit_button')));
    await tester.tap(find.byKey(const Key('booking_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('booking_conflict_banner')), findsOneWidget);
    expect(
      find.textContaining('Selected appointment slot was just taken'),
      findsOneWidget,
    );
  });
}
