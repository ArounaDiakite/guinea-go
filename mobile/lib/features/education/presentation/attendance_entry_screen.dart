import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/school_controller.dart';
import '../data/school_repository.dart';
import '../models/attendance.dart';

/// Submits (or corrects) one time slot's attendance for a single date,
/// for every student in that class at once - matches the backend's
/// POST/PUT /timeslots/{id}/attendance shape exactly (a whole-class
/// list of statuses per date, not one call per student). There is no
/// GET-by-timeslot+date endpoint to pre-fill an already-submitted day,
/// so this always starts from "everyone present" and lets the admin
/// adjust; submitting tries POST first, and transparently falls back
/// to PUT with the same selections if the backend reports that day was
/// already recorded (409), matching the API's create-then-correct model.
class AttendanceEntryScreen extends ConsumerStatefulWidget {
  const AttendanceEntryScreen({
    super.key,
    required this.institutionId,
    required this.academicUnitId,
    required this.timeSlotId,
  });

  final String institutionId;
  final String academicUnitId;
  final String timeSlotId;

  @override
  ConsumerState<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends ConsumerState<AttendanceEntryScreen> {
  DateTime _date = DateTime.now();
  final Map<String, AttendanceStatus> _statuses = {};
  bool _statusesInitialized = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(schoolRepositoryProvider);
      try {
        await repository.submitAttendance(timeSlotId: widget.timeSlotId, date: _date, statuses: _statuses);
      } on DioException catch (error) {
        if (error.response?.statusCode == 409) {
          await repository.correctAttendance(timeSlotId: widget.timeSlotId, date: _date, statuses: _statuses);
        } else {
          rethrow;
        }
      }
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = StudentListQuery(institutionId: widget.institutionId, academicUnitId: widget.academicUnitId);
    final studentsAsync = ref.watch(studentsProvider(query));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Présences')),
      body: SafeArea(
        child: studentsAsync.when(
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
                    onPressed: () => ref.invalidate(studentsProvider(query)),
                  ),
                ],
              ),
            ),
          ),
          data: (students) {
            if (!_statusesInitialized) {
              _statusesInitialized = true;
              for (final student in students) {
                _statuses[student.id] = AttendanceStatus.present;
              }
            }

            if (students.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.groups_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucun élève dans cette classe.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date de la séance',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(_formatDate(_date)),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                    itemCount: students.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final status = _statuses[student.id] ?? AttendanceStatus.present;
                      return AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                student.fullName,
                                style: textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            DropdownButton<AttendanceStatus>(
                              value: status,
                              underline: const SizedBox.shrink(),
                              items: [
                                for (final option in AttendanceStatus.values)
                                  DropdownMenuItem(value: option, child: Text(option.label)),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _statuses[student.id] = value);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  child: Column(
                    children: [
                      if (_errorMessage != null) ...[
                        AppErrorBanner(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppButton(label: 'Enregistrer les présences', isLoading: _isSubmitting, onPressed: _submit),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
