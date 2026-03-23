import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/neon_button.dart';

class ChargingSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ChargingSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ChargingSessionScreen> createState() =>
      _ChargingSessionScreenState();
}

class _ChargingSessionScreenState extends ConsumerState<ChargingSessionScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  double _energyConsumed = 0.0;
  double _totalCost = 0.0;
  double _pricePerKwh = 8.0; // default, will update from DB
  bool _stopping = false;
  Map<String, dynamic>? _sessionData;
  bool _loading = true;
  double _maxPowerKw = 7.2; // default
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session = await _client.from('charging_sessions').select('''
            *,
            connectors(connector_id, max_power_kw, stations(price_per_kwh))
          ''').eq('session_id', widget.sessionId).maybeSingle();

      if (session == null) throw Exception('Session not found');

      setState(() {
        _sessionData = session;
        _pricePerKwh =
            (session['connectors']['stations']['price_per_kwh'] as num)
                .toDouble();
        _maxPowerKw = (session['connectors']['max_power_kw'] as num).toDouble();
        _loading = false;
      });
      _startTimer();
    } catch (e) {
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  void _startTimer() {
    // Energy per second: maxPowerKw / 3600 (kWh/s)
    final energyPerSecond = _maxPowerKw / 3600;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed += const Duration(seconds: 1);
        _energyConsumed += energyPerSecond;
        _totalCost = _energyConsumed * _pricePerKwh;
      });
    });
  }

  Future<void> _stopSession() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    _timer?.cancel();

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      // 1. Calculate & Validate Wallet
      final wallet = await _client
          .from('wallets')
          .select('wallet_id, user_id, balance, created_at, updated_at')
          .eq('user_id', userId)
          .maybeSingle();

      final balance = (wallet?['balance'] as num?)?.toDouble() ?? 0.0;
      if (balance < _totalCost) {
        // Allow session to stop but maybe mark as 'failed_payment' or prompt to add money
        // For now, we'll just throw error as per plan
        throw Exception('Insufficient wallet balance to pay ₹${_totalCost.toStringAsFixed(2)}');
      }

      final connectorId = _sessionData!['connector_id'];

      // 2. Mark Connector AVAILABLE (important to free it up immediately)
      await _client
          .from('connectors')
          .update({'status': 'available'}).eq('connector_id', connectorId);

      // 3. Update Session to COMPLETED
      await _client.from('charging_sessions').update({
        'end_time': DateTime.now().toIso8601String(),
        'energy_consumed_kwh': _energyConsumed,
        'total_cost': _totalCost,
        'status': 'completed',
      }).eq('session_id', widget.sessionId);

      // 4. Deduct Wallet Balance
      final newBalance = balance - _totalCost;
      await _client.from('wallets').update({
        'balance': newBalance,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('user_id', userId);

      // 5. Create Transaction Log
      await _client.from('transactions').insert({
        'wallet_id': wallet?['wallet_id'],
        'session_id': widget.sessionId,
        'amount': _totalCost,
        'type': 'debit',
      });

      if (!mounted) return;
      _showSummaryDialog();
    } catch (e) {
      setState(() => _stopping = false);
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
      
      // If payment failed but timer stopped, we should ideally restart timer or allow retry
      // For simplicity, we'll just let the user try stopping again after adding balance
      if (_timer == null || !_timer!.isActive) {
        _startTimer(); // Restart simulation if it was stopped but DB update failed
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.markerAvailable, size: 28),
            SizedBox(width: 10),
            Text('Session Complete!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow('Duration', AppFormatters.formatDuration(_elapsed)),
            _SummaryRow(
                'Energy Used', AppFormatters.formatEnergy(_energyConsumed)),
            _SummaryRow('Total Cost', AppFormatters.formatCurrency(_totalCost),
                highlight: true),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(AppRoutes.map);
            },
            child: const Text('Back to Map'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Charging',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.markerAvailable.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.markerAvailable),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.markerAvailable,
                            shape: BoxShape.circle,
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .fadeOut(duration: 800.ms),
                        const SizedBox(width: 6),
                        const Text('Active',
                            style: TextStyle(
                                color: AppColors.markerAvailable,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Timer ring
                    GlassCard(
                      borderColor: AppColors.primary,
                      child: Column(
                        children: [
                          const Text(
                            'Time Elapsed',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppFormatters.formatDuration(_elapsed),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms),
                    const SizedBox(height: 20),
                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(Icons.electric_bolt_rounded,
                                    color: AppColors.primary, size: 26),
                                const SizedBox(height: 8),
                                Text(
                                  AppFormatters.formatEnergy(_energyConsumed),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const Text('Energy',
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
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(Icons.currency_rupee_rounded,
                                    color: AppColors.warning, size: 26),
                                const SizedBox(height: 8),
                                Text(
                                  AppFormatters.formatCurrency(_totalCost),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const Text('Cost',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ).animate(delay: 200.ms).fadeIn(),
                    const SizedBox(height: 40),
                    // Stop button
                    NeonButton(
                      label: 'Stop Charging & Pay',
                      isLoading: _stopping,
                      icon: Icons.stop_circle_outlined,
                      onPressed: _stopSession,
                    ).animate(delay: 400.ms).fadeIn(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.primary : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
