import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/services/sop_warning_service.dart';

class OtpHandoverDialog extends StatefulWidget {
  final String orderId;
  final String expectedOtp;
  final String recipientName;
  final String recipientRole; // 'rider' or 'beneficiary'

  const OtpHandoverDialog({
    super.key,
    required this.orderId,
    required this.expectedOtp,
    required this.recipientName,
    required this.recipientRole,
  });

  @override
  State<OtpHandoverDialog> createState() => _OtpHandoverDialogState();
}

class _OtpHandoverDialogState extends State<OtpHandoverDialog> {
  final TextEditingController _otpController = TextEditingController();
  final Color primaryGreen = const Color(0xFF347A5C);
  bool _isVerifying = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtpAndHandover() async {
    String inputOtp = _otpController.text.trim();
    if (inputOtp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the 6-digit handover OTP.")),
      );
      return;
    }

    setState(() => _isVerifying = true);

    if (inputOtp == widget.expectedOtp.trim()) {
      try {
        // Update Order & Donation document status in Firestore
        WriteBatch batch = FirebaseFirestore.instance.batch();

        DocumentReference orderRef = FirebaseFirestore.instance.collection('Orders').doc(widget.orderId);
        DocumentReference donationRef = FirebaseFirestore.instance.collection('Donations').doc(widget.orderId);

        Map<String, dynamic> updateData = {
          'status': 'Picked',
          'orderStatus': 'picked_up',
          'handoverConfirmedAt': FieldValue.serverTimestamp(),
        };

        batch.set(orderRef, updateData, SetOptions(merge: true));
        batch.set(donationRef, updateData, SetOptions(merge: true));

        await batch.commit();

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Handover verified! Food handed over to ${widget.recipientName}."),
              backgroundColor: primaryGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint("Error confirming OTP handover: $e");
        if (mounted) {
          setState(() => _isVerifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification error: ${e.toString()}"), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      setState(() => _isVerifying = false);

      // Log OTP failure SOP violation
      await SOPWarningService().logSOPViolation(
        uid: widget.orderId,
        role: widget.recipientRole,
        violationType: "Handover OTP Verification Failure",
        proofDetails: "Invalid OTP ($inputOtp vs expected) entered during handover to ${widget.recipientName}.",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid OTP code. Please check with recipient."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: primaryGreen.withOpacity(0.12),
            child: Icon(Icons.shield_outlined, color: primaryGreen),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Verify Handover OTP",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ask ${widget.recipientName} (${widget.recipientRole.toUpperCase()}) for their 6-digit verification OTP code before transferring food.",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: "000000",
                counterText: "",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isVerifying ? null : _verifyOtpAndHandover,
          child: _isVerifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text("Confirm Handover", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
