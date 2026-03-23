import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../data/models/profile_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  File? _newAvatarFile;
  final _picker = ImagePicker();

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _modelController;
  late TextEditingController _plateController;
  String? _selectedVehicleType;

  final List<String> _vehicleTypes = [
    'Electric Scooter',
    'Electric Bike',
    'Electric Car (Hatchback)',
    'Electric Car (Sedan)',
    'Electric Car (SUV)',
    'Electric Auto-rickshaw',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _modelController = TextEditingController();
    _plateController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  void _initFields(ProfileModel profile) {
    _nameController.text = profile.fullName;
    _phoneController.text = profile.phone;
    _modelController.text = profile.vehicleModel;
    _plateController.text = profile.licensePlate ?? '';
    _selectedVehicleType = profile.vehicleType;
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _newAvatarFile = File(pickedFile.path));
    }
  }

  Future<void> _updateProfile(ProfileModel currentProfile) async {
    final notifier = ref.read(profileActionProvider.notifier);
    
    final updatedProfile = currentProfile.copyWith(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      vehicleType: _selectedVehicleType,
      vehicleModel: _modelController.text.trim(),
      licensePlate: _plateController.text.trim().isEmpty ? null : _plateController.text.trim(),
    );

    await notifier.updateProfile(
      profile: updatedProfile,
      avatarFile: _newAvatarFile,
    );

    if (mounted) {
      setState(() {
        _isEditing = false;
        _newAvatarFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.markerAvailable),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final actionState = ref.watch(profileActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              onPressed: () {
                 ref.read(authNotifierProvider.notifier).signOut();
                 context.go('/login');
              },
            ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No profile found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/profile-setup'),
                    child: const Text('Setup Profile'),
                  ),
                ],
              ),
            );
          }

          if (!_isEditing && _nameController.text.isEmpty) {
            _initFields(profile);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header / Avatar
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isEditing ? _pickImage : null,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 2),
                                image: _newAvatarFile != null
                                    ? DecorationImage(image: FileImage(_newAvatarFile!), fit: BoxFit.cover)
                                    : profile.avatarUrl != null
                                        ? DecorationImage(image: NetworkImage(profile.avatarUrl!), fit: BoxFit.cover)
                                        : null,
                              ),
                              child: _newAvatarFile == null && profile.avatarUrl == null
                                  ? const Icon(Icons.person_rounded, size: 60, color: AppColors.primary)
                                  : null,
                            ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ).animate().scale(),
                      const SizedBox(height: 16),
                      if (!_isEditing) ...[
                        Text(
                          profile.fullName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          profile.phone,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Info Cards
                if (!_isEditing) ...[
                   _buildInfoCard(
                    'Vehicle Details',
                    Icons.directions_car_rounded,
                    [
                      _buildInfoRow('Type', profile.vehicleType),
                      _buildInfoRow('Model', profile.vehicleModel),
                      if (profile.licensePlate != null) _buildInfoRow('License Plate', profile.licensePlate!),
                    ],
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 32),
                  NeonButton(
                    label: 'Edit Profile',
                    onPressed: () => setState(() => _isEditing = true),
                    icon: Icons.edit_note_rounded,
                  ).animate().fadeIn(delay: 400.ms),
                ] else ...[
                  // Edit Form
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEditField('Full Name', _nameController, Icons.person_outline),
                        const SizedBox(height: 16),
                        _buildEditField('Phone Number', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),
                        const Text('Vehicle Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        DropdownButtonFormField<String>(
                          value: _selectedVehicleType,
                          dropdownColor: const Color(0xFF001F3F),
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration(Icons.ev_station_outlined),
                          items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => _selectedVehicleType = v),
                        ),
                        const SizedBox(height: 16),
                        _buildEditField('Vehicle Model', _modelController, Icons.directions_car_outlined),
                        const SizedBox(height: 16),
                        _buildEditField('License Plate', _plateController, Icons.badge_outlined),
                      ],
                    ),
                  ).animate().fadeIn(),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _isEditing = false;
                            _newAvatarFile = null;
                            _initFields(profile);
                          }),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.textSecondary),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: NeonButton(
                          label: 'Save',
                          isLoading: actionState.isLoading,
                          onPressed: () => _updateProfile(profile),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _buildInputDecoration(icon),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.7), size: 18),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
