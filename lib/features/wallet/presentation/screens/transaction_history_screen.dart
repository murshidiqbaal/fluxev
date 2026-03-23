import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../shared/widgets/glass_card.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder(
        future: _fetchTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('${snapshot.error}',
                    style: const TextStyle(color: AppColors.error)));
          }
          final txns = snapshot.data ?? [];
          if (txns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: AppColors.textSecondary, size: 56),
                  const SizedBox(height: 16),
                  const Text('No transactions yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: txns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final t = txns[i];
              final isDebit = t['type'] == 'debit';
              final amount = (t['amount'] as num).toDouble();
              return GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (isDebit
                                ? AppColors.error
                                : AppColors.markerAvailable)
                            .withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDebit
                            ? Icons.electric_bolt_rounded
                            : Icons.add_rounded,
                        color: isDebit
                            ? AppColors.error
                            : AppColors.markerAvailable,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDebit ? 'Charging Session' : 'Wallet Top-up',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                          Text(
                            AppFormatters.formatDate(
                              DateTime.parse(t['created_at'] as String),
                            ),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isDebit ? '-' : '+'}${AppFormatters.formatCurrency(amount)}',
                      style: TextStyle(
                        color: isDebit
                            ? AppColors.error
                            : AppColors.markerAvailable,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: (i * 60).ms)
                  .fadeIn()
                  .slide(begin: const Offset(0.1, 0));
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final wallet = await client
        .from('wallets')
        .select('wallet_id, user_id, balance, created_at, updated_at')
        .eq('user_id', userId)
        .maybeSingle();
    if (wallet == null) return [];

    final txns = await client
        .from('transactions')
        .select()
        .eq('wallet_id', wallet['wallet_id'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(txns);
  }
}
