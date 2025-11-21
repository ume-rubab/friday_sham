import 'package:device_apps/device_apps.dart';
import '../models/installed_app.dart';

/// AppListService - Uses device_apps package (Pure Flutter, no native code needed)
/// 
/// This service gets installed apps directly from Flutter using device_apps package.
/// No need for native method channels - works out of the box!
class AppListService {
  /// Get list of all installed apps on the device
  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      print('📱 [AppListService] Getting all installed apps using device_apps package...');
      
      // Get all installed apps (including system apps)
      List<Application> apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: true,
        includeAppIcons: false, // Set to true if you need icons
        onlyAppsWithLaunchIntent: false,
      );
      
      print('📱 [AppListService] Found ${apps.length} installed apps');
      
      // Convert to InstalledApp model
      final List<InstalledApp> installedApps = apps.map((app) {
        return InstalledApp(
          packageName: app.packageName,
          appName: app.appName,
          versionName: app.versionName,
          versionCode: app.versionCode.toInt(),
          isSystemApp: app.systemApp,
          installTime: DateTime.fromMillisecondsSinceEpoch(app.installTimeMillis),
          lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(app.updateTimeMillis),
          iconPath: null, // device_apps doesn't provide icon path directly
        );
      }).toList();
      
      print('✅ [AppListService] Converted ${installedApps.length} apps to InstalledApp model');
      return installedApps;
    } catch (e, stackTrace) {
      print('❌ [AppListService] Error getting installed apps: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get list of user-installed apps (excluding system apps)
  Future<List<InstalledApp>> getUserApps() async {
    try {
      print('📱 [AppListService] Getting user apps only...');
      
      // Get only user-installed apps (exclude system apps)
      List<Application> apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: false, // Only user apps
        includeAppIcons: false,
        onlyAppsWithLaunchIntent: false,
      );
      
      print('📱 [AppListService] Found ${apps.length} user apps');
      
      // Convert to InstalledApp model
      final List<InstalledApp> installedApps = apps.map((app) {
        return InstalledApp(
          packageName: app.packageName,
          appName: app.appName,
          versionName: app.versionName,
          versionCode: app.versionCode.toInt(),
          isSystemApp: false, // User apps are not system apps
          installTime: DateTime.fromMillisecondsSinceEpoch(app.installTimeMillis),
          lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(app.updateTimeMillis),
          iconPath: null,
        );
      }).toList();
      
      return installedApps;
    } catch (e, stackTrace) {
      print('❌ [AppListService] Error getting user apps: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get list of system apps only
  Future<List<InstalledApp>> getSystemApps() async {
    try {
      print('📱 [AppListService] Getting system apps only...');
      
      // Get all apps first
      List<Application> allApps = await DeviceApps.getInstalledApplications(
        includeSystemApps: true,
        includeAppIcons: false,
        onlyAppsWithLaunchIntent: false,
      );
      
      // Filter system apps
      final systemApps = allApps.where((app) => app.systemApp).toList();
      print('📱 [AppListService] Found ${systemApps.length} system apps');
      
      // Convert to InstalledApp model
      final List<InstalledApp> installedApps = systemApps.map((app) {
        return InstalledApp(
          packageName: app.packageName,
          appName: app.appName,
          versionName: app.versionName,
          versionCode: app.versionCode.toInt(),
          isSystemApp: true,
          installTime: DateTime.fromMillisecondsSinceEpoch(app.installTimeMillis),
          lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(app.updateTimeMillis),
          iconPath: null,
        );
      }).toList();
      
      return installedApps;
    } catch (e, stackTrace) {
      print('❌ [AppListService] Error getting system apps: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  /// Launch an app by package name
  Future<bool> launchApp(String packageName) async {
    try {
      print('🚀 [AppListService] Launching app: $packageName');
      final bool launched = await DeviceApps.openApp(packageName);
      if (launched) {
        print('✅ [AppListService] App launched successfully: $packageName');
      } else {
        print('❌ [AppListService] Failed to launch app: $packageName');
      }
      return launched;
    } catch (e) {
      print('❌ [AppListService] Error launching app: $e');
      return false;
    }
  }

  /// Uninstall an app by package name
  Future<bool> uninstallApp(String packageName) async {
    try {
      print('🗑️ [AppListService] Uninstalling app: $packageName');
      final bool uninstalled = await DeviceApps.uninstallApp(packageName);
      if (uninstalled) {
        print('✅ [AppListService] App uninstalled successfully: $packageName');
      } else {
        print('❌ [AppListService] Failed to uninstall app: $packageName');
      }
      return uninstalled;
    } catch (e) {
      print('❌ [AppListService] Error uninstalling app: $e');
      return false;
    }
  }

  /// Get app info by package name
  Future<InstalledApp?> getAppInfo(String packageName) async {
    try {
      print('📱 [AppListService] Getting app info: $packageName');
      final Application? app = await DeviceApps.getApp(packageName, true);
      
      if (app == null) {
        print('⚠️ [AppListService] App not found: $packageName');
        return null;
      }
      
      return InstalledApp(
        packageName: app.packageName,
        appName: app.appName,
        versionName: app.versionName,
        versionCode: app.versionCode.toInt(),
        isSystemApp: app.systemApp,
        installTime: DateTime.fromMillisecondsSinceEpoch(app.installTimeMillis),
        lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(app.updateTimeMillis),
        iconPath: null,
      );
    } catch (e) {
      print('❌ [AppListService] Error getting app info: $e');
      return null;
    }
  }

  /// Check if an app is installed
  Future<bool> isAppInstalled(String packageName) async {
    try {
      final Application? app = await DeviceApps.getApp(packageName, true);
      return app != null;
    } catch (e) {
      print('❌ [AppListService] Error checking if app is installed: $e');
      return false;
    }
  }
}
