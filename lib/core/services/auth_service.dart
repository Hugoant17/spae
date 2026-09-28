import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService(this._client);
  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signUpMember({
    required String email,
    required String password,
    required String fullName,
    required String dni,
    required String phone,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'dni': dni,
        'phone': phone,
        'role': UserRole.member.name,
      },
    );
  }

  Future<AppUser> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    final row = await _client.from('profiles').select().eq('id', response.user!.id).single();
    if(row['enabled']!=true){await signOut();throw const AuthException('Cuenta desactivada.');}
    return AppUser.fromMap(row);
  }

  Future<void> resetPassword(String email) => _client.auth.resetPasswordForEmail(email);
  Future<void> signOut() => _client.auth.signOut();
}

