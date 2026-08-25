import 'package:flutter/material.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/theme/app_text_styles.dart';
import 'package:martfury/widgets/async_state_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'product_detail_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _offers = [];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final offers = await _apiService.getRechargeOffers();
      if (mounted) {
        setState(() {
          _offers = offers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load offers. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  // void _handleOfferClick(Map<String, dynamic> offer) async {
  //   final linkType = (offer['link_type'] ?? '').toString().toLowerCase();
    
  //   if (linkType == 'product' && offer['product_id'] != null) {
  //     final productIdStr = offer['product_id'].toString();
  //     final productId = int.tryParse(productIdStr);
  //     if (productId != null) {
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (_) => ProductDetailScreen(productId: productId),
  //         ),
  //       );
  //     }
  //   } else if (offer['url'] != null && offer['url'].toString().isNotEmpty) {
  //     final urlStr = offer['url'].toString();
  //     final uri = Uri.parse(urlStr);
  //     try {
  //       if (await canLaunchUrl(uri)) {
  //         final openNewTab = offer['open_new_tab'] == true;
  //         await launchUrl(
  //           uri, 
  //           mode: openNewTab ? LaunchMode.externalApplication : LaunchMode.platformDefault,
  //         );
  //       }
  //     } catch (e) {
  //       debugPrint('Could not launch URL: $e');
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerRed,
        title: const Text('Offers', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        automaticallyImplyLeading: false, // Don't show back button in bottom nav
      ),
      body: AsyncStateView(
        isLoading: _isLoading,
        errorMessage: _error,
        onRetry: _loadOffers,
        child: _offers.isEmpty && !_isLoading
            ? _buildEmptyState()
            : _buildContent(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_offer_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No Offers Available',
            style: AppTextStyles.heading2.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for exciting deals!',
            style: AppTextStyles.body2.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadOffers,
      color: AppColors.headerRed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _offers.length,
        itemBuilder: (context, index) {
          final offer = _offers[index];
          final bannerUrl = offer['banner']?.toString() ?? '';
          final title = offer['title']?.toString() ?? '';
          final description = offer['description']?.toString() ?? '';
          
          return GestureDetector(
            onTap: () {
              
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bannerUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(color: AppColors.headerRed),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty) ...[
                          Text(
                            title,
                            style: AppTextStyles.heading3,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: AppTextStyles.body2.copyWith(color: Colors.grey.shade700),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
