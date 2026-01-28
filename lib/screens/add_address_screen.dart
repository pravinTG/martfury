import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_endpoints.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/custom_snackbar.dart';

class AddAddressScreen extends StatefulWidget {
  final String? routename;
  final String? discount;
  final List<Map<String, dynamic>> cartItems;

  const AddAddressScreen({
    super.key,
    this.routename,
    required this.cartItems,
    this.discount,
  });

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _address1Ctrl = TextEditingController();
  final TextEditingController _address2Ctrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _zipCtrl = TextEditingController();

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

  String _stateValue = 'Maharashtra';
  bool _isSaving = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  Future<void> _addAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        if (!mounted) return;
        CustomSnackBar.show(context, 'Please login to add address', isError: true);
        return;
      }

      final Map<String, dynamic> body = {
        "address": {
          "first_name": _firstNameCtrl.text.trim(),
          "last_name": _lastNameCtrl.text.trim(),
          "email": _emailCtrl.text.trim(),
          "address_1": _address1Ctrl.text.trim(),
          "address_2": _address2Ctrl.text.trim(),
          "city": _cityCtrl.text.trim(),
          "state": _stateValue,
          "postcode": _zipCtrl.text.trim(),
          "country": "IN",
          "phone": _phoneCtrl.text.trim(),
          "address_type": _addressType,
        }
      };

      final response = await ApiService.posts(
        ApiEndpoints.addressAdd,
        body,
        token: token,
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        CustomSnackBar.show(context, 'Address added successfully!', isError: false);
        Navigator.pop(context, decoded);
      } else {
        CustomSnackBar.show(context, 'Failed to add address', isError: true);
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
        title: Text('Add New Address', style: AppTextStyles.heading3),
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
                      _addressTypeDropdown(),
                      const SizedBox(height: 16),

                      _sectionTitle('First Name *'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _firstNameCtrl,
                        hint: 'First Name',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Please enter first name' : null,
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Last Name'),
                      const SizedBox(height: 8),
                      _textField(controller: _lastNameCtrl, hint: 'Last Name'),
                      const SizedBox(height: 16),

                      _sectionTitle('Mobile Number *'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _phoneCtrl,
                        hint: 'Mobile Number',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter mobile number';
                          if (v.trim().length != 10) return 'Enter 10-digit mobile number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Email *'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _emailCtrl,
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

                      _sectionTitle('Address Line 1 *'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _address1Ctrl,
                        hint: 'Address Line 1',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter Address Line 1'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Address Line 2 *'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _address2Ctrl,
                        hint: 'Address Line 2',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter Address Line 2'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('City *'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _cityCtrl,
                        hint: 'City',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter city name' : null,
                      ),
                      const SizedBox(height: 16),

                      _sectionTitle('Select State *'),
                      const SizedBox(height: 8),
                      _stateDropdown(),
                      const SizedBox(height: 16),

                      _sectionTitle('Pincode *'),
                      const SizedBox(height: 8),
                      _textField(
                        controller: _zipCtrl,
                        hint: 'Pincode',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter pincode';
                          if (v.trim().length != 6) return 'Enter valid 6-digit pincode';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _addAddress,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text('Save Address', style: TextStyle(color: Colors.black)),
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
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  Widget _addressTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _addressType,
      items: _addressTypes
          .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
          .toList(),
      onChanged: (val) => setState(() => _addressType = val ?? 'Select'),
      validator: (val) => val == 'Select' ? 'Please select address type' : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _stateDropdown() {
    return DropdownButtonFormField<String>(
      value: _stateValue,
      items: _states
          .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
          .toList(),
      onChanged: (val) => setState(() => _stateValue = val ?? _stateValue),
      validator: (val) => val == null || val.isEmpty ? 'Please select a state' : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}



