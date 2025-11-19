import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bump_app/models/user_profile.dart';
import 'package:bump_app/models/friend_request.dart';

/// Social Service
///
/// Handles all social features including profiles, friend requests, and friendships
class SocialService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create or update user profile
  Future<UserProfile?> upsertProfile({
    required String userId,
    required String displayName,
    String? bio,
    String? avatarUrl,
    List<String>? interests,
  }) async {
    try {
      final response = await _supabase.from('profiles').upsert({
        'user_id': userId,
        'display_name': displayName,
        'bio': bio,
        'avatar_url': avatarUrl,
        'interests': interests ?? [],
      }).select().single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('프로필 업데이트 오류: $e');
      return null;
    }
  }

  /// Get user profile by user ID
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('프로필 조회 오류: $e');
      return null;
    }
  }

  /// Send friend request
  Future<FriendRequest?> sendFriendRequest({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final response = await _supabase.from('friend_requests').insert({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'status': 'pending',
      }).select().single();

      return FriendRequest.fromJson(response);
    } catch (e) {
      print('친구 요청 전송 오류: $e');
      return null;
    }
  }

  /// Get pending friend requests (received)
  Future<List<FriendRequestWithProfile>> getPendingRequests(
      String userId) async {
    try {
      final response = await _supabase
          .from('friend_requests')
          .select('*, sender:profiles!sender_id(*)')
          .eq('receiver_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        return FriendRequestWithProfile(
          request: FriendRequest.fromJson(item),
          profile: UserProfile.fromJson(item['sender']),
        );
      }).toList();
    } catch (e) {
      print('대기 중인 친구 요청 조회 오류: $e');
      return [];
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      return true;
    } catch (e) {
      print('친구 요청 수락 오류: $e');
      return false;
    }
  }

  /// Reject friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);

      return true;
    } catch (e) {
      print('친구 요청 거부 오류: $e');
      return false;
    }
  }

  /// Get list of friends
  Future<List<UserProfile>> getFriends(String userId) async {
    try {
      // Query friendships where user is either user1 or user2
      final response = await _supabase
          .from('friendships')
          .select('user1_id, user2_id, user1:profiles!user1_id(*), user2:profiles!user2_id(*)')
          .or('user1_id.eq.$userId,user2_id.eq.$userId');

      final friends = <UserProfile>[];
      for (final item in response as List) {
        // Get the friend's profile (the one that's not the current user)
        if (item['user1_id'] == userId) {
          friends.add(UserProfile.fromJson(item['user2']));
        } else {
          friends.add(UserProfile.fromJson(item['user1']));
        }
      }

      return friends;
    } catch (e) {
      print('친구 목록 조회 오류: $e');
      return [];
    }
  }

  /// Get friend suggestions based on bumps and mutual friends
  Future<List<UserProfile>> getFriendSuggestions(
      String userId, {int limit = 10}) async {
    try {
      final response = await _supabase.rpc(
        'get_friend_suggestions',
        params: {
          'current_user_id': userId,
          'limit_count': limit,
        },
      );

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('친구 추천 조회 오류: $e');
      return [];
    }
  }

  /// Search users by display name
  Future<List<UserProfile>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .ilike('display_name', '%$query%')
          .limit(20);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      print('사용자 검색 오류: $e');
      return [];
    }
  }

  /// Check if two users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final user1 = userId1.compareTo(userId2) < 0 ? userId1 : userId2;
      final user2 = userId1.compareTo(userId2) < 0 ? userId2 : userId1;

      final response = await _supabase
          .from('friendships')
          .select('id')
          .eq('user1_id', user1)
          .eq('user2_id', user2)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('친구 관계 확인 오류: $e');
      return false;
    }
  }

  /// Remove friendship
  Future<bool> removeFriend(String userId1, String userId2) async {
    try {
      final user1 = userId1.compareTo(userId2) < 0 ? userId1 : userId2;
      final user2 = userId1.compareTo(userId2) < 0 ? userId2 : userId1;

      await _supabase
          .from('friendships')
          .delete()
          .eq('user1_id', user1)
          .eq('user2_id', user2);

      return true;
    } catch (e) {
      print('친구 삭제 오류: $e');
      return false;
    }
  }
}
