import 'dart:convert';
import 'package:flutter/material.dart';

class ViolationCardWidget extends StatelessWidget {
  final String role;
  final String violationType;
  final String proofDetails;
  final String photoUrl;
  final String actionStatus;
  final String timestampFormatted;
  final VoidCallback? onGeminiAudit;
  final VoidCallback? onIssueWarning;
  final VoidCallback? onDismiss;

  const ViolationCardWidget({
    super.key,
    required this.role,
    required this.violationType,
    required this.proofDetails,
    this.photoUrl = '',
    required this.actionStatus,
    required this.timestampFormatted,
    this.onGeminiAudit,
    this.onIssueWarning,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF347A5C);

    Color statusColor = actionStatus == 'Warning Issued'
        ? Colors.red
        : actionStatus == 'Dismissed'
            ? Colors.grey
            : Colors.orange.shade800;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timestampFormatted,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    actionStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              violationType,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 6),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Proof Details: $proofDetails",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ),

            if (photoUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildPhotoThumbnail(photoUrl),
            ],

            if (onGeminiAudit != null || onIssueWarning != null || onDismiss != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onGeminiAudit != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade800,
                        side: BorderSide(color: Colors.blue.shade800),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text("Gemini Audit", style: TextStyle(fontSize: 11)),
                      onPressed: onGeminiAudit,
                    ),
                  if (onIssueWarning != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.warning, size: 14),
                      label: const Text("Issue Warning", style: TextStyle(fontSize: 11)),
                      onPressed: onIssueWarning,
                    ),
                  ],
                  if (onDismiss != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: onDismiss,
                      child: const Text("Dismiss", style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String photoData) {
    return Container(
      height: 100,
      width: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: photoData.startsWith('http')
            ? Image.network(photoData, fit: BoxFit.cover)
            : Image.memory(
                base64Decode(photoData.contains(',') ? photoData.split(',').last : photoData),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
              ),
      ),
    );
  }
}
