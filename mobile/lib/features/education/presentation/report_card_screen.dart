import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/school_controller.dart';
import '../models/grade.dart';

/// Weighted averages, per subject and overall, computed by the backend
/// on the fly from that period's grades - nothing here is stored or
/// cached beyond this screen's own provider.
class ReportCardScreen extends ConsumerStatefulWidget {
  const ReportCardScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends ConsumerState<ReportCardScreen> {
  Period _period = Period.t1;

  @override
  Widget build(BuildContext context) {
    final query = ReportCardQuery(studentId: widget.studentId, period: _period);
    final reportCardAsync = ref.watch(reportCardProvider(query));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Bulletin')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Row(
                children: [
                  for (final period in Period.values) ...[
                    Expanded(
                      child: ChoiceChip(
                        label: Text(period.apiValue),
                        selected: _period == period,
                        onSelected: (_) => setState(() => _period = period),
                      ),
                    ),
                    if (period != Period.values.last) const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            Expanded(
              child: reportCardAsync.when(
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
                          onPressed: () => ref.invalidate(reportCardProvider(query)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (reportCard) {
                  if (reportCard.subjectAverages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.summarize_outlined, color: AppColors.textHint, size: 48),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Aucune note enregistrée pour ${_period.label.toLowerCase()}.',
                              style: textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                    children: [
                      for (final subject in reportCard.subjectAverages) ...[
                        _SubjectAverageCard(subject: subject),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _OverallAverageCard(average: reportCard.overallAverage),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectAverageCard extends StatelessWidget {
  const _SubjectAverageCard({required this.subject});

  final SubjectAverage subject;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.subjectName, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(
                  '${subject.gradeCount} note${subject.gradeCount > 1 ? 's' : ''}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${_formatAverage(subject.average)}/20',
            style: textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _OverallAverageCard extends StatelessWidget {
  const _OverallAverageCard({required this.average});

  final double? average;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.secondaryLight, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Expanded(
            child: Text('Moyenne générale', style: textTheme.titleMedium?.copyWith(color: AppColors.secondaryDark)),
          ),
          Text(
            average != null ? '${_formatAverage(average!)}/20' : '—',
            style: textTheme.headlineSmall?.copyWith(color: AppColors.secondaryDark, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String _formatAverage(double value) => value.toStringAsFixed(2);
