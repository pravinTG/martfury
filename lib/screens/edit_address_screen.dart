import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/custom_snackbar.dart';

class EditAddressScreen extends StatefulWidget {
  final String addressId;
  final Map<String, dynamic>? addressData;
  final String? navigate;
  final String? discount;
  final List<Map<String, dynamic>> cartItems;

  const EditAddressScreen({
    super.key,
    required this.addressId,
    this.addressData,
    this.navigate,
    required this.cartItems,
    this.discount,
  });

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  String _addressType = 'Select';
  final List<String> _addressTypes = ['Select', 'Home', 'Office', 'Other'];

  final List<String> _states = [
    "Andaman and Nicobar Islands",
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chandigarh",
    "Chhattisgarh",
    "Dadra and Nagar Haveli",
    "Daman",
    "Delhi",
    "Diu",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jammu & Kashmir",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Ladakh",
    "Lakshadweep",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Puducherry",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttarakhand",
    "Uttar Pradesh",
    "West Bengal",
  ];

  final txtFirstName = TextEditingController();
  final txtLastName = TextEditingController();
  final txtMobileNumber = TextEditingController();
  final txtEmail = TextEditingController();
  final txtAddressLine1 = TextEditingController();
  final txtAddressLine2 = TextEditingController();
  final txtCity = TextEditingController();
  final txtPincode = TextEditingController();

  String _stateValue = 'Maharashtra';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prefillFields();
  }

  void _prefillFields() {
    final data = widget.addressData;
    if (data == null) return;

    txtFirstName.text = data['first_name']?.toString() ?? '';
    txtLastName.text = data['last_name']?.toString() ?? '';
    txtMobileNumber.text = data['phone']?.toString() ?? '';
    txtEmail.text = data['email']?.toString() ?? '';
    txtAddressLine1.text = data['address_1']?.toString() ?? '';
    txtAddressLine2.text = data['address_2']?.toString() ?? '';
    txtCity.text = data['city']?.toString() ?? '';
    txtPincode.text = data['postcode']?.toString() ?? '';

    // Normalize API values like "home"/"office"/"other" to our dropdown values
    final rawType = data['address_type']?.toString() ?? data['type']?.toString() ?? '';
    final normalizedType = _normalizeAddressType(rawType);
    _addressType = _addressTypes.contains(normalizedType) ? normalizedType : 'Select';
    _stateValue = data['state']?.toString() ?? _stateValue;
  }

  String _normalizeAddressType(String value) {
    final v = value.trim().toLowerCase();
    if (v == 'home') return 'Home';
    if (v == 'office') return 'Office';
    if (v == 'other') return 'Other';
    if (v.isEmpty || v == 'select') return 'Select';
    // If backend returns already-capitalized or custom value, try to title-case it
    return v[0].toUpperCase() + v.substring(1);
  }

  @override
  void dispose() {
    txtFirstName.dispose();
    txtLastName.dispose();
    txtMobileNumber.dispose();
    txtEmail.dispose();
    txtAddressLine1.dispose();
    txtAddressLine2.dispose();
    txtCity.dispose();
    txtPincode.dispose();
    super.dispose();
  }

  Future<void> _updateAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        if (!mounted) return;
        CustomSnackBar.show(context, 'Please login to edit address', isError: true);
        return;
      }

      final Map<String, dynamic> body = {
        "address": {
          "first_name": txtFirstName.text.trim(),
          "last_name": txtLastName.text.trim(),
          "email": txtEmail.text.trim(),
          "address_1": txtAddressLine1.text.trim(),
          "address_2": txtAddressLine2.text.trim(),
          "city": txtCity.text.trim(),
          "state": _stateValue,
          "postcode": txtPincode.text.trim(),
          "country": "IN",
          "id": widget.addressId,
          "phone": txtMobileNumber.text.trim(),
          "address_type": _addressType,
        }
      };

      // Old app uses apiService.editAddress(body) -> we keep same behavior:
      // POST to /address/update with address.id in body
      final response = await ApiService.posts(
        ApiEndpoints.addressUpdate,
        body,
        token: token,
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        CustomSnackBar.show(context, 'Address Edited successfully', isError: false);
        Navigator.pop(context, decoded);
      } else {
        CustomSnackBar.show(context, 'Failed to Edit address', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(context, 'Something went wrong: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Address', style: AppTextStyles.heading3),
      ),
      body: SafeArea(
        child: _isSaving
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Address Type'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _addressType,
                        items: _addressTypes
                            .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) => setState(() => _addressType = val ?? 'Select'),
                        validator: (val) =>
                            val == 'Select' ? 'Please select address type' : null,
                        decoration: _fieldDecoration('Address Type'),
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('First Name'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: txtFirstName,
                        hint: 'First Name',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'First Name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Last Name'),
                      const SizedBox(height: 8),
                      _textField(controller: txtLastName, hint: 'Last Name'),
                      const SizedBox(height: 16),

                      _sectionTitle('Mobile Number'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: txtMobileNumber,
                        hint: 'Mobile Number',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                          if (v.trim().length != 10) return 'Enter 10 digit mobile number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Email'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: txtEmail,
                        hint: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter email';
                          final pattern = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!pattern.hasMatch(v.trim())) return 'Enter valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Address Line 1'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: txtAddressLine1,
                        hint: 'Street Address',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Street Address required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Address Line 2'),
                      const SizedBox(height: 8),
                      _textField(controller: txtAddressLine2, hint: 'Address Line 2'),
                      const SizedBox(height: 16),

                      _sectionTitle('City'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: txtCity,
                        hint: 'City',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'City is required' : null,
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('State'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _stateValue,
                        items: _states
                            .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) => setState(() => _stateValue = val ?? _stateValue),
                        validator: (val) => val == null || val.isEmpty ? 'Select State' : null,
                        decoration: _fieldDecoration('Select State'),
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Pincode'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: txtPincode,
                        hint: 'Pincode',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Pincode required';
                          if (v.trim().length != 6) return 'Enter 6 digit pincode';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _updateAddress,
                          child: const Text('UPDATE ADDRESS'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF6F6F6),
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: _fieldDecoration(hint),
      validator: validator,
    );
  }
}


