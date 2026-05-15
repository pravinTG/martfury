import 'package:flutter/material.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/screens/order_summary_screen.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/theme/app_text_styles.dart';

class AddressSelectionScreen extends StatefulWidget {
  const AddressSelectionScreen({super.key, required this.cartData});

  final Map<String, dynamic> cartData;

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _addresses = <Map<String, dynamic>>[];
  int? _selectedAddressId;

  bool get _isCheckoutFlow {
    final cartItems = widget.cartData['cart_items'];
    return cartItems is List && cartItems.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final addresses = await _apiService.getAddressList();
      setState(() {
        _addresses = addresses;
        _selectedAddressId = addresses.isNotEmpty
            ? int.tryParse(addresses.first['id'].toString())
            : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddressForm({Map<String, dynamic>? initial}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AddressFormSheet(initial: initial),
    );
    if (result == null) return;

    setState(() => _isSaving = true);
    try {
      if (initial == null) {
        await _apiService.addAddress(address: result);
      } else {
        await _apiService.updateAddress(
          address: <String, dynamic>{...result, 'id': initial['id']},
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(initial == null ? 'Address added' : 'Address updated'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadAddresses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Address save failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic>? get _selectedAddress {
    if (_selectedAddressId == null) return null;
    for (final a in _addresses) {
      final id = int.tryParse(a['id'].toString());
      if (id == _selectedAddressId) return a;
    }
    return null;
  }

  Future<void> _goToSummary() async {
    final selectedAddress = _selectedAddress;
    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an address first')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSummaryScreen(
          cartData: widget.cartData,
          selectedAddress: selectedAddress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Address', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.yellow,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load addresses\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadAddresses,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_addresses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No saved addresses found'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _openAddressForm(),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add Address'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAddresses,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _checkoutStepper(),
          const SizedBox(height: 12),
          ..._addresses.map((address) {
            final id = int.tryParse(address['id'].toString()) ?? -1;
            final selected = id == _selectedAddressId;
            return _addressCard(address, id, selected);
          }),
        ],
      ),
    );
  }

  Widget _checkoutStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purpleLight),
      ),
      child: Row(
        children: const [
          _AddressStepDot(label: 'Address', done: true, active: true),
          Expanded(child: Divider(thickness: 1)),
          _AddressStepDot(label: 'Summary', done: false),
          Expanded(child: Divider(thickness: 1)),
          _AddressStepDot(label: 'Payment', done: false),
        ],
      ),
    );
  }

  Widget _addressCard(Map<String, dynamic> address, int id, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.yellow : Colors.transparent,
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: RadioListTile<int>(
        value: id,
        groupValue: _selectedAddressId,
        activeColor: AppColors.yellow,
        onChanged: (value) => setState(() => _selectedAddressId = value),
        title: Text(
          '${address['first_name'] ?? ''} ${address['last_name'] ?? ''}',
          style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${address['address_1'] ?? ''}, ${address['address_2'] ?? ''}\n'
          '${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['postcode'] ?? ''}\n'
          'Phone: ${address['phone'] ?? ''}',
          style: AppTextStyles.caption.copyWith(height: 1.4),
        ),
        secondary: IconButton(
          onPressed: _isSaving ? null : () => _openAddressForm(initial: address),
          icon: Icon(Icons.edit_outlined, color: selected ? AppColors.yellow : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _isCheckoutFlow
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => _openAddressForm(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.yellow),
                      ),
                      child: const Text(
                        'Add New',
                        style: TextStyle(color: AppColors.yellow),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _goToSummary,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => _openAddressForm(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.yellow),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Add New Address',
                    style: TextStyle(color: AppColors.yellow),
                  ),
                ),
              ),
      ),
    );
  }
}

class _AddressStepDot extends StatelessWidget {
  const _AddressStepDot({
    required this.label,
    required this.done,
    this.active = false,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = done ? AppColors.yellow : AppColors.purpleLight;
    final Color fgColor = done ? Colors.white : AppColors.textSecondary;
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: bgColor,
          child: Icon(
            done ? Icons.check : Icons.circle,
            size: done ? 14 : 10,
            color: fgColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.yellow : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class AddressFormSheet extends StatefulWidget {
  const AddressFormSheet({super.key, this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _address1;
  late final TextEditingController _address2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _postcode;
  late final TextEditingController _phone;
  String _addressType = 'home';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? <String, dynamic>{};
    _firstName = TextEditingController(text: (initial['first_name'] ?? '').toString());
    _lastName = TextEditingController(text: (initial['last_name'] ?? '').toString());
    _email = TextEditingController(text: (initial['email'] ?? '').toString());
    _address1 = TextEditingController(text: (initial['address_1'] ?? '').toString());
    _address2 = TextEditingController(text: (initial['address_2'] ?? '').toString());
    _city = TextEditingController(text: (initial['city'] ?? '').toString());
    _state = TextEditingController(text: (initial['state'] ?? '').toString());
    _postcode = TextEditingController(text: (initial['postcode'] ?? '').toString());
    _phone = TextEditingController(text: (initial['phone'] ?? '').toString());
    _addressType = (initial['address_type'] ?? 'home').toString();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _address1.dispose();
    _address2.dispose();
    _city.dispose();
    _state.dispose();
    _postcode.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, viewInsets + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initial == null ? 'Add Address' : 'Edit Address',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _field(_firstName, 'First name'),
              _field(_lastName, 'Last name'),
              _field(_email, 'Email'),
              _field(_phone, 'Phone'),
              _field(_address1, 'Address line 1'),
              _field(_address2, 'Address line 2', required: false),
              _field(_city, 'City'),
              _field(_state, 'State'),
              _field(_postcode, 'Pincode'),
              DropdownButtonFormField<String>(
                value: _addressType,
                items: const [
                  DropdownMenuItem(value: 'home', child: Text('Home')),
                  DropdownMenuItem(value: 'office', child: Text('Office')),
                ],
                onChanged: (value) => setState(() => _addressType = value ?? 'home'),
                decoration: const InputDecoration(labelText: 'Address Type'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.pop(context, <String, dynamic>{
                      'first_name': _firstName.text.trim(),
                      'last_name': _lastName.text.trim(),
                      'email': _email.text.trim(),
                      'address_1': _address1.text.trim(),
                      'address_2': _address2.text.trim(),
                      'city': _city.text.trim(),
                      'state': _state.text.trim(),
                      'postcode': _postcode.text.trim(),
                      'country': 'IN',
                      'phone': _phone.text.trim(),
                      'address_type': _addressType,
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => (value == null || value.trim().isEmpty)
                ? 'Please enter $label'
                : null
            : null,
      ),
    );
  }
}
