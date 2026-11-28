import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

/// State of the self-updater ("web" build, from vestasecurity.date).
class UpdateStatus {
  final bool supported;
  final String? currentVersionName;
  final bool canInstall;
  final bool silent;
  final bool available;
  final String? availableVersionName;
  final bool mandatory;
  final String? notes;
  final DateTime? lastCheck;
  final String? lastError;

  const UpdateStatus({
    required this.supported,
    this.currentVersionName,
    this.canInstall = false,
    this.silent = false,
    this.available = false,
    this.availableVersionName,
    this.mandatory = false,
    this.notes,
    this.lastCheck,
    this.lastError,
  });

  factory UpdateStatus.fromMap(Map<dynamic, dynamic> map) {
    final last = map['lastCheck'];
    return UpdateStatus(
      supported: map['supported'] == true,
      currentVersionName: map['currentVersionName'] as String?,
      canInstall: map['canInstall'] == true,
      silent: map['silent'] == true,
      available: map['available'] == true,
      availableVersionName: map['availableVersionName'] as String?,
      mandatory: map['mandatory'] == true,
      notes: map['notes'] as String?,
      lastCheck: last is int && last > 0
          ? DateTime.fromMillisecondsSinceEpoch(last)
          : null,
      lastError: map['lastError'] as String?,
    );
  }
}

/// Updates. Two builds (Android flavours):
/// - "web": the APK downloads and installs its own updates (native code in
///   android/app/src/web; checks every 6 h on Wi-Fi and when the app opens).
/// - "play": Google Play installs them; here we only ask Play to update now.
class AppUpdater {
  AppUpdater._();

  static const _channel = MethodChannel('vesta/updater');
  static const _launchInterval = Duration(hours: 6);

  static bool get isPlayBuild => appFlavor == 'play';

  static Future<UpdateStatus> status() async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('status');
      return UpdateStatus.fromMap(map ?? const {});
    } on MissingPluginException {
      return const UpdateStatus(supported: false);
    } on PlatformException {
      return const UpdateStatus(supported: false);
    }
  }

  /// Checks now and, if there is a new version, downloads and installs it.
  static Future<UpdateStatus> checkNow() async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkNow');
      return UpdateStatus.fromMap(map ?? const {});
    } on MissingPluginException {
      return const UpdateStatus(supported: false);
    }
  }

  static Future<void> openInstallSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');

  /// When the app opens. Never throws.
  static Future<UpdateStatus?> checkOnLaunch() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      if (isPlayBuild) {
        await _checkPlay();
        return null;
      }
      final current = await status();
      if (!current.supported) return current;
      final last = current.lastCheck;
      if (last != null &&
          DateTime.now().difference(last) < _launchInterval &&
          !current.available) {
        return current;
      }
      return await checkNow();
    } catch (e) {
      debugPrint('Comprobación de actualización fallida: $e');
      return null;
    }
  }

  static Future<void> _checkPlay() async {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

    // Priority 4-5 (set when publishing in Play Console): mandatory update.
    if (info.updatePriority >= 4 && info.immediateUpdateAllowed) {
      await InAppUpdate.performImmediateUpdate();
    } else if (info.flexibleUpdateAllowed) {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        await InAppUpdate.completeFlexibleUpdate();
      }
    }
  }
}
