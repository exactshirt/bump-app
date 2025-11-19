import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bump_app/models/chat_room.dart';
import 'package:bump_app/models/message.dart';

/// Chat Service
///
/// Handles all chat-related functionality including rooms, messages, and real-time updates
class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get or create a chat room between two users
  Future<ChatRoom?> getOrCreateChatRoom({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_or_create_chat_room',
        params: {
          'user1_id': user1Id,
          'user2_id': user2Id,
        },
      );

      final roomId = response as String;

      // Fetch the full room data
      final roomResponse = await _supabase
          .from('chat_rooms')
          .select()
          .eq('id', roomId)
          .single();

      return ChatRoom.fromJson(roomResponse);
    } catch (e) {
      print('채팅방 생성/조회 오류: $e');
      return null;
    }
  }

  /// Get all chat rooms for a user
  Future<List<ChatRoom>> getChatRooms(String userId) async {
    try {
      final response = await _supabase
          .from('chat_rooms')
          .select()
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('last_message_at', ascending: false);

      return (response as List)
          .map((json) => ChatRoom.fromJson(json))
          .toList();
    } catch (e) {
      print('채팅방 목록 조회 오류: $e');
      return [];
    }
  }

  /// Send a message
  Future<Message?> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      final response = await _supabase.from('messages').insert({
        'chat_room_id': chatRoomId,
        'sender_id': senderId,
        'content': content,
        'message_type': messageType,
        'is_read': false,
      }).select().single();

      return Message.fromJson(response);
    } catch (e) {
      print('메시지 전송 오류: $e');
      return null;
    }
  }

  /// Get messages in a chat room
  Future<List<Message>> getMessages(
    String chatRoomId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('chat_room_id', chatRoomId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => Message.fromJson(json))
          .toList()
          .reversed
          .toList(); // Reverse to show oldest first
    } catch (e) {
      print('메시지 조회 오류: $e');
      return [];
    }
  }

  /// Mark messages as read
  Future<int> markMessagesAsRead({
    required String chatRoomId,
    required String userId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'mark_messages_as_read',
        params: {
          'in_chat_room_id': chatRoomId,
          'for_user_id': userId,
        },
      );

      return response as int;
    } catch (e) {
      print('메시지 읽음 표시 오류: $e');
      return 0;
    }
  }

  /// Get unread message count
  Future<int> getUnreadMessageCount(
    String userId, {
    String? chatRoomId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_unread_message_count',
        params: {
          'for_user_id': userId,
          'in_chat_room_id': chatRoomId,
        },
      );

      return response as int;
    } catch (e) {
      print('읽지 않은 메시지 수 조회 오류: $e');
      return 0;
    }
  }

  /// Subscribe to real-time messages in a chat room
  RealtimeChannel subscribeToMessages({
    required String chatRoomId,
    required void Function(Message message) onNewMessage,
  }) {
    final channel = _supabase
        .channel('messages:$chatRoomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_room_id',
            value: chatRoomId,
          ),
          callback: (payload) {
            final message = Message.fromJson(payload.newRecord);
            onNewMessage(message);
          },
        )
        .subscribe();

    return channel;
  }

  /// Subscribe to real-time updates for all user's chat rooms
  RealtimeChannel subscribeToChatRooms({
    required String userId,
    required void Function(ChatRoom room) onRoomUpdate,
  }) {
    final channel = _supabase
        .channel('chat_rooms:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_rooms',
          callback: (payload) {
            final room = ChatRoom.fromJson(payload.newRecord);
            // Only notify if this user is part of the room
            if (room.user1Id == userId || room.user2Id == userId) {
              onRoomUpdate(room);
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }
}
