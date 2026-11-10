import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/onboarding/auth_wrapper.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class VolunteerVerificationScreen extends StatefulWidget {
  const VolunteerVerificationScreen({super.key});

  @override
  State<VolunteerVerificationScreen> createState() => _VolunteerVerificationScreenState();
}

class _VolunteerVerificationScreenState extends State<VolunteerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _vehicleRegController = TextEditingController();

  String _vehicleType = 'small'; // Default: small (Bike/Car) vs large (Van/Cargo)
  String? _drivingLicenseBase64;
  String? _vehicleDocBase64;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(Function(String base64) onSelected) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 25,
        maxWidth: 800,
      );

      if (photo != null) {
        final bytes = await File(photo.path).readAsBytes();
        onSelected(base64Encode(bytes));
        setState(() {});
      }
    } catch (e) {
      _showError("Error uploading image: ${e.toString()}");
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_drivingLicenseBase64 == null) {
      _showError("Please upload your Driving License photo.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("User session expired. Please log in again.");
        return;
      }

      await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
        "isVerified": false,
        "verificationStatus": "pending",
        "vehicleType": _vehicleType,
        "verificationData": {
          "cnic": _cnicController.text.trim(),
          "vehicleType": _vehicleType,
          "vehicleRegistrationNumber": _vehicleRegController.text.trim(),
          "drivingLicense": _drivingLicenseBase64,
          "vehicleDocument": _vehicleDocBase64,
          "submittedAt": DateTime.now().millisecondsSinceEpoch,
        }
      }, SetOptions(merge: true));

      debugPrint("Volunteer verification submitted successfully for UID: ${user.uid}");

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      debugPrint("Firestore Verification Submission Error: $e");
      _showError("Failed to submit application: ${e.toString()}");
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
          title: "Rider Verification",
          statusBadge: "Pending Documents",
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                const Text("Rider & Cargo Verification", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Provide driver identity details to accept food delivery tasks.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),

                _buildTextField(_cnicController, "CNIC Number"),
                _buildTextField(_vehicleRegController, "Vehicle Registration No. (e.g. LEB-1234)"),

                const SizedBox(height: 10),
                const Text("Select Vehicle Capacity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Small (Bike / Car)"),
                        selected: _vehicleType == 'small',
                        selectedColor: primaryGreen.withOpacity(0.2),
                        onSelected: (selected) {
                          if (selected) setState(() => _vehicleType = 'small');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Large (Cargo / Van)"),
                        selected: _vehicleType == 'large',
                        selectedColor: primaryGreen.withOpacity(0.2),
                        onSelected: (selected) {
                          if (selected) setState(() => _vehicleType = 'large');
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _buildImageTile("Driving License Photo *", _drivingLicenseBase64, (base64) => _drivingLicenseBase64 = base64),
                const SizedBox(height: 10),
                _buildImageTile("Vehicle Registration Document", _vehicleDocBase64, (base64) => _vehicleDocBase64 = base64),

                const SizedBox(height: 30),
                PrimaryActionButton(
                  label: "Submit Driver Application",
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
        leading: Icon(base64Val != null ? Icons.check_circle : Icons.directions_car, color: base64Val != null ? Colors.green : primaryGreen),
        title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: base64Val != null ? const Icon(Icons.check, color: Colors.green) : null,
        onTap: () => _pickImage(onPicked),
      ),
    );
  }
}
