import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
  String _title = '';
  String _contentHtml = '';

  @override
  void initState() {
    super.initState();
    _fetchFaq();
  }

  Future<void> _fetchFaq() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await _apiService.getPage(137);

      setState(() {
        _title = (page['title']?['rendered'] ?? '').toString();
        _contentHtml = (page['content']?['rendered'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      print('💥 Failed to load FAQ API: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.headerRed,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "FAQ'S",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),

      // ------- BODY DIRECTLY HERE -------
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Failed to load data',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _fetchFaq,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_title.isNotEmpty)
              Text(
                  _title,
                  style: AppTextStyles.heading1
              ),
            const SizedBox(height: 12),
            Html(
              data: _contentHtml,
              style: {
                "body": Style(
                  fontSize: FontSize(15.0),
                  color: Colors.black87,
                  lineHeight: LineHeight(1.6),
                ),
                "h1": Style(fontWeight: FontWeight.bold, fontSize: FontSize(22.0), color: AppColors.headerRed, margin: Margins.only(top: 16, bottom: 8)),
                "h2": Style(fontWeight: FontWeight.bold, fontSize: FontSize(20.0), color: AppColors.headerRed, margin: Margins.only(top: 16, bottom: 8)),
                "h3": Style(fontWeight: FontWeight.bold, fontSize: FontSize(18.0), color: AppColors.headerRed, margin: Margins.only(top: 16, bottom: 8)),
                "h4": Style(fontWeight: FontWeight.bold, fontSize: FontSize(16.0), color: AppColors.headerRed, margin: Margins.only(top: 16, bottom: 8)),
                "h5": Style(fontWeight: FontWeight.bold, fontSize: FontSize(15.0), color: AppColors.headerRed, margin: Margins.only(top: 16, bottom: 8)),
                "h6": Style(fontWeight: FontWeight.bold, fontSize: FontSize(14.0), color: AppColors.headerRed, margin: Margins.only(top: 16, bottom: 8)),
                "strong": Style(fontWeight: FontWeight.bold, color: Colors.black, fontSize: FontSize(16.0)),
                "p": Style(fontSize: FontSize(15.0), color: Colors.black87, margin: Margins.only(bottom: 12)),
                "li": Style(fontSize: FontSize(15.0), color: Colors.black87, margin: Margins.only(bottom: 6)),
              },
            )
          ],
        ),
      ),
    );
  }
}
