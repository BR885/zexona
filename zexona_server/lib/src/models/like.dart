import 'package:serverpod/serverpod.dart';

class Like extends Table {
  IntColumn get id => int().autoIncrement();
  StringColumn get userId => string();
  StringColumn get postId => string();
  DateTimeColumn get createdAt => dateTime();
}