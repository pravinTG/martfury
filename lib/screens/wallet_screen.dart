import 'package:flutter/material.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/theme/app_text_styles.dart';
import 'package:martfury/token_storage_service.dart';
import 'package:martfury/widgets/async_state_view.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _amountController = TextEditingController();
  final GlobalKey _withdrawCardKey = GlobalKey();

  bool _isLoading = true;
  String? _error;
  int? _userId;

  double _walletBalance = 0;
  double _usableBalance = 0;
  double _lockedBalance = 0;

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _withdrawRequests = [];

  bool _isSubmittingWithdraw = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final idStr = await TokenStorageService.getUserId();
      final uid = int.tryParse(idStr ?? '');
      if (uid == null) {
        throw Exception('User id not found. Please login again.');
      }
      _userId = uid;

      final results = await Future.wait([
        _apiService.getWalletBalance(uid),
        _apiService.getUsableBalance(uid),
        _apiService.getLockedBalance(uid),
        _apiService.getWalletTransactions(uid),
        _apiService.getWithdrawRequests(uid),
      ]);

      setState(() {
        _walletBalance = results[0] as double;
        _usableBalance = results[1] as double;
        _lockedBalance = results[2] as double;
        _transactions = (results[3] as List).cast<Map<String, dynamic>>();
        _withdrawRequests = (results[4] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitWithdraw() async {
    final uid = _userId;
    if (uid == null) return;
    if (_isSubmittingWithdraw) return;

    final raw = _amountController.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSubmittingWithdraw = true);
    try {
      final res = await _apiService.createWithdrawRequest(userId: uid, amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((res['message'] ?? 'Withdraw request submitted').toString()),
          backgroundColor: Colors.green,
        ),
      );
      _amountController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingWithdraw = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.yellow,
          title: const Text('Wallet', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Transactions'),
              Tab(text: 'Withdraw History'),
            ],
          ),
        ),
        body: AsyncStateView(
          isLoading: _isLoading,
          errorMessage: _error,
          onRetry: _load,
          child: TabBarView(
            children: [
              _buildContent(showWithdrawHistory: false),
              _buildContent(showWithdrawHistory: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent({required bool showWithdrawHistory}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _balanceCard(),
        const SizedBox(height: 12),
        _quickActions(),
        const SizedBox(height: 12),
        _withdrawCard(),
        const SizedBox(height: 16),
        Text(
          showWithdrawHistory ? 'Withdraw requests' : 'Transactions',
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: 10),
        if (showWithdrawHistory) _withdrawHistoryList() else _transactionList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Balance',
            style: AppTextStyles.body2.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_walletBalance.toStringAsFixed(2)}',
            style: AppTextStyles.heading1.copyWith(
              color: Colors.white,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniStat('Usable', _usableBalance),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStat('Locked', _lockedBalance),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: AppTextStyles.body1.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _actionTile(Icons.add_circle_outline, 'Add Balance'),
          _actionTile(Icons.compare_arrows, 'Wallet Transfer'),
          _actionTile(Icons.account_balance_wallet_outlined, 'Withdraw Request'),
          _actionTile(Icons.group_outlined, 'Wallet Referral'),
          _actionTile(Icons.verified_user_outlined, 'KYC Verification'),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 12 * 2) / 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (label == 'Withdraw Request') {
            final ctx = _withdrawCardKey.currentContext;
            if (ctx != null) {
              await Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
              );
            }
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label coming soon')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.purpleLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.yellow),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withdrawCard() {
    return Container(
      key: _withdrawCardKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter Amount (₹)', style: AppTextStyles.body2),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '100',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 140,
            child: ElevatedButton(
              onPressed: _isSubmittingWithdraw ? null : _submitWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmittingWithdraw
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Proceed', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionList() {
    if (_transactions.isEmpty) {
      return _emptyList('No transactions found');
    }
    return Column(
      children: _transactions.map((t) {
        final type = (t['transaction_type'] ?? '').toString();
        final amount = double.tryParse((t['amount'] ?? '0').toString()) ?? 0;
        final date = (t['date'] ?? '').toString();
        final isCredit = type.toLowerCase() == 'credit';
        return _listCard(
          icon: isCredit ? Icons.add : Icons.remove,
          title: isCredit ? 'Credit' : 'Debit',
          subtitle: date,
          trailing: Text(
            '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
            style: AppTextStyles.body1.copyWith(
              fontWeight: FontWeight.w700,
              color: isCredit ? AppColors.success : AppColors.error,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _withdrawHistoryList() {
    if (_withdrawRequests.isEmpty) {
      return _emptyList('No withdraw requests');
    }
    return Column(
      children: _withdrawRequests.map((r) {
        final amount = double.tryParse((r['amount'] ?? '0').toString()) ?? 0;
        final status = (r['status'] ?? '').toString();
        final createdAt = (r['created_at'] ?? '').toString();
        return _listCard(
          icon: Icons.account_balance_wallet_outlined,
          title: '₹${amount.toStringAsFixed(2)}',
          subtitle: createdAt,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: _statusColor(status),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('approved') || s.contains('completed')) return AppColors.success;
    if (s.contains('rejected') || s.contains('failed')) return AppColors.error;
    return AppColors.warning;
  }

  Widget _listCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.purpleLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.yellow),
        ),
        title: Text(title, style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: trailing,
      ),
    );
  }

  Widget _emptyList(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(text, style: AppTextStyles.body2),
      ),
    );
  }
}

