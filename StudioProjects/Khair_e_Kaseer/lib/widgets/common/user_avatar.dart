import 'dart:convert';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? base64Image;
  final String? name;
  final double radius;
  final bool showStatusDot;
  final Color? statusDotColor;

  const UserAvatar({
    super.key,
    this.photoUrl,
    this.base64Image,
    this.name,
    this.radius = 28,
    this.showStatusDot = false,
    this.statusDotColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF347A5C);

    ImageProvider? imageProvider;
    if (base64Image != null && base64Image!.isNotEmpty) {
      try {
        String cleanBase64 = base64Image!.contains(',') ? base64Image!.split(',').last : base64Image!;
        imageProvider = MemoryImage(base64Decode(cleanBase64));
      } catch (e) {
        debugPrint("Base64 avatar error: $e");
      }
    } else if (photoUrl != null && photoUrl!.isNotEmpty && photoUrl!.startsWith('http')) {
      imageProvider = NetworkImage(photoUrl!);
    }

    String initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim().substring(0, 1).toUpperCase()
        : '';

    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: primaryGreen.withOpacity(0.12),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? (initial.isNotEmpty
                  ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: radius * 0.8,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    )
                  : Icon(Icons.person, size: radius * 1.1, color: primaryGreen))
              : null,
        ),
        if (showStatusDot)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: statusDotColor ?? Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
