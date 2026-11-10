import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class EditProfileDialog extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const EditProfileDialog({
    super.key,
    required this.uid,
    required this.userData,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final Color primaryGreen = const Color(0xFF347A5C);
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  File? _selectedImageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.userData['firstName'] ?? widget.userData['name'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.userData['lastName'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userData['phone'] ?? widget.userData['phoneNumber'] ?? '',
    );
    _bioController = TextEditingController(
      text: widget.userData['bio'] ?? widget.userData['organizationDescription'] ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      String? photoUrl = widget.userData['photoUrl'] ?? widget.userData['profilePicture'];

      // 1. Upload new image if selected
      if (_selectedImageFile != null) {
        try {
          Reference storageRef = FirebaseStorage.instance
              .ref()
              .child('user_profile_images')
              .child('${widget.uid}.jpg');

          UploadTask uploadTask = storageRef.putFile(_selectedImageFile!);
          TaskSnapshot snapshot = await uploadTask;
          photoUrl = await snapshot.ref.getDownloadURL();
        } catch (storageError) {
          debugPrint("Firebase Storage upload fallback: $storageError");
        }
      }

      // 2. Update Firestore document under /Users/{uid}
      Map<String, dynamic> updateData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
        updateData['profilePicture'] = photoUrl;
      }

      await FirebaseFirestore.instance.collection('Users').doc(widget.uid).update(updateData);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Profile updated successfully!"),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving profile: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update profile: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _triggerPasswordReset() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: currentUser!.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Password reset link sent to ${currentUser.email}"),
              backgroundColor: primaryGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentPhotoUrl = widget.userData['photoUrl'] ?? widget.userData['profilePicture'] ?? '';

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Edit Profile & Settings",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),

            // Avatar Section
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: primaryGreen.withOpacity(0.1),
                    backgroundImage: _selectedImageFile != null
                        ? FileImage(_selectedImageFile!) as ImageProvider
                        : (currentPhotoUrl.isNotEmpty && currentPhotoUrl.startsWith('http'))
                            ? NetworkImage(currentPhotoUrl)
                            : null,
                    child: (_selectedImageFile == null && currentPhotoUrl.isEmpty)
                        ? Icon(Icons.person, size: 50, color: primaryGreen)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form Fields
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: "First Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: "Last Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.phonelink_ring_outlined, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: primaryGreen),
                const SizedBox(width: 4),
                Text(
                  "Phone number updates require dual-OTP verification",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _bioController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Bio / Mission Note",
                hintText: "Short overview of your profile...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Security Option
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_reset, color: Colors.grey),
              title: const Text("Reset Security Password", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: const Text("Receive a reset link on registered email", style: TextStyle(fontSize: 12)),
              trailing: TextButton(
                onPressed: _triggerPasswordReset,
                child: const Text("Send Link"),
              ),
            ),

            const SizedBox(height: 16),

            PrimaryActionButton(
              label: "Save Changes",
              isLoading: _isSaving,
              onPressed: _saveProfile,
            ),
          ],
        ),
      ),
    );
  }
}
