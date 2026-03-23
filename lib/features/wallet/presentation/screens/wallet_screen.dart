import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/widgets/glass_card.dart';

final walletProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    // Try to fetch the wallet for this user
    final wallet = await client
        .from('wallets')
        .select('wallet_id, user_id, balance, created_at, updated_at')
        .eq('user_id', userId)
        .maybeSingle();

    // The SQL trigger handles wallet creation on signup.
    // We only create one here as a final safety fallback.
    if (wallet == null) {
      return await client
          .from('wallets')
          .insert({
            'user_id': userId,
            'balance': 0.0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('wallet_id, user_id, balance, created_at, updated_at')
          .single();
    }

    return wallet;
  } catch (e) {
    debugPrint('❌ Error fetching/creating wallet: $e');
    return null;
  }
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push(AppRoutes.transactionHistory),
          ),
        ],
      ),
      body: walletAsync.when(
        data: (wallet) {
          final balance =
              wallet != null ? (wallet['balance'] as num).toDouble() : 0.0;
          final walletId = wallet?['wallet_id'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0A2A3F),
                        Color(0xFF001F3F),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'FluxEV Wallet',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppFormatters.formatCurrency(balance),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Current Balance',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.95, 0.95)),
                const SizedBox(height: 28),

                // Quick actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ).animate(delay: 300.ms).fadeIn(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        onTap: () =>
                            _showAddMoneyDialog(context, ref, walletId),
                        child: const Column(
                          children: [
                            Icon(Icons.add_circle_rounded,
                                color: AppColors.primary, size: 32),
                            SizedBox(height: 8),
                            Text('Add Money',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            Text('To Wallet',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        onTap: () => context.push(AppRoutes.transactionHistory),
                        child: const Column(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                color: AppColors.secondary, size: 32),
                            SizedBox(height: 8),
                            Text('History',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            Text('Transactions',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate(delay: 400.ms).fadeIn(),
                const SizedBox(height: 28),

                // Quick preset amounts
                Text(
                  'Quick Top-up',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate(delay: 500.ms).fadeIn(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickAmountButton(
                      amount: 100,
                      onTap: () => _addMoneyToWallet(
                        context,
                        ref,
                        walletId,
                        100,
                      ),
                    ),
                    _QuickAmountButton(
                      amount: 500,
                      onTap: () => _addMoneyToWallet(
                        context,
                        ref,
                        walletId,
                        500,
                      ),
                    ),
                    _QuickAmountButton(
                      amount: 1000,
                      onTap: () => _addMoneyToWallet(
                        context,
                        ref,
                        walletId,
                        1000,
                      ),
                    ),
                    _QuickAmountButton(
                      amount: 2000,
                      onTap: () => _addMoneyToWallet(
                        context,
                        ref,
                        walletId,
                        2000,
                      ),
                    ),
                  ],
                ).animate(delay: 600.ms).fadeIn(),
                const SizedBox(height: 28),

                // Wallet info section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Testing Info',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Wallet ID',
                        walletId ?? 'Not found',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Status',
                        'Active',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Balance',
                        AppFormatters.formatCurrency(balance),
                      ),
                    ],
                  ),
                ).animate(delay: 700.ms).fadeIn(),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Loading wallet...',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading wallet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.error,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showAddMoneyDialog(
      BuildContext context, WidgetRef ref, String? walletId) {
    final amountController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Money to Wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter amount (₹)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [100, 500, 1000, 2000].map((amount) {
                  return FilterChip(
                    label: Text('₹$amount'),
                    onSelected: (_) {
                      amountController.text = amount.toString();
                    },
                    backgroundColor: AppColors.surfaceVariant,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    side: const BorderSide(color: AppColors.cardBorder),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      await _addMoneyToWallet(
                        context,
                        ref,
                        walletId,
                        amount,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    )
                  : const Text('Add Money'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMoneyToWallet(
    BuildContext context,
    WidgetRef ref,
    String? walletId,
    double amount,
  ) async {
    if (walletId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet not found. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User session not found. Please log in again.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Fetch current wallet for the logged-in user (safer than using walletId)
      final wallet = await client
          .from('wallets')
          .select('wallet_id, user_id, balance, created_at, updated_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (wallet == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet not found. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final currentBalance = (wallet['balance'] as num).toDouble();
      final newBalance = currentBalance + amount;

      // Update wallet balance using userId to ensure consistency
      await client.from('wallets').update({
        'balance': newBalance,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // Create transaction record
      await client.from('transactions').insert({
        'wallet_id': wallet['wallet_id'],
        'user_id': userId,
        'amount': amount,
        'type': 'credit',
        'description': 'Wallet Top-up',
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Invalidate wallet provider to refresh UI
      ref.invalidate(walletProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${AppFormatters.formatCurrency(amount)} added successfully!',
          ),
          backgroundColor: AppColors.markerAvailable,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      print('Error adding money: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _QuickAmountButton extends StatefulWidget {
  final double amount;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.amount,
    required this.onTap,
  });

  @override
  State<_QuickAmountButton> createState() => _QuickAmountButtonState();
}

class _QuickAmountButtonState extends State<_QuickAmountButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              await Future.delayed(const Duration(milliseconds: 500));
              widget.onTap();
              setState(() => _isLoading = false);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            )
          : Text(
              '₹${widget.amount.toInt()}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
