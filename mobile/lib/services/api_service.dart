import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  ApiService({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_URL',
              defaultValue: 'http://10.0.2.2:8000',
            );

  final String baseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  WebSocketChannel? _channel;

  Future<String?> get token => _storage.read(key: 'access_token');

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final accessToken = await token;
      if (accessToken == null) {
        throw const ApiException('Please sign in again.');
      }
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final uri = Uri.parse('$baseUrl$path');
    final response = switch (method) {
      'POST' => await http.post(uri, headers: headers, body: jsonEncode(body)),
      _ => await http.get(uri, headers: headers),
    };
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        (decoded is Map<String, dynamic> ? decoded['detail']?.toString() : null) ??
            'Request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _request(
      '/auth/login',
      method: 'POST',
      authenticated: false,
      body: {'email': email, 'password': password},
    );
    await _storage.write(
      key: 'access_token',
      value: (result as Map<String, dynamic>)['access_token'] as String,
    );
    return me();
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    await _request(
      '/auth/register',
      method: 'POST',
      authenticated: false,
      body: {'email': email, 'password': password},
    );
    return login(email, password);
  }

  Future<Map<String, dynamic>> me() async =>
      await _request('/auth/me') as Map<String, dynamic>;

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _channel?.sink.close();
    _channel = null;
  }

  Future<Map<String, dynamic>> portfolio() async =>
      await _request('/trading/portfolio') as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> history() async =>
      _list(await _request('/trading/history'));

  Future<List<Map<String, dynamic>>> blocks() async =>
      _list(await _request('/blockchain/blocks'));

  Future<Map<String, dynamic>> merkleProof(String transactionId) async =>
      await _request('/blockchain/merkle/$transactionId') as Map<String, dynamic>;

  Future<Map<String, dynamic>> simulateTampering({
    required String transactionId,
    required String replacementQuantity,
  }) async =>
      await _request(
        '/blockchain/simulate-tampering',
        method: 'POST',
        body: {
          'transaction_id': transactionId,
          'replacement_quantity': replacementQuantity,
        },
      ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> trade(String side, String amount) async =>
      await _request('/trading/$side', method: 'POST', body: {'btc_quantity': amount})
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> verify(String identifier) async =>
      await _request(
        '/blockchain/verify-transaction',
        method: 'POST',
        body: RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(identifier)
            ? {'transaction_hash': identifier}
            : {'transaction_id': identifier},
      ) as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> audit() async =>
      _list(await _request('/audit/history'));

  Future<Map<String, dynamic>> adminDashboard() async =>
      await _request('/admin/dashboard') as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> adminUsers() async =>
      _list(await _request('/admin/users'));

  Future<Stream<dynamic>?> connectBlockchain() async {
    final accessToken = await token;
    if (accessToken == null) return null;
    final uri = Uri.parse(baseUrl).replace(
      scheme: baseUrl.startsWith('https') ? 'wss' : 'ws',
      path: '/ws/blockchain',
      queryParameters: {'token': accessToken},
    );
    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready;
    return _channel!.stream;
  }

  List<Map<String, dynamic>> _list(dynamic response) {
    if (response is! List<dynamic>) {
      throw const ApiException('The API returned an unexpected list response.');
    }
    return response
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
