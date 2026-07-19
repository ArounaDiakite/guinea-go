import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/catalog_controller.dart';
import '../models/store.dart';

class StoreManageScreen extends ConsumerWidget {
  const StoreManageScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(storeDetailProvider(storeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Gérer la boutique')),
      body: SafeArea(
        child: storeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppErrorBanner(message: extractApiErrorMessage(error)),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Réessayer',
                    variant: AppButtonVariant.secondary,
                    expand: false,
                    onPressed: () => ref.invalidate(storeDetailProvider(storeId)),
                  ),
                ],
              ),
            ),
          ),
          data: (store) => _ManageMenu(store: store),
        ),
      ),
    );
  }
}

class _ManageMenu extends StatelessWidget {
  const _ManageMenu({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: textTheme.titleMedium, overflow: TextOverflow.ellipsis, maxLines: 1),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      store.isVerified ? 'Boutique vérifiée' : 'Vérification en attente',
                      style: textTheme.bodySmall?.copyWith(
                        color: store.isVerified ? AppColors.secondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Gestion', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.shopping_bag_outlined,
          label: 'Produits',
          subtitle: 'Catalogue, prix, stock',
          onTap: () => context.push('/hub/store/${store.id}/products'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.category_outlined,
          label: 'Catégories',
          subtitle: 'Taxonomie partagée entre toutes les boutiques',
          onTap: () => context.push('/hub/store/categories'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.receipt_long_outlined,
          label: 'Commandes reçues',
          subtitle: 'Historique des commandes de la boutique',
          onTap: () => context.push('/hub/store/${store.id}/orders'),
        ),
      ],
    );
  }
}

class _ManagementTile extends StatelessWidget {
  const _ManagementTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}
