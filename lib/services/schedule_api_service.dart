import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/schedule_item.dart';
import 'api_config.dart';

abstract class ScheduleRepository {
  Future<List<ScheduleItem>> fetchSchedules({ScheduleCategory? category});

  Future<ScheduleItem> createSchedule(ScheduleDraft draft);

  Future<ScheduleItem> updateSchedule(int id, ScheduleDraft draft);

  Future<void> deleteSchedule(int id);
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScheduleApiService implements ScheduleRepository {
  ScheduleApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _buildUri(
      [Map<String, String?> queryParameters = const <String, String?>{}]) {
    final Map<String, String> filteredQuery = <String, String>{};
    queryParameters.forEach((String key, String? value) {
      if (value != null && value.isNotEmpty) {
        filteredQuery[key] = value;
      }
    });

    final Uri baseUri = Uri.parse('${ApiConfig.baseUrl}/schedules.php');
    return baseUri.replace(
      queryParameters: filteredQuery.isEmpty ? null : filteredQuery,
    );
  }

  @override
  Future<List<ScheduleItem>> fetchSchedules(
      {ScheduleCategory? category}) async {
    final http.Response response = await _client.get(
      _buildUri(<String, String?>{'category': category?.value}),
      headers: _headers,
    );

    final Map<String, dynamic> payload = _decodePayload(response);
    final List<dynamic> items =
        payload['data'] as List<dynamic>? ?? <dynamic>[];
    return items
        .map((dynamic item) =>
        ScheduleItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ScheduleItem> createSchedule(ScheduleDraft draft) async {
    final http.Response response = await _client.post(
      _buildUri(),
      headers: _headers,
      body: jsonEncode(draft.toJson()),
    );

    final Map<String, dynamic> payload = _decodePayload(response);
    return ScheduleItem.fromJson(payload['data'] as Map<String, dynamic>);
  }

  @override
  Future<ScheduleItem> updateSchedule(int id, ScheduleDraft draft) async {
    final http.Response response = await _client.put(
      _buildUri(<String, String?>{'id': '$id'}),
      headers: _headers,
      body: jsonEncode(draft.toJson()),
    );

    final Map<String, dynamic> payload = _decodePayload(response);
    return ScheduleItem.fromJson(payload['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteSchedule(int id) async {
    final http.Response response = await _client.delete(
      _buildUri(<String, String?>{'id': '$id'}),
      headers: _headers,
    );

    _decodePayload(response);
  }

  Map<String, dynamic> _decodePayload(http.Response response) {
    final Map<String, dynamic> payload =
    jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        payload['message'] as String? ?? 'Permintaan ke server gagal.',
      );
    }

    final bool success = payload['success'] as bool? ?? false;
    if (!success) {
      throw ApiException(
        payload['message'] as String? ??
            'Server mengembalikan respons tidak valid.',
      );
    }

    return payload;
  }

  Map<String, String> get _headers {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }
}
