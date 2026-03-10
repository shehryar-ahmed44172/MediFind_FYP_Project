/// MediFind - PostgreSQL Database Test Script
/// 
/// ⚠️  FOR LOCAL TESTING ONLY - DO NOT USE IN PRODUCTION  ⚠️
/// 
/// Run with: dart run test/db_test.dart

import 'package:postgres/postgres.dart';

// ============================================================
//   *** DATABASE CONNECTION CONFIG ***
// ============================================================
const String DB_HOST = 'localhost';
const int    DB_PORT = 5432;
const String DB_NAME = 'MediFind_Mobile_Application';
const String DB_USER = 'postgres';
const String DB_PASS = '44172';
// ============================================================

Future<void> main() async {
  print('\n🏥 MediFind - PostgreSQL Database Test Script');
  print('=' * 50);

  final conn = await Connection.open(
    Endpoint(
      host: DB_HOST,
      port: DB_PORT,
      database: DB_NAME,
      username: DB_USER,
      password: DB_PASS,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
  print('✅ Connected to PostgreSQL: $DB_NAME\n');

  try {
    await _testUsersTable(conn);
    await _testMedicalProfilesTable(conn);
    await _testEmergenciesTable(conn);
    await _testRespondersTracking(conn);
    await _testAnalyticsQueries(conn);
    print('\n🎉 ALL TESTS PASSED SUCCESSFULLY!');
  } catch (e, st) {
    print('\n❌ TEST FAILED: $e');
    print(st);
  } finally {
    await conn.close();
    print('🔌 Connection closed.');
  }
}

// ============================================================
// 1. USERS TABLE — column names are lowercase in this DB
// ============================================================
Future<void> _testUsersTable(Connection conn) async {
  print('--- Testing `users` table ---');

  await conn.execute(
    'INSERT INTO users (id, fullname, email, phonenumber, role) '
    'VALUES (\$1, \$2, \$3, \$4, \$5) ON CONFLICT (id) DO NOTHING',
    parameters: ['usr_test_patient', 'Test Patient', 'patient@medifind.test', '+10000000001', 'PATIENT'],
  );
  print('  ✅ Inserted test Patient');

  await conn.execute(
    'INSERT INTO users (id, fullname, email, phonenumber, role) '
    'VALUES (\$1, \$2, \$3, \$4, \$5) ON CONFLICT (id) DO NOTHING',
    parameters: ['usr_test_responder', 'Test Responder', 'responder@medifind.test', '+10000000002', 'RESPONDER'],
  );
  print('  ✅ Inserted test Responder');

  await conn.execute(
    'INSERT INTO users (id, fullname, email, phonenumber, role) '
    'VALUES (\$1, \$2, \$3, \$4, \$5) ON CONFLICT (id) DO NOTHING',
    parameters: ['usr_test_caregiver', 'Test Caregiver', 'caregiver@medifind.test', '+10000000003', 'CAREGIVER'],
  );
  print('  ✅ Inserted test Caregiver');

  final result = await conn.execute(
    'SELECT id, fullname, email, role FROM users ORDER BY createdat DESC LIMIT 5',
  );
  print('\n  👤 Recent Users in DB:');
  for (final row in result) {
    print('     [${row[3]}] ${row[1]} (${row[2]})');
  }
  print('');
}

// ============================================================
// 2. MEDICAL PROFILES TABLE
// ============================================================
Future<void> _testMedicalProfilesTable(Connection conn) async {
  print('--- Testing `medical_profiles` table ---');

  await conn.execute(
    'INSERT INTO medical_profiles (id, userid, bloodtype, chronicdiseases, allergies, medications) '
    'VALUES (\$1, \$2, \$3, \$4::jsonb, \$5::jsonb, \$6::jsonb) ON CONFLICT (id) DO NOTHING',
    parameters: [
      'med_test_001', 'usr_test_patient', 'O+',
      '["Type 2 Diabetes", "Hypertension"]',
      '[{"substance": "Penicillin", "severity": "High"}]',
      '[{"name": "Metformin", "dosage": "500mg"}]',
    ],
  );
  print('  ✅ Inserted medical profile for test patient');

  final result = await conn.execute(
    'SELECT mp.bloodtype, mp.allergies, u.fullname FROM medical_profiles mp '
    'JOIN users u ON u.id = mp.userid WHERE mp.userid = \$1',
    parameters: ['usr_test_patient'],
  );
  if (result.isNotEmpty) {
    print('  💊 Profile: Blood Type=${result[0][0]}, Patient=${result[0][2]}');
  }
  print('');
}

// ============================================================
// 3. EMERGENCIES TABLE
// ============================================================
Future<void> _testEmergenciesTable(Connection conn) async {
  print('--- Testing `emergencies` table ---');

  await conn.execute(
    'INSERT INTO emergencies (id, userid, status, emergencytype, latitude, longitude) '
    'VALUES (\$1, \$2, \$3, \$4, \$5, \$6) ON CONFLICT (id) DO NOTHING',
    parameters: ['emg_test_001', 'usr_test_patient', 'TRIGGERED', 'CHEST_PAIN', 34.052235, -118.243683],
  );
  print('  ✅ Created test emergency (TRIGGERED)');

  // Assign the responder
  await conn.execute(
    'UPDATE emergencies SET status=\$1, assignedresponderid=\$2, estimatedarrivaltime=\$3 WHERE id=\$4',
    parameters: ['ASSIGNED', 'usr_test_responder', 5, 'emg_test_001'],
  );
  print('  ✅ Assigned test responder');

  final result = await conn.execute(
    'SELECT e.id, e.status, e.emergencytype, u.fullname AS responder '
    'FROM emergencies e LEFT JOIN users u ON u.id = e.assignedresponderid WHERE e.id = \$1',
    parameters: ['emg_test_001'],
  );
  if (result.isNotEmpty) {
    final row = result[0];
    print('  🚨 Emergency: status=${row[1]}, type=${row[2]}, responder=${row[3]}');
  }
  print('');
}

// ============================================================
// 4. RESPONDERS TRACKING TABLE
// ============================================================
Future<void> _testRespondersTracking(Connection conn) async {
  print('--- Testing `responders_tracking` table ---');

  await conn.execute(
    'INSERT INTO responders_tracking (id, fullname, phonenumber, latitude, longitude) '
    'VALUES (\$1, \$2, \$3, \$4, \$5) ON CONFLICT (id) DO NOTHING',
    parameters: ['usr_test_responder', 'Test Responder', '+10000000002', 34.0500, -118.2400],
  );
  print('  ✅ Inserted responder GPS location');

  final result = await conn.execute(
    '''SELECT id, fullname,
      6371 * acos(
        cos(radians(34.0522)) * cos(radians(latitude)) * cos(radians(longitude) - radians(-118.2436))
        + sin(radians(34.0522)) * sin(radians(latitude))
      ) AS distance_km
    FROM responders_tracking WHERE isactive = true AND status = \'AVAILABLE\'
    ORDER BY distance_km ASC LIMIT 1''',
  );
  if (result.isNotEmpty) {
    final row = result[0];
    print('  📍 Nearest responder=${row[1]}, distance=${(row[2] as double).toStringAsFixed(2)} km');
  }
  print('');
}

// ============================================================
// 5. ANALYTICS / CROSS-TABLE QUERIES
// ============================================================
Future<void> _testAnalyticsQueries(Connection conn) async {
  print('--- Testing Analytics Queries ---');

  final result = await conn.execute(
    'SELECT emergencytype, COUNT(*) FROM emergencies '
    'WHERE status IN (\'TRIGGERED\', \'ASSIGNED\') GROUP BY emergencytype',
  );
  print('  📊 Active emergencies by type:');
  for (final row in result) {
    print('     ${row[0]}: ${row[1]}');
  }
  print('');
}
