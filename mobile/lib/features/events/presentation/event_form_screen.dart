import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/event_organizer_controller.dart';
import '../data/event_organizer_repository.dart';
import '../models/event.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _descriptionController = TextEditingController();

  Country? _country;
  City? _city;
  EventCategory _category = EventCategory.concert;
  DateTime _startDatetime = DateTime.now().add(const Duration(days: 7));
  DateTime? _endDatetime;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDatetime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDatetime),
    );
    if (time == null) return;
    setState(() {
      _startDatetime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_endDatetime != null && !_endDatetime!.isAfter(_startDatetime)) {
        _endDatetime = null;
      }
    });
  }

  Future<void> _pickEnd() async {
    final initial = _endDatetime ?? _startDatetime.add(const Duration(hours: 2));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _startDatetime,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _endDatetime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_country == null || _city == null) {
      setState(() => _errorMessage = 'Choisissez un pays et une ville.');
      return;
    }
    if (_endDatetime == null || !_endDatetime!.isAfter(_startDatetime)) {
      setState(() => _errorMessage = 'La date de fin doit être après la date de début.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(eventOrganizerRepositoryProvider).createEvent(
        name: _nameController.text.trim(),
        venue: _venueController.text.trim(),
        countryId: _country!.id,
        cityId: _city!.id,
        startDatetime: _startDatetime,
        endDatetime: _endDatetime!,
        category: _category,
        description: _descriptionController.text.trim(),
      );
      ref.invalidate(myEventsProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countriesAsync = ref.watch(eventOrganizerCountriesProvider);
    final citiesAsync = ref.watch(eventOrganizerCitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel événement')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
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
                      AppTextField(
                        controller: _nameController,
                        label: 'Nom de l\'événement',
                        prefixIcon: Icons.event_outlined,
                        validator: (value) => AppValidators.required(value, 'Le nom'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _venueController,
                        label: 'Lieu',
                        prefixIcon: Icons.location_on_outlined,
                        validator: (value) => AppValidators.required(value, 'Le lieu'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Catégorie', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<EventCategory>(
                        initialValue: _category,
                        isExpanded: true,
                        items: [
                          for (final value in EventCategory.values)
                            DropdownMenuItem(value: value, child: Text(value.label)),
                        ],
                        onChanged: (value) => setState(() => _category = value ?? _category),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Pays', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      countriesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les pays.'),
                        data: (countries) => DropdownButtonFormField<Country>(
                          initialValue: _country,
                          isExpanded: true,
                          hint: const Text('Choisir un pays'),
                          items: [
                            for (final country in countries)
                              DropdownMenuItem(value: country, child: Text(country.name)),
                          ],
                          onChanged: (value) => setState(() {
                            _country = value;
                            _city = null;
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Ville', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      citiesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les villes.'),
                        data: (cities) {
                          final available = _country == null
                              ? const <City>[]
                              : cities.where((city) => city.countryCode == _country!.code).toList();
                          return DropdownButtonFormField<City>(
                            initialValue: _city,
                            isExpanded: true,
                            hint: Text(_country == null ? 'Choisissez d\'abord un pays' : 'Choisir une ville'),
                            items: [
                              for (final city in available) DropdownMenuItem(value: city, child: Text(city.name)),
                            ],
                            onChanged: _country == null ? null : (value) => setState(() => _city = value),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Début', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      InkWell(
                        onTap: _pickStart,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InputDecorator(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_rounded)),
                          child: Text(_formatDateTime(_startDatetime), overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Fin', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      InkWell(
                        onTap: _pickEnd,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InputDecorator(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_rounded)),
                          child: Text(
                            _endDatetime == null ? 'Choisir une date de fin' : _formatDateTime(_endDatetime!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description (optionnel)',
                        prefixIcon: Icons.notes_outlined,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Créer l\'événement', isLoading: _isSubmitting, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
