import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/city.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/event_search_controller.dart';
import '../models/event.dart';
import '../models/event_search_params.dart';

class EventSearchScreen extends ConsumerStatefulWidget {
  const EventSearchScreen({super.key});

  @override
  ConsumerState<EventSearchScreen> createState() => _EventSearchScreenState();
}

class _EventSearchScreenState extends ConsumerState<EventSearchScreen> {
  City? _city;
  EventCategory? _category;
  DateTime? _onOrAfter;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _onOrAfter ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _onOrAfter = picked);
  }

  void _submit() {
    context.push(
      '/hub/events/results',
      extra: EventSearchParams(
        cityId: _city?.id,
        cityName: _city?.name,
        category: _category,
        onOrAfter: _onOrAfter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(eventCitiesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Événements'),
        actions: [
          IconButton(
            tooltip: 'Mes billets',
            icon: const Icon(Icons.confirmation_number_outlined),
            onPressed: () => context.push('/hub/events/bookings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Trouvez votre prochain événement', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Filtrez par ville, catégorie ou date - tous les filtres sont optionnels.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            citiesAsync.when(
              data: (cities) => _SearchForm(
                cities: cities,
                city: _city,
                category: _category,
                onOrAfter: _onOrAfter,
                onCityChanged: (city) => setState(() => _city = city),
                onCategoryChanged: (category) => setState(() => _category = category),
                onPickDate: _pickDate,
                onClearDate: () => setState(() => _onOrAfter = null),
                onSubmit: _submit,
              ),
              loading: () => const AppCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stackTrace) => AppCard(
                child: Column(
                  children: [
                    const AppErrorBanner(message: 'Impossible de charger la liste des villes.'),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Réessayer',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => ref.invalidate(eventCitiesProvider),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _formatDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

class _SearchForm extends StatelessWidget {
  const _SearchForm({
    required this.cities,
    required this.city,
    required this.category,
    required this.onOrAfter,
    required this.onCityChanged,
    required this.onCategoryChanged,
    required this.onPickDate,
    required this.onClearDate,
    required this.onSubmit,
  });

  final List<City> cities;
  final City? city;
  final EventCategory? category;
  final DateTime? onOrAfter;
  final ValueChanged<City?> onCityChanged;
  final ValueChanged<EventCategory?> onCategoryChanged;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ville (optionnel)', style: textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<City>(
            initialValue: city,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_city_rounded),
              hintText: 'Toutes les villes',
            ),
            items: [
              for (final city in cities) DropdownMenuItem(value: city, child: Text(city.name)),
            ],
            onChanged: onCityChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Catégorie (optionnel)', style: textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<EventCategory>(
            initialValue: category,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
              hintText: 'Toutes les catégories',
            ),
            items: [
              for (final value in EventCategory.values)
                DropdownMenuItem(value: value, child: Text(value.label)),
            ],
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('À partir du (optionnel)', style: textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.calendar_today_rounded),
                suffixIcon: onOrAfter == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onClearDate,
                      ),
              ),
              child: Text(onOrAfter == null ? 'Toutes les dates' : _formatDate(onOrAfter!)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Rechercher', icon: Icons.search_rounded, onPressed: onSubmit),
        ],
      ),
    );
  }
}
