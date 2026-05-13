import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

class ChatProvider extends ChangeNotifier {
  // Firestore batch writes support up to 500 operations.
  // Use a lower ceiling to leave headroom and avoid accidental overflows.
  static const int _maxBatchOps = 450;
  static const String _sharedDayCachePrefix = 'chat_shared_day_cache_v1';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // -----------------------------------------------------------------------
  // Local state
  // -----------------------------------------------------------------------

  List<FriendModel> _friends = [];
  List<FriendModel> get friends => List.unmodifiable(_friends);
  List<FriendModel> get blockedUsers =>
      List.unmodifiable(_friends.where((friend) => friend.isBlocked));

  List<FriendRequestModel> _pendingRequests = [];
  List<FriendRequestModel> get pendingRequests =>
      List.unmodifiable(_pendingRequests);

  int get pendingRequestCount => _pendingRequests.length;

  /// Sender-uids whose pending request has been accepted/declined locally but
  /// whose deletion may not yet have propagated through the Firestore stream.
  /// Mapped to the timestamp of the request we acted on so a newer resend
  /// bypasses the suppression and is surfaced again.
  final Map<String, DateTime> _suppressedRequests = <String, DateTime>{};

  StreamSubscription<QuerySnapshot>? _friendsSub;
  StreamSubscription<QuerySnapshot>? _requestsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unreadChatsSub;

  // Optimistic send queue so messages render instantly.
  final List<MessageModel> _optimisticMessages = [];
  List<MessageModel> get optimisticMessages =>
      List.unmodifiable(_optimisticMessages);
  int _totalUnreadCount = 0;
  int get totalUnreadCount => _totalUnreadCount;

  // -----------------------------------------------------------------------
  // Initialization (call once after login)
  // -----------------------------------------------------------------------

  void listenToFriends() {
    if (_uid.isEmpty) return;
    _friendsSub?.cancel();
    _friendsSub = _db
        .collection('users')
        .doc(_uid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .listen((snap) {
          _friends = snap.docs.map((d) {
            final data = d.data();
            data['uid'] = d.id;
            return FriendModel.fromJson(data);
          }).toList();
          notifyListeners();
        });
  }

  void listenToFriendRequests() {
    if (_uid.isEmpty) return;
    _requestsSub?.cancel();
    _requestsSub = _db
        .collection('users')
        .doc(_uid)
        .collection('friend_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
          final raw = snap.docs.map((d) {
            final data = d.data();
            data['senderUid'] = d.id;
            return FriendRequestModel.fromJson(data);
          }).toList();

          // Drop suppression entries whose underlying request has either been
          // removed server-side (no longer in the snapshot) or has a newer
          // timestamp than what we suppressed (the friend re-sent a fresh
          // request after we accepted/declined an earlier one). This defeats
          // the visual "flicker" where an accepted request reappears for an
          // instant before the deletion propagates.
          final byUid = <String, FriendRequestModel>{
            for (final r in raw) r.senderUid: r,
          };
          _suppressedRequests.removeWhere((uid, ts) {
            final current = byUid[uid];
            if (current == null) return true;
            if (current.timestamp.isAfter(ts)) return true;
            return false;
          });

          _pendingRequests = raw
              .where((r) => !_suppressedRequests.containsKey(r.senderUid))
              .toList();
          notifyListeners();
        });
  }

  void listenToGlobalUnreadCount() {
    if (_uid.isEmpty) return;
    _unreadChatsSub?.cancel();
    final unreadKey = 'unreadCount_$_uid';
    _unreadChatsSub = _db
        .collection('chats')
        .where('participants', arrayContains: _uid)
        .where(unreadKey, isGreaterThan: 0)
        .snapshots()
        .listen((snap) {
          var total = 0;
          for (final doc in snap.docs) {
            final count = (doc.data()[unreadKey] as num?)?.toInt() ?? 0;
            total += count;
          }
          if (total != _totalUnreadCount) {
            _totalUnreadCount = total;
            notifyListeners();
          }
        });
  }

  // -----------------------------------------------------------------------
  // Friend System
  // -----------------------------------------------------------------------

  Future<void> sendFriendRequest(String targetUid) async {
    if (_uid.isEmpty) return;
    final myDoc = await _db.collection('users').doc(_uid).get();
    final myData = myDoc.data() ?? {};

    final request = FriendRequestModel(
      senderUid: _uid,
      senderDisplayName: myData['display_name'] as String? ?? '',
      senderUsername: myData['username'] as String? ?? '',
      senderPhotoUrl: myData['photo_url'] as String? ?? '',
      status: 'pending',
      timestamp: DateTime.now(),
    );

    await _db
        .collection('users')
        .doc(targetUid)
        .collection('friend_requests')
        .doc(_uid)
        .set(request.toJson());
  }

  Future<void> acceptFriendRequest(String senderUid) async {
    if (_uid.isEmpty) return;

    final previousRequests = List<FriendRequestModel>.from(_pendingRequests);
    final acted = _pendingRequests.firstWhere(
      (r) => r.senderUid == senderUid,
      orElse: () => FriendRequestModel(
        senderUid: senderUid,
        senderDisplayName: '',
        senderUsername: '',
        senderPhotoUrl: '',
        status: 'pending',
        timestamp: DateTime.now(),
      ),
    );

    // Suppress this request from future stream emissions until either the
    // deletion propagates or the friend resends a fresh request.
    _suppressedRequests[senderUid] = acted.timestamp;
    _pendingRequests = _pendingRequests
        .where((r) => r.senderUid != senderUid)
        .toList();
    notifyListeners();

    try {
      final senderDoc = await _db.collection('users').doc(senderUid).get();
      final senderData = senderDoc.data() ?? {};

      final myDoc = await _db.collection('users').doc(_uid).get();
      final myData = myDoc.data() ?? {};

      final batch = _db.batch();

      final myFriendRef = _db
          .collection('users')
          .doc(_uid)
          .collection('friends')
          .doc(senderUid);
      batch.set(
        myFriendRef,
        FriendModel(
          uid: senderUid,
          displayName: senderData['display_name'] as String? ?? '',
          username: senderData['username'] as String? ?? '',
          photoUrl: senderData['photo_url'] as String? ?? '',
        ).toJson(),
      );

      final theirFriendRef = _db
          .collection('users')
          .doc(senderUid)
          .collection('friends')
          .doc(_uid);
      batch.set(
        theirFriendRef,
        FriendModel(
          uid: _uid,
          displayName: myData['display_name'] as String? ?? '',
          username: myData['username'] as String? ?? '',
          photoUrl: myData['photo_url'] as String? ?? '',
        ).toJson(),
      );

      final requestRef = _db
          .collection('users')
          .doc(_uid)
          .collection('friend_requests')
          .doc(senderUid);
      batch.delete(requestRef);

      await batch.commit();
    } catch (e, st) {
      _suppressedRequests.remove(senderUid);
      _pendingRequests = previousRequests;
      notifyListeners();
      debugPrint('Failed to accept friend request from $senderUid: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> declineFriendRequest(String senderUid) async {
    if (_uid.isEmpty) return;

    final previousRequests = List<FriendRequestModel>.from(_pendingRequests);
    final acted = _pendingRequests.firstWhere(
      (r) => r.senderUid == senderUid,
      orElse: () => FriendRequestModel(
        senderUid: senderUid,
        senderDisplayName: '',
        senderUsername: '',
        senderPhotoUrl: '',
        status: 'pending',
        timestamp: DateTime.now(),
      ),
    );

    _suppressedRequests[senderUid] = acted.timestamp;
    _pendingRequests = _pendingRequests
        .where((r) => r.senderUid != senderUid)
        .toList();
    notifyListeners();

    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('friend_requests')
          .doc(senderUid)
          .delete();
    } catch (e, st) {
      _suppressedRequests.remove(senderUid);
      _pendingRequests = previousRequests;
      notifyListeners();
      debugPrint('Failed to decline friend request from $senderUid: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> removeFriend(String friendUid) async {
    if (_uid.isEmpty) return;

    final previousFriends = List<FriendModel>.from(_friends);

    // Optimistic
    _friends = _friends.where((f) => f.uid != friendUid).toList();
    notifyListeners();

    final chatId = buildChatId(_uid, friendUid);

    // Step 1: Best-effort chat history cleanup.
    // A failure here (e.g. transient permission-denied on a single message)
    // must NOT hold the friendship record hostage. We log and continue.
    try {
      await clearChatHistory(chatId);
    } catch (error, stackTrace) {
      debugPrint(
        'clearChatHistory failed during removeFriend($friendUid); '
        'continuing with friend doc deletion: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    // Step 2: Authoritative deletion of the friendship docs on both sides.
    // Only failures here cause a UI rollback.
    try {
      final batch = _db.batch();
      batch.delete(
        _db.collection('users').doc(_uid).collection('friends').doc(friendUid),
      );
      batch.delete(
        _db.collection('users').doc(friendUid).collection('friends').doc(_uid),
      );
      await batch.commit();
    } catch (error, stackTrace) {
      _friends = previousFriends;
      notifyListeners();
      debugPrint('Failed to delete friend docs for $friendUid: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> setLocalNickname(String friendUid, String nickname) async {
    if (_uid.isEmpty) return;

    // Optimistic
    _friends = _friends.map((f) {
      if (f.uid == friendUid) return f.copyWith(nickname: nickname);
      return f;
    }).toList();
    notifyListeners();

    await _db
        .collection('users')
        .doc(_uid)
        .collection('friends')
        .doc(friendUid)
        .update({'nickname': nickname});
  }

  // -----------------------------------------------------------------------
  // Messaging
  // -----------------------------------------------------------------------

  Future<void> sendTextMessage(
    String chatId,
    String text, {
    MessageModel? replyTo,
  }) async {
    if (_uid.isEmpty || text.trim().isEmpty) return;

    final now = DateTime.now();
    final participants = _participantsFromChatId(chatId);
    final friendUid = _friendUidFromParticipants(participants);
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    final chatRef = _db.collection('chats').doc(chatId);

    final message = MessageModel(
      id: msgRef.id,
      senderId: _uid,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 7)),
      type: 'text',
      payload: {'text': text.trim()},
      status: 'sent',
      replyToId: replyTo?.id,
      replyToSenderId: replyTo?.senderId,
      replyToPreview: replyTo == null ? null : _previewForMessage(replyTo),
    );

    // Optimistic
    _optimisticMessages.add(message);
    notifyListeners();

    try {
      final batch = _db.batch();
      batch.set(msgRef, message.toJson());
      batch.set(chatRef, <String, dynamic>{
        'participants': participants,
        'lastMessage': text.trim(),
        'lastMessageSenderId': _uid,
        'lastMessageTime': Timestamp.fromDate(now),
        if (friendUid.isNotEmpty)
          'unreadCount_$friendUid': FieldValue.increment(1),
        'isTyping_$_uid': false,
      }, SetOptions(merge: true));
      await batch.commit();

      _optimisticMessages.removeWhere((m) => m.id == message.id);
      notifyListeners();
    } catch (e, st) {
      _optimisticMessages.removeWhere((m) => m.id == message.id);
      notifyListeners();
      debugPrint('Failed to send text message in chat $chatId: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> sendWidgetMessage(
    String chatId,
    String type,
    Map<String, dynamic> payload,
  ) async {
    if (_uid.isEmpty) return;

    final now = DateTime.now();
    final participants = _participantsFromChatId(chatId);
    final friendUid = _friendUidFromParticipants(participants);
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    final chatRef = _db.collection('chats').doc(chatId);

    final message = MessageModel(
      id: msgRef.id,
      senderId: _uid,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 7)),
      type: type,
      payload: payload,
      status: 'sent',
    );

    // Optimistic
    _optimisticMessages.add(message);
    notifyListeners();

    try {
      final batch = _db.batch();
      batch.set(msgRef, message.toJson());
      batch.set(chatRef, <String, dynamic>{
        'participants': participants,
        'lastMessage': _widgetPreviewText(type, payload),
        'lastMessageSenderId': _uid,
        'lastMessageTime': Timestamp.fromDate(now),
        if (friendUid.isNotEmpty)
          'unreadCount_$friendUid': FieldValue.increment(1),
        'isTyping_$_uid': false,
      }, SetOptions(merge: true));
      await batch.commit();

      _optimisticMessages.removeWhere((m) => m.id == message.id);
      notifyListeners();
    } catch (e, st) {
      _optimisticMessages.removeWhere((m) => m.id == message.id);
      notifyListeners();
      debugPrint('Failed to send widget message in chat $chatId: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> clearChatHistory(String chatId) async {
    final messagesRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    // Page through all messages in chunks of `_maxBatchOps` so we never
    // exceed Firestore's 500-op WriteBatch limit, even on long chats.
    while (true) {
      final snapshot = await messagesRef.limit(_maxBatchOps).get();

      // Nothing left to delete -> exit cleanly.
      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Last partial page processed -> done.
      if (snapshot.docs.length < _maxBatchOps) return;
    }
  }

  /// Returns a real-time stream of messages for the given chatId.
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => MessageModel.fromJson(d.data())).toList(),
        );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> chatMetaStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  Future<void> markChatAsRead(String chatId) async {
    if (_uid.isEmpty) return;
    final chatRef = _db.collection('chats').doc(chatId);
    final unreadKey = 'unreadCount_$_uid';

    // Reset our own unread counter on the parent chat doc.
    try {
      await chatRef.set(<String, dynamic>{
        unreadKey: 0,
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      debugPrint('Failed to reset unread count on chat $chatId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    // Fetch every message in this chat that was sent by the OTHER user so we
    // can flip its status -> 'read' and stamp `readAt`.
    final QuerySnapshot<Map<String, dynamic>> unreadMessages;
    try {
      unreadMessages = await chatRef
          .collection('messages')
          .where('senderId', isNotEqualTo: _uid)
          .get();
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch unread messages in chat $chatId: $error');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }

    if (unreadMessages.docs.isEmpty) return;

    WriteBatch? batch;
    var ops = 0;
    for (final doc in unreadMessages.docs) {
      final data = doc.data();
      // Skip already-read messages so we do not produce no-op writes.
      if ((data['status'] as String? ?? 'sent') == 'read') continue;
      batch ??= _db.batch();
      batch.update(doc.reference, <String, dynamic>{
        'status': 'read',
        'readAt': FieldValue.serverTimestamp(),
      });
      ops++;
      if (ops == _maxBatchOps) {
        try {
          await batch.commit();
        } catch (error, stackTrace) {
          debugPrint(
            'Failed to commit read-receipt batch for chat $chatId: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
        batch = null;
        ops = 0;
      }
    }
    if (batch != null && ops > 0) {
      try {
        await batch.commit();
      } catch (error, stackTrace) {
        debugPrint(
          'Failed to commit final read-receipt batch for chat $chatId: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  String _sharedDayCacheKey({
    required String uid,
    required String weekId,
    required String dayId,
  }) => '$_sharedDayCachePrefix:$uid:$weekId:$dayId';

  List<Map<String, dynamic>> _decodeExercises(String? raw) {
    if (raw == null || raw.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> getCachedSharedDayExercises({
    required String uid,
    required String weekId,
    required String dayId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sharedDayCacheKey(uid: uid, weekId: weekId, dayId: dayId);
    return _decodeExercises(prefs.getString(key));
  }

  Future<void> _setCachedSharedDayExercises({
    required String uid,
    required String weekId,
    required String dayId,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sharedDayCacheKey(uid: uid, weekId: weekId, dayId: dayId);
    await prefs.setString(key, jsonEncode(exercises));
  }

  Future<List<Map<String, dynamic>>> _fetchSharedDayExercisesFromFirestore({
    required DocumentReference<Map<String, dynamic>> dayDocRef,
  }) async {
    final snap = await dayDocRef.get();
    final raw = (snap.data()?['exercises'] as List<dynamic>?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  bool _exerciseListsEqual(
    List<Map<String, dynamic>> first,
    List<Map<String, dynamic>> second,
  ) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (jsonEncode(first[i]) != jsonEncode(second[i])) return false;
    }
    return true;
  }

  Future<void> _syncSharedDayCacheInBackground({
    required String uid,
    required String weekId,
    required String dayId,
    required DocumentReference<Map<String, dynamic>> dayDocRef,
    required List<Map<String, dynamic>> currentCached,
  }) async {
    try {
      final remote = await _fetchSharedDayExercisesFromFirestore(
        dayDocRef: dayDocRef,
      );
      if (!_exerciseListsEqual(remote, currentCached)) {
        await _setCachedSharedDayExercises(
          uid: uid,
          weekId: weekId,
          dayId: dayId,
          exercises: remote,
        );
      }
    } catch (_) {
      // Silent background sync.
    }
  }

  Future<List<Map<String, dynamic>>> loadSharedDayExercisesWithCache({
    required String uid,
    required String weekId,
    required String dayId,
    required DocumentReference<Map<String, dynamic>> dayDocRef,
  }) async {
    final cached = await getCachedSharedDayExercises(
      uid: uid,
      weekId: weekId,
      dayId: dayId,
    );

    unawaited(
      _syncSharedDayCacheInBackground(
        uid: uid,
        weekId: weekId,
        dayId: dayId,
        dayDocRef: dayDocRef,
        currentCached: cached,
      ),
    );

    if (cached.isNotEmpty) return cached;

    final remote = await _fetchSharedDayExercisesFromFirestore(
      dayDocRef: dayDocRef,
    );
    await _setCachedSharedDayExercises(
      uid: uid,
      weekId: weekId,
      dayId: dayId,
      exercises: remote,
    );
    return remote;
  }

  Future<void> setTypingStatus(String chatId, bool isTyping) async {
    if (_uid.isEmpty) return;
    final participants = _participantsFromChatId(chatId);
    await _db.collection('chats').doc(chatId).set(<String, dynamic>{
      'participants': participants,
      'isTyping_$_uid': isTyping,
    }, SetOptions(merge: true));
  }

  // -----------------------------------------------------------------------
  // Fitness USP shares (PR )
  // -----------------------------------------------------------------------

  /// Sends a Personal Record bubble. The optional [previousBest] enables a
  /// "+15 kg from last PR" delta inside the bubble.
  Future<void> sendPRMessage(
    String chatId, {
    required String exerciseName,
    required double weight,
    required String unit,
    required int reps,
    double? previousBest,
  }) async {
    final previousBestEntry = previousBest == null
        ? null
        : <String, dynamic>{'previousBest': previousBest};
    await sendWidgetMessage(chatId, 'pr_share', <String, dynamic>{
      'exerciseName': exerciseName,
      'weight': weight,
      'unit': unit,
      'reps': reps,
      ...?previousBestEntry,
      'achievedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // -----------------------------------------------------------------------
  // Reactions / Delete
  // -----------------------------------------------------------------------

  /// Toggles a single emoji reaction on a message. If the current user has
  /// already reacted with that emoji, it is removed; otherwise it is added
  /// (replacing any other emoji from this user on the same message so each
  /// user only ever has one active reaction per message).
  Future<void> toggleReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    if (_uid.isEmpty || emoji.isEmpty) return;
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    try {
      await _db.runTransaction<void>((tx) async {
        final snap = await tx.get(msgRef);
        if (!snap.exists) return;
        final data = snap.data() ?? const <String, dynamic>{};
        final raw = (data['reactions'] as Map<dynamic, dynamic>?) ?? const {};

        final current = <String, List<String>>{};
        raw.forEach((key, value) {
          if (value is List) {
            current[key.toString()] = value.map((e) => e.toString()).toList();
          }
        });

        // Remove this UID from every emoji first (one reaction per user).
        for (final key in current.keys.toList()) {
          current[key] = current[key]!.where((u) => u != _uid).toList();
          if (current[key]!.isEmpty) current.remove(key);
        }

        // Was the user already on this emoji? `current` no longer has them, so
        // we determine 'toggle off' by comparing against the original list.
        final originalList =
            (raw[emoji] as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];
        final wasReacted = originalList.contains(_uid);

        if (!wasReacted) {
          current[emoji] = [...(current[emoji] ?? const <String>[]), _uid];
        }

        tx.update(msgRef, <String, dynamic>{'reactions': current});
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to toggle reaction on $messageId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Soft-deletes a message authored by the current user for everyone in the
  /// chat. The bubble will render as 'This message was deleted' on both
  /// sides and the chat preview is replaced.
  Future<void> deleteMessage(String chatId, MessageModel message) async {
    if (_uid.isEmpty || message.senderId != _uid) return;
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id);
    final chatRef = _db.collection('chats').doc(chatId);

    try {
      final batch = _db.batch();
      batch.update(msgRef, <String, dynamic>{
        'isDeleted': true,
        'payload': <String, dynamic>{'text': ''},
      });
      // If this was the latest preview, replace it.
      batch.set(chatRef, <String, dynamic>{
        'lastMessage': 'Message deleted',
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (error, stackTrace) {
      debugPrint('Failed to delete message ${message.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Hides a message from the current user's view only. The friend will
  /// still see it. Implemented by appending the current uid to the message's
  /// `deletedFor` array — the chat room filters messages whose `deletedFor`
  /// contains the local uid.
  Future<void> deleteMessageForMe(String chatId, String messageId) async {
    if (_uid.isEmpty || messageId.isEmpty) return;
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    try {
      await msgRef.update(<String, dynamic>{
        'deletedFor': FieldValue.arrayUnion(<String>[_uid]),
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to delete-for-me message $messageId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // -----------------------------------------------------------------------
  // Pin / Mute / Block
  // -----------------------------------------------------------------------

  Future<void> _setFriendFlag(
    String friendUid,
    String field,
    bool value,
  ) async {
    if (_uid.isEmpty || friendUid.isEmpty) return;

    // Optimistic local update.
    _friends = _friends.map((f) {
      if (f.uid != friendUid) return f;
      switch (field) {
        case 'isPinned':
          return f.copyWith(isPinned: value);
        case 'isMuted':
          return f.copyWith(isMuted: value);
        case 'isBlocked':
          return f.copyWith(isBlocked: value);
      }
      return f;
    }).toList();
    notifyListeners();

    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('friends')
          .doc(friendUid)
          .set(<String, dynamic>{field: value}, SetOptions(merge: true));

      if (field == 'isBlocked') {
        await _db.collection('users').doc(_uid).set(<String, dynamic>{
          'blockedUsers': value
              ? FieldValue.arrayUnion(<String>[friendUid])
              : FieldValue.arrayRemove(<String>[friendUid]),
        }, SetOptions(merge: true));
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to update $field on friend $friendUid: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> setPinnedFriend(String friendUid, bool isPinned) =>
      _setFriendFlag(friendUid, 'isPinned', isPinned);

  Future<void> setMutedFriend(String friendUid, bool isMuted) =>
      _setFriendFlag(friendUid, 'isMuted', isMuted);

  Future<void> setBlockedFriend(String friendUid, bool isBlocked) =>
      _setFriendFlag(friendUid, 'isBlocked', isBlocked);

  // -----------------------------------------------------------------------
  // User search (for friend discovery)
  // -----------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.trim().toLowerCase();

    final snap = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: lowerQuery)
        .where('username', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
        .limit(15)
        .get();

    return snap.docs.where((d) => d.id != _uid).map((d) {
      final data = d.data();
      data['uid'] = d.id;
      return data;
    }).toList();
  }

  /// Checks whether a friend request was already sent to [targetUid].
  Future<bool> hasPendingRequestTo(String targetUid) async {
    final doc = await _db
        .collection('users')
        .doc(targetUid)
        .collection('friend_requests')
        .doc(_uid)
        .get();
    return doc.exists;
  }

  // -----------------------------------------------------------------------
  // Cleanup
  // -----------------------------------------------------------------------

  @override
  void dispose() {
    _friendsSub?.cancel();
    _requestsSub?.cancel();
    _unreadChatsSub?.cancel();
    super.dispose();
  }

  List<String> _participantsFromChatId(String chatId) {
    final participants = chatId
        .split('_')
        .where((uid) => uid.isNotEmpty)
        .toList();
    if (!participants.contains(_uid) && _uid.isNotEmpty) {
      participants.add(_uid);
    }
    return participants.toSet().toList();
  }

  String _friendUidFromParticipants(List<String> participants) {
    for (final uid in participants) {
      if (uid != _uid) return uid;
    }
    return '';
  }

  String _widgetPreviewText(String type, Map<String, dynamic> payload) {
    if (type == 'meal_share') return '🍽 Shared a meal';
    if (type == 'exercise_share') return '💪 Shared a workout';
    if (type == 'pr_share') {
      final exercise = payload['exerciseName'] as String? ?? 'PR';
      final weight = payload['weight'];
      final unit = payload['unit'] as String? ?? 'kg';
      return '🏆 New PR: $exercise ${weight ?? ''}$unit';
    }
    if (type == 'streak_share') {
      final days = payload['streakDays'] ?? 0;
      return '🔥 $days-day streak';
    }
    if (type == 'challenge') {
      final title = payload['title'] as String? ?? 'Challenge';
      return '⚡ Challenge: $title';
    }
    if (type == 'text') return (payload['text'] as String? ?? '').trim();
    return 'Shared an item';
  }

  /// Short, single-line preview used inside reply chips.
  String _previewForMessage(MessageModel message) {
    if (message.isDeleted) return 'Message deleted';
    switch (message.type) {
      case 'meal_share':
        final name = message.payload['mealName'] as String? ?? 'a meal';
        return '🍽 Meal: $name';
      case 'exercise_share':
        final title =
            message.payload['title'] as String? ??
            message.payload['name'] as String? ??
            'a workout';
        return '💪 Workout: $title';
      case 'pr_share':
        final exercise = message.payload['exerciseName'] as String? ?? 'PR';
        final weight = message.payload['weight'];
        final unit = message.payload['unit'] as String? ?? 'kg';
        return '🏆 PR: $exercise ${weight ?? ''}$unit';
      default:
        final text = (message.payload['text'] as String? ?? '').trim();
        if (text.length <= 80) return text;
        return '${text.substring(0, 80)}…';
    }
  }
}
