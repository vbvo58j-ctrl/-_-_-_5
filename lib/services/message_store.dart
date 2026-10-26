
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/blousab_message.dart';

class MessageStore {
  // تسلسل عمليات الكتابة لكل محادثة حتى لا تتداخل عمليتا حفظ متزامنتان.
  // المشاركة static مهمة لأن الشاشات قد تنشئ أكثر من MessageStore.
  static final Map<String, Future<void>> _writeQueues = <String, Future<void>>{};

  Future<void> _serialized(String key, Future<void> Function() action) async {
    final previous = _writeQueues[key] ?? Future<void>.value();
    final current = previous
        .catchError((Object _) {})
        .then((_) => action());
    _writeQueues[key] = current;
    try {
      await current;
    } finally {
      if (identical(_writeQueues[key], current)) {
        _writeQueues.remove(key);
      }
    }
  }

  String _storageKey(String conversationId) =>
      'wasl_messages_$conversationId';

  Future<List<BlousabMessage>> getMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(conversationId));

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final messages = decoded
          .map(
            (item) => BlousabMessage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return messages;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessage(BlousabMessage message) async {
    final key = _storageKey(message.conversationId);
    await _serialized(key, () async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      List<BlousabMessage> messages = <BlousabMessage>[];

      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as List<dynamic>;
          messages = decoded
              .map((item) => BlousabMessage.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList();
        } catch (_) {
          // إذا كان التخزين تالفًا، لا نوقف التطبيق؛ نبدأ قائمة جديدة.
          messages = <BlousabMessage>[];
        }
      }

      // منع تكرار الرسالة نفسها عند حفظها مرة أخرى.
      if (messages.any((item) => item.id == message.id)) return;

      messages.add(message);
      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      await prefs.setString(
        key,
        jsonEncode(messages.map((item) => item.toJson()).toList()),
      );
    });
  }

  Future<void> clearMessages(String conversationId) async {
    final key = _storageKey(conversationId);
    await _serialized(key, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    });
  }
}