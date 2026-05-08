import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/brutl_user_provider.dart';
import 'edit_name_screen.dart';
import 'edit_username_screen.dart';
import 'widgets/settings_widgets.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  File? _selectedImage;
  bool _uploading = false;

  Future<void> _pickImage() async {
    if (_uploading) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final File file = File(picked.path);
    setState(() {
      _selectedImage = file;
      _uploading = true;
    });

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw StateError('You must be signed in to update your photo.');
      }

      final storageRef = FirebaseStorage.instance.ref(
        'users/${firebaseUser.uid}/profile.jpg',
      );
      final task = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await task.ref.getDownloadURL();
      if (!mounted) return;
      await context.read<BrutlUserProvider>().updatePhotoUrl(url);
    } catch (e) {
      debugPrint('ACCOUNT: photo upload failed — $e');
      if (mounted) {
        setState(() => _selectedImage = null);
        _showError('Could not upload photo. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.statusError,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<BrutlUserProvider>();
    final user = userProvider.user;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = firebaseUser?.email ?? '';
    final displayName = user.displayName.isNotEmpty
        ? user.displayName
        : (firebaseUser?.displayName ?? '');
    final username = user.username.isNotEmpty ? '@${user.username}' : '—';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Account Setting'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              Center(child: _buildAvatar(user.photoUrl)),
              const SizedBox(height: AppSpacing.xxl),
              SettingsActionBoxWidget(
                children: [
                  SettingsTileWidget(
                    title: 'Name',
                    trailingText: displayName.isNotEmpty ? displayName : 'Set',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditNameScreen(),
                      ),
                    ),
                  ),
                  SettingsTileWidget(
                    title: 'Username',
                    trailingText: username,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditUsernameScreen(),
                      ),
                    ),
                  ),
                  SettingsTileWidget(
                    title: 'Email',
                    trailingText: email.isNotEmpty ? email : '—',
                    showChevron: false,
                    onTap: null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String remotePhotoUrl) {
    ImageProvider? imageProvider;
    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (remotePhotoUrl.isNotEmpty) {
      imageProvider = NetworkImage(remotePhotoUrl);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.backgroundTertiary,
            border: Border.all(color: AppColors.borderDefault, width: 2),
            image: imageProvider != null
                ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                : null,
          ),
          child: imageProvider == null
              ? const Icon(
                  Icons.person,
                  size: 56,
                  color: AppColors.textTertiary,
                )
              : null,
        ),
        if (_uploading)
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.accentPrimary,
                strokeWidth: 2,
              ),
            ),
          ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Material(
            color: AppColors.accentPrimary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _pickImage,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundPrimary,
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
