import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/city.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/hotel_search_controller.dart';
import '../models/hotel_search_params.dart';

class HotelSearchScreen extends ConsumerStatefulWidget {
  const HotelSearchScreen({super.key});

  @override
  ConsumerState<HotelSearchScreen> createState() => _HotelSearchScreenState();
}

class _HotelSearchScreenState extends ConsumerState<HotelSearchScreen> {
  City? _city;
  DateTime _checkIn = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 2));
  String? _errorMessage;

  Future<void> _pickCheckIn() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _checkIn = picked;
      if (!_checkOut.isAfter(_checkIn)) {
        _checkOut = _checkIn.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickCheckOut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOut,
      firstDate: _checkIn.add(const Duration(days: 1)),
      lastDate: _checkIn.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _checkOut = picked);
  }

  void _submit() {
    setState(() => _errorMessage = null);

    if (_city == null) {
      setState(() => _errorMessage = 'Choisissez une ville.');
      return;
    }

    context.push(
      '/hub/hotels/results',
      extra: HotelSearchParams(
        cityId: _city!.id,
        cityName: _city!.name,
        checkIn: _checkIn,
        checkOut: _checkOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(hotelCitiesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hôtels'),
        actions: [
          IconButton(
            tooltip: 'Mes réservations',
            icon: const Icon(Icons.bookmark_outline_rounded),
            onPressed: () => context.push('/hub/hotels/bookings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Où séjournez-vous ?', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Recherchez un hôtel disponible pour vos dates.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            citiesAsync.when(
              data: (cities) => _SearchForm(
                cities: cities,
                city: _city,
                checkIn: _checkIn,
                checkOut: _checkOut,
                errorMessage: _errorMessage,
                onCityChanged: (city) => setState(() => _city = city),
                onPickCheckIn: _pickCheckIn,
                onPickCheckOut: _pickCheckOut,
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
                      onPressed: () => ref.invalidate(hotelCitiesProvider),
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
    required this.checkIn,
    required this.checkOut,
    required this.errorMessage,
    required this.onCityChanged,
    required this.onPickCheckIn,
    required this.onPickCheckOut,
    required this.onSubmit,
  });

  final List<City> cities;
  final City? city;
  final DateTime checkIn;
  final DateTime checkOut;
  final String? errorMessage;
  final ValueChanged<City?> onCityChanged;
  final VoidCallback onPickCheckIn;
  final VoidCallback onPickCheckOut;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nights = checkOut.difference(checkIn).inDays;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorMessage != null) ...[
            AppErrorBanner(message: errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          Text('Ville', style: textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<City>(
            initialValue: city,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_city_rounded),
              hintText: 'Choisir une ville',
            ),
            items: [
              for (final city in cities) DropdownMenuItem(value: city, child: Text(city.name)),
            ],
            onChanged: onCityChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arrivée', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: onPickCheckIn,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InputDecorator(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_rounded)),
                        child: Text(_formatDate(checkIn)),
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
                    Text('Départ', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: onPickCheckOut,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InputDecorator(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_rounded)),
                        child: Text(_formatDate(checkOut)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$nights nuit${nights > 1 ? 's' : ''}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Rechercher', icon: Icons.search_rounded, onPressed: onSubmit),
        ],
      ),
    );
  }
}
