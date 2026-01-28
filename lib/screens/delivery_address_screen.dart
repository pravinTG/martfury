import 'dart:convert';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/spacing.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';
import '../services/session_manager.dart';
import '../utils/custom_snackbar.dart';
import '../utils/safe_print.dart';
import 'add_address_screen.dart';
import 'edit_address_screen.dart';

class DeliveryAddressScreen extends StatefulWidget {
  static const String routeName = '/delivery-address';
  
  final List<Map<String, dynamic>>? cartItems;
  final String? navigationValue;
  final String? discount;

  const DeliveryAddressScreen({
    super.key,
    this.cartItems,
    this.navigationValue,
    this.discount,
  });

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _addresses = [];
  String? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please login to view addresses';
        });
        return;
      }

      final response = await ApiService.gets(
        ApiEndpoints.addressList,
        token: token,
      );

      safePrint('Address list API response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> addresses = [];
        
        if (data is Map && data['addresses'] != null && data['addresses'] is List) {
          addresses = List<Map<String, dynamic>>.from(data['addresses']);
        } else if (data is List) {
          addresses = List<Map<String, dynamic>>.from(data);
        }

        setState(() {
          _addresses = addresses.reversed.toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load addresses: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching addresses: $e';
      });
      safePrint('Error fetching addresses: $e');
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      final token = await SessionManager.getValidFirebaseToken();
      if (token == null) {
        CustomSnackBar.show(context, 'Please login to delete addresses', isError: true);
        return;
      }

      final response = await ApiService.posts(
        ApiEndpoints.addressDelete,
        {"id": addressId},
        token: token,
      );

      safePrint('Delete address response: ${response.body}');

      if (response.statusCode == 200) {
        CustomSnackBar.show(context, 'Address deleted successfully!', isError: false);
        await _fetchAddresses();
        if (_selectedAddressId == addressId) {
          setState(() => _selectedAddressId = null);
        }
      } else {
        CustomSnackBar.show(context, 'Failed to delete address', isError: true);
      }
    } catch (e) {
      CustomSnackBar.show(context, 'Error deleting address: $e', isError: true);
      safePrint('Error deleting address: $e');
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Delivery Address',
          style: AppTextStyles.heading3,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddAddressScreen(
                    routename: widget.navigationValue,
                    cartItems: widget.cartItems ?? const [],
                    discount: widget.discount,
                  ),
                ),
              );
              if (result != null) {
                await _fetchAddresses();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAddresses,
        color: AppColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _errorMessage != null
                ? _buildErrorState()
                : _addresses.isEmpty
                    ? _buildEmptyState()
                    : Stack(
                        children: [
                          ListView.separated(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: 80,
                            ),
                            itemBuilder: (context, index) {
                              final address = _addresses[index];
                              final addressId = address['id']?.toString() ?? '';
                              final isSelected = _selectedAddressId == addressId;

                              return _buildAddressCard(
                                address: address,
                                isSelected: isSelected,
                                onSelect: () {
                                  setState(() {
                                    _selectedAddressId =
                                        _selectedAddressId == addressId ? null : addressId;
                                  });
                                },
                                onDelete: () => _deleteAddress(addressId),
                                onEdit: () async {
                                  final result = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => EditAddressScreen(
                                        addressId: addressId,
                                        addressData: address,
                                        navigate: widget.navigationValue,
                                        cartItems: widget.cartItems ?? const [],
                                        discount: widget.discount,
                                      ),
                                    ),
                                  );
                                  if (result != null) {
                                    await _fetchAddresses();
                                  }
                                },
                              );
                            },
                            separatorBuilder: (_, __) => Spacing.sizedBoxH12,
                            itemCount: _addresses.length,
                          ),
                          if (_selectedAddressId != null)
                            _buildDeliverButton(),
                        ],
                      ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddAddressScreen(
                      routename: widget.navigationValue,
                      cartItems: widget.cartItems ?? const [],
                      discount: widget.discount,
                    ),
                  ),
                );
                if (result != null) {
                  await _fetchAddresses();
                }
              },
              child: Text(
                'ADD NEW ADDRESS',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard({
    required Map<String, dynamic> address,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onDelete,
    required VoidCallback onEdit,
  }) {
    final firstName = address['first_name']?.toString() ?? '';
    final lastName = address['last_name']?.toString() ?? '';
    final phone = address['phone']?.toString() ?? '';
    final address1 = address['address_1']?.toString() ?? '';
    final address2 = address['address_2']?.toString() ?? '';
    final city = address['city']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    final pincode = address['postcode']?.toString() ?? '';
    final addressType = address['address_type']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        // If this screen was opened from Checkout "Change", return selected address immediately
        onSelect();
        if (isSelected) {
          final result = _toCheckoutAddress(address);
          Navigator.of(context).pop(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (addressType.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      addressType.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const Spacer(),
                Radio<String>(
                  value: address['id']?.toString() ?? '',
                  groupValue: _selectedAddressId,
                  onChanged: (_) {
                    onSelect();
                    if (!isSelected) {
                      // After selecting, allow quick return for Checkout flow
                      final result = _toCheckoutAddress(address);
                      Navigator.of(context).pop(result);
                    }
                  },
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            Spacing.sizedBoxH12,
            Row(
              children: [
                Text(
                  '$firstName $lastName',
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacing.sizedBoxW8,
                Text(
                  '│',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Spacing.sizedBoxW8,
                Text(
                  phone,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Spacing.sizedBoxH8,
            Text(
              address1,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (address2.isNotEmpty) ...[
              Spacing.sizedBoxH4,
              Text(
                address2,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            Spacing.sizedBoxH4,
            Text(
              '$city, $state - $pincode',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Spacing.sizedBoxH12,
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[700]),
                    label: Text(
                      'REMOVE',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    label: Text(
                      'EDIT',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverButton() {
    if (_selectedAddressId == null) return const SizedBox.shrink();

    final selectedAddress = _addresses.firstWhere(
      (addr) => addr['id']?.toString() == _selectedAddressId,
      orElse: () => {},
    );

    if (selectedAddress.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.delivery_dining, size: 20),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            // Match CheckoutScreen expectation: pop back a Map<String, String>
            Navigator.of(context).pop(_toCheckoutAddress(selectedAddress));
          },
          label: Text(
            'DELIVER TO THIS ADDRESS',
            style: AppTextStyles.body1.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// Convert API address map to the simple shape used by `CheckoutScreen`.
  Map<String, String> _toCheckoutAddress(Map<String, dynamic> address) {
    final firstName = address['first_name']?.toString() ?? '';
    final lastName = address['last_name']?.toString() ?? '';
    final phone = address['phone']?.toString() ?? '';
    final address1 = address['address_1']?.toString() ?? '';
    final address2 = address['address_2']?.toString() ?? '';
    final city = address['city']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    final pincode = address['postcode']?.toString() ?? '';

    final line1Parts = <String>[address1, address2, '$city, $state - $pincode']
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return {
      'name': ('$firstName $lastName').trim(),
      'phone': phone,
      'addressLine1': line1Parts.join(', '),
    };
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error,
            ),
            Spacing.sizedBoxH16,
            Text(
              _errorMessage ?? 'Error loading addresses',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            Spacing.sizedBoxH16,
            ElevatedButton(
              onPressed: _fetchAddresses,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 80,
            color: AppColors.textSecondary,
          ),
          Spacing.sizedBoxH16,
          Text(
            'No addresses found',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Spacing.sizedBoxH8,
          Text(
            'Add your first address to get started',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
