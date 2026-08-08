import 'package:serverpod/serverpod.dart';

class AuthEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  // Send verification code (test mode - accepts any code)
  Future<bool> sendCode(Session session, String phone) async {
    print('📱 Phone number received: $phone');
    print('✅ Verification code: 123456 (use this to login)');
    
    // Store the phone in session for later verification
    session.put('pendingPhone', phone);
    
    return true;
  }

  // Verify the code (test mode - accepts 123456)
  Future<Map<String, dynamic>> verifyCode(Session session, String phone, String code) async {
    print('📱 Verifying $phone with code: $code');
    
    // For testing: accept 123456
    if (code == '123456') {
      print('✅ Login successful!');
      
      // Store user session
      session.put('isLoggedIn', true);
      session.put('userId', DateTime.now().millisecondsSinceEpoch);
      
      return {
        'success': true,
        'message': 'Login successful',
        'userId': session.get('userId'),
      };
    }
    
    print('❌ Invalid code');
    return {
      'success': false,
      'message': 'Invalid verification code',
    };
  }
}