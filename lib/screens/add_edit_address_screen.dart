import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/custom_snackbar.dart';

class AddEditAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? address;

  const AddEditAddressScreen({
    super.key,
    this.address,
  });

  bool get isEdit => address != null && address!['id'] != null;

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _companyCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _address1Ctrl = TextEditingController();
  final TextEditingController _address2Ctrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _stateCtrl = TextEditingController();
  final TextEditingController _zipCtrl = TextEditingController();

  String _country = 'United Kingdom (UK)';
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFromAddress();
  }

  void _initFromAddress() {
    final addr = widget.address;
    if (addr == null) return;

    _firstNameCtrl.text = addr['first_name']?.toString() ?? '';
    _lastNameCtrl.text = addr['last_name']?.toString() ?? '';
    _companyCtrl.text = addr['company']?.toString() ?? '';
    _phoneCtrl.text = addr['phone']?.toString() ?? '';
    _emailCtrl.text = addr['email']?.toString() ?? '';
    _address1Ctrl.text = addr['address_1']?.toString() ?? '';
    _address2Ctrl.text = addr['address_2']?.toString() ?? '';
    _cityCtrl.text = addr['city']?.toString() ?? '';
    _stateCtrl.text = addr['state']?.toString() ?? '';
    _zipCtrl.text = addr['postcode']?.toString() ?? '';
    _country = addr['country']?.toString().isNotEmpty == true
        ? addr['country'].toString()
        : _country;
    _isDefault = (addr['is_default'] == true) ||
        addr['is_default'].toString() == '1';
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);

    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            'Please login to manage addresses',
            isError: true,
          );
        }
        return;
      }

      final body = {
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address_1': _address1Ctrl.text.trim(),
        'address_2': _address2Ctrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'postcode': _zipCtrl.text.trim(),
        'country': _country,
        'is_default': _isDefault ? 1 : 0,
      };

      final bool isEdit = widget.isEdit;
      final endpoint = isEdit
          ? '${ApiEndpoints.addressUpdate}/${widget.address!['id']}'
          : ApiEndpoints.addressAdd;

      final response = isEdit
          ? await ApiService.puts(endpoint, body, token: token)
          : await ApiService.posts(endpoint, body, token: token);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        CustomSnackBar.show(
          context,
          isEdit ? 'Address updated successfully' : 'Address added successfully',
          isError: false,
        );

        final decoded = jsonDecode(response.body);
        Navigator.pop(context, decoded);
      } else {
        CustomSnackBar.show(
          context,
          'Failed to save address (${response.statusCode})',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        'Something went wrong: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
        title: Text(
          widget.isEdit ? 'Edit Delivery Address' : 'Add Delivery Address',
          style: AppTextStyles.heading3,
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country / Region
                    Text(
                      'Country / Region',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownField<String>(
                      value: _country,
                      items: const [
                        'United Kingdom (UK)',
                        'India (IN)',
                        'United States (US)',
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _country = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Contact Information
                    Text(
                      'Contact Information',
                      style: AppTextStyles.body1
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('First Name *'),
                    _buildTextField(
                      controller: _firstNameCtrl,
                      hint: 'First name',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Last Name *'),
                    _buildTextField(
                      controller: _lastNameCtrl,
                      hint: 'Last name',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Company Name'),
                    _buildTextField(
                      controller: _companyCtrl,
                      hint: 'Company name',
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Phone Number *'),
                    _buildPhoneRow(),
                    const SizedBox(height: 16),

                    _buildLabel('Email *'),
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        final regex = RegExp(
                            r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!regex.hasMatch(v.trim())) {
                          return 'Enter valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Shipping Address',
                      style: AppTextStyles.body1
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Address Line 1 *'),
                    _buildTextField(
                      controller: _address1Ctrl,
                      hint: 'Street name and number',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Address Line 2 *'),
                    _buildTextField(
                      controller: _address2Ctrl,
                      hint:
                          'Building/apt/block., floor, entrance code, etc.',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('State / Province *'),
                    _buildTextField(
                      controller: _stateCtrl,
                      hint: 'State/Province',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('City *'),
                    _buildTextField(
                      controller: _cityCtrl,
                      hint: 'City',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Post/Zip Code *'),
                    _buildTextField(
                      controller: _zipCtrl,
                      hint: 'Post/Zip code',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Checkbox(
                          value: _isDefault,
                          onChanged: (val) {
                            setState(() => _isDefault = val ?? false);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          activeColor: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Set as default shipping address',
                            style: AppTextStyles.body2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTextStyles.caption
            .copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String hint = '',
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(e.toString()),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPhoneRow() {
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
              value: 'UK +44',
              items: const [
                DropdownMenuItem(value: 'UK +44', child: Text('UK +44')),
                DropdownMenuItem(value: 'IN +91', child: Text('IN +91')),
                DropdownMenuItem(value: 'US +1', child: Text('US +1')),
              ],
              onChanged: (_) {},
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: 'Enter your phone number',
                hintStyle: AppTextStyles.body2,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Required';
                }
                if (v.trim().length != 10) {
                  return 'Enter 10-digit mobile number';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}


