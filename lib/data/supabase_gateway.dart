import 'package:supabase_flutter/supabase_flutter.dart';
import 'sync_service.dart';

class SupabaseRemoteGateway implements RemoteGateway {
  final SupabaseClient _client;
  SupabaseRemoteGateway(this._client);

  @override
  bool get isConfigured => true;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  String? get userEmail => _client.auth.currentUser?.email;

  @override
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp(String email, String password) async {
    final response = await _client.auth.signUp(email: email, password: password);
    return response.session != null;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final ownerId = userId;
    if (ownerId == null) throw StateError('Sign in before syncing.');
    final ownedRows = rows.map((row) => {...row, 'user_id': ownerId}).toList();
    await _client.from(table).upsert(ownedRows, onConflict: 'user_id,id');
  }

  @override
  Future<void> remove(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    if (userId == null) throw StateError('Sign in before syncing.');
    await _client.from(table).delete().inFilter('id', ids);
  }

  @override
  Future<void> removeRelated(String table, String column, String value) async {
    if (userId == null) throw StateError('Sign in before syncing.');
    await _client.from(table).delete().eq(column, value);
  }

  @override
  Future<List<Map<String, Object?>>> fetchAll(String table) async {
    if (userId == null) throw StateError('Sign in before syncing.');
    const pageSize = 500;
    final rows = <Map<String, Object?>>[];
    var start = 0;
    while (true) {
      final page = await _client.from(table).select().order('id').range(start, start + pageSize - 1);
      rows.addAll(page.map((row) => Map<String, Object?>.from(row)));
      if (page.length < pageSize) return rows;
      start += pageSize;
    }
  }
}
