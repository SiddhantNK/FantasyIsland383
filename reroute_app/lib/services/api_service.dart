import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // Default to localhost, configurable via UI settings if running on emulator / remote
  static String baseUrl = 'http://127.0.0.1:8000';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<Map<String, dynamic>> checkHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/health'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Server health check failed (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> getState() async {
    final response = await http.get(Uri.parse('$baseUrl/state'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load state: ${response.body}');
  }

  static Future<PlanModel?> getLatestPlan() async {
    final response = await http.get(Uri.parse('$baseUrl/plans/latest'), headers: _headers);
    if (response.statusCode == 200) {
      return PlanModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Failed to get latest plan: ${response.body}');
  }

  static Future<PlanModel> createInitialPlan() async {
    final response = await http.post(Uri.parse('$baseUrl/plans/initial'), headers: _headers);
    if (response.statusCode == 200) {
      return PlanModel.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Failed to generate initial plan');
  }

  static Future<PlanComparisonModel> getPlanComparison(int planId) async {
    final response = await http.get(Uri.parse('$baseUrl/plans/$planId/compare'), headers: _headers);
    if (response.statusCode == 200) {
      return PlanComparisonModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to compare plan #$planId: ${response.body}');
  }

  // --- Natural Language AI Parser
  static Future<Map<String, dynamic>> parseIncident(String text) async {
    final response = await http.post(
      Uri.parse('$baseUrl/incidents/parse'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 501) {
      throw Exception('Gemini AI Parser is not connected on backend (GEMINI_API_KEY missing in .env)');
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Failed to parse incident');
  }

  // --- Submit Incident (Form or AI)
  static Future<DisruptionModel> submitIncident(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/incidents'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      return DisruptionModel.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Failed to submit incident');
  }

  static Future<List<DisruptionModel>> getIncidents({String? status}) async {
    final url = status != null ? '$baseUrl/incidents?status=$status' : '$baseUrl/incidents';
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((item) => DisruptionModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to list incidents');
  }

  static Future<DisruptionModel> updateIncident(int id, Map<String, dynamic> corrections) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/incidents/$id'),
      headers: _headers,
      body: jsonEncode({'corrections': corrections}),
    );
    if (response.statusCode == 200) {
      return DisruptionModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update incident #$id');
  }

  static Future<Map<String, dynamic>> confirmIncident(int id, {Map<String, dynamic>? corrections}) async {
    final payload = corrections != null ? {'corrections': corrections} : {};
    final response = await http.post(
      Uri.parse('$baseUrl/incidents/$id/confirm'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    final errorsList = err['errors'];
    final errorMsg = errorsList is List && errorsList.isNotEmpty
        ? errorsList.join("; ")
        : (err['detail'] ?? 'Failed to confirm incident');
    throw Exception(errorMsg);
  }

  static Future<DisruptionModel> rejectIncident(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/incidents/$id/reject'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return DisruptionModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to reject incident #$id');
  }

  static Future<List<HistoryModel>> getHistory() async {
    final response = await http.get(Uri.parse('$baseUrl/history'), headers: _headers);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((item) => HistoryModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load history');
  }

  static Future<void> resetDemo() async {
    final response = await http.post(Uri.parse('$baseUrl/admin/reset'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to reset demo');
    }
  }
}
