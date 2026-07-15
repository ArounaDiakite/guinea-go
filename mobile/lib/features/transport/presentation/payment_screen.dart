import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../data/transport_repository.dart';
import '../models/booking.dart';
import '../models/payment.dart';
import '../utils/currency.dart';

enum _PaymentPhase { choosingProvider, submitting, waitingConfirmation, confirmed, failed }

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentProvider _selectedProvider = PaymentProvider.orangeMoney;
  _PaymentPhase _phase = _PaymentPhase.choosingProvider;
  String? _errorMessage;
  late Booking _booking;

  static const _pollInterval = Duration(seconds: 2);
  static const _pollTimeout = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  Future<void> _pay() async {
    setState(() {
      _phase = _PaymentPhase.submitting;
      _errorMessage = null;
    });

    try {
      await ref
          .read(transportRepositoryProvider)
          .payForBooking(bookingId: _booking.id, provider: _selectedProvider, amount: _booking.pricePaid);
      if (mounted) setState(() => _phase = _PaymentPhase.waitingConfirmation);
      await _pollUntilConfirmed();
    } catch (error) {
      if (mounted) {
        setState(() {
          _phase = _PaymentPhase.failed;
          _errorMessage = extractApiErrorMessage(error);
        });
      }
    }
  }

  /// The sandbox payment endpoint returns immediately with status
  /// "pending" - the backend confirms it ~2s later via a background
  /// task, with no webhook/callback the client can await. Re-fetching
  /// the booking list is the only way to observe the flip to
  /// CONFIRMED (there's no GET booking-by-id endpoint).
  Future<void> _pollUntilConfirmed() async {
    final deadline = DateTime.now().add(_pollTimeout);

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(_pollInterval);
      if (!mounted) return;

      try {
        final bookings = await ref.read(transportRepositoryProvider).getMyBookings();
        Booking? match;
        for (final candidate in bookings) {
          if (candidate.id == _booking.id) {
            match = candidate;
            break;
          }
        }

        if (match == null) continue;

        if (match.status == BookingStatus.confirmed) {
          if (mounted) setState(() => _phase = _PaymentPhase.confirmed);
          return;
        }

        if (match.status == BookingStatus.cancelled || match.status == BookingStatus.expired) {
          if (mounted) {
            setState(() {
              _phase = _PaymentPhase.failed;
              _errorMessage = 'Le paiement a échoué. La réservation n\'est plus disponible.';
            });
          }
          return;
        }
      } catch (_) {
        // A transient poll failure isn't fatal - keep trying until the
        // deadline, the same as a slow-but-successful confirmation.
      }
    }

    if (mounted) {
      setState(() {
        _phase = _PaymentPhase.failed;
        _errorMessage = 'La confirmation prend plus de temps que prévu. '
            'Vérifiez "Mes réservations" dans quelques instants.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: SafeArea(
        child: switch (_phase) {
          _PaymentPhase.choosingProvider || _PaymentPhase.submitting => _ProviderSelection(
            booking: _booking,
            selectedProvider: _selectedProvider,
            isSubmitting: _phase == _PaymentPhase.submitting,
            errorMessage: _errorMessage,
            onProviderChanged: (provider) => setState(() => _selectedProvider = provider),
            onPay: _pay,
          ),
          _PaymentPhase.waitingConfirmation => const _WaitingConfirmation(),
          _PaymentPhase.confirmed => _Confirmed(booking: _booking),
          _PaymentPhase.failed => _Failed(
            message: _errorMessage ?? 'Une erreur est survenue.',
            onRetry: () => setState(() => _phase = _PaymentPhase.choosingProvider),
          ),
        },
      ),
    );
  }
}

class _ProviderSelection extends StatelessWidget {
  const _ProviderSelection({
    required this.booking,
    required this.selectedProvider,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onProviderChanged,
    required this.onPay,
  });

  final Booking booking;
  final PaymentProvider selectedProvider;
  final bool isSubmitting;
  final String? errorMessage;
  final ValueChanged<PaymentProvider> onProviderChanged;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: AppColors.accentDark, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Réservation en attente de paiement',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.accentDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Montant à payer', style: textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(formatGnf(booking.pricePaid), style: textTheme.displayLarge),
              const SizedBox(height: AppSpacing.xl),
              Text('Moyen de paiement', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final provider in PaymentProvider.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ProviderTile(
                    provider: provider,
                    selected: provider == selectedProvider,
                    onTap: () => onProviderChanged(provider),
                  ),
                ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorBanner(message: errorMessage!),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: AppButton(label: 'Payer maintenant', isLoading: isSubmitting, onPressed: onPay),
          ),
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.selected, required this.onTap});

  final PaymentProvider provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.primary : AppColors.textHint,
          ),
          const SizedBox(width: AppSpacing.md),
          Text(provider.label, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _WaitingConfirmation extends StatelessWidget {
  const _WaitingConfirmation();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text('Confirmation du paiement en cours...', style: textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cela ne prend que quelques secondes.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Confirmed extends StatelessWidget {
  const _Confirmed({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text('Réservation confirmée !', style: textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              formatGnf(booking.pricePaid),
              style: textTheme.titleLarge?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Voir mes réservations',
              onPressed: () => context.go('/hub/transport/bookings'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Retour à l\'accueil',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go('/hub/home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            AppErrorBanner(message: message),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
