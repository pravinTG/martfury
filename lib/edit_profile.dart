import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:martfury/api_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/widgets/app_loader.dart';
import 'package:martfury/widgets/app_snackbar.dart';
import 'package:martfury/widgets/app_textfield.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoadingProfile = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String _profileImageUrl = '';
  String _selectedImagePath = '';
  String? _selectedGender;
  String? _selectedBirthday;

  @override
  void initState() {
    super.initState();
    _loadCustomerProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerProfile() async {
    try {
      final profile = await _apiService.getCustomerProfile();
      if (!mounted) return;

      final billing = profile['billing'] as Map<String, dynamic>?;

      _firstNameController.text =
          _getString(profile, ['first_name']) ??
              _getString(billing, ['first_name']) ??
              '';
      _lastNameController.text =
          _getString(profile, ['last_name']) ??
              _getString(billing, ['last_name']) ??
              '';
      _emailController.text = _getString(profile, ['email']) ?? '';
      _phoneController.text = _getString(billing, ['phone']) ?? '';
      _profileImageUrl = _getString(profile, ['avatar_url']) ?? '';

      final gender = _getString(profile, ['gender']);
      _selectedGender = _normalizeGender(gender);

      _selectedBirthday = _getString(profile, [
        'birthday',
        'birth_date',
        'date_of_birth',
      ]);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Failed to load profile: $e', type: AppSnackType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      AppSnackBar.show(context, 'First name, email, and phone are required', type: AppSnackType.error);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? profileImageBase64;
      if (_selectedImagePath.isNotEmpty) {
        setState(() {
          _isUploadingImage = true;
        });
        profileImageBase64 = await _encodeImageToBase64(_selectedImagePath);
      }

      final payload = <String, dynamic>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'billing': {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
        'shipping': {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
        },
        if (profileImageBase64 != null) 'profile_image': profileImageBase64,
      };

      if (_selectedGender != null && _selectedGender!.isNotEmpty) {
        payload['gender'] = _selectedGender;
      }
      if (_selectedBirthday != null && _selectedBirthday!.isNotEmpty) {
        payload['birthday'] = _selectedBirthday;
      }

      await _apiService.updateCustomerProfile(customerData: payload);
      if (!mounted) return;

      AppSnackBar.show(context, 'Profile updated successfully', type: AppSnackType.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Failed to update profile: $e', type: AppSnackType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<String> _encodeImageToBase64(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() {
      _selectedImagePath = picked.path;
    });
  }

  String? _getString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _normalizeGender(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == 'male') return 'Male';
    if (lower == 'female') return 'Female';
    if (lower == 'other') return 'Other';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                // Profile Picture
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFFE0E0E0),
                        backgroundImage: _selectedImagePath.isNotEmpty
                            ? FileImage(File(_selectedImagePath))
                            : (_profileImageUrl.isNotEmpty
                            ? NetworkImage(_profileImageUrl) as ImageProvider
                            : null),
                        child: _selectedImagePath.isEmpty && _profileImageUrl.isEmpty
                            ? const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.yellow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // First Name
                _buildLabel('First Name'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _firstNameController,
                  hintText: 'First name',
                ),

                const SizedBox(height: 20),

                // Last Name
                _buildLabel('Last Name'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _lastNameController,
                  hintText: 'Last name',
                ),

                const SizedBox(height: 20),

                // Phone Number
                _buildLabel('Phone Number'),
                const SizedBox(height: 8),
                _buildPhoneField(),

                const SizedBox(height: 20),

                // Email
                _buildLabel('Email'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 20),

                // Gender
                // _buildLabel('Gender', required: false),
                // const SizedBox(height: 8),
                // _buildDropdownField(
                //   value: _selectedGender,
                //   hintText: 'Select',
                //   items: ['Male', 'Female', 'Other'],
                //   onChanged: (value) {
                //     setState(() {
                //       _selectedGender = value;
                //     });
                //   },
                // ),

                // const SizedBox(height: 20),
                //
                // // Birthday
                // _buildLabel('Birthday', required: false),
                // const SizedBox(height: 8),
                // _buildDropdownField(
                //   value: _selectedBirthday,
                //   hintText: 'mm/dd/yyyy',
                //   items: [],
                //   onChanged: (value) {
                //     setState(() {
                //       _selectedBirthday = value;
                //     });
                //   },
                //   onTap: () async {
                //     final DateTime? picked = await showDatePicker(
                //       context: context,
                //       initialDate: DateTime.now(),
                //       firstDate: DateTime(1900),
                //       lastDate: DateTime.now(),
                //       builder: (context, child) {
                //         return Theme(
                //           data: Theme.of(context).copyWith(
                //             colorScheme: const ColorScheme.light(
                //               primary: AppColors.yellow,
                //             ),
                //           ),
                //           child: child!,
                //         );
                //       },
                //     );
                //     if (picked != null) {
                //       setState(() {
                //         _selectedBirthday =
                //         '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
                //       });
                //     }
                //   },
                // ),

                const SizedBox(height: 32),

                // Save Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                      : const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,color: Colors.white
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Info Text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'All data will be encrypted',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isUploadingImage)
                  const AppBlockingLoader(message: 'Uploading image...'),
              ],
            ),
    );
  }

  Widget _buildLabel(String text, {bool required = true}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Row(
      children: [
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     border: Border.all(color: AppColors.border),
        //     borderRadius: BorderRadius.circular(12),
        //   ),
        //   child: const Text(
        //     'UK +44',
        //     style: TextStyle(
        //       fontSize: 14,
        //       fontWeight: FontWeight.w500,
        //     ),
        //   ),
        // ),
        Expanded(
          child: AppTextField(
            controller: _phoneController,
            hintText: 'Enter your phone number',
            keyboardType: TextInputType.phone,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hintText,
    required List<String> items,
    required Function(String?) onChanged,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {
        if (items.isNotEmpty) {
          _showBottomSheet(items, onChanged);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value ?? hintText,
              style: TextStyle(
                color: value == null ? Colors.grey.shade400 : Colors.black,
                fontSize: 14,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  void _showBottomSheet(List<String> items, Function(String?) onChanged) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items.map((item) {
              return ListTile(
                title: Text(
                  item,
                  style: const TextStyle(fontSize: 16),
                ),
                onTap: () {
                  onChanged(item);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}