import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SpaeRepository {
  SpaeRepository(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> trainings() async =>
      List<Map<String, dynamic>>.from(await _client.from('trainings').select().order('start_date'));

  Future<Map<String, dynamic>> publicLookup(String term) async =>
      Map<String, dynamic>.from(await _client.rpc('public_participant_lookup', params: {'lookup_value': term}));

  Future<void> createEnrollment(Map<String, dynamic> values) async {
    await _client.from('enrollments').insert(values);
  }

  Future<String> uploadReceipt({required Uint8List bytes, required String extension}) async {
    final userId = _client.auth.currentUser?.id ?? 'public';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('payment-receipts').uploadBinary(path, bytes);
    return path;
  }

  Future<List<Map<String, dynamic>>> table(String name, {String? orderBy}) async {
    var query = _client.from(name).select();
    final result = orderBy == null ? await query : await query.order(orderBy, ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> insert(String table, Map<String, dynamic> values) async {
    await _client.from(table).insert(values);
  }

  Future<void> update(String table, String id, Map<String, dynamic> values) async {
    await _client.from(table).update(values).eq('id', id);
  }

  Future<void> approveEnrollment(String id, {String? reason}) async {
    await _client.from('enrollments').update({
      'status': reason == null ? 'approved' : 'rejected',
      'rejection_reason': reason,
    }).eq('id', id);
  }

  Future<void> registerAttendance({
    required String sessionId,
    required String enrollmentId,
    required bool present,
  }) async {
    await _client.from('attendance').upsert({
      'session_id': sessionId,
      'enrollment_id': enrollmentId,
      'status': present ? 'present' : 'absent',
    }, onConflict: 'session_id,enrollment_id');
  }
}
