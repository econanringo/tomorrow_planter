import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'models.dart';

class ApiClient {
  ApiClient({http.Client? client, FirebaseAuth? auth})
      : _client = client ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  final http.Client _client;
  final FirebaseAuth _auth;

  Future<Map<String, String>> _headers() async {
    final user = _auth.currentUser;
    final token = await user?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.backendUrl}$path');

  Future<StartReflectionResponse> startReflection() async {
    final res = await _client.post(
      _uri('/v1/sessions/reflection'),
      headers: await _headers(),
    );
    _ensureOk(res);
    return StartReflectionResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Stream<AgentSseEvent> postReflectionMessage({
    required String sessionId,
    required String message,
  }) async* {
    yield* _ssePost(
      '/v1/sessions/$sessionId/messages',
      body: {'message': message},
    );
  }

  Stream<AgentSseEvent> startDiscussion({required String sessionId}) async* {
    yield* _ssePost('/v1/sessions/$sessionId/discuss');
  }

  Stream<AgentSseEvent> interveneDiscussion({
    required String sessionId,
    required String message,
  }) async* {
    yield* _ssePost(
      '/v1/sessions/$sessionId/discuss/intervene',
      body: {'message': message},
    );
  }

  Future<FinalizeResponse> finalize({required String sessionId}) async {
    final res = await _client.post(
      _uri('/v1/sessions/$sessionId/finalize'),
      headers: await _headers(),
    );
    _ensureOk(res);
    return FinalizeResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<TomorrowPlan> getTodayPlan() async {
    final res = await _client.get(
      _uri('/v1/plans/today'),
      headers: await _headers(),
    );
    _ensureOk(res);
    return TomorrowPlan.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> seedDemo() async {
    final res = await _client.post(
      _uri('/v1/demo/seed'),
      headers: await _headers(),
    );
    _ensureOk(res);
  }

  Stream<AgentSseEvent> _ssePost(
    String path, {
    Map<String, dynamic>? body,
  }) async* {
    final request = http.Request('POST', _uri(path));
    request.headers.addAll(await _headers());
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final err = await response.stream.bytesToString();
      throw ApiException(response.statusCode, err);
    }

    final buffer = StringBuffer();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      var content = buffer.toString();
      while (true) {
        final idx = content.indexOf('\n\n');
        if (idx < 0) break;
        final block = content.substring(0, idx).trim();
        content = content.substring(idx + 2);
        buffer
          ..clear()
          ..write(content);
        for (final line in block.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          final map = jsonDecode(payload) as Map<String, dynamic>;
          yield AgentSseEvent.fromJson(map);
        }
      }
    }
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, res.body);
    }
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}
