import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class BeneficiaryVerificationScreen extends StatefulWidget {
  const BeneficiaryVerificationScreen({super.key});

  @override
  State<BeneficiaryVerificationScreen> createState() => _BeneficiaryVerificationScreenState();
}

class _BeneficiaryVerificationScreenState extends State<BeneficiaryVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  final TextEditingController _applicantCnicController = TextEditingController();
  final TextEditingController _guardianCnicController = TextEditingController();
  final TextEditingController _motherCnicController = TextEditingController();
  final TextEditingController _spouseCnicController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _utilityMeterController = TextEditingController();

  final List<TextEditingController> _dependentCnicControllers = [];

  String? _cnicFrontBase64;
  String? _cnicBackBase64;
  String? _proofDocBase64;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  void _addDependentField() {
    if (_dependentCnicControllers.length < 10) {
      setState(() {
        _dependentCnicControllers.add(TextEditingController());
      });
    }
  }

  void _removeDependentField(int index) {
    setState(() {
      _dependentCnicControllers[index].dispose();
      _dependentCnicControllers.removeAt(index);
    });
  }

  Future<void> _pickImage(ImageSource source, Function(String base64) onSelected) async {
    try {
      final XFile? photo = await _picker.pickImage(source: source, imageQuality: 50);
      if (photo != null) {
        final bytes = await File(photo.path).readAsBytes();
        onSelected(base64Encode(bytes));
        setState(() {});
      }
    } catch (e) {
      _showError("Error selecting image: ${e.toString()}");
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cnicFrontBase64 == null || _cnicBackBase64 == null) {
      _showError("Please upload both Front and Back photos of your CNIC.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final List<String> allCollectedCnics = [
        _applicantCnicController.text.trim(),
        if (_guardianCnicController.text.trim().isNotEmpty) _guardianCnicController.text.trim(),
        if (_motherCnicController.text.trim().isNotEmpty) _motherCnicController.text.trim(),
        if (_spouseCnicController.text.trim().isNotEmpty) _spouseCnicController.text.trim(),
        ..._dependentCnicControllers
            .map((c) => c.text.trim())
            .where((text) => text.isNotEmpty)
      ];

      for (String cnic in allCollectedCnics) {
        DocumentSnapshot indexDoc = await FirebaseFirestore.instance
            .collection('FamilyCNICs')
            .doc(cnic)
            .get();

        if (indexDoc.exists) {
          final data = indexDoc.data() as Map<String, dynamic>;
          if (data['registeredByUid'] != user.uid) {
            _showError("CNIC $cnic is already linked to another family profile.");
            setState(() => _isSubmitting = false);
            return;
          }
        }
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (String cnic in allCollectedCnics) {
        DocumentReference cnicRef = FirebaseFirestore.instance.collection('FamilyCNICs').doc(cnic);
        batch.set(cnicRef, {
          'cnic': cnic,
          'registeredByUid': user.uid,
          'linkedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      DocumentReference userRef = FirebaseFirestore.instance.collection('Users').doc(user.uid);
      batch.set(userRef, {
        "isVerified": false,
        "verificationStatus": "pending",
        "cnicNumber": _applicantCnicController.text.trim(),
        "address": _addressController.text.trim(),
        "verificationData": {
          "applicantCnic": _applicantCnicController.text.trim(),
          "guardianCnic": _guardianCnicController.text.trim(),
          "motherCnic": _motherCnicController.text.trim(),
          "spouseCnic": _spouseCnicController.text.trim(),
          "dependentsCnics": _dependentCnicControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
          "officialAddress": _addressController.text.trim(),
          "utilityMeterNumber": _utilityMeterController.text.trim(),
          "cnicFront": _cnicFrontBase64,
          "cnicBack": _cnicBackBase64,
          "proofDoc": _proofDocBase64,
          "submittedAt": DateTime.now().millisecondsSinceEpoch,
        }
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Family verification details submitted! Pending admin approval."),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
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
          title: "Beneficiary Verification",
          statusBadge: "Pending Documents",
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                const Text("Complete Household Identity", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Enter your family details to access meal requests. This prevents fraud and duplicate allocations.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),

                _buildSectionHeader("Applicant Identity"),
                _buildTextField(_applicantCnicController, "Applicant CNIC (e.g. 37405-1234567-1)", true),

                const SizedBox(height: 15),
                _buildSectionHeader("Family Identity Anchors"),
                _buildTextField(_guardianCnicController, "Father / Guardian CNIC (Optional)", false),
                _buildTextField(_motherCnicController, "Mother CNIC (Optional)", false),
                _buildTextField(_spouseCnicController, "Spouse CNIC (Optional)", false),

                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader("Dependents / Children (Form-B or CNIC)"),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: primaryGreen),
                      onPressed: _addDependentField,
                    )
                  ],
                ),
                ...List.generate(_dependentCnicControllers.length, (index) {
                  return Row(
                    children: [
                      Expanded(child: _buildTextField(_dependentCnicControllers[index], "Dependent #${index + 1} CNIC / Form-B", false)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeDependentField(index),
                      )
                    ],
                  );
                }),

                const SizedBox(height: 15),
                _buildSectionHeader("Residence Details"),
                _buildTextField(_addressController, "Residential Address", true),
                _buildTextField(_utilityMeterController, "Electricity / Gas Meter No. (Optional)", false),

                const SizedBox(height: 15),
                _buildSectionHeader("Upload Documents"),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageButton("CNIC Front *", _cnicFrontBase64, (base64) => _cnicFrontBase64 = base64),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildImageButton("CNIC Back *", _cnicBackBase64, (base64) => _cnicBackBase64 = base64),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildImageButton("Upload Form-B / Bill / FRC (Optional)", _proofDocBase64, (base64) => _proofDocBase64 = base64),

                const SizedBox(height: 30),
                PrimaryActionButton(
                  label: "Submit Verification",
                  isLoading: _isSubmitting,
                  onPressed: _submitVerification,
                  height: 50,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryGreen)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, bool isRequired) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextFormField(
        controller: controller,
        validator: (val) {
          if (isRequired && (val == null || val.trim().isEmpty)) {
            return "This field is required";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildImageButton(String label, String? base64Val, Function(String) onPicked) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(base64Val != null ? Icons.check_circle : Icons.camera_alt, color: base64Val != null ? Colors.green : primaryGreen),
        title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onTap: () => _pickImage(ImageSource.gallery, onPicked),
      ),
    );
  }
}
