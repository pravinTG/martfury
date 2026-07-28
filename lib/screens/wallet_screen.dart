import 'package:flutter/material.dart';
import 'package:martfury/api_service.dart';
import 'package:martfury/theme/app_colors.dart';
import 'package:martfury/theme/app_text_styles.dart';
import 'package:martfury/token_storage_service.dart';
import 'package:martfury/widgets/async_state_view.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:martfury/razorpay_config.dart';

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

  bool _isSubmittingWithdraw = false;
  late Razorpay _razorpay;
  double? _addingAmount;
  
  bool _showBonusTooltip = false;

  @override
  void initState() {
    super.initState();
    _load();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_addingAmount == null || _userId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.addWalletBalance(
        userId: _userId!,
        amount: _addingAmount!,
        note: 'Wallet Recharge via Razorpay (${response.paymentId})',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((res['message'] ?? 'Wallet balance added successfully').toString()),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update wallet: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    } finally {
      _addingAmount = null;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _addingAmount = null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}'), backgroundColor: Colors.red),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _addingAmount = null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: ${response.walletName}')),
    );
  }

  void _startAddBalanceFlow() {
    final TextEditingController amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Add Balance',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the amount you wish to top up.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.headerRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _addingAmount = amount;
                      
                      final amountPaise = (amount * 100).round();
                      _razorpay.open({
                        'key': RazorpayConfig.keyId,
                        'amount': amountPaise,
                        'currency': 'INR',
                        'name': 'Goodies World',
                        'description': 'Wallet Recharge',
                        'theme': {
                          'color': '#4B1F78',
                        },
                      });
                    },
                    child: const Text('Proceed to Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
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
        _apiService.getWalletData(uid),
        _apiService.getWalletTransactions(uid),
      ]);

      setState(() {
        final walletData = results[0] as Map<String, double>;
        _walletBalance = walletData['main_wallet'] ?? 0;
        _usableBalance = walletData['usable_wallet'] ?? 0;
        _lockedBalance = walletData['bonus_wallet'] ?? 0;
        
        final transactions = (results[1] as List).cast<Map<String, dynamic>>();
        
        // Combine both lists and sort by date descending
        _transactions = [...transactions];
        _transactions.sort((a, b) {
          final dateA = DateTime.tryParse((a['date'] ?? '').toString()) ?? DateTime(2000);
          final dateB = DateTime.tryParse((b['date'] ?? '').toString()) ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerRed,
        title: const Text('Wallet', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: AsyncStateView(
        isLoading: _isLoading,
        errorMessage: _error,
        onRetry: _load,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewPadding.bottom + 120),
      children: [
        _balanceCard(),
        const SizedBox(height: 12),
        _quickActions(),
        const SizedBox(height: 12),
        _withdrawCard(),
        Text(
          'Transaction history',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: 16),
        _transactionHistoryList(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.headerRed, Color(0xFF962323)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerRed.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet Balance',
                style: AppTextStyles.body2.copyWith(color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${_usableBalance.toStringAsFixed(2)}',
            style: AppTextStyles.heading1.copyWith(
              color: Colors.white,
              fontSize: 36,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Bonus',
                  _lockedBalance,
                  hasLock: true,
                  onTap: () {
                    setState(() {
                      _showBonusTooltip = !_showBonusTooltip;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_showBonusTooltip)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 220,
                  child: _buildTooltip(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTooltip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 30),
          child: CustomPaint(
            size: const Size(14, 8),
            painter: TrianglePainter(color: Colors.black87),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Will unlock when offer conditions are complete.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _showBonusTooltip = false;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, double value, {bool hasLock = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white70, fontWeight: FontWeight.w500)),
              if (hasLock) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock, color: Colors.white70, size: 12),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: AppTextStyles.body1.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _quickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _actionTile(Icons.add_circle_outline, 'Add Balance', Colors.blue),
          // _actionTile(Icons.compare_arrows, 'Transfer', Colors.orange),
          _actionTile(Icons.account_balance_wallet_outlined, 'Withdraw', Colors.green),
          // _actionTile(Icons.group_outlined, 'Referral', Colors.purple),
          // _actionTile(Icons.verified_user_outlined, 'KYC Info', Colors.red),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, MaterialColor color) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 32 * 2 - 16 * 2) / 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (label == 'Withdraw' || label == 'Withdraw Request') {
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
          if (label == 'Add Balance') {
            _startAddBalanceFlow();
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label coming soon')),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color.shade600, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withdrawCard() {
    return Container(
      key: _withdrawCardKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.purpleLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.yellow, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Withdraw Money',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixText: '₹ ',
                prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                hintText: '0',
                hintStyle: TextStyle(fontSize: 24, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmittingWithdraw ? null : _submitWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.headerRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSubmittingWithdraw
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Submit Request', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }


  Widget _transactionHistoryList() {
    if (_transactions.isEmpty) {
      return _emptyList('No transactions found');
    }
    return Column(
      children: _transactions.map((r) {
        final amount = double.tryParse((r['amount'] ?? r['total'] ?? '0').toString()) ?? 0;
        final typeStr = (r['transaction_type_1'] ?? r['type'] ?? r['transaction_type'] ?? '').toString().toLowerCase();
        final isCredit = typeStr == 'credit' || typeStr.contains('credit');
        
        String details = (r['note'] ?? r['details'] ?? '').toString().trim();
        String titleText = (r['transaction_type'] ?? '').toString().trim();
        if (titleText.isEmpty || titleText.toLowerCase() == 'debit' || titleText.toLowerCase() == 'credit') {
          if (details.isNotEmpty) {
            titleText = details;
          }
        }
        if (titleText.isEmpty) titleText = 'Transaction';

        final date = (r['date'] ?? r['created_at'] ?? '').toString();

        if (titleText == 'Withdraw Request' && r.containsKey('withdraw_status')) {
          return _withdrawRequestCard(r, amount, date);
        }

        return _listCard(
          icon: isCredit ? Icons.arrow_downward : Icons.arrow_upward,
          iconColor: isCredit ? Colors.green : Colors.red,
          title: titleText,
          subtitle: date,
          trailing: Text(
            '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isCredit ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _withdrawRequestCard(Map<String, dynamic> r, double amount, String date) {
    final status = (r['withdraw_status'] ?? '').toString().toLowerCase();
    final paymentMethod = (r['payment_method'] ?? '').toString();
    final reference = (r['transaction_reference'] ?? '').toString();
    final remarks = (r['remarks'] ?? '').toString();
    
    String displayDate = date;
    if (status == 'approved' && r['approved_at'] != null && r['approved_at'].toString().isNotEmpty) {
      displayDate = r['approved_at'].toString();
    } else if (status == 'rejected' && r['rejected_at'] != null && r['rejected_at'].toString().isNotEmpty) {
      displayDate = r['rejected_at'].toString();
    }
    
    Color statusColor;
    String statusIcon;
    String statusText;
    
    if (status == 'approved') {
      statusColor = Colors.green;
      statusIcon = '🟢';
      statusText = 'Approved';
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusIcon = '🔴';
      statusText = 'Rejected';
    } else {
      statusColor = Colors.orange;
      statusIcon = '🟡';
      statusText = 'Pending';
    }

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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_upward, color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Withdraw Request', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(displayDate, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(statusIcon),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (paymentMethod.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Payment Method : $paymentMethod', style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                  ],
                  if (reference.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Reference No : $reference', style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                  ],
                  if (remarks.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Remarks : $remarks', style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listCard({
    required IconData icon,
    Color iconColor = AppColors.yellow,
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
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
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

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width / 2, 0); // Top center
    path.lineTo(0, size.height); // Bottom left
    path.lineTo(size.width, size.height); // Bottom right
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

