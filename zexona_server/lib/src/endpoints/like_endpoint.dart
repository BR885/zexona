import 'package:serverpod/serverpod.dart';
import '../models/like.dart';

class LikeEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  Future<String> toggleLike(Session session, String userId, String postId) async {
    var existing = await Like.db.find(
      session,
      where: (t) => t.userId.equals(userId) & t.postId.equals(postId),
    );

    if (existing.isNotEmpty) {
      await Like.db.delete(session, existing.first);
      return 'unliked';
    } else {
      var like = Like();
      like.userId = userId;
      like.postId = postId;
      like.createdAt = DateTime.now();
      await Like.db.insert(session, like);
      return 'liked';
    }
  }

  Future<int> getLikeCount(Session session, String postId) async {
    var likes = await Like.db.find(
      session,
      where: (t) => t.postId.equals(postId),
    );
    return likes.length;
  }
}