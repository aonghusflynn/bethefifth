import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/venue.dart';
import '../../providers/games_provider.dart';
import '../../services/api_service.dart';

/// self-contained provider to fetch Dublin venues
final venuesProvider = FutureProvider.autoDispose<List<Venue>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  try {
    final List<dynamic> jsonList = await apiService.listVenues(city: 'Dublin');
    final List<Venue> list = jsonList.map((e) => Venue.fromJson(e as Map<String, dynamic>)).toList();
    if (list.isEmpty) {
      throw Exception('No venues found in database');
    }
    return list;
  } catch (_) {
    // Return pre-seeded fallbacks if offline or db not ready
    return const [
      Venue(
        id: '00000000-0000-0000-0000-000000000001',
        name: 'Irishtown Stadium (4G)',
        address: 'Ringsend, Dublin 4',
        city: 'Dublin',
        lat: 53.3412,
        lng: -6.2201,
        surface: '4G Astro',
      ),
      Venue(
        id: '00000000-0000-0000-0000-000000000002',
        name: 'Sandymount YMCA',
        address: 'Sandymount Road, Dublin 4',
        city: 'Dublin',
        lat: 53.3321,
        lng: -6.2185,
        surface: '3G Astro',
      ),
      Venue(
        id: '00000000-0000-0000-0000-000000000003',
        name: 'Herbert Park Pitch',
        address: 'Herbert Park, Ballsbridge',
        city: 'Dublin',
        lat: 53.3256,
        lng: -6.2341,
        surface: 'All-Weather Astro',
      ),
      Venue(
        id: '00000000-0000-0000-0000-000000000004',
        name: 'Ringsend Park Pitch',
        address: 'Ringsend Park, Dublin 4',
        city: 'Dublin',
        lat: 53.3401,
        lng: -6.2112,
        surface: '4G Astro',
      ),
    ];
  }
});

class CreateGameScreen extends ConsumerStatefulWidget {
  const CreateGameScreen({super.key});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  String? _selectedVenueId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  int _durationMinutes = 60;
  int _maxPlayers = 10;
  int _skillLevel = 3;
  
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: BtfColors.limeDeep,
            onPrimary: BtfColors.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: BtfColors.limeDeep,
            onPrimary: BtfColors.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVenueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Dublin pitch venue.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final startsAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await ref.read(gamesProvider.notifier).createGame(
            title: _titleController.text.trim(),
            venueId: _selectedVenueId!,
            startsAt: startsAt,
            durationMinutes: _durationMinutes,
            maxPlayers: _maxPlayers,
            skillLevel: _skillLevel,
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match published successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish match: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final venuesAsync = ref.watch(venuesProvider);

    return Scaffold(
      backgroundColor: isDark ? BtfColors.ink : BtfColors.paper,
      appBar: AppBar(
        title: const Text('POST NEW GAME'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(BtfSpace.x4),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POST A PITCH MATCH',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: BtfColors.muted,
                        ),
                      ),
                      const SizedBox(height: BtfSpace.x4),
                      
                      // Match Title
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Match Title',
                          hintText: 'e.g. Tuesday Night Astro',
                          prefixIcon: Icon(Icons.sports_soccer_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a match title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: BtfSpace.x4),
                      
                      // Venue Selector
                      venuesAsync.when(
                        data: (venues) {
                          return DropdownButtonFormField<String>(
                            value: _selectedVenueId,
                            decoration: const InputDecoration(
                              labelText: 'Select Dublin Venue',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            dropdownColor: isDark ? BtfColors.ink2 : BtfColors.paper,
                            items: venues.map((v) {
                              return DropdownMenuItem<String>(
                                value: v.id,
                                child: Text(
                                  v.name,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedVenueId = val;
                              });
                            },
                            validator: (value) => value == null ? 'Please select a venue' : null,
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(BtfColors.lime),
                          ),
                        ),
                        error: (err, stack) => const Text('Failed to load venues.'),
                      ),
                      const SizedBox(height: BtfSpace.x4),
                      
                      // Date & Time Picker Row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(BtfRadius.md),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? BtfColors.ink2 : BtfColors.paper2,
                                  borderRadius: BorderRadius.circular(BtfRadius.md),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 18, color: BtfColors.lime),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Date', style: TextStyle(fontSize: 10, color: BtfColors.muted)),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('MMM d, yyyy').format(_selectedDate),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: BtfSpace.x3),
                          Expanded(
                            child: InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(BtfRadius.md),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? BtfColors.ink2 : BtfColors.paper2,
                                  borderRadius: BorderRadius.circular(BtfRadius.md),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18, color: BtfColors.lime),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Kick-off', style: TextStyle(fontSize: 10, color: BtfColors.muted)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedTime.format(context),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: BtfSpace.x4),
                      
                      // Duration & Capacity Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _durationMinutes,
                              decoration: const InputDecoration(
                                labelText: 'Duration',
                                prefixIcon: Icon(Icons.timer_outlined),
                              ),
                              dropdownColor: isDark ? BtfColors.ink2 : BtfColors.paper,
                              items: const [
                                DropdownMenuItem(value: 45, child: Text('45 mins')),
                                DropdownMenuItem(value: 60, child: Text('60 mins')),
                                DropdownMenuItem(value: 90, child: Text('90 mins')),
                                DropdownMenuItem(value: 120, child: Text('120 mins')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _durationMinutes = val;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: BtfSpace.x3),
                          Expanded(
                            child: TextFormField(
                              initialValue: '10',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Capacity (Max)',
                                prefixIcon: Icon(Icons.people_outline),
                                suffixText: 'players',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Required';
                                final val = int.tryParse(value);
                                if (val == null || val < 2 || val > 30) {
                                  return 'Enter 2-30';
                                }
                                return null;
                              },
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null) {
                                  _maxPlayers = parsed;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: BtfSpace.x4),
                      
                      // Skill Level Selector
                      Text(
                        'REQUIRED SKILL LEVEL',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: BtfColors.muted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: BtfSpace.x2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          final level = index + 1;
                          final isSelected = _skillLevel == level;
                          final label = skillLevelLabels[level]!;
                          
                          Color color = Colors.green;
                          if (level == 1) color = Colors.blue;
                          if (level == 2) color = Colors.teal;
                          if (level == 3) color = Colors.orange;
                          if (level == 4) color = BtfColors.coral;
                          if (level == 5) color = Colors.purple;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _skillLevel = level;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? color : color.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(BtfRadius.sm),
                                border: Border.all(
                                  color: isSelected ? color : color.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$level',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    label.substring(0, 3).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: BtfSpace.x4),
                      
                      // Description / Rules / Price info
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes / Rules',
                          hintText: 'e.g. Pitch 4 booked. No metal studs allowed. Cost split equally at the venue.',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom CTA
            Container(
              padding: const EdgeInsets.all(BtfSpace.x4),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: isDark ? BtfColors.ink2 : BtfColors.chalk.withOpacity(0.5),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(BtfColors.ink),
                          ),
                        )
                      : const Text(
                          'PUBLISH MATCH',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
