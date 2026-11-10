import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool isFullScreen;

  const LoadingOverlay({
    super.key,
    this.message,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF347A5C);

    Widget content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryGreen),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );

    if (isFullScreen) {
      return Container(
        color: Colors.black.withOpacity(0.3),
        child: content,
      );
    }

    return content;
  }
}
