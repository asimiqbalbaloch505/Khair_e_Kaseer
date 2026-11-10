import 'package:flutter/material.dart';

class WarningBadgeWidget extends StatelessWidget {
  final int warningCount;
  final int maxWarnings;
  final bool isFlagged;

  const WarningBadgeWidget({
    super.key,
    required this.warningCount,
    this.maxWarnings = 2,
    this.isFlagged = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isDanger = warningCount >= maxWarnings || (isFlagged && warningCount > 0);
    bool isWarning = warningCount > 0 && !isDanger;

    Color bg = isDanger
        ? Colors.red.shade50
        : isWarning
            ? Colors.amber.shade50
            : Colors.green.shade50;

    Color border = isDanger
        ? Colors.red.shade300
        : isWarning
            ? Colors.amber.shade300
            : Colors.green.shade300;

    Color textColor = isDanger
        ? Colors.red.shade700
        : isWarning
            ? Colors.amber.shade900
            : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDanger
                ? Icons.error_outline
                : isWarning
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            "Warnings: $warningCount/$maxWarnings",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
