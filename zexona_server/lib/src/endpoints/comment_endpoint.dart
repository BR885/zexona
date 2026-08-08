import 'package:serverpod/serverpod.dart';
import '../models/comment.dart';

class CommentEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  Future<String> addComment(Session session, String userId, String postId, String text) async {
    var comment = Comment();
    comment.userId = userId;
    comment.postId = postId;
    comment.text = text;
    comment.createdAt = DateTime.now();
    await Comment.db.insert(session, comment);
    return 'comment_added';
  }

  Future<List<Comment>> getComments(Session session, String postId) async {
    var comments = await Comment.db.find(
      session,
      where: (t) => t.postId.equals(postId),
      orderBy: (t) => t.createdAt,
    );
    return comments;
  }
}