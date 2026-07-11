import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/theme/app_text_styles.dart';
import 'package:martfury/widgets/async_state_view.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerRed,
        title: Text('Order #$orderId', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: apiService.getOrderById(orderId),
        builder: (context, snapshot) {
          final order = snapshot.data ?? {};
          final lineItems = (order['line_items'] as List?) ?? [];
          return AsyncStateView(
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            errorMessage: snapshot.hasError
                ? 'Failed to load order detail: ${snapshot.error}'
                : null,
            onRetry: () {},
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _orderHeader(order),
                      const SizedBox(height: 16),
                      Text('Items', style: AppTextStyles.heading2),
                      const SizedBox(height: 8),
                      ...lineItems.map((item) {
                        final row = item as Map<String, dynamic>;
                        return _itemCard(row);
                      }),
                    ],
                  ),
                ),
                if (order['status'] != 'refunded' && order['status'] != 'cancelled' && order['status'] != 'failed')
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewPadding.bottom + 80),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showRefundBottomSheet(context, orderId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.headerRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Request Return', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRefundBottomSheet(BuildContext context, int orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _RefundForm(orderId: orderId),
        );
      },
    );
  }

  Widget _orderHeader(Map<String, dynamic> order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _detailTile('Status', '${order['status'] ?? '-'}'),
          _detailTile('Total', '₹${order['total'] ?? '-'}', highlight: true),
          _detailTile('Payment', '${order['payment_method_title'] ?? '-'}'),
          _detailTile('Date', '${order['date_created'] ?? '-'}'),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: AppTextStyles.body2),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.body1.copyWith(
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? AppColors.yellow : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final imageUrl = _extractImageUrl(item);
    final quantity = int.tryParse(item['quantity'].toString()) ?? 1;
    final total = _toDouble(item['total'] ?? item['subtotal'] ?? item['price']);
    final unitPrice = quantity > 0 ? total / quantity : total;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 74,
                    height: 74,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['name'] ?? ''}',
                  style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${unitPrice.toStringAsFixed(2)} x $quantity',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Text(
            '₹${total.toStringAsFixed(2)}',
            style: AppTextStyles.body1.copyWith(
              color: AppColors.yellow,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _extractImageUrl(Map<String, dynamic> item) {
    final image = item['image'];
    if (image is Map && image['src'] != null) return image['src'].toString();
    if (image is String) return image;
    final images = item['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['src'] != null) return first['src'].toString();
    }
    return '';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    final sanitized = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(sanitized) ?? 0;
  }

  Widget _placeholder() {
    return Container(
      width: 74,
      height: 74,
      color: AppColors.purpleLight,
      child: const Icon(Icons.fastfood_outlined, color: AppColors.yellow),
    );
  }
}

class _RefundForm extends StatefulWidget {
  final int orderId;
  const _RefundForm({required this.orderId});

  @override
  State<_RefundForm> createState() => _RefundFormState();
}

class _RefundFormState extends State<_RefundForm> {
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();

  final List<String> _reasons = [
    'Received damaged product',
    'Product missing from the package',
    'Wrong product received',
    'Product not as described',
    'Other'
  ];
  
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    print('👉 Submit clicked');
    final reason = _selectedReason == 'Other' 
        ? _customReasonController.text.trim() 
        : _selectedReason;

    print('👉 Selected reason: $_selectedReason');
    print('👉 Custom reason: ${_customReasonController.text.trim()}');
    print('👉 Final reason to submit: $reason');

    if (reason == null || reason.isEmpty) {
      print('⚠️ Reason is empty. Showing snackbar.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for refund')),
      );
      return;
    }

    setState(() => _isLoading = true);
    print('🔄 isLoading set to true. Calling API...');
    
    try {
      final res = await _apiService.refundOrder(
        orderId: widget.orderId,
        reason: reason,
        imagePaths: _selectedImages.map((e) => e.path).toList(),
      );
      
      print('✅ API success response: $res');
      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        print('🎉 Showing success dialog');
        _showSuccessDialog(res['message'] ?? 'Refund request submitted successfully');
      }
    } catch (e) {
      print('❌ API error caught: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        print('⏹️ Setting isLoading to false');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text('Success!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.headerRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(color: Colors.white, fontSize: 16)),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Request Return',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Select Reason',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: const TextStyle(color: Colors.black, fontSize: 16),
            value: _selectedReason,
            items: _reasons.map((r) => DropdownMenuItem(
              value: r, 
              child: Text(r, style: const TextStyle(color: Colors.black)),
            )).toList(),
            onChanged: (val) {
              setState(() {
                _selectedReason = val;
              });
            },
          ),
          if (_selectedReason == 'Other') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customReasonController,
              decoration: InputDecoration(
                labelText: 'Enter your reason',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate, color: AppColors.headerRed),
                label: const Text('Add Images', style: TextStyle(color: AppColors.headerRed)),
              ),
              const SizedBox(width: 12),
              Text('${_selectedImages.length} images selected', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 8),
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(_selectedImages[index].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.headerRed,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Submit Request', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }
}

