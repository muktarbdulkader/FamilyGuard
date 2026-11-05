import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';

abstract interface class ChatRepository {
  Stream<List<ChatContact>> watchContacts(UserModel user);
  Stream<List<ChatConversation>> watchConversations(
    UserModel user,
    List<ChatContact> contacts,
  );
  Stream<String?> watchParticipantName(String userId);
  Future<String> ensureConversation({
    required String familyId,
    required String currentUserId,
    required UserRole currentUserRole,
    required String otherUserId,
  });
  Stream<List<ChatMessage>> watchRecentMessages(String conversationId);
  Future<List<ChatMessage>> loadOlderMessages({
    required String conversationId,
    required ChatMessage before,
  });
  Future<String> sendMessage({
    required String conversationId,
    required String familyId,
    required String senderId,
    required String recipientId,
    required String text,
    required String messageId,
    bool retry = false,
  });
  Future<void> markMessagesRead({
    required String conversationId,
    required String currentUserId,
    required Iterable<ChatMessage> messages,
  });
}

class ChatService implements ChatRepository {
  ChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static String conversationId({
    required String familyId,
    required String parentId,
    required String childId,
  }) {
    final key = '$familyId|$parentId|$childId';
    return 'chat_${sha256.convert(utf8.encode(key))}';
  }

  @override
  Stream<List<ChatContact>> watchContacts(UserModel user) {
    if (user.role == UserRole.parent) {
      return _watchParentFamilies(user.uid).asyncMap((snapshot) async {
        final contacts = <ChatContact>[];
        for (final familyDoc in snapshot) {
          final familyData = familyDoc.data() ?? const <String, dynamic>{};
          final childIds = List<String>.from(
            familyData['childIds'] ?? familyData['childrenIds'] ?? const [],
          );
          final childSnapshot = await _firestore
              .collection('users')
              .where('familyId', isEqualTo: familyDoc.id)
              .where('role', isEqualTo: UserRole.child.value)
              .get();
          final childProfilesById = {
            for (final doc in childSnapshot.docs) doc.id: doc.data(),
          };
          final childIdsToInclude = {...childIds, ...childProfilesById.keys};
          for (final childId in childIdsToInclude) {
            final childData =
                childProfilesById[childId] ??
                (await _firestore.collection('users').doc(childId).get())
                    .data();
            if (childData == null) continue;
            final displayName = (childData['displayName'] as String?)?.trim();
            contacts.add(
              ChatContact(
                familyId: familyDoc.id,
                userId: childId,
                displayName: displayName != null && displayName.isNotEmpty
                    ? displayName
                    : 'Child',
                isParent: false,
              ),
            );
          }
        }
        contacts.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
        return contacts;
      });
    }

    if (user.role != UserRole.child ||
        user.familyId == null ||
        user.familyId!.isEmpty) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('families')
        .doc(user.familyId)
        .snapshots()
        .asyncMap((familyDoc) async {
          if (!familyDoc.exists) return const <ChatContact>[];
          final familyData = familyDoc.data() ?? const <String, dynamic>{};
          final parentIds = List<String>.from(
            familyData['parentIds'] ??
                (familyData['parentId'] == null
                    ? const []
                    : [familyData['parentId']]),
          );
          final contacts = <ChatContact>[];
          for (final parentId in parentIds) {
            final parentDoc = await _firestore
                .collection('users')
                .doc(parentId)
                .get();
            final name = (parentDoc.data()?['displayName'] as String?)?.trim();
            contacts.add(
              ChatContact(
                familyId: familyDoc.id,
                userId: parentId,
                displayName: name != null && name.isNotEmpty ? name : 'Parent',
                isParent: true,
              ),
            );
          }
          return contacts;
        });
  }

  @override
  Stream<List<ChatConversation>> watchConversations(
    UserModel user,
    List<ChatContact> contacts,
  ) {
    final conversationsById = <String, ChatContact>{};
    for (final contact in contacts) {
      final parentId = user.role == UserRole.parent ? user.uid : contact.userId;
      final childId = user.role == UserRole.child ? user.uid : contact.userId;
      conversationsById.putIfAbsent(
        conversationId(
          familyId: contact.familyId,
          parentId: parentId,
          childId: childId,
        ),
        () => contact,
      );
    }
    if (conversationsById.isEmpty) return Stream.value(const []);

    final entries = conversationsById.entries.toList(growable: false);
    final latest = List<ChatConversation?>.filled(entries.length, null);
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    late final StreamController<List<ChatConversation>> controller;
    controller = StreamController<List<ChatConversation>>(
      onListen: () {
        for (var index = 0; index < entries.length; index++) {
          final contact = entries[index].value;
          final parentId = user.role == UserRole.parent
              ? user.uid
              : contact.userId;
          final childId = user.role == UserRole.child
              ? user.uid
              : contact.userId;
          final subscription = _firestore
              .collection('conversations')
              .where('familyId', isEqualTo: contact.familyId)
              .where('parentId', isEqualTo: parentId)
              .where('childId', isEqualTo: childId)
              .where('participantIds', arrayContains: user.uid)
              .limit(1)
              .snapshots()
              .listen((snapshot) {
                latest[index] = snapshot.docs.isEmpty
                    ? null
                    : ChatConversation.fromFirestore(snapshot.docs.first);
                final conversations =
                    latest.whereType<ChatConversation>().toList()
                      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                controller.add(conversations);
              }, onError: controller.addError);
          subscriptions.add(subscription);
        }
      },
      onCancel: () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      },
    );
    return controller.stream;
  }

  @override
  Stream<String?> watchParticipantName(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data()?['displayName'] as String?;
    });
  }

  @override
  Future<String> ensureConversation({
    required String familyId,
    required String currentUserId,
    required UserRole currentUserRole,
    required String otherUserId,
  }) async {
    if (familyId.isEmpty || currentUserId.isEmpty || otherUserId.isEmpty) {
      throw ArgumentError('Family and participant IDs are required.');
    }
    if (currentUserId == otherUserId) {
      throw ArgumentError('A conversation requires two different users.');
    }

    final parentId = currentUserRole == UserRole.parent
        ? currentUserId
        : otherUserId;
    final childId = currentUserRole == UserRole.child
        ? currentUserId
        : otherUserId;
    if (currentUserRole != UserRole.parent &&
        currentUserRole != UserRole.child) {
      throw StateError('Only linked parents and children can use chat.');
    }

    final id = conversationId(
      familyId: familyId,
      parentId: parentId,
      childId: childId,
    );
    final ref = _firestore.collection('conversations').doc(id);
    var exists = false;
    try {
      exists = (await ref.get()).exists;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied' && error.code != 'unavailable') {
        rethrow;
      }
    }
    if (!exists) {
      try {
        await ref.set({
          'familyId': familyId,
          'parentId': parentId,
          'childId': childId,
          'participantIds': [parentId, childId],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException {
        if (!(await ref.get()).exists) rethrow;
      }
    }
    return id;
  }

  @override
  Stream<List<ChatMessage>> watchRecentMessages(String conversationId) {
    return _messages(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ChatMessage.fromFirestore)
              .toList(growable: false),
        );
  }

  @override
  Future<List<ChatMessage>> loadOlderMessages({
    required String conversationId,
    required ChatMessage before,
  }) async {
    final cursor = before.snapshot;
    if (cursor == null) return const [];
    final snapshot = await _messages(conversationId)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(cursor)
        .limit(30)
        .get();
    return snapshot.docs.map(ChatMessage.fromFirestore).toList(growable: false);
  }

  @override
  Future<String> sendMessage({
    required String conversationId,
    required String familyId,
    required String senderId,
    required String recipientId,
    required String text,
    required String messageId,
    bool retry = false,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty || normalizedText.length > 4000) {
      throw ArgumentError('Messages must contain 1 to 4000 characters.');
    }
    final ref = _messages(conversationId).doc(messageId);
    if (retry) {
      final existing = await ref.get();
      if (existing.exists) {
        final data = existing.data() ?? const <String, dynamic>{};
        if (data['senderId'] == senderId && data['text'] == normalizedText) {
          return messageId;
        }
        throw StateError('This message identifier is already in use.');
      }
    }
    await ref.set({
      'messageId': messageId,
      'conversationId': conversationId,
      'familyId': familyId,
      'senderId': senderId,
      'recipientId': recipientId,
      'text': normalizedText,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
    return messageId;
  }

  @override
  Future<void> markMessagesRead({
    required String conversationId,
    required String currentUserId,
    required Iterable<ChatMessage> messages,
  }) async {
    final unreadMessages = messages
        .where(
          (message) =>
              message.recipientId == currentUserId && message.readAt == null,
        )
        .toList(growable: false);
    if (unreadMessages.isEmpty) return;

    final batch = _firestore.batch();
    for (final message in unreadMessages) {
      batch.update(_messages(conversationId).doc(message.id), {
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> _messages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');
  }

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _watchParentFamilies(
    String parentId,
  ) {
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    userSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    familySubscription;
    late final StreamController<List<DocumentSnapshot<Map<String, dynamic>>>>
    controller;
    controller = StreamController<List<DocumentSnapshot<Map<String, dynamic>>>>(
      onListen: () {
        userSubscription = _firestore
            .collection('users')
            .doc(parentId)
            .snapshots()
            .listen((userDocument) {
              final familyId = userDocument.data()?['familyId'] as String?;
              familySubscription?.cancel();
              if (familyId == null || familyId.isEmpty) {
                controller.add(const []);
                return;
              }
              familySubscription = _firestore
                  .collection('families')
                  .doc(familyId)
                  .snapshots()
                  .listen(
                    (familyDocument) => controller.add(
                      familyDocument.exists ? [familyDocument] : const [],
                    ),
                    onError: controller.addError,
                  );
            }, onError: controller.addError);
      },
      onCancel: () async {
        await userSubscription?.cancel();
        await familySubscription?.cancel();
      },
    );
    return controller.stream;
  }
}
