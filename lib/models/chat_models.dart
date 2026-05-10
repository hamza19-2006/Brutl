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
    this.replyToId,
    this.replyToSenderId,
    this.replyToPreview,
    this.reactions = const <String, List<String>>{},
    this.isDeleted = false,
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

  // ── Reply metadata ────────────────────────────────────────────────────────
  /// id of the message this one is replying to (null if not a reply).
  final String? replyToId;
  /// senderId of the message being replied to.
  final String? replyToSenderId;
  /// short preview text of the message being replied to.
  final String? replyToPreview;

  // ── Reactions ─────────────────────────────────────────────────────────────
  /// Map of emoji -> list of UIDs that reacted with it.
  final Map<String, List<String>> reactions;

  // ── Soft delete ───────────────────────────────────────────────────────────
  /// When true, render as 'This message was deleted'. Original payload is
  /// cleared by the provider on delete.
  final bool isDeleted;

  bool get isReply => replyToId != null && replyToId!.isNotEmpty;
  bool get hasReactions => reactions.isNotEmpty;

  MessageModel copyWith({
    String? status,
    DateTime? readAt,
    Map<String, List<String>>? reactions,
    bool? isDeleted,
    Map<String, dynamic>? payload,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      timestamp: timestamp,
      expiresAt: expiresAt,
      type: type,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      readAt: readAt ?? this.readAt,
      replyToId: replyToId,
      replyToSenderId: replyToSenderId,
      replyToPreview: replyToPreview,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

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
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
      if (replyToPreview != null) 'replyToPreview': replyToPreview,
      if (reactions.isNotEmpty) 'reactions': reactions,
      if (isDeleted) 'isDeleted': true,
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'];
    final parsedReactions = <String, List<String>>{};
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        if (value is List) {
          parsedReactions[key.toString()] =
              value.map((e) => e.toString()).toList();
        }
      });
    }

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
      replyToId: json['replyToId'] as String?,
      replyToSenderId: json['replyToSenderId'] as String?,
      replyToPreview: json['replyToPreview'] as String?,
      reactions: parsedReactions,
      isDeleted: (json['isDeleted'] as bool?) ?? false,
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
    this.addedAt,
    this.isPinned = false,
    this.isMuted = false,
    this.isBlocked = false,
  });

  final String uid;
  final String nickname;
  final String displayName;
  final String username;
  final String photoUrl;
  final DateTime? addedAt;

  /// Pinned chats sort to the top of the chat list.
  final bool isPinned;
  /// Muted chats suppress notifications and don't show unread badges.
  final bool isMuted;
  /// Blocked friends are hidden from the chat list and cannot send messages.
  final bool isBlocked;

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
      'isPinned': isPinned,
      'isMuted': isMuted,
      'isBlocked': isBlocked,
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
      isPinned: (json['isPinned'] as bool?) ?? false,
      isMuted: (json['isMuted'] as bool?) ?? false,
      isBlocked: (json['isBlocked'] as bool?) ?? false,
    );
  }

  FriendModel copyWith({
    String? nickname,
    bool? isPinned,
    bool? isMuted,
    bool? isBlocked,
  }) {
    return FriendModel(
      uid: uid,
      nickname: nickname ?? this.nickname,
      displayName: displayName,
      username: username,
      photoUrl: photoUrl,
      addedAt: addedAt,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}

// ---------------------------------------------------------------------------
// Presence (online / last-seen)
// ---------------------------------------------------------------------------

@immutable
class PresenceModel {
  const PresenceModel({
    required this.isOnline,
    required this.lastSeen,
  });

  final bool isOnline;
  final DateTime? lastSeen;

  static const PresenceModel offline = PresenceModel(
    isOnline: false,
    lastSeen: null,
  );

  factory PresenceModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PresenceModel.offline;
    return PresenceModel(
      isOnline: (json['isOnline'] as bool?) ?? false,
      lastSeen: MessageModel._toNullableDateTime(json['lastSeen']),
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
