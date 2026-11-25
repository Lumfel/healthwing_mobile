import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:healthwing_mobile/config/api_config.dart';
import 'package:healthwing_mobile/models/models.dart';
import 'package:healthwing_mobile/services/services.dart';

class _InMemoryAuthStorage extends AuthStorage {
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

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this.sentFrames);

  final List<String> sentFrames;
  final Completer<void> _done = Completer<void>();

  @override
  void add(dynamic data) {
    sentFrames.add(data.toString());
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final item in stream) {
      add(item);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;
}

class _FakeWebSocketChannel implements WebSocketChannel {
  _FakeWebSocketChannel() : _sink = _FakeWebSocketSink(<String>[]);

  final StreamController<dynamic> incoming =
      StreamController<dynamic>.broadcast();
  final _FakeWebSocketSink _sink;

  List<String> get sentFrames => _sink.sentFrames;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserRole strict 3-role RBAC', () {
    test('accepts owner, vet_staff, head_vet and rejects admin', () {
      expect(UserRole.fromWire('owner'), UserRole.owner);
      expect(UserRole.fromWire('vet_staff'), UserRole.vetStaff);
      expect(UserRole.fromWire('head_vet'), UserRole.headVet);
      expect(UserRole.tryFromWire('admin'), isNull);
      expect(() => UserRole.fromWire('admin'), throwsFormatException);
    });
  });

  group('ApiConfig', () {
    test('uses emulator defaults and derives WebSocket Origin', () {
      const cfg = ApiConfig();
      expect(cfg.baseUrl, 'http://10.0.2.2/HealthWing/api/mobile');
      expect(cfg.wsUrl, 'ws://10.0.2.2:8080');
      expect(cfg.resolveWsOrigin(), 'http://10.0.2.2:8080');
      expect(
        cfg.endpointUri('/auth.php', {'action': 'login'}).toString(),
        'http://10.0.2.2/HealthWing/api/mobile/auth.php?action=login',
      );
      expect(ApiConfig.loadingLabel, 'Loading...');
    });
  });

  group('ApiClient', () {
    test('implements all contract endpoints and error handling', () async {
      final storage = _InMemoryAuthStorage();
      final mockHttp = MockClient((request) async {
        final path = request.url.path;
        final action = request.url.queryParameters['action'];

        if (path.endsWith('/auth.php') && action == 'login') {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'tok.sig',
              'ws_token': 'wstok.sig',
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

        if (path.endsWith('/auth.php') && action == 'register') {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Owner account created successfully.',
              'user': {
                'id': 10,
                'username': 'owner2',
                'role': 'owner',
                'first_name': 'Jane',
                'last_name': 'Doe',
                'email': 'jane2@example.com',
                'contact': '09170000000',
                'prc_license_no': null,
                'status': 'Active',
              },
            }),
            201,
          );
        }

        expect(request.headers['Authorization'], 'Bearer tok.sig');

        if (path.endsWith('/owner_dashboard.php')) {
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
        }

        if (path.endsWith('/booking.php') && action == 'book') {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Appointment booked successfully.',
              'booking': {
                'schedule_id': 123,
                'owner_id': 1,
                'pet_id': 1,
                'pet_name': 'Mochi',
                'service': 'Wellness Care',
                'appointment_time': '2026-12-01 10:00:00',
                'end_time': '2026-12-01 10:30:00',
                'duration_minutes': 30,
                'status': 'Pending',
                'was_shifted': false,
                'requested_time': '2026-12-01 10:00:00',
                'veterinarian_id': 1,
                'veterinarian_name': 'Camille Reyes',
                'veterinarian_specialty': 'Wellness',
                'room_id': 1,
                'room_name': 'Main Consultation Room',
                'notes': '',
              },
            }),
            201,
          );
        }

        if (path.endsWith('/booking.php') && action == 'emergency') {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Emergency request #55 triaged at Queue Position #1.',
              'emergency': {
                'booking_id': 55,
                'owner_id': 1,
                'pet_id': 1,
                'status': 'Pending',
                'severity_level': 'Urgent',
                'triage': {
                  'booking_id': 55,
                  'queue_position': 1,
                  'priority_score': 78.5,
                  'severity_level': 'Urgent',
                  'assigned_room_name': 'Emergency Trauma Bay 1',
                  'assigned_vet_name': 'Dr. Camille Reyes',
                  'rationale': 'Queue #1',
                },
                'preempted_schedules': [],
              },
            }),
            201,
          );
        }

        if (path.endsWith('/receipt.php')) {
          expect(request.url.queryParameters['code'], 'RCPT-001');
          return http.Response(
            jsonEncode({
              'success': true,
              'receipt': {
                'block_id': 1,
                'block_index': 1,
                'receipt_code': 'RCPT-001',
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
                  'block_hash': 'hash1',
                  'prev_hash': 'hash0',
                  'merkle_root': 'root1',
                  'verified': true,
                },
                'attending_vet': {
                  'veterinarian_id': 1,
                  'name': 'Dr. Camille Reyes',
                  'prc_license_no': 'PRC-VET-004821',
                },
                'payload': {
                  'receipt_code': 'RCPT-001',
                  'owner_name': 'Jane Doe',
                  'pet_name': 'Mochi',
                  'service_summary': 'Wellness Care',
                  'amount': 500.0,
                  'notes': '',
                  'issued_by': 'Dr. Camille Reyes',
                },
              },
            }),
            200,
          );
        }

        if (path.endsWith('/vet_clinical.php') && action == 'overview') {
          return http.Response(
            jsonEncode({
              'success': true,
              'action': 'overview',
              'cipher': 'AES-256-GCM',
              'current_vet': {
                'veterinarian_id': 1,
                'name': 'Dr. Camille Reyes',
                'role': 'vet_staff',
                'prc_license_no': 'PRC-VET-004821',
              },
              'pets': [
                {
                  'Pet_ID': '1',
                  'Pet_Name': 'Mochi',
                  'OwnerFirstName': 'Jane',
                  'OwnerLastName': 'Doe',
                  'Description': 'Healthy',
                  'Past_Conditions': '',
                  'Current_Ailment': '',
                  'Current_Medications': 'Vitamins',
                  'CheckupCount': '2',
                  'LastCheckup': '2026-12-01',
                },
              ],
              'rooms': [
                {
                  'Room_ID': '1',
                  'Room_Name': 'Main Consultation Room',
                  'Room_Type': 'General',
                  'Status': 'idle',
                },
              ],
              'recent_checkups': [
                {
                  'Checkup_ID': '10',
                  'Pet_ID': '1',
                  'Pet_Name': 'Mochi',
                  'Veterinarian_ID': '1',
                  'Diagnosis': 'Routine check',
                  'Prescription': 'Vitamins',
                  'Notes': 'All clear',
                  'Checkup_Date': '2026-12-01',
                },
              ],
            }),
            200,
          );
        }

        if (path.endsWith('/vet_clinical.php') &&
            action == 'save_clinical_note') {
          return http.Response(
            jsonEncode({
              'success': true,
              'action': 'save_clinical_note',
              'message': 'Clinical note saved.',
              'checkup_id': 101,
              'pet_id': 1,
              'updated_pet_record': true,
              'cipher': 'AES-256-GCM',
            }),
            201,
          );
        }

        if (path.endsWith('/vet_clinical.php') && action == 'update_room') {
          return http.Response(
            jsonEncode({
              'success': true,
              'action': 'update_room',
              'message': 'Room status updated.',
              'room_id': 3,
              'status': 'ongoing',
              'updated': true,
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Too many requests.',
            'retry_after': 30,
          }),
          429,
        );
      });

      final client = ApiClient(authStorage: storage, httpClient: mockHttp);

      final loginRes = await client.login(
        const LoginRequest(username: 'owner1', password: 'password123'),
      );
      expect(loginRes.user.role, UserRole.owner);
      expect(await storage.readToken(), 'tok.sig');
      expect(await storage.readWsToken(), 'wstok.sig');

      final regRes = await client.register(
        const RegisterRequest(
          privacyConsent: true,
          firstName: 'Jane',
          lastName: 'Doe',
          email: 'jane2@example.com',
          username: 'owner2',
          password: 'password123',
          role: UserRole.owner,
        ),
      );
      expect(regRes.user.status, 'Active');

      final dash = await client.getOwnerDashboard();
      expect(dash.activePets.single.petName, 'Mochi');

      final booked = await client.bookAppointment(
        const BookAppointmentRequest(
          appointmentTime: '2026-12-01 10:00:00',
          petId: 1,
        ),
      );
      expect(booked.booking.scheduleId, 123);

      final emergency = await client.submitEmergency(
        const EmergencyBookingRequest(
          petId: 1,
          severityLevel: EmergencySeverity.urgent,
          details: 'Breathing difficulty',
        ),
      );
      expect(emergency.emergency.triage?.queuePosition, 1);

      final receipt = await client.verifyReceipt('RCPT-001');
      expect(receipt.receipt.chain.verified, isTrue);
      expect(receipt.receipt.attendingVet.prcLicenseNo, 'PRC-VET-004821');

      final overview = await client.getVetClinicalOverview();
      expect(overview.pets.single.petId, 1);
      expect(overview.rooms.single.parsedStatus, RoomStatus.idle);
      expect(overview.recentCheckups.single.checkupId, 10);

      final note = await client.saveClinicalNote(
        const SaveClinicalNoteRequest(
          petId: 1,
          diagnosis: 'Routine',
          prescription: 'Vitamins',
          updatePetRecord: true,
        ),
      );
      expect(note.checkupId, 101);

      final room = await client.setRoomStatus(
        const RoomStatusRequest(roomId: 3, status: RoomStatus.ongoing),
      );
      expect(room.parsedStatus, RoomStatus.ongoing);
    });
  });

  group('WsClient', () {
    test('authenticates with ws_token, subscribes, and streams events',
        () async {
      final fakeChannel = _FakeWebSocketChannel();
      Map<String, dynamic>? capturedHeaders;

      final wsClient = WsClient(
        channelFactory: (uri, headers) {
          capturedHeaders = headers;
          return fakeChannel;
        },
      );

      final chatFuture = wsClient.chatMessages.first;
      final triageFuture = wsClient.triageBroadcasts.first;

      await wsClient.connect(
        wsToken: 'ws_tok_123',
        initialChannels: const ['booking_55'],
      );

      expect(capturedHeaders?['Origin'], 'http://10.0.2.2:8080');
      expect(jsonDecode(fakeChannel.sentFrames.first), {
        'type': 'auth',
        'token': 'ws_tok_123',
      });

      fakeChannel.incoming.add(
        jsonEncode({
          'type': 'auth_ok',
          'role': 'owner',
          'user_id': 1,
          'expires_at': 1999999999,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(wsClient.isAuthenticated, isTrue);
      expect(jsonDecode(fakeChannel.sentFrames.last), {
        'type': 'subscribe',
        'channel_key': 'booking_55',
      });

      fakeChannel.incoming.add(
        jsonEncode({
          'type': 'chat_message',
          'channel_key': 'booking_55',
          'message': {
            'Channel_Key': 'booking_55',
            'Sender_Role': 'vet_staff',
            'Sender_ID': 2,
            'Sender_Name': 'Dr. Camille Reyes',
            'Message_Text': 'Please bring Mochi to Trauma Bay 1.',
            'Message_Type': 'text',
            'Created_At': '2026-12-01 09:05:00',
          },
        }),
      );
      fakeChannel.incoming.add(
        jsonEncode({
          'type': 'triage_broadcast',
          'timestamp': '2026-12-01T09:06:00+08:00',
          'summary': {'queue_length': 1},
        }),
      );

      final chat = await chatFuture;
      final triage = await triageFuture;
      expect(chat.message.senderName, 'Dr. Camille Reyes');
      expect(triage.summary, {'queue_length': 1});

      await wsClient.dispose();
      await fakeChannel.incoming.close();
    });
  });

  group('OfflineCache', () {
    test('persists and reads Pet Medical Cards and Rx records offline',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final cache = OfflineCache();

      const rx = OfflineRxRecord(
        checkupId: 10,
        petId: 1,
        petName: 'Mochi',
        checkupDate: '2026-12-01',
        diagnosis: 'Mild dermatitis',
        prescription: 'Medicated shampoo twice weekly',
        attendingVetName: 'Dr. Camille Reyes',
        attendingVetPrc: 'PRC-VET-004821',
      );
      const card = OfflinePetMedicalCard(
        pet: ActivePet(
          petId: 1,
          petName: 'Mochi',
          petType: 'Dog',
          species: 'Golden Retriever',
          age: 3,
          weightKg: 24.5,
          createdAt: '2026-01-01 10:00:00',
        ),
        currentMedications: 'Medicated shampoo',
        prescriptions: [rx],
        cachedAt: '2026-12-01T11:00:00Z',
      );

      await cache.savePetMedicalCards(1, const [card]);
      await cache.saveRxRecords(1, const [rx]);

      final loadedCard = await cache.readPetMedicalCard(1, 1);
      final loadedRx = await cache.readRxForPet(1, 1);

      expect(loadedCard?.pet.petName, 'Mochi');
      expect(loadedCard?.prescriptions.single.prescription, rx.prescription);
      expect(loadedRx.single.attendingVetPrc, 'PRC-VET-004821');
      expect(await cache.lastSavedAt(1), isNotNull);
    });
  });

  group('ScreenSecurity', () {
    test('invokes healthwing/security setSecureScreen method channel',
        () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ScreenSecurity.defaultChannel, (call) async {
        calls.add(call);
        final args = call.arguments as Map<dynamic, dynamic>;
        return args['enabled'] as bool;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ScreenSecurity.defaultChannel, null);
      });

      final security = ScreenSecurity();
      expect(await security.setSecureScreen(true), isTrue);
      expect(security.isSecure, isTrue);
      expect(await security.setSecureScreen(false), isFalse);
      expect(security.isSecure, isFalse);

      expect(calls.length, 2);
      expect(calls[0].method, 'setSecureScreen');
      expect(calls[0].arguments, {'enabled': true});
      expect(calls[1].arguments, {'enabled': false});
    });
  });
}
