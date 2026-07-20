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
import '../models/subject.dart';
import '../models/teacher.dart';
import '../models/timeslot.dart';

/// Handles both create (timeSlotId == null) and edit, same shape as
/// the other education forms.
class TimeSlotFormScreen extends ConsumerWidget {
  const TimeSlotFormScreen({
    super.key,
    required this.institutionId,
    required this.academicUnitId,
    this.timeSlotId,
  });

  final String institutionId;
  final String academicUnitId;
  final String? timeSlotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (timeSlotId == null) {
      return _TimeSlotForm(institutionId: institutionId, academicUnitId: academicUnitId, existingTimeSlot: null);
    }

    final timeSlotAsync = ref.watch(timeSlotDetailProvider(timeSlotId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le créneau')),
      body: SafeArea(
        child: timeSlotAsync.when(
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
                    onPressed: () => ref.invalidate(timeSlotDetailProvider(timeSlotId!)),
                  ),
                ],
              ),
            ),
          ),
          data: (timeSlot) => _TimeSlotForm(
            institutionId: institutionId,
            academicUnitId: academicUnitId,
            existingTimeSlot: timeSlot,
          ),
        ),
      ),
    );
  }
}

class _TimeSlotForm extends ConsumerStatefulWidget {
  const _TimeSlotForm({
    required this.institutionId,
    required this.academicUnitId,
    required this.existingTimeSlot,
  });

  final String institutionId;
  final String academicUnitId;
  final TimeSlot? existingTimeSlot;

  @override
  ConsumerState<_TimeSlotForm> createState() => _TimeSlotFormState();
}

class _TimeSlotFormState extends ConsumerState<_TimeSlotForm> {
  Subject? _subject;
  Teacher? _teacher;
  DayOfWeek _dayOfWeek = DayOfWeek.monday;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _subjectInitialized = false;
  bool _teacherInitialized = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingTimeSlot != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTimeSlot;
    if (existing != null) {
      _dayOfWeek = existing.dayOfWeek;
      _startTime = existing.startTime;
      _endTime = existing.endTime;
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (_subject == null) {
      setState(() => _errorMessage = 'Choisissez une matière.');
      return;
    }
    if (_teacher == null) {
      setState(() => _errorMessage = 'Choisissez un enseignant.');
      return;
    }
    if (_startTime == null || _endTime == null) {
      setState(() => _errorMessage = 'Choisissez une heure de début et de fin.');
      return;
    }
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes <= startMinutes) {
      setState(() => _errorMessage = 'L\'heure de fin doit être après l\'heure de début.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(schoolRepositoryProvider);

      if (_isEditing) {
        await repository.updateTimeSlot(
          timeSlotId: widget.existingTimeSlot!.id,
          academicUnitId: widget.academicUnitId,
          subjectId: _subject!.id,
          teacherId: _teacher!.id,
          dayOfWeek: _dayOfWeek,
          startTime: _startTime!,
          endTime: _endTime!,
        );
      } else {
        await repository.createTimeSlot(
          academicUnitId: widget.academicUnitId,
          subjectId: _subject!.id,
          teacherId: _teacher!.id,
          dayOfWeek: _dayOfWeek,
          startTime: _startTime!,
          endTime: _endTime!,
        );
      }
      ref.invalidate(scheduleProvider(widget.academicUnitId));
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subjectsAsync = ref.watch(subjectsProvider(widget.institutionId));
    final teachersAsync = ref.watch(teachersProvider(widget.institutionId));

    return Scaffold(
      appBar: _isEditing ? null : AppBar(title: const Text('Nouveau créneau')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      AppErrorBanner(message: _errorMessage!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text('Matière', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    subjectsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) =>
                          const AppErrorBanner(message: 'Impossible de charger les matières.'),
                      data: (subjects) {
                        if (!_subjectInitialized) {
                          _subjectInitialized = true;
                          if (widget.existingTimeSlot != null) {
                            for (final subject in subjects) {
                              if (subject.id == widget.existingTimeSlot!.subjectId) _subject = subject;
                            }
                          }
                        }
                        if (subjects.isEmpty) {
                          return Text(
                            'Créez d\'abord une matière pour pouvoir l\'associer à un créneau.',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          );
                        }
                        return DropdownButtonFormField<Subject>(
                          initialValue: _subject,
                          isExpanded: true,
                          hint: const Text('Choisir une matière'),
                          items: [
                            for (final subject in subjects)
                              DropdownMenuItem(value: subject, child: Text(subject.name)),
                          ],
                          onChanged: (value) => setState(() => _subject = value),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Enseignant', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    teachersAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) =>
                          const AppErrorBanner(message: 'Impossible de charger les enseignants.'),
                      data: (teachers) {
                        if (!_teacherInitialized) {
                          _teacherInitialized = true;
                          if (widget.existingTimeSlot != null) {
                            for (final teacher in teachers) {
                              if (teacher.id == widget.existingTimeSlot!.teacherId) _teacher = teacher;
                            }
                          }
                        }
                        if (teachers.isEmpty) {
                          return Text(
                            'Créez d\'abord un enseignant pour pouvoir l\'associer à un créneau.',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          );
                        }
                        return DropdownButtonFormField<Teacher>(
                          initialValue: _teacher,
                          isExpanded: true,
                          hint: const Text('Choisir un enseignant'),
                          items: [
                            for (final teacher in teachers)
                              DropdownMenuItem(value: teacher, child: Text(teacher.fullName)),
                          ],
                          onChanged: (value) => setState(() => _teacher = value),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Jour', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<DayOfWeek>(
                      initialValue: _dayOfWeek,
                      isExpanded: true,
                      items: [
                        for (final day in DayOfWeek.values) DropdownMenuItem(value: day, child: Text(day.label)),
                      ],
                      onChanged: (value) => setState(() => _dayOfWeek = value ?? _dayOfWeek),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Début', style: textTheme.labelMedium),
                              const SizedBox(height: AppSpacing.xs),
                              InkWell(
                                onTap: () => _pickTime(isStart: true),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: InputDecorator(
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule_outlined)),
                                  child: Text(_startTime?.format(context) ?? 'Choisir'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fin', style: textTheme.labelMedium),
                              const SizedBox(height: AppSpacing.xs),
                              InkWell(
                                onTap: () => _pickTime(isStart: false),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: InputDecorator(
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule_outlined)),
                                  child: Text(_endTime?.format(context) ?? 'Choisir'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isEditing ? 'Enregistrer' : 'Créer le créneau',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
