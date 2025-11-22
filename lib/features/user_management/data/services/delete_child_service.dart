import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class DeleteChildService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  /// Delete child and all associated data from Firebase
  Future<bool> deleteChild({
    required String parentId,
    required String childId,
    String? childName, // Optional child name for notification
  }) async {
    try {
      print('🗑️ [DeleteChild] Starting deletion for child: $childId');

      // Get child name before deletion (if not provided)
      String? name = childName;
      if (name == null) {
        try {
          final childDoc = await _firestore
              .collection('parents')
              .doc(parentId)
              .collection('children')
              .doc(childId)
              .get();
          if (childDoc.exists) {
            final data = childDoc.data();
            name = data?['name'] ?? data?['firstName'] ?? 'Child';
          }
        } catch (e) {
          print('⚠️ [DeleteChild] Could not fetch child name: $e');
          name = 'Child';
        }
      }

      // 🔥 Show notification IMMEDIATELY (before slow delete operations)
      await _showDeleteNotification(name ?? 'Child');
      print('✅ [DeleteChild] Notification shown immediately');

      // Delete operations in background (non-blocking for user)
      // 1. Delete child's location data
      _deleteLocationData(parentId, childId).catchError((e) {
        print('⚠️ [DeleteChild] Error deleting location: $e');
      });
      
      // 2. Delete child's flagged messages
      _deleteFlaggedMessages(parentId, childId).catchError((e) {
        print('⚠️ [DeleteChild] Error deleting flagged messages: $e');
      });
      
      // 3. Delete child's geofence data
      _deleteGeofenceData(parentId, childId).catchError((e) {
        print('⚠️ [DeleteChild] Error deleting geofence: $e');
      });
      
      // 4. Delete child's general messages
      _deleteMessages(parentId, childId).catchError((e) {
        print('⚠️ [DeleteChild] Error deleting messages: $e');
      });
      
      // 5. Delete child document from parent's children collection (MOST IMPORTANT)
      await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .delete();

      // 6. Clear child's local data
      _clearChildLocalData(childId).catchError((e) {
        print('⚠️ [DeleteChild] Error clearing local data: $e');
      });

      print('✅ [DeleteChild] Child $childId deleted successfully');
      return true;
    } catch (e) {
      print('❌ [DeleteChild] Error deleting child: $e');
      return false;
    }
  }

  /// Delete child's location data
  Future<void> _deleteLocationData(String parentId, String childId) async {
    try {
      final locationRef = _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('location');

      // Delete current location
      await locationRef.doc('current').delete();

      // Delete location history (batch delete)
      final locationHistory = await locationRef.get();
      final batch = _firestore.batch();
      
      for (final doc in locationHistory.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [DeleteChild] Location data deleted');
    } catch (e) {
      print('⚠️ [DeleteChild] Error deleting location data: $e');
    }
  }

  /// Delete child's flagged messages
  Future<void> _deleteFlaggedMessages(String parentId, String childId) async {
    try {
      final flaggedMessagesRef = _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('flagged_messages');

      // Batch delete all flagged messages
      final flaggedMessages = await flaggedMessagesRef.get();
      final batch = _firestore.batch();
      
      for (final doc in flaggedMessages.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [DeleteChild] Flagged messages deleted');
    } catch (e) {
      print('⚠️ [DeleteChild] Error deleting flagged messages: $e');
    }
  }

  /// Delete child's geofence data
  Future<void> _deleteGeofenceData(String parentId, String childId) async {
    try {
      final geofenceRef = _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .doc(childId)
          .collection('geofences');

      // Batch delete all geofences
      final geofences = await geofenceRef.get();
      final batch = _firestore.batch();
      
      for (final doc in geofences.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [DeleteChild] Geofence data deleted');
    } catch (e) {
      print('⚠️ [DeleteChild] Error deleting geofence data: $e');
    }
  }

  /// Delete child's general messages
  Future<void> _deleteMessages(String parentId, String childId) async {
    try {
      final messagesRef = _firestore.collection('messages');
      
      // Delete messages where childId matches
      final messages = await messagesRef
          .where('childId', isEqualTo: childId)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [DeleteChild] General messages deleted');
    } catch (e) {
      print('⚠️ [DeleteChild] Error deleting general messages: $e');
    }
  }

  /// Clear child's local data from SharedPreferences
  Future<void> _clearChildLocalData(String childId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove child-specific data
      await prefs.remove('child_uid');
      await prefs.remove('last_message_timestamp_$childId');
      
      print('✅ [DeleteChild] Local data cleared');
    } catch (e) {
      print('⚠️ [DeleteChild] Error clearing local data: $e');
    }
  }

  /// Show notification in status bar when child is deleted
  Future<void> _showDeleteNotification(String childName) async {
    try {
      // Create notification channel first (if not exists)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'child_deleted_channel',
        'Child Deleted Notifications',
        description: 'Notifications when a child is deleted',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(channel);
        print('✅ [DeleteChild] Notification channel created');
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'child_deleted_channel',
        'Child Deleted Notifications',
        channelDescription: 'Notifications when a child is deleted',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFF007AFF),
        ticker: 'Child deleted',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Child Deleted',
        '$childName deleted successfully',
        platformChannelSpecifics,
        payload: 'child_deleted',
      );

      print('✅ [DeleteChild] Notification shown: $childName deleted');
    } catch (e) {
      print('❌ [DeleteChild] Error showing notification: $e');
    }
  }
}
