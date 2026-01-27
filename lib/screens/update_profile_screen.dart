import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/custom_snackbar.dart';
import '../utils/safe_print.dart';

class UpdateProfileScreen extends StatefulWidget {
  static const String routeName = '/update-profile';

  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _mobileFocus = FocusNode();

  String _profileImageUrl = '';
  String _selectedImagePath = '';
  String _countryCode = '+44'; // default to UK +44 like design

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _firstNameFocus.dispose();
    _emailFocus.dispose();
    _mobileFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchUserDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final customerId = await SessionManager.getBackendUserId();
      if (customerId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      // Prefer Bearer token if available, fallback to Basic Auth
      final response = await ApiService.gets(
        '${ApiEndpoints.customers}$customerId',
      );

      safePrint('👤 Customer GET status: ${response.statusCode}');
      safePrint('👤 Customer GET body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String phone = '';
        final billing = (data is Map) ? data['billing'] : null;
        if (billing is Map && billing['phone'] != null) {
          phone = billing['phone'].toString();
        } else if (data is Map && data['mobile'] != null) {
          phone = data['mobile'].toString();
        }

        if (phone.startsWith('+91')) {
          phone = phone.substring(3);
          _countryCode = '+91';
        }

        setState(() {
          _firstNameCtrl.text = (data is Map ? (data['first_name']?.toString() ?? '') : '');
          _lastNameCtrl.text = (data is Map ? (data['last_name']?.toString() ?? '') : '');
          _emailCtrl.text = (data is Map ? (data['email']?.toString() ?? '') : '');
          _mobileCtrl.text = phone;
          _profileImageUrl = (data is Map ? (data['avatar_url']?.toString() ?? '') : '');
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to fetch user details (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching user details: $e';
      });
    }
  }

  Future<String> _encodeImageToBase64(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> _updateUserDetails() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final customerId = await SessionManager.getBackendUserId();
      if (customerId == null) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      String? avatarBase64;
      if (_selectedImagePath.isNotEmpty) {
        setState(() => _isUploadingImage = true);
        avatarBase64 = await _encodeImageToBase64(_selectedImagePath);
      }

      final phone = '${_countryCode.replaceAll(RegExp(r'[^0-9+]'), '')}${_mobileCtrl.text.trim()}';

      final body = <String, dynamic>{
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'billing': {
          'phone': phone,
        },
        if (avatarBase64 != null) 'profile_image': avatarBase64,
      };

      final response = await ApiService.puts(
        '${ApiEndpoints.customers}$customerId',
        body,
      );

      safePrint('👤 Customer PUT status: ${response.statusCode}');
      safePrint('👤 Customer PUT body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['id'] != null) {
          CustomSnackBar.show(context, 'Profile updated successfully!', isError: false);
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorMessage = 'Update failed: invalid response';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Update failed: ${response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  void _pickImage() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null && mounted) {
                  setState(() => _selectedImagePath = picked.path);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                if (picked != null && mounted) {
                  setState(() => _selectedImagePath = picked.path);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.primaryDark,
                                backgroundImage: _selectedImagePath.isNotEmpty
                                    ? FileImage(File(_selectedImagePath)) as ImageProvider
                                    : (_profileImageUrl.isNotEmpty ? NetworkImage(_profileImageUrl) : null),
                                child: _selectedImagePath.isEmpty && _profileImageUrl.isEmpty
                                    ? Text(
                                        _firstNameCtrl.text.isNotEmpty
                                            ? _firstNameCtrl.text.substring(0, _firstNameCtrl.text.length >= 2 ? 2 : 1).toUpperCase()
                                            : 'U',
                                        style: const TextStyle(fontSize: 24, color: Colors.white),
                                      )
                                    : null,
                              ),
                              GestureDetector(
                                onTap: _pickImage,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white,
                                  child: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap to change profile picture',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),

                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.08),
                              border: Border.all(color: AppColors.error.withOpacity(0.25)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.body2.copyWith(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        _buildInfoCard(),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _updateUserDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text('Save Changes', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isUploadingImage)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text('Uploading Image...', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline),
                const SizedBox(width: 8),
                Text(
                  'Personal Information',
                  style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _firstNameCtrl,
              focusNode: _firstNameFocus,
              nextFocus: _emailFocus,
              hint: 'Full Name',
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Please enter your full name';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emailCtrl,
              focusNode: _emailFocus,
              nextFocus: _mobileFocus,
              hint: 'Email Address',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {

              },
            ),
            const SizedBox(height: 12),
            _buildPhoneField(hint: 'Phone Number'),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    String hint = '',
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        hintText: hint,
        hintStyle: AppTextStyles.body2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
      onFieldSubmitted: (_) => nextFocus?.requestFocus(),
    );
  }

  Widget _buildPhoneField({String hint = 'Enter your phone number'}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _countryCode,
              style: AppTextStyles.body1,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
              items: const [
                DropdownMenuItem(value: '+44', child: Text('UK +44')),
                DropdownMenuItem(value: '+91', child: Text('IN +91')),
                DropdownMenuItem(value: '+1', child: Text('US +1')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _countryCode = val);
                }
              },
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: TextFormField(
              controller: _mobileCtrl,
              focusNode: _mobileFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                hintText: hint,
                hintStyle: AppTextStyles.body2,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Please enter your phone number';
                if (v.length != 10) return 'Phone number must be 10 digits';
                if (!RegExp(r'^[0-9]+$').hasMatch(v)) return 'Phone number must contain only digits';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}


