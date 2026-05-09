import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_models.dart';

class ChatProvider extends ChangeNotifier {
  // Firestore batch writes support up to 500 operations.
  // Use a lower ceiling to leave headroom and avoid accidental overflows.
  static const int _maxBatchOps = 450;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // -----------------------------------------------------------------------
  // Local state
  // -----------------------------------------------------------------------

  List<FriendModel> _friends = [];
  List<FriendModel> get friends => List.unmodifiable(_friends);

  List<FriendRequestModel> _pendingRequests = [];
  List<FriendRequestModel> get pendingRequests =>
      List.unmodifiable(_pendingRequests);

  int get pendingRequestCount => _pendingRequests.length;

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
          _pendingRequests = snap.docs.map((d) {
            final data = d.data();
            data['senderUid'] = d.id;
            return FriendRequestModel.fromJson(data);
          }).toList();
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

    // Optimistic local mutation (UI is only notified after successful commit).
    _pendingRequests = _pendingRequests
        .where((r) => r.senderUid != senderUid)
        .toList();

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
      notifyListeners();
    } catch (e, st) {
      _pendingRequests = previousRequests;
      notifyListeners();
      debugPrint('Failed to accept friend request from $senderUid: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> declineFriendRequest(String senderUid) async {
    if (_uid.isEmpty) return;

    // Optimistic
    _pendingRequests = _pendingRequests
        .where((r) => r.senderUid != senderUid)
        .toList();
    notifyListeners();

    await _db
        .collection('users')
        .doc(_uid)
        .collection('friend_requests')
        .doc(senderUid)
        .delete();
  }

  Future<void> removeFriend(String friendUid) async {
    if (_uid.isEmpty) return;

    final previousFriends = List<FriendModel>.from(_friends);

    // Optimistic
    _friends = _friends.where((f) => f.uid != friendUid).toList();
    notifyListeners();

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
      debugPrint('Failed to delete friend records for $friendUid: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    try {
      final chatId = buildChatId(_uid, friendUid);
      await clearChatHistory(chatId);
    } catch (error, stackTrace) {
      debugPrint(
        'Friend removed but chat history clear failed for $friendUid: $error',
      );
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

  Future<void> sendTextMessage(String chatId, String text) async {
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

    while (true) {
      final snapshot = await messagesRef.limit(_maxBatchOps).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

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

    await chatRef.set(<String, dynamic>{unreadKey: 0}, SetOptions(merge: true));

    final unreadMessages = await chatRef
        .collection('messages')
        .where('senderId', isNotEqualTo: _uid)
        .get();

    if (unreadMessages.docs.isEmpty) return;

    WriteBatch? batch;
    var ops = 0;
    for (final doc in unreadMessages.docs) {
      final data = doc.data();
      if ((data['status'] as String? ?? 'sent') == 'read') continue;
      batch ??= _db.batch();
      batch.update(doc.reference, <String, dynamic>{
        'status': 'read',
        'readAt': FieldValue.serverTimestamp(),
      });
      ops++;
      if (ops == _maxBatchOps) {
        await batch.commit();
        batch = null;
        ops = 0;
      }
    }
    if (batch != null && ops > 0) {
      await batch.commit();
    }
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
    if (type == 'meal_share') return 'Shared a meal';
    if (type == 'exercise_share') return 'Shared a workout';
    if (type == 'text') return (payload['text'] as String? ?? '').trim();
    return 'Shared an item';
  }
}
