import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/deep_link_utils.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  MobileScannerController? _controller;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _validatedConnector;
  bool _validating = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned || _validating) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

    // Parse the data: URI, split format, or pure UUID
    final connectorId = DeepLinkUtils.extractConnectorId(rawValue);

    if (connectorId != null) {
      await _validateConnector(connectorId);
    } else {
      if (!mounted) return;
      _showError('Invalid QR code format');
    }
  }

  Future<void> _validateConnector(String connectorId) async {
    setState(() => _validating = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // 1. Check Wallet Balance
      final wallet = await client
          .from('wallets')
          .select('wallet_id, user_id, balance, created_at, updated_at')
          .eq('user_id', userId)
          .maybeSingle();

      final balance = (wallet?['balance'] as num?)?.toDouble() ?? 0.0;
      if (balance < 50.0) {
        throw Exception('Minimum ₹50 balance required to start charging');
      }

      // 2. Fetch Connector & Station info
      final connector = await client.from('connectors').select('''
            id,
            status,
            connector_type,
            max_power_kw,
            station_id,
            stations(
              id,
              name,
              address,
              price_per_kwh
            )
          ''').eq('connector_id', connectorId).maybeSingle();

      if (connector == null) throw Exception('Connector not found');

      // 3. Check for Reservations
      final reservations = await client
          .from('reservations')
          .select()
          .eq('connector_id', connectorId)
          .eq('status', 'active');

      final activeReservation = (reservations as List).cast<Map<String, dynamic>>().firstWhere(
        (res) {
          final start = DateTime.parse(res['reserved_start']);
          final end = DateTime.parse(res['reserved_end']);
          final now = DateTime.now();
          // Arrival window: 10 mins before start until end
          return now.isAfter(start.subtract(const Duration(minutes: 10))) &&
                 now.isBefore(end);
        },
        orElse: () => {},
      );

      if (activeReservation.isNotEmpty) {
        if (activeReservation['user_id'] != userId) {
          throw Exception('This connector is reserved by another user');
        } else {
          // It's the current user's reservation
          connector['is_reserved_by_me'] = true;
          connector['reservation_id'] = activeReservation['id'];
        }
      }

      setState(() {
        _validatedConnector = connector;
        _scanned = true;
        _validating = false;
      });
      _controller?.stop();
    } catch (e) {
      setState(() => _validating = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _startChargingSession() async {
    if (_validatedConnector == null) return;
    final connectorId = _validatedConnector!['id'];

    setState(() => _validating = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // 1. If there's a reservation, complete it
      if (_validatedConnector!['is_reserved_by_me'] == true) {
        final reservationId = _validatedConnector!['reservation_id'];
        await client
            .from('reservations')
            .update({'status': 'completed'})
            .eq('reservation_id', reservationId);
      }

      // 2. Update connector to busy
      await client
          .from('connectors')
          .update({'status': 'busy'}).eq('connector_id', connectorId);

      // 3. Create session
      final session = await client
          .from('charging_sessions')
          .insert({
            'user_id': userId,
            'connector_id': connectorId,
            'status': 'active',
          })
          .select()
          .maybeSingle();

      if (!mounted) return;
      context.pushReplacement('/session/${session?['id']}');
    } catch (e) {
      setState(() => _validating = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller!, onDetect: _onDetect),
          // Dark overlay
          Container(
            color: Colors.black.withOpacity(_scanned ? 0.8 : 0.45),
          ).animate().fadeIn(),
          // Scan frame cutout
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 24,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan Station QR',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Point camera at the QR code on the connector',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Section or Validation Card
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: _validatedConnector != null
                ? _buildValidationCard()
                : _buildScannerInstructions(),
          ),

          if (_validating)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ).animate().fadeIn(),
        ],
      ),
    );
  }

  Widget _buildScannerInstructions() {
    return Column(
      children: [
        const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 32),
        const SizedBox(height: 8),
        const Text('Place QR code inside the frame',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 16),
        IconButton(
          onPressed: () => _controller?.toggleTorch(),
          icon: const Icon(Icons.flashlight_on_rounded,
              color: Colors.white, size: 28),
        ),
      ],
    );
  }

  Widget _buildValidationCard() {
    final station = _validatedConnector!['stations'];
    final power = (_validatedConnector!['max_power_kw'] as num).toDouble();
    final price = (station['price_per_kwh'] as num).toDouble();

    return GlassCard(
      borderColor: AppColors.primary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.ev_station_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _validatedConnector!['connector_type'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetail('Power', '${power.toStringAsFixed(0)} kW'),
              _buildDetail('Price', AppFormatters.formatCurrency(price)),
              _buildDetail(
                'Status', 
                _validatedConnector!['is_reserved_by_me'] == true ? 'Reserved' : 'Ready', 
                color: _validatedConnector!['is_reserved_by_me'] == true ? AppColors.primary : AppColors.success
              ),
            ],
          ),
          const SizedBox(height: 24),
          NeonButton(
            label: 'Start Charging Session',
            icon: Icons.bolt_rounded,
            onPressed: _startChargingSession,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _scanned = false;
                  _validatedConnector = null;
                });
                _controller?.start();
              },
              child: const Text(
                'Cancel & Rescan',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildDetail(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }
}
