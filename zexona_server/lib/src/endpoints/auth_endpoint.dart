import 'package:serverpod/serverpod.dart';

class AuthEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  Future<Map<String, dynamic>> sendCode(Session session, String phone) async {
    print('📱 Phone: $phone, Code: 123456');
    return {'success': true, 'code': '123456'};
  }

  Future<Map<String, dynamic>> verifyCode(Session session, String phone, String code) async {
    print('Verifying $phone with code: $code');
    return {'success': code == '123456'};
  }
}