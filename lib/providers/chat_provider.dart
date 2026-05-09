import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_models.dart';

class ChatProvider extends ChangeNotifier {
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

  // Optimistic send queue so messages render instantly.
  final List<MessageModel> _optimisticMessages = [];
  List<MessageModel> get optimisticMessages =>
      List.unmodifiable(_optimisticMessages);

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

    // Optimistic: remove from local list immediately
    _pendingRequests = _pendingRequests
        .where((r) => r.senderUid != senderUid)
        .toList();
    notifyListeners();

    // Fetch sender profile
    final senderDoc = await _db.collection('users').doc(senderUid).get();
    final senderData = senderDoc.data() ?? {};

    final myDoc = await _db.collection('users').doc(_uid).get();
    final myData = myDoc.data() ?? {};

    final batch = _db.batch();

    // Add friend to my list
    final myFriendRef = _db
        .collection('users')
        .doc(_uid)
        .collection('friends')
        .doc(senderUid);
    batch.set(myFriendRef, FriendModel(
      uid: senderUid,
      displayName: senderData['display_name'] as String? ?? '',
      username: senderData['username'] as String? ?? '',
      photoUrl: senderData['photo_url'] as String? ?? '',
    ).toJson());

    // Add me to sender's list
    final theirFriendRef = _db
        .collection('users')
        .doc(senderUid)
        .collection('friends')
        .doc(_uid);
    batch.set(theirFriendRef, FriendModel(
      uid: _uid,
      displayName: myData['display_name'] as String? ?? '',
      username: myData['username'] as String? ?? '',
      photoUrl: myData['photo_url'] as String? ?? '',
    ).toJson());

    // Delete the pending request
    final requestRef = _db
        .collection('users')
        .doc(_uid)
        .collection('friend_requests')
        .doc(senderUid);
    batch.delete(requestRef);

    await batch.commit();
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

    // Optimistic
    _friends = _friends.where((f) => f.uid != friendUid).toList();
    notifyListeners();

    final batch = _db.batch();
    batch.delete(
      _db.collection('users').doc(_uid).collection('friends').doc(friendUid),
    );
    batch.delete(
      _db.collection('users').doc(friendUid).collection('friends').doc(_uid),
    );
    await batch.commit();
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
    final msgRef = _db.collection('chats').doc(chatId).collection('messages').doc();

    final message = MessageModel(
      id: msgRef.id,
      senderId: _uid,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 7)),
      type: 'text',
      payload: {'text': text.trim()},
    );

    // Optimistic
    _optimisticMessages.add(message);
    notifyListeners();

    await msgRef.set(message.toJson());

    _optimisticMessages.removeWhere((m) => m.id == message.id);
    notifyListeners();
  }

  Future<void> sendWidgetMessage(
    String chatId,
    String type,
    Map<String, dynamic> payload,
  ) async {
    if (_uid.isEmpty) return;

    final now = DateTime.now();
    final msgRef = _db.collection('chats').doc(chatId).collection('messages').doc();

    final message = MessageModel(
      id: msgRef.id,
      senderId: _uid,
      timestamp: now,
      expiresAt: now.add(const Duration(days: 7)),
      type: type,
      payload: payload,
    );

    // Optimistic
    _optimisticMessages.add(message);
    notifyListeners();

    await msgRef.set(message.toJson());

    _optimisticMessages.removeWhere((m) => m.id == message.id);
    notifyListeners();
  }

  Future<void> clearChatHistory(String chatId) async {
    final messagesRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages');
    final snapshot = await messagesRef.get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Returns a real-time stream of messages for the given chatId.
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MessageModel.fromJson(d.data()))
            .toList());
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

    return snap.docs
        .where((d) => d.id != _uid)
        .map((d) {
          final data = d.data();
          data['uid'] = d.id;
          return data;
        })
        .toList();
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
    super.dispose();
  }
}
