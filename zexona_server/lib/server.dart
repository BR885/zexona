import 'dart:io';
import 'package:serverpod/serverpod.dart';
import 'generated/protocol.dart';

void run(List<String> args) async {
  var pod = Serverpod(
    args,
    Protocol(),
    DatabaseConfig(
      database: 'zexona',
      username: 'postgres',
      password: 'postgres',
      host: 'localhost',
      port: 5432,
    ),
  );

  print('🚀 Zexona server starting on port 8082...');
  await pod.start(port: 8082);
  print('✅ Server running on http://localhost:8082');
  await stdin.first;
}