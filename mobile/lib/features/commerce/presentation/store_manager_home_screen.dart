import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/store_manager_controller.dart';
import '../models/store.dart';

class StoreManagerHomeScreen extends ConsumerWidget {
  const StoreManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(myStoresProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes boutiques')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/store/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Créer'),
      ),
      body: SafeArea(
        child: storesAsync.when(
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
                    onPressed: () => ref.invalidate(myStoresProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (stores) {
            if (stores.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucune boutique pour le moment.', style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Créez votre première boutique pour commencer à vendre.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: stores.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _StoreCard(store: stores[index]),
            );
          },
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.push('/hub/store/${store.id}'),
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
                Text(store.name, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}
