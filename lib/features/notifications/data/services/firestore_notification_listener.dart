import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';

/// Service to listen to Firestore notifications and show local notifications
/// This works WITHOUT Cloud Functions - just Firestore + Local Notifications
class FirestoreNotificationListener {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  final List<StreamSubscription> _subscriptions = [];
  String? _lastNotificationId;

  /// Start listening to Firestore notifications for current parent
  Future<void> startListening() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('⚠️ [FirestoreListener] User not logged in');
        return;
      }

      final parentId = currentUser.uid;

      print('🔔 [FirestoreListener] Starting listener for parent: $parentId');

      // Listen to all children's notifications
      final childrenSnapshot = await _firestore
          .collection('parents')
          .doc(parentId)
          .collection('children')
          .get();

      if (childrenSnapshot.docs.isEmpty) {
        print('⚠️ [FirestoreListener] No children found');
        return;
      }

      // Listen to each child's notifications collection
      for (final childDoc in childrenSnapshot.docs) {
        final childId = childDoc.id;
        
        final subscription = _firestore
            .collection('parents')
            .doc(parentId)
            .collection('children')
            .doc(childId)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .limit(1) // Only listen to latest notification
            .snapshots()
            .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final latestDoc = snapshot.docs.first;
            final notificationId = latestDoc.id;
            
            // Only show if it's a new notification
            if (_lastNotificationId != notificationId) {
              _lastNotificationId = notificationId;
              
              try {
                final notification = NotificationModel.fromFirestore(latestDoc);
                _showLocalNotification(notification);
                print('✅ [FirestoreListener] Notification shown: ${notification.title}');
              } catch (e) {
                print('❌ [FirestoreListener] Error parsing notification: $e');
              }
            }
          }
        });
        
        _subscriptions.add(subscription);
      }

      print('✅ [FirestoreListener] Listening started');
    } catch (e) {
      print('❌ [FirestoreListener] Error starting listener: $e');
    }
  }

  /// Stop listening to notifications
  void stopListening() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _lastNotificationId = null;
    print('🛑 [FirestoreListener] Stopped listening');
  }

  /// Show local notification from Firestore notification
  Future<void> _showLocalNotification(NotificationModel notification) async {
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: const Color(0xFF007AFF),
        styleInformation: BigTextStyleInformation(
          notification.body,
          contentTitle: notification.title,
        ),
        autoCancel: true,
        ticker: 'New notification',
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _localNotifications.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: notification.data.toString(),
      );

      print('✅ [FirestoreListener] Local notification shown: ${notification.title}');
    } catch (e) {
      print('❌ [FirestoreListener] Error showing notification: $e');
    }
  }
}

