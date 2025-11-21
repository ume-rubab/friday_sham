import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_permission_service.dart';
import 'child_message_monitor_service.dart';
import '../datasources/message_remote_datasource.dart';
import '../../../location_tracking/data/services/geofencing_detection_service.dart';
import '../../../location_tracking/data/datasources/geofence_remote_datasource.dart';
import '../../../app_limits/data/services/real_time_app_usage_service.dart';

class ChildAppInitializationService {
  final MessageRemoteDataSourceImpl _messageDataSource;
  ChildMessageMonitorService? _messageMonitor;
  GeofencingDetectionService? _geofencingService;
  RealTimeAppUsageService? _realTimeAppUsageService;

  ChildAppInitializationService({required MessageRemoteDataSourceImpl messageDataSource})
      : _messageDataSource = messageDataSource;

  /// Initialize child app with all permissions and services
  Future<void> initializeChildApp() async {
    try {
      print('Initializing child app...');
      
      // Get parent and child IDs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final parentId = prefs.getString('parent_uid');
      final childId = prefs.getString('child_uid');

      if (parentId == null || childId == null) {
        print('Parent or child ID not found in SharedPreferences');
        return;
      }

      print('Child app initialized for: $childId, parent: $parentId');

      // Request all permissions at startup
      await _requestAllPermissions();

      // Initialize message monitoring
      await _initializeMessageMonitoring(parentId, childId);

      // Initialize geofencing monitoring
      await _initializeGeofencingMonitoring();

      // Initialize real-time app usage tracking (includes installed apps sync)
      await _initializeAppUsageTracking(parentId, childId);

      print('Child app initialization completed');
    } catch (e) {
      print('Error initializing child app: $e');
    }
  }

  /// Request all necessary permissions
  Future<void> _requestAllPermissions() async {
    try {
      print('Requesting all permissions...');
      
      // Request message permissions
      final messagePermissionsGranted = await MessagePermissionService.requestMessagePermissions();
      if (!messagePermissionsGranted) {
        print('Message permissions not granted');
      }

      // TODO: Add other permissions (location, camera, etc.)
      // This is where you can add location permissions, camera permissions, etc.
      
      print('All permissions requested');
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  /// Initialize message monitoring
  Future<void> _initializeMessageMonitoring(String parentId, String childId) async {
    try {
      print('Initializing message monitoring...');
      
      _messageMonitor = ChildMessageMonitorService(dataSource: _messageDataSource);
      await _messageMonitor!.initialize();
      
      print('Message monitoring initialized');
    } catch (e) {
      print('Error initializing message monitoring: $e');
    }
  }

  /// Initialize geofencing monitoring
  Future<void> _initializeGeofencingMonitoring() async {
    try {
      print('Initializing geofencing monitoring...');
      
      final geofenceDataSource = GeofenceRemoteDataSourceImpl(
        firestore: FirebaseFirestore.instance,
      );
      
      _geofencingService = GeofencingDetectionService(
        geofenceDataSource: geofenceDataSource,
      );
      
      await _geofencingService!.startGeofencingMonitoring();
      
      print('Geofencing monitoring initialized');
    } catch (e) {
      print('Error initializing geofencing monitoring: $e');
    }
  }

  /// Initialize app usage tracking and installed apps sync
  Future<void> _initializeAppUsageTracking(String parentId, String childId) async {
    try {
      print('🔄 [ChildAppInit] ========== INITIALIZING APP USAGE TRACKING ==========');
      print('   Child ID: $childId');
      print('   Parent ID: $parentId');
      
      _realTimeAppUsageService = RealTimeAppUsageService();
      
      // Initialize service with child and parent IDs
      print('🔄 [ChildAppInit] Initializing RealTimeAppUsageService...');
      _realTimeAppUsageService!.initialize(
        childId: childId,
        parentId: parentId,
      );
      print('✅ [ChildAppInit] Service initialized');
      
      // Start real-time tracking (this also starts installed apps sync)
      print('🔄 [ChildAppInit] Starting tracking service...');
      await _realTimeAppUsageService!.startTracking();
      
      print('✅ [ChildAppInit] App usage tracking and installed apps sync initialized');
      print('📱 [ChildAppInit] Installed apps will sync immediately and then every 5 minutes');
      print('🔄 [ChildAppInit] ====================================================');
    } catch (e, stackTrace) {
      print('❌ [ChildAppInit] Error initializing app usage tracking: $e');
      print('❌ [ChildAppInit] Stack trace: $stackTrace');
    }
  }

  /// Stop all services
  Future<void> stopAllServices() async {
    try {
      print('Stopping all services...');
      
      // Stop message monitoring
      _messageMonitor?.stop();
      _messageMonitor = null;
      
      // Stop geofencing monitoring
      await _geofencingService?.stopGeofencingMonitoring();
      _geofencingService = null;
      
      // Stop app usage tracking
      await _realTimeAppUsageService?.stopTracking();
      _realTimeAppUsageService?.dispose();
      _realTimeAppUsageService = null;
      
      print('All services stopped');
    } catch (e) {
      print('Error stopping services: $e');
    }
  }

  /// Check if all permissions are granted
  Future<bool> checkAllPermissions() async {
    try {
      final messagePermissions = await MessagePermissionService.checkMessagePermissions();
      // TODO: Add other permission checks
      
      return messagePermissions; // && other permissions
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  /// Get permission status for display
  Future<Map<String, bool>> getPermissionStatus() async {
    return await MessagePermissionService.getPermissionStatus();
  }

  /// Dispose resources
  void dispose() {
    _messageMonitor?.stop();
    _messageMonitor = null;
    _geofencingService?.dispose();
    _geofencingService = null;
    _realTimeAppUsageService?.dispose();
    _realTimeAppUsageService = null;
  }
}
