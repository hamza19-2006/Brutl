import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/settings_widgets.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  static final Uri _emailUri = Uri(
    scheme: 'mailto',
    path: 'brutlapp@gmail.com',
    queryParameters: <String, String>{'subject': 'Support Request'},
  );

  static final Uri _whatsAppUri = Uri(
    scheme: 'https',
    host: 'wa.me',
    path: '923097719166',
    queryParameters: <String, String>{
      'text': 'Hello Brutl Support, I need help with...',
    },
  );

  Future<void> _openEmailSupport(BuildContext context) {
    return _launchSupportUri(
      context,
      uri: _emailUri,
      errorMessage: 'No email app found to open support request.',
    );
  }

  Future<void> _openWhatsAppSupport(BuildContext context) {
    return _launchSupportUri(
      context,
      uri: _whatsAppUri,
      forceExternal: true,
      errorMessage: 'WhatsApp is not available on this device.',
    );
  }

  Future<void> _launchSupportUri(
    BuildContext context, {
    required Uri uri,
    bool forceExternal = false,
    required String errorMessage,
  }) async {
    final canOpen = await canLaunchUrl(uri);
    if (!canOpen) {
      if (!context.mounted) return;
      _showErrorSnackBar(context, errorMessage);
      return;
    }

    final url = uri;
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (!context.mounted) return;
      _showErrorSnackBar(context, errorMessage);
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusError,
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: AppTextStyles.bodyMedium(color: Colors.white),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Contact Support'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              _SupportBox(
                onTap: () => _openEmailSupport(context),
                backgroundColor: AppColors.backgroundTertiary,
                borderColor: AppColors.borderStrong,
                leading: const Icon(
                  Icons.email_outlined,
                  color: Colors.white,
                  size: 24,
                ),
                title: 'Email Support',
                trailingText: 'brutlapp@gmail.com',
                trailingColor: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SupportBox(
                onTap: () => _openWhatsAppSupport(context),
                backgroundColor: const Color(0xFF1B5E37),
                borderColor: const Color(0xFF25D366),
                leading: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Colors.white,
                  size: 24,
                ),
                title: 'WhatsApp Support',
                trailingText: '+92 3097719166',
                trailingColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportBox extends StatelessWidget {
  const _SupportBox({
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.leading,
    required this.title,
    required this.trailingText,
    required this.trailingColor,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Widget leading;
  final String title;
  final String trailingText;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headingMedium(color: Colors.white),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  trailingText,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodyMedium(color: trailingColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
