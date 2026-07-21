import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../payments/models/payment.dart';
import '../application/school_controller.dart';
import '../data/school_repository.dart';
import '../models/student_fee.dart';

enum _PaymentPhase { choosingAmount, submitting, waitingConfirmation, confirmed, failed }

/// Records one payment against a StudentFee - unlike the shared
/// transport/hotel/event PaymentScreen (which polls a single booking's
/// PENDING_PAYMENT -> CONFIRMED status), a school fee has no booking
/// status to poll: several payments accumulate onto the same fee, and
/// there's nothing to confirm/cancel/expire. Confirmation here means
/// re-fetching the student's fees after the same sandbox delay margin
/// and checking that amount_paid actually advanced by this payment's
/// amount.
///
/// Receives the full StudentFee via `extra` rather than a
/// studentFeeId path param + detail provider, same reasoning as
/// GradeFormArgs: the backend has no GET-single-StudentFee endpoint.
class FeePaymentScreen extends ConsumerStatefulWidget {
  const FeePaymentScreen({super.key, required this.studentId, required this.studentFee});

  final String studentId;
  final StudentFee studentFee;

  @override
  ConsumerState<FeePaymentScreen> createState() => _FeePaymentScreenState();
}

class _FeePaymentScreenState extends ConsumerState<FeePaymentScreen> {
  static const _confirmationWait = Duration(seconds: 4);

  late final _amountController = TextEditingController(
    text: widget.studentFee.amountRemaining.toStringAsFixed(0),
  );
  PaymentProvider _provider = PaymentProvider.orangeMoney;
  _PaymentPhase _phase = _PaymentPhase.choosingAmount;
  String? _errorMessage;
  StudentFee? _confirmedFee;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Montant invalide.');
      return;
    }
    if (amount > widget.studentFee.amountRemaining + 0.01) {
      setState(() => _errorMessage = 'Le montant dépasse le solde restant.');
      return;
    }

    setState(() {
      _phase = _PaymentPhase.submitting;
      _errorMessage = null;
    });

    try {
      await ref.read(schoolRepositoryProvider).payStudentFee(
        studentId: widget.studentId,
        studentFeeId: widget.studentFee.id,
        provider: _provider,
        amount: amount,
      );
      if (mounted) setState(() => _phase = _PaymentPhase.waitingConfirmation);
      await _awaitConfirmation(amount);
    } catch (error) {
      if (mounted) {
        setState(() {
          _phase = _PaymentPhase.failed;
          _errorMessage = extractApiErrorMessage(error);
        });
      }
    }
  }

  Future<void> _awaitConfirmation(double amount) async {
    await Future.delayed(_confirmationWait);
    if (!mounted) return;

    try {
      final fees = await ref.read(schoolRepositoryProvider).getStudentFees(widget.studentId);
      StudentFee? updated;
      for (final fee in fees) {
        if (fee.id == widget.studentFee.id) {
          updated = fee;
          break;
        }
      }

      final expectedPaid = widget.studentFee.amountPaid + amount;
      if (updated != null && updated.amountPaid >= expectedPaid - 0.01) {
        ref.invalidate(studentFeesProvider(widget.studentId));
        if (mounted) {
          setState(() {
            _phase = _PaymentPhase.confirmed;
            _confirmedFee = updated;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _phase = _PaymentPhase.failed;
          _errorMessage =
              'La confirmation prend plus de temps que prévu. Vérifiez l\'historique dans quelques instants.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _phase = _PaymentPhase.failed;
          _errorMessage = extractApiErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement des frais')),
      body: SafeArea(
        child: switch (_phase) {
          _PaymentPhase.choosingAmount || _PaymentPhase.submitting => _AmountAndProvider(
            studentFee: widget.studentFee,
            amountController: _amountController,
            selectedProvider: _provider,
            isSubmitting: _phase == _PaymentPhase.submitting,
            errorMessage: _errorMessage,
            onProviderChanged: (provider) => setState(() => _provider = provider),
            onPay: _pay,
          ),
          _PaymentPhase.waitingConfirmation => const _WaitingConfirmation(),
          _PaymentPhase.confirmed => _Confirmed(fee: _confirmedFee ?? widget.studentFee),
          _PaymentPhase.failed => _Failed(
            message: _errorMessage ?? 'Une erreur est survenue.',
            onRetry: () => setState(() => _phase = _PaymentPhase.choosingAmount),
          ),
        },
      ),
    );
  }
}

class _AmountAndProvider extends StatelessWidget {
  const _AmountAndProvider({
    required this.studentFee,
    required this.amountController,
    required this.selectedProvider,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onProviderChanged,
    required this.onPay,
  });

  final StudentFee studentFee;
  final TextEditingController amountController;
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
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentFee.feeScheduleName,
                      style: textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(studentFee.period, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.md),
                    _RecapRow(label: 'Montant dû', value: formatGnf(studentFee.amountDue)),
                    _RecapRow(label: 'Déjà payé', value: formatGnf(studentFee.amountPaid)),
                    _RecapRow(
                      label: 'Solde restant',
                      value: formatGnf(studentFee.amountRemaining),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: amountController,
                label: 'Montant à payer (GNF)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
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
            child: AppButton(label: 'Enregistrer le paiement', isLoading: isSubmitting, onPressed: onPay),
          ),
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: emphasize
                ? textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)
                : textTheme.bodyMedium,
          ),
        ],
      ),
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
          Expanded(
            child: Text(
              provider.label,
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
  const _Confirmed({required this.fee});

  final StudentFee fee;

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
            Text('Paiement enregistré !', style: textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              fee.amountRemaining > 0
                  ? 'Reste ${formatGnf(fee.amountRemaining)} sur ${formatGnf(fee.amountDue)}'
                  : 'Frais entièrement payés (${formatGnf(fee.amountDue)})',
              style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Retour à l\'historique', onPressed: () => context.pop()),
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
