import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/neon_button.dart';
import '../providers/profile_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  
  String? _selectedVehicleType;
  File? _avatarFile;
  final _picker = ImagePicker();

  final List<String> _vehicleTypes = [
    'Electric Scooter',
    'Electric Bike',
    'Electric Car (Hatchback)',
    'Electric Car (Sedan)',
    'Electric Car (SUV)',
    'Electric Auto-rickshaw',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() => _avatarFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _selectedVehicleType == null) {
      if (_selectedVehicleType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a vehicle type'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    final notifier = ref.read(profileActionProvider.notifier);
    await notifier.setupProfile(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      vehicleType: _selectedVehicleType!,
      vehicleModel: _modelController.text.trim(),
      licensePlate: _plateController.text.trim().isEmpty ? null : _plateController.text.trim(),
      avatarFile: _avatarFile,
    );

    if (mounted) {
      final state = ref.read(profileActionProvider);
      if (state is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${state.error}'), backgroundColor: AppColors.error),
        );
      } else {
        context.go('/home'); // Navigate to home on success
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(profileActionProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001F3F), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   const Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  const Text(
                    'Tell us about yourself and your vehicle',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 40),

                  // Avatar Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                            image: _avatarFile != null
                                ? DecorationImage(image: FileImage(_avatarFile!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _avatarFile == null
                              ? const Icon(Icons.person_add_rounded, size: 40, color: AppColors.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(delay: 400.ms),
                  const SizedBox(height: 40),

                  // Form Fields in a Glass Card
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Full Name'),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration('Enter your full name', Icons.person_outline),
                          validator: (v) => v!.isEmpty ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildLabel('Phone Number'),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration('Enter your phone number', Icons.phone_outlined),
                          validator: (v) => v!.isEmpty ? 'Phone is required' : null,
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('Vehicle Type'),
                        DropdownButtonFormField<String>(
                          value: _selectedVehicleType,
                          dropdownColor: const Color(0xFF001F3F),
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration('Select vehicle type', Icons.ev_station_outlined),
                          items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => _selectedVehicleType = v),
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('Vehicle Model'),
                        TextFormField(
                          controller: _modelController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration('e.g. Tata Nexon EV', Icons.directions_car_outlined),
                          validator: (v) => v!.isEmpty ? 'Model is required' : null,
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('License Plate (Optional)'),
                        TextFormField(
                          controller: _plateController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration('e.g. KL 01 AB 1234', Icons.badge_outlined),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
                  const SizedBox(height: 32),

                  // Save Button
                  NeonButton(
                    label: 'Save Profile & Continue',
                    isLoading: actionState.isLoading,
                    onPressed: _saveProfile,
                  ).animate().fadeIn(delay: 800.ms),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.7), size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
