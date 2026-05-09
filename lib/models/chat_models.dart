import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------

@immutable
class MessageModel {
  // Values below this threshold are treated as Unix seconds and multiplied by
  // 1000. The threshold corresponds to ~March 1973 in Unix milliseconds.
  static const int _unixMillisecondsThreshold = 100000000000;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.timestamp,
    required this.expiresAt,
    required this.type,
    required this.payload,
    this.status = 'sent',
    this.readAt,
  });

  final String id;
  final String senderId;
  final DateTime timestamp;
  final DateTime expiresAt;

  /// One of: 'text', 'meal_share', 'exercise_share'
  final String type;

  /// Flexible map holding the actual data.
  /// For text: {'text': '...'}.
  /// For meal_share / exercise_share: structured maps.
  final Map<String, dynamic> payload;
  final String status; // sent, delivered, read
  final DateTime? readAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'senderId': senderId,
      'timestamp': Timestamp.fromDate(timestamp),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'type': type,
      'payload': payload,
      'status': status,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      timestamp: _toDateTime(json['timestamp']),
      expiresAt: _toDateTime(json['expiresAt']),
      type: json['type'] as String? ?? 'text',
      payload: Map<String, dynamic>.from(
        (json['payload'] as Map<dynamic, dynamic>?) ?? <String, dynamic>{},
      ),
      status: json['status'] as String? ?? 'sent',
      readAt: _toNullableDateTime(json['readAt']),
    );
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      final raw = value.toInt();
      final milliseconds = raw > _unixMillisecondsThreshold ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    if (value is Map<dynamic, dynamic>) {
      final seconds = (value['seconds'] as num?)?.toInt();
      final nanoseconds = (value['nanoseconds'] as num?)?.toInt() ?? 0;
      if (seconds != null) {
        final milliseconds = (seconds * 1000) + (nanoseconds ~/ 1000000);
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Friend
// ---------------------------------------------------------------------------

@immutable
class FriendModel {
  const FriendModel({
    required this.uid,
    this.nickname = '',
    this.displayName = '',
    this.username = '',
    this.photoUrl = '',
    DateTime? addedAt,
  }) : addedAt = addedAt ?? null;

  final String uid;
  final String nickname;
  final String displayName;
  final String username;
  final String photoUrl;
  final DateTime? addedAt;

  /// The name to display in UI: nickname first, then displayName, then @username.
  String get resolvedName => nickname.isNotEmpty
      ? nickname
      : displayName.isNotEmpty
      ? displayName
      : '@$username';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'nickname': nickname,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
      'addedAt': addedAt != null
          ? Timestamp.fromDate(addedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      uid: json['uid'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      addedAt: MessageModel._toDateTime(json['addedAt']),
    );
  }

  FriendModel copyWith({String? nickname}) {
    return FriendModel(
      uid: uid,
      nickname: nickname ?? this.nickname,
      displayName: displayName,
      username: username,
      photoUrl: photoUrl,
      addedAt: addedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Friend Request
// ---------------------------------------------------------------------------

@immutable
class FriendRequestModel {
  const FriendRequestModel({
    required this.senderUid,
    required this.senderDisplayName,
    required this.senderUsername,
    required this.senderPhotoUrl,
    required this.status,
    required this.timestamp,
  });

  final String senderUid;
  final String senderDisplayName;
  final String senderUsername;
  final String senderPhotoUrl;
  final String status; // 'pending'
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'senderUid': senderUid,
      'senderDisplayName': senderDisplayName,
      'senderUsername': senderUsername,
      'senderPhotoUrl': senderPhotoUrl,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      senderUid: json['senderUid'] as String? ?? '',
      senderDisplayName: json['senderDisplayName'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? '',
      senderPhotoUrl: json['senderPhotoUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      timestamp: MessageModel._toDateTime(json['timestamp']),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: Build deterministic chat ID from two UIDs.
// ---------------------------------------------------------------------------

String buildChatId(String uidA, String uidB) {
  final sorted = [uidA, uidB]..sort();
  return '${sorted[0]}_${sorted[1]}';
}
