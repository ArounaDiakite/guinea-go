import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/trip_search_controller.dart';
import '../../../core/models/city.dart';
import '../models/trip_search_params.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  City? _origin;
  City? _destination;
  DateTime _date = DateTime.now();
  String? _errorMessage;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    setState(() => _errorMessage = null);

    if (_origin == null || _destination == null) {
      setState(() => _errorMessage = 'Choisissez une ville de départ et une ville d\'arrivée.');
      return;
    }
    if (_origin!.id == _destination!.id) {
      setState(() => _errorMessage = 'La ville de départ et d\'arrivée doivent être différentes.');
      return;
    }

    context.push(
      '/hub/transport/results',
      extra: TripSearchParams(
        originCityId: _origin!.id,
        originCityName: _origin!.name,
        destinationCityId: _destination!.id,
        destinationCityName: _destination!.name,
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport'),
        actions: [
          IconButton(
            tooltip: 'Mes réservations',
            icon: const Icon(Icons.confirmation_number_outlined),
            onPressed: () => context.push('/hub/transport/bookings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Où allez-vous ?', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Recherchez un trajet en bus entre deux villes.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            citiesAsync.when(
              data: (cities) => _SearchForm(
                cities: cities,
                origin: _origin,
                destination: _destination,
                date: _date,
                errorMessage: _errorMessage,
                onOriginChanged: (city) => setState(() => _origin = city),
                onDestinationChanged: (city) => setState(() => _destination = city),
                onPickDate: _pickDate,
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
                      onPressed: () => ref.invalidate(citiesProvider),
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

class _SearchForm extends StatelessWidget {
  const _SearchForm({
    required this.cities,
    required this.origin,
    required this.destination,
    required this.date,
    required this.errorMessage,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onPickDate,
    required this.onSubmit,
  });

  final List<City> cities;
  final City? origin;
  final City? destination;
  final DateTime date;
  final String? errorMessage;
  final ValueChanged<City?> onOriginChanged;
  final ValueChanged<City?> onDestinationChanged;
  final VoidCallback onPickDate;
  final VoidCallback onSubmit;

  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorMessage != null) ...[
            AppErrorBanner(message: errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          Text('Ville de départ', style: textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          _CityDropdown(
            cities: cities,
            value: origin,
            hint: 'Choisir une ville',
            icon: Icons.trip_origin_rounded,
            onChanged: onOriginChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Ville d\'arrivée', style: textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          _CityDropdown(
            cities: cities,
            value: destination,
            hint: 'Choisir une ville',
            icon: Icons.location_on_rounded,
            onChanged: onDestinationChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Date du voyage', style: textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.calendar_today_rounded),
              ),
              child: Text(_formatDate(date)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Rechercher', icon: Icons.search_rounded, onPressed: onSubmit),
        ],
      ),
    );
  }
}

class _CityDropdown extends StatelessWidget {
  const _CityDropdown({
    required this.cities,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

  final List<City> cities;
  final City? value;
  final String hint;
  final IconData icon;
  final ValueChanged<City?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<City>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(prefixIcon: Icon(icon), hintText: hint),
      items: [
        for (final city in cities) DropdownMenuItem(value: city, child: Text(city.name)),
      ],
      onChanged: onChanged,
    );
  }
}
