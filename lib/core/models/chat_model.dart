import 'package:cloud_firestore/cloud_firestore.dart';

class ChatContact {
  const ChatContact({
    required this.familyId,
    required this.userId,
    required this.displayName,
    required this.isParent,
  });

  final String familyId;
  final String userId;
  final String displayName;
  final bool isParent;
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.familyId,
    required this.parentId,
    required this.childId,
    required this.participantIds,
    required this.lastMessage,
    required this.lastSenderId,
    required this.updatedAt,
    required this.unreadCounts,
  });

  final String id;
  final String familyId;
  final String parentId;
  final String childId;
  final List<String> participantIds;
  final String lastMessage;
  final String? lastSenderId;
  final DateTime updatedAt;
  final Map<String, int> unreadCounts;

  int unreadCountFor(String userId) => unreadCounts[userId] ?? 0;

  factory ChatConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final updatedAt = data['updatedAt'];
    final rawUnreadCounts = data['unreadCounts'];

    return ChatConversation(
      id: snapshot.id,
      familyId: data['familyId'] as String? ?? '',
      parentId: data['parentId'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      participantIds: List<String>.from(data['participantIds'] ?? const []),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastSenderId: data['lastSenderId'] as String?,
      updatedAt: updatedAt is Timestamp
          ? updatedAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      unreadCounts: rawUnreadCounts is Map
          ? rawUnreadCounts.map(
              (key, value) => MapEntry(key.toString(), value as int? ?? 0),
            )
          : const {},
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.familyId,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.createdAt,
    required this.readAt,
    this.snapshot,
  });

  final String id;
  final String conversationId;
  final String familyId;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime createdAt;
  final DateTime? readAt;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];
    final readAt = data['readAt'];

    return ChatMessage(
      id: snapshot.id,
      conversationId: data['conversationId'] as String? ?? '',
      familyId: data['familyId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      recipientId: data['recipientId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      readAt: readAt is Timestamp ? readAt.toDate() : null,
      snapshot: snapshot,
    );
  }
}
