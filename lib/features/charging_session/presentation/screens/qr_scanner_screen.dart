import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';

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

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

    _scanned = true;
    await _controller?.stop();

    // Parse the QR data: station_id|connector_id
    try {
      final parts = rawValue.split('|');
      if (parts.length >= 2) {
        final stationId = parts[0];
        final connectorId = parts[1];
        if (!mounted) return;
        await _startChargingSession(stationId, connectorId);
      } else {
        if (!mounted) return;
        _showError('Invalid QR code format');
        _scanned = false;
        _controller?.start();
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Unable to read QR code');
      _scanned = false;
      _controller?.start();
    }
  }

  Future<void> _startChargingSession(
      String stationId, String connectorId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Verify connector availability
      final connector = await client
          .from('connectors')
          .select()
          .eq('id', connectorId)
          .maybeSingle();

      if (connector?['status'] != 'available') {
        throw Exception('This connector is currently busy');
      }

      // Update connector to busy
      await client
          .from('connectors')
          .update({'status': 'busy'}).eq('id', connectorId);

      // Create session
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
      Navigator.pop(context); // close loading
      context.pushReplacement('/session/${session?['id']}');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      _showError(e.toString().replaceAll('Exception: ', ''));
      _scanned = false;
      _controller?.start();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
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
          Container(color: Colors.black.withOpacity(0.45)),
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
          // Bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: AppColors.primary, size: 32),
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
            ),
          ),
        ],
      ),
    );
  }
}
