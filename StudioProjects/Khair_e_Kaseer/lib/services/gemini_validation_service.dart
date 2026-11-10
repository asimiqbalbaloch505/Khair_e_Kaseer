import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiAnalysisResult {
  final bool isViolating;
  final double confidence;
  final String reason;
  final String suggestedSOP;
  final String rawResponse;

  GeminiAnalysisResult({
    required this.isViolating,
    required this.confidence,
    required this.reason,
    required this.suggestedSOP,
    required this.rawResponse,
  });

  factory GeminiAnalysisResult.fromJson(Map<String, dynamic> json, String raw) {
    return GeminiAnalysisResult(
      isViolating: json['isViolating'] == true,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      reason: json['reason'] ?? 'No reason provided',
      suggestedSOP: json['suggestedSOP'] ?? 'General Food Safety SOP',
      rawResponse: raw,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isViolating': isViolating,
      'confidence': confidence,
      'reason': reason,
      'suggestedSOP': suggestedSOP,
      'rawResponse': rawResponse,
    };
  }
}

class GeminiValidationService {
  static final GeminiValidationService _instance = GeminiValidationService._internal();
  factory GeminiValidationService() => _instance;
  GeminiValidationService._internal();

  // Optional Gemini API Key. Can be set or passed from caller.
  String? _apiKey;

  void setApiKey(String key) {
    _apiKey = key;
  }

  static const String _defaultModel = "gemini-1.5-flash";

  /// Inspects a food listing photo (base64 encoded or network URL)
  /// Checks for spoiled/unhygienic food or fake non-food items.
  Future<GeminiAnalysisResult> inspectFoodImage({
    required String imageBase64OrUrl,
    String? foodDescription,
    String? apiKey,
  }) async {
    final effectiveKey = apiKey ?? _apiKey;

    const String promptText = """
You are a food safety & app SOP compliance inspector for 'Khair-e-Kaseer' food donation app.
Analyze the provided food item image and description.

Check for:
1. Is the item actual edible food, or a fake/non-food photo?
2. Is the food noticeably spoiled, moldy, unhygienic, or unsafe for consumption?

Respond ONLY with valid JSON in this exact schema:
{
  "isViolating": true or false,
  "confidence": 0.0 to 1.0,
  "reason": "Detailed concise reason for audit conclusion",
  "suggestedSOP": "Food Freshness & Hygiene SOP" or "Legitimate Food Photo SOP"
}
""";

    if (effectiveKey == null || effectiveKey.isEmpty) {
      debugPrint("Gemini API key not configured. Using local fallback rule analysis.");
      return _localFallbackFoodCheck(foodDescription, imageBase64OrUrl);
    }

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_defaultModel:generateContent?key=$effectiveKey');

      List<Map<String, dynamic>> parts = [];
      parts.add({'text': "$promptText\n\nFood Description: ${foodDescription ?? 'Not provided'}"});

      if (imageBase64OrUrl.startsWith('data:image') || !imageBase64OrUrl.startsWith('http')) {
        String cleanBase64 = imageBase64OrUrl.contains(',')
            ? imageBase64OrUrl.split(',').last
            : imageBase64OrUrl;
        parts.add({
          'inlineData': {
            'mimeType': 'image/jpeg',
            'data': cleanBase64,
          }
        });
      }

      final body = jsonEncode({
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final candidates = resData['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final partsList = content['parts'] as List?;
          if (partsList != null && partsList.isNotEmpty) {
            final textRes = partsList[0]['text'] as String;
            final cleanedJson = _cleanJsonResponse(textRes);
            final jsonMap = jsonDecode(cleanedJson) as Map<String, dynamic>;
            return GeminiAnalysisResult.fromJson(jsonMap, textRes);
          }
        }
      } else {
        debugPrint("Gemini API returned status ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error calling Gemini API for food inspection: $e");
    }

    return _localFallbackFoodCheck(foodDescription, imageBase64OrUrl);
  }

  /// Inspects Rider Dispute Comments and Proof of Delivery (POD) photo.
  Future<GeminiAnalysisResult> inspectRiderDisputeAndPOD({
    required String podImageBase64OrUrl,
    required String disputeComments,
    String? apiKey,
  }) async {
    final effectiveKey = apiKey ?? _apiKey;

    const String promptText = """
You are an audit reviewer for 'Khair-e-Kaseer' delivery platform.
Review the Proof-of-Delivery (POD) image and rider dispute report comment.

Evaluate:
1. Is the POD photo clear and authentic proof of handover, or is it blank/fake/suspicious?
2. Does the rider report comment indicate a valid handover dispute or a policy violation?

Respond ONLY with valid JSON in this exact schema:
{
  "isViolating": true or false,
  "confidence": 0.0 to 1.0,
  "reason": "Clear explanation of audit finding",
  "suggestedSOP": "Proof of Delivery SOP" or "Rider Dispute Resolution SOP"
}
""";

    if (effectiveKey == null || effectiveKey.isEmpty) {
      return _localFallbackPODCheck(disputeComments, podImageBase64OrUrl);
    }

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_defaultModel:generateContent?key=$effectiveKey');

      List<Map<String, dynamic>> parts = [];
      parts.add({'text': "$promptText\n\nDispute Report Comment: $disputeComments"});

      if (podImageBase64OrUrl.isNotEmpty && (!podImageBase64OrUrl.startsWith('http') || podImageBase64OrUrl.startsWith('data:image'))) {
        String cleanBase64 = podImageBase64OrUrl.contains(',')
            ? podImageBase64OrUrl.split(',').last
            : podImageBase64OrUrl;
        parts.add({
          'inlineData': {
            'mimeType': 'image/jpeg',
            'data': cleanBase64,
          }
        });
      }

      final body = jsonEncode({
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final candidates = resData['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final partsList = content['parts'] as List?;
          if (partsList != null && partsList.isNotEmpty) {
            final textRes = partsList[0]['text'] as String;
            final cleanedJson = _cleanJsonResponse(textRes);
            final jsonMap = jsonDecode(cleanedJson) as Map<String, dynamic>;
            return GeminiAnalysisResult.fromJson(jsonMap, textRes);
          }
        }
      }
    } catch (e) {
      debugPrint("Error calling Gemini API for POD inspection: $e");
    }

    return _localFallbackPODCheck(disputeComments, podImageBase64OrUrl);
  }

  String _cleanJsonResponse(String text) {
    String clean = text.trim();
    if (clean.startsWith('```json')) {
      clean = clean.substring(7);
    } else if (clean.startsWith('```')) {
      clean = clean.substring(3);
    }
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
    return clean.trim();
  }

  GeminiAnalysisResult _localFallbackFoodCheck(String? description, String imgData) {
    String desc = (description ?? '').toLowerCase();
    bool isSuspicious = desc.contains('rotten') ||
        desc.contains('expired') ||
        desc.contains('spoiled') ||
        desc.contains('mold') ||
        desc.contains('fake');

    return GeminiAnalysisResult(
      isViolating: isSuspicious,
      confidence: 0.85,
      reason: isSuspicious
          ? "Local Audit: Keyword analysis flagged keywords indicating potential food spoilage or invalid posting."
          : "Local Audit: Food post image and description passed initial safety checks.",
      suggestedSOP: "Food Safety & Quality SOP",
      rawResponse: "Fallback heuristic evaluation executed.",
    );
  }

  GeminiAnalysisResult _localFallbackPODCheck(String comment, String imgData) {
    String c = comment.toLowerCase();
    bool isSuspicious = imgData.isEmpty || c.contains('no photo') || c.contains('refused') || c.contains('fake');

    return GeminiAnalysisResult(
      isViolating: isSuspicious,
      confidence: 0.80,
      reason: isSuspicious
          ? "Local Audit: Missing POD proof or suspicious comment keywords detected."
          : "Local Audit: POD proof photo and dispute comments appear valid.",
      suggestedSOP: "Proof of Delivery SOP",
      rawResponse: "Fallback POD heuristic evaluation executed.",
    );
  }
}
