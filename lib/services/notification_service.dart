import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_classic_service.dart';
import '../screens/chat_screen.dart';

/// Local notification delivery while the app's Dart engine and transport listeners are alive.
class BlousabNotificationService {
  BlousabNotificationService._();
  static final BlousabNotificationService instance = BlousabNotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Set<String> _seen = <String>{};

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@android:drawable/sym_def_app_icon');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    const channel = AndroidNotificationChannel(
      'blousab_messages', 'رسائل بلوساب',
      description: 'إشعارات الرسائل الجديدة في بلوساب',
      importance: Importance.high,
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    _initialized = true;
  }

  Future<void> handleEvent(BlousabEvent event) async {
    if (!_initialized || event.type != 'message' || event.message == null) return;
    try {
      final decoded = jsonDecode(event.message!);
      if (decoded is! Map) return;
      final senderId = decoded['senderId']?.toString() ?? '';
      final senderName = decoded['senderName']?.toString() ?? event.name ?? 'رسالة جديدة';
      final conversationId = decoded['conversationId']?.toString() ?? '';
      final id = decoded['id']?.toString() ?? '${senderId}_${conversationId}_${event.message.hashCode}';
      if (senderId.isEmpty || _seen.contains(id)) return;
      _seen.add(id);
      if (_seen.length > 500) _seen.clear();
      if (ChatScreen.activeConversationId == conversationId && conversationId.isNotEmpty) return;
      final type = decoded['type']?.toString() ?? 'text';
      final text = type == 'file' ? 'أرسل لك صورة أو ملفًا' : (decoded['text']?.toString() ?? 'رسالة جديدة');
      await _plugin.show(id.hashCode & 0x7fffffff, senderName, text,
        const NotificationDetails(android: AndroidNotificationDetails(
          'blousab_messages', 'رسائل بلوساب',
          channelDescription: 'إشعارات الرسائل الجديدة في بلوساب',
          importance: Importance.high, priority: Priority.high,
          icon: '@android:drawable/sym_action_chat',
        )),
        payload: conversationId);
    } catch (_) {
      // Ignore malformed transport packets; chat parsing handles its own errors.
    }
  }
}
