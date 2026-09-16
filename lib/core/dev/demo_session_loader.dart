import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/local/local_data_source.dart';

/// Debug/profile-only helper for walkthroughs and screenshots on an emulator.
///
/// If `demo_session.json` exists in the app documents directory, its session
/// (`token`, `refreshToken`, `userId`, `role`) is stored as if the user had
/// logged in, and the file is deleted. Release builds never read the file.
/// (Profile builds are allowed so screenshots reflect real AOT performance.)
///
///   adb push demo_session.json /data/local/tmp/
///   adb shell run-as com.example.medifind_mobile_application cp /data/local/tmp/demo_session.json app_flutter/
///   (profile builds) adb push demo_session.json /sdcard/Android/data/com.example.medifind_mobile_application/files/
class DemoSessionLoader {
  static Future<void> loadIfPresent() async {
    if (kReleaseMode) return;
    try {
      // Documents dir (debug builds, via run-as) or the app's external files dir
      // (profile builds are not debuggable, but adb can write there).
      final candidates = <File>[
        File('${(await getApplicationDocumentsDirectory()).path}/demo_session.json'),
        if (Platform.isAndroid && await getExternalStorageDirectory() != null)
          File('${(await getExternalStorageDirectory())!.path}/demo_session.json'),
      ];
      File? file;
      for (final candidate in candidates) {
        if (await candidate.exists()) {
          file = candidate;
          break;
        }
      }
      if (file == null) return;

      final session = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      await file.delete();

      final local = LocalDataSource();
      await local.initializeHive();
      await local.clearAuthToken();
      await local.saveAuthToken(session['token'] as String);
      await local.saveRefreshToken(session['refreshToken'] as String);
      await local.saveCurrentUserId(session['userId'] as String);
      await local.saveCurrentUserRole(session['role'] as String);
      debugPrint('[DemoSession] Signed in as ${session['role']} ${session['userId']}');
    } catch (e) {
      debugPrint('[DemoSession] Ignored invalid demo session: $e');
    }
  }
}
