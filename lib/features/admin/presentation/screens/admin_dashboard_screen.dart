import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/neon_button.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _stations = [];
  bool _loading = true;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    final data = await _client.from('stations').select('''
      *,
      connectors(id, status, connector_type)
    ''').order('created_at', ascending: false);
    setState(() {
      _stations = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  void _showAddStationDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Station',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(nameCtrl, 'Station Name', Icons.ev_station_outlined),
              const SizedBox(height: 10),
              _field(addressCtrl, 'Address', Icons.location_on_outlined),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _field(
                          latCtrl, 'Latitude', Icons.my_location_rounded,
                          number: true)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _field(
                          lngCtrl, 'Longitude', Icons.explore_outlined,
                          number: true)),
                ],
              ),
              const SizedBox(height: 10),
              _field(priceCtrl, 'Price/kWh (₹)', Icons.bolt_rounded,
                  number: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final userId = _client.auth.currentUser?.id;
                await _client.from('stations').insert({
                  'name': nameCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'latitude': double.parse(latCtrl.text.trim()),
                  'longitude': double.parse(lngCtrl.text.trim()),
                  'price_per_kwh': double.parse(priceCtrl.text.trim()),
                  'created_by': userId,
                });
                if (!context.mounted) return;
                Navigator.pop(context);
                await _loadStations();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Station added!'),
                    backgroundColor: AppColors.markerAvailable,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('$e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  TextField _field(TextEditingController ctrl, String label, IconData icon,
      {bool number = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _toggleConnector(
      String connectorId, String currentStatus) async {
    final newStatus = currentStatus == 'available' ? 'offline' : 'available';
    await _client
        .from('connectors')
        .update({'status': newStatus}).eq('id', connectorId);
    await _loadStations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.add_circle_rounded, color: AppColors.primary),
            onPressed: _showAddStationDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _stations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.ev_station_rounded,
                          color: AppColors.textSecondary, size: 60),
                      const SizedBox(height: 16),
                      const Text('No stations yet',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      NeonButton(
                        label: 'Add Station',
                        icon: Icons.add,
                        onPressed: _showAddStationDialog,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStations,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final s = _stations[i];
                      final connectors = (s['connectors'] as List?) ?? [];
                      return GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.ev_station_rounded,
                                    color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s['name'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.markerAvailable
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    s['status'] as String,
                                    style: const TextStyle(
                                        color: AppColors.markerAvailable,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(s['address'] as String,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              '₹${(s['price_per_kwh'] as num).toDouble().toStringAsFixed(2)}/kWh  •  ${connectors.length} connectors',
                              style: const TextStyle(
                                  color: AppColors.primary, fontSize: 13),
                            ),
                            if (connectors.isNotEmpty) ...[
                              const Divider(height: 20),
                              const Text('Connectors',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: connectors.map((c) {
                                  final status = c['status'] as String;
                                  final color = status == 'available'
                                      ? AppColors.markerAvailable
                                      : status == 'busy'
                                          ? AppColors.markerBusy
                                          : AppColors.markerOffline;
                                  return GestureDetector(
                                    onTap: () => _toggleConnector(
                                        c['id'] as String, status),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.15),
                                        border: Border.all(color: color),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.power_outlined,
                                              color: color, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${c['connector_type']} • $status',
                                            style: TextStyle(
                                                color: color, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ).animate(delay: (i * 60).ms).fadeIn();
                    },
                  ),
                ),
    );
  }
}
