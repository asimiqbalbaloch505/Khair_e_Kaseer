import 'package:flutter/material.dart';

class WarningHistoryWidget extends StatefulWidget {
  final int warningCount;
  final bool isFlagged;
  final String? flaggedReason;
  final List<dynamic> warningHistory;

  const WarningHistoryWidget({
    super.key,
    required this.warningCount,
    required this.isFlagged,
    this.flaggedReason,
    required this.warningHistory,
  });

  @override
  State<WarningHistoryWidget> createState() => _WarningHistoryWidgetState();
}

class _WarningHistoryWidgetState extends State<WarningHistoryWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    bool hasWarnings = widget.warningCount > 0 || widget.isFlagged;
    Color statusColor = widget.warningCount >= 2
        ? Colors.orange.shade800
        : widget.warningCount == 1
            ? Colors.amber.shade900
            : Colors.green.shade700;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasWarnings ? statusColor.withOpacity(0.4) : Colors.grey.shade200,
          width: hasWarnings ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.12),
              child: Icon(
                hasWarnings ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                color: statusColor,
              ),
            ),
            title: const Text(
              "SOP Warnings & Status",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              hasWarnings
                  ? "Warnings: ${widget.warningCount}/2 | Account ${widget.isFlagged ? 'Flagged' : 'Active'}"
                  : "Good Standing | 0 Warnings Recorded",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            trailing: widget.warningHistory.isNotEmpty
                ? IconButton(
                    icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  )
                : null,
          ),

          if (widget.isFlagged && widget.flaggedReason != null && widget.flaggedReason!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Flag Reason: ${widget.flaggedReason}",
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          if (_isExpanded && widget.warningHistory.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Warning History Logs:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  ...widget.warningHistory.map((w) {
                    Map<String, dynamic> wMap = w is Map<String, dynamic> ? w : {};
                    String reason = wMap['reason'] ?? 'SOP Violation';
                    List sops = (wMap['sopsViolated'] as List?) ?? [];
                    String timestamp = wMap['timestamp'] ?? '';
                    String issuedBy = wMap['issuedBy'] ?? 'Admin System';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "SOP: ${sops.join(', ')}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                              Text(
                                issuedBy,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Reason: $reason",
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                          if (timestamp.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              "Logged on: $timestamp",
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 4),
                  Text(
                    "* Accumulating >2 warnings automatically initiates a manual review process.",
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
