import 'dart:io';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_google/serverpod_auth_google.dart';
import 'generated/protocol.dart';
import 'src/endpoints/auth_endpoint.dart';

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

  // Register Google Auth
  pod.registerModule(GoogleAuthModule());

  print('🚀 Zexona server starting on port 8082...');
  await pod.start(port: 8082);
  print('✅ Server running on http://localhost:8082');
  await stdin.first;
}