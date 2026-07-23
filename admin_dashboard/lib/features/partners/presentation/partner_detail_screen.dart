import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/partners_controller.dart';
import '../data/partners_repository.dart';
import '../models/pending_user.dart';

/// No GET-by-id endpoint exists for admin users - the full record
/// travels via `extra` from the row that was tapped in
/// PartnersListScreen, same "no single-fetch, so pass the whole object"
/// shape as GradeFormScreen/FeePaymentScreen in mobile/.
class PartnerDetailScreen extends ConsumerStatefulWidget {
  const PartnerDetailScreen({super.key, required this.user});

  final PendingUser user;

  @override
  ConsumerState<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends ConsumerState<PartnerDetailScreen> {
  bool _isActivating = false;
  String? _errorMessage;

  Future<void> _activate() async {
    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    try {
      await ref.read(partnersRepositoryProvider).activateUser(widget.user.id);
      ref.invalidate(pendingUsersProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = widget.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Détail du compte')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.fullName, style: textTheme.titleMedium),
                              Text(
                                partnerRoleLabel(user.role),
                                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    _DetailRow(icon: Icons.mail_outline_rounded, label: 'Email', value: user.email),
                    _DetailRow(icon: Icons.phone_outlined, label: 'Téléphone', value: user.phone),
                    _DetailRow(icon: Icons.location_city_outlined, label: 'Ville', value: user.city),
                    _DetailRow(
                      icon: Icons.flag_outlined,
                      label: 'Pays',
                      value: user.countryCode,
                    ),
                    _DetailRow(
                      icon: Icons.event_outlined,
                      label: 'Inscrit le',
                      value: _formatDate(user.createdAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_errorMessage != null) ...[
                AppErrorBanner(message: _errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                label: 'Activer ce compte',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _isActivating,
                expand: false,
                onPressed: _activate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 110,
            child: Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
