import 'package:serverpod/serverpod.dart';

class Comment extends Table {
  IntColumn get id => int().autoIncrement();
  StringColumn get userId => string();
  StringColumn get postId => string();
  StringColumn get text => string();
  DateTimeColumn get createdAt => dateTime();
}