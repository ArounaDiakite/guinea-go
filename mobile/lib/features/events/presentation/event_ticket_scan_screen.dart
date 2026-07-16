import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../data/event_organizer_repository.dart';
import '../models/event_ticket_validation_result.dart';

enum _ScanPhase { scanning, validating, result }

class EventTicketScanScreen extends ConsumerStatefulWidget {
  const EventTicketScanScreen({super.key});

  @override
  ConsumerState<EventTicketScanScreen> createState() => _EventTicketScanScreenState();
}

class _EventTicketScanScreenState extends ConsumerState<EventTicketScanScreen> {
  final _controller = MobileScannerController();
  _ScanPhase _phase = _ScanPhase.scanning;
  EventTicketValidationResult? _result;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // The camera keeps emitting frames while a request is in flight -
    // ignore anything after the first detected code until this scan
    // is fully resolved, otherwise the same QR held in frame fires
    // several concurrent validate calls.
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    _isProcessing = true;
    setState(() {
      _phase = _ScanPhase.validating;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(eventOrganizerRepositoryProvider).validateTicket(code);
      if (mounted) {
        setState(() {
          _result = result;
          _phase = _ScanPhase.result;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = extractApiErrorMessage(error);
          _phase = _ScanPhase.result;
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  void _scanAgain() {
    setState(() {
      _phase = _ScanPhase.scanning;
      _result = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un billet')),
      body: SafeArea(
        child: switch (_phase) {
          _ScanPhase.scanning || _ScanPhase.validating => _ScannerView(
            controller: _controller,
            onDetect: _onDetect,
            isValidating: _phase == _ScanPhase.validating,
          ),
          _ScanPhase.result => _ResultView(
            result: _result,
            errorMessage: _errorMessage,
            onScanAgain: _scanAgain,
          ),
        },
      ),
    );
  }
}

class _ScannerView extends StatelessWidget {
  const _ScannerView({required this.controller, required this.onDetect, required this.isValidating});

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool isValidating;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_rounded, color: AppColors.error, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Impossible d\'accéder à la caméra. Vérifiez l\'autorisation dans les réglages.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textOnPrimary, width: 3),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.xxl,
          child: Column(
            children: [
              if (isValidating) ...[
                const CircularProgressIndicator(color: AppColors.textOnPrimary),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                isValidating ? 'Vérification du billet...' : 'Placez le QR code du billet dans le cadre.',
                style: const TextStyle(color: AppColors.textOnPrimary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.errorMessage, required this.onScanAgain});

  final EventTicketValidationResult? result;
  final String? errorMessage;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isSuccess = result != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSuccess) ...[
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
              const SizedBox(height: AppSpacing.lg),
              Text('Billet validé', style: textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            result!.passengerName,
                            style: textTheme.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${result!.ticketCategory} · ${result!.quantity} billet${result!.quantity > 1 ? 's' : ''}',
                            style: textTheme.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.qr_code_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            result!.code,
                            style: textTheme.bodyMedium?.copyWith(letterSpacing: 1.5),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 64),
              const SizedBox(height: AppSpacing.lg),
              Text('Billet refusé', style: textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                errorMessage ?? 'Une erreur est survenue.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Scanner un autre billet', onPressed: onScanAgain),
          ],
        ),
      ),
    );
  }
}
