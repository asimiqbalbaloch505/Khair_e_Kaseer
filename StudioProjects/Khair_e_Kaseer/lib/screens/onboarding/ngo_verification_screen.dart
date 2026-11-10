import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/onboarding/auth_wrapper.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class NgoVerificationScreen extends StatefulWidget {
  const NgoVerificationScreen({super.key});

  @override
  State<NgoVerificationScreen> createState() => _NgoVerificationScreenState();
}

class _NgoVerificationScreenState extends State<NgoVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  final TextEditingController _ngoNameController = TextEditingController();
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _repCnicController = TextEditingController();

  String? _certificateBase64;
  String? _repCnicFrontBase64;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(Function(String base64) onSelected) async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (photo != null) {
        final bytes = await File(photo.path).readAsBytes();
        onSelected(base64Encode(bytes));
        setState(() {});
      }
    } catch (e) {
      _showError("Error picking document image.");
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_certificateBase64 == null) {
      _showError("Please upload the NGO Registration Certificate.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('Users').doc(user.uid).update({
        "isVerified": false,
        "verificationStatus": "pending",
        "verificationData": {
          "ngoName": _ngoNameController.text.trim(),
          "ngoRegNumber": _regNoController.text.trim(),
          "officialAddress": _addressController.text.trim(),
          "representativeCnic": _repCnicController.text.trim(),
          "certificateImage": _certificateBase64,
          "repCnicFront": _repCnicFrontBase64,
          "submittedAt": DateTime.now().millisecondsSinceEpoch,
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("NGO application submitted successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      _showError("Failed to submit verification: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bgCream,
        appBar: const UnverifiedAppBar(
          title: "NGO Verification",
          statusBadge: "Pending Credentials",
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                const Text("Organization Verification", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Submit official registration credentials to claim bulk meals.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),

                _buildTextField(_ngoNameController, "Official NGO Name"),
                _buildTextField(_regNoController, "Govt. Registration / License No."),
                _buildTextField(_addressController, "Official Head Office Address"),
                _buildTextField(_repCnicController, "Representative CNIC No."),

                const SizedBox(height: 15),
                _buildImageTile("NGO Certificate Image *", _certificateBase64, (base64) => _certificateBase64 = base64),
                const SizedBox(height: 10),
                _buildImageTile("Representative CNIC Front", _repCnicFrontBase64, (base64) => _repCnicFrontBase64 = base64),

                const SizedBox(height: 30),
                PrimaryActionButton(
                  label: "Submit NGO Application",
                  isLoading: _isSubmitting,
                  onPressed: _submitVerification,
                  height: 50,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        validator: (val) => val == null || val.trim().isEmpty ? "Field is required" : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildImageTile(String label, String? base64Val, Function(String) onPicked) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(base64Val != null ? Icons.check_circle : Icons.upload_file, color: base64Val != null ? Colors.green : primaryGreen),
        title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        onTap: () => _pickImage(onPicked),
      ),
    );
  }
}
