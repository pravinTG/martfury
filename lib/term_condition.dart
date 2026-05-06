import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:martfury/theme/app_text_styles.dart';
import '../api_service.dart';
import '../theme/app_colors.dart';

class TermCondition extends StatefulWidget {
  const TermCondition({super.key});

  @override
  State<TermCondition> createState() => _TermConditionState();
}

class _TermConditionState extends State<TermCondition> {
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
      final page = await _apiService.getPage(451);

      setState(() {
        _title = (page['title']?['rendered'] ?? '').toString();
        _contentHtml = (page['content']?['rendered'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
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
        backgroundColor: AppColors.yellow,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Terms and Conditions",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
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
              Text(
                'Error: $_error',
                textAlign: TextAlign.center,
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
                "*":Style.fromTextStyle(AppTextStyles.body2.copyWith(fontSize: 16)),
              },
            )
          ],
        ),
      ),
    );
  }
}
