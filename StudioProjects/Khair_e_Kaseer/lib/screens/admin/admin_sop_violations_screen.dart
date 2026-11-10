import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:khair_e_kaseer/services/sop_warning_service.dart';
import 'package:khair_e_kaseer/services/gemini_validation_service.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class AdminSopViolationsScreen extends StatefulWidget {
  const AdminSopViolationsScreen({super.key});

  @override
  State<AdminSopViolationsScreen> createState() => _AdminSopViolationsScreenState();
}

class _AdminSopViolationsScreenState extends State<AdminSopViolationsScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);
  final SOPWarningService _warningService = SOPWarningService();
  final GeminiValidationService _geminiService = GeminiValidationService();

  String _filterStatus = 'All'; // 'All', 'Pending Review', 'Warning Issued', 'Dismissed'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "SOP Violation Audit Logs",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Filter Chips Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending Review'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Warning Issued'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Dismissed'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Real-time Violation Log Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sop_violations')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryGreen));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.rule_folder_outlined,
                    title: "No SOP violation logs found",
                    subtitle: "Logged violation audits will appear here.",
                  );
                }

                List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                if (_filterStatus != 'All') {
                  docs = docs.where((doc) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    String actionStatus = data['actionStatus'] ?? 'Pending Review';
                    return actionStatus.toLowerCase() == _filterStatus.toLowerCase();
                  }).toList();
                }

                if (docs.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.filter_alt_off_outlined,
                    title: "No logs matching '$_filterStatus'",
                    subtitle: "Try selecting a different filter above.",
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String violationId = doc.id;

                    String uid = data['uid'] ?? 'Unknown User';
                    String role = (data['userRole'] ?? 'User').toString();
                    String violationType = data['violationType'] ?? 'SOP Violation';
                    String proofDetails = data['proofDetails'] ?? 'No proof recorded';
                    String photoUrl = data['photoUrl'] ?? '';
                    String actionStatus = data['actionStatus'] ?? 'Pending Review';

                    Timestamp? ts = data['timestamp'] as Timestamp?;
                    String timeFormatted = ts != null
                        ? DateFormat('MMM dd, yyyy - hh:mm a').format(ts.toDate())
                        : 'Just now';

                    return ViolationCardWidget(
                      role: role,
                      violationType: violationType,
                      proofDetails: proofDetails,
                      photoUrl: photoUrl,
                      actionStatus: actionStatus,
                      timestampFormatted: timeFormatted,
                      onGeminiAudit: () => _runGeminiReaudit(violationType, proofDetails, photoUrl),
                      onIssueWarning: actionStatus == 'Pending Review'
                          ? () => _issueWarningFromViolation(uid, violationId, violationType)
                          : null,
                      onDismiss: actionStatus == 'Pending Review'
                          ? () => _dismissViolation(violationId)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _filterStatus == label;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: primaryGreen.withOpacity(0.2),
      checkmarkColor: primaryGreen,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? primaryGreen : Colors.black87,
      ),
      onSelected: (selected) {
        setState(() => _filterStatus = label);
      },
    );
  }

  void _runGeminiReaudit(String type, String proof, String photoUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: primaryGreen),
            const SizedBox(width: 16),
            const Text("Running Gemini AI Visual Audit..."),
          ],
        ),
      ),
    );

    GeminiAnalysisResult result = await _geminiService.inspectFoodImage(
      imageBase64OrUrl: photoUrl.isNotEmpty ? photoUrl : "no_image",
      foodDescription: "$type: $proof",
    );

    if (mounted) {
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                result.isViolating ? Icons.error_outline : Icons.check_circle_outline,
                color: result.isViolating ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              const Text("Gemini Audit Result"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Violation Flagged: ${result.isViolating ? 'YES' : 'NO'}",
                    style: TextStyle(fontWeight: FontWeight.bold, color: result.isViolating ? Colors.red : Colors.green)),
                const SizedBox(height: 6),
                Text("Confidence Score: ${(result.confidence * 100).toStringAsFixed(1)}%"),
                const SizedBox(height: 6),
                Text("Suggested SOP: ${result.suggestedSOP}"),
                const SizedBox(height: 10),
                const Text("Audit Reasoning:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(result.reason, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }
  }

  void _issueWarningFromViolation(String uid, String violationId, String violationType) async {
    bool success = await _warningService.issueWarning(
      uid: uid,
      reason: "Confirmed SOP violation: $violationType",
      sopsViolated: [violationType],
      issuedBy: "Admin Audit Log",
      violationId: violationId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Warning issued & violation status updated!" : "Failed to issue warning."),
          backgroundColor: success ? primaryGreen : Colors.red,
        ),
      );
    }
  }

  void _dismissViolation(String violationId) async {
    try {
      await FirebaseFirestore.instance.collection('sop_violations').doc(violationId).update({
        'actionStatus': 'Dismissed',
        'dismissedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Violation log dismissed.")),
        );
      }
    } catch (e) {
      debugPrint("Error dismissing violation: $e");
    }
  }
}
