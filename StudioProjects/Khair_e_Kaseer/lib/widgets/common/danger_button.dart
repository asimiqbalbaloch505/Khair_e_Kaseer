import 'package:flutter/material.dart';

class DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isOutlined;
  final double height;

  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isOutlined = false,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    const Color dangerRed = Colors.redAccent;

    return SizedBox(
      height: height,
      child: isOutlined
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: dangerRed,
                side: const BorderSide(color: dangerRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: isLoading ? null : onPressed,
              child: _buildChild(dangerRed),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dangerRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: isLoading ? null : onPressed,
              child: _buildChild(Colors.white),
            ),
    );
  }

  Widget _buildChild(Color fgColor) {
    return isLoading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(color: fgColor, strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          );
  }
}
