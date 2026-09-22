import 'dart:async';

import '../../../core/realtime/realtime_service.dart';
import '../models/notification_model.dart';
import 'notifications_service.dart';

class NotificationsData {
  final List<NotificationModel> notifications;
  final int unreadCount;

  const NotificationsData({
    required this.notifications,
    required this.unreadCount,
  });
}

abstract interface class NotificationsGateway {
  Stream<Map<String, dynamic>> get events;

  Future<void> startRealtime();

  Future<void> disposeRealtime();

  Future<NotificationsData> load({bool unreadOnly = false});

  Future<NotificationModel> markAsRead(String notificationId);

  Future<NotificationModel> markAsUnread(String notificationId);

  Future<int> markAllAsRead();

  Future<void> deleteNotification(String notificationId);
}

class ApiNotificationsGateway implements NotificationsGateway {
  final NotificationsService _notifications;
  final RealtimeService _realtime;

  ApiNotificationsGateway({
    NotificationsService? notificationsService,
    RealtimeService? realtimeService,
  }) : _notifications = notificationsService ?? NotificationsService(),
       _realtime = realtimeService ?? RealtimeService();

  @override
  Stream<Map<String, dynamic>> get events => _realtime.events;

  @override
  Future<void> startRealtime() => _realtime.start();

  @override
  Future<void> disposeRealtime() => _realtime.dispose();

  @override
  Future<NotificationsData> load({bool unreadOnly = false}) async {
    final results = await Future.wait<dynamic>([
      _notifications.getNotifications(unreadOnly: unreadOnly ? true : null),
      _notifications.getUnreadCount(),
    ]);
    return NotificationsData(
      notifications: results[0] as List<NotificationModel>,
      unreadCount: results[1] as int,
    );
  }

  @override
  Future<NotificationModel> markAsRead(String notificationId) =>
      _notifications.markAsRead(notificationId);

  @override
  Future<NotificationModel> markAsUnread(String notificationId) =>
      _notifications.markAsUnread(notificationId);

  @override
  Future<int> markAllAsRead() => _notifications.markAllAsRead();

  @override
  Future<void> deleteNotification(String notificationId) =>
      _notifications.deleteNotification(notificationId);
}
