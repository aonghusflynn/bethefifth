import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';
import '../../providers/squads_provider.dart';
import '../../providers/venues_provider.dart';

class CreateSeriesScreen extends ConsumerStatefulWidget {
  const CreateSeriesScreen({super.key});

  @override
  ConsumerState<CreateSeriesScreen> createState() => _CreateSeriesScreenState();
}

class _CreateSeriesScreenState extends ConsumerState<CreateSeriesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  String? _venueId;
  String? _squadId;
  RecurrencePattern _pattern = RecurrencePattern.weekly;
  DateTime _startsAt = _defaultStart();
  int _maxPlayers = 10;
  int _skillLevel = 3;
  bool _submitting = false;

  /// Next week, at a plausible evening kick-off.
  static DateTime _defaultStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 19, 0)
        .add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final venuesAsync = ref.watch(venuesProvider);
    final squadsAsync = ref.watch(squadsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.newRecurringGame),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(BtfSpace.x4),
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.gameDetails,
                hintText: 'Tuesday Night 5s',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
            ),
            const SizedBox(height: BtfSpace.x4),

            // Venue
            venuesAsync.when(
              data: (venues) => DropdownButtonFormField<String>(
                initialValue: _venueId ?? venues.first.id,
                decoration: InputDecoration(labelText: l10n.venue),
                items: venues
                    .map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Text(v.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _venueId = value),
              ),
              loading: () => const LinearProgressIndicator(
                color: BtfColors.lime,
              ),
              error: (err, _) => Text(
                err.toString(),
                style: const TextStyle(color: BtfColors.coral),
              ),
            ),
            const SizedBox(height: BtfSpace.x4),

            // Recurrence
            DropdownButtonFormField<RecurrencePattern>(
              initialValue: _pattern,
              decoration: InputDecoration(labelText: l10n.repeats),
              items: [
                DropdownMenuItem(
                  value: RecurrencePattern.weekly,
                  child: Text(l10n.repeatWeekly),
                ),
                DropdownMenuItem(
                  value: RecurrencePattern.fortnightly,
                  child: Text(l10n.repeatFortnightly),
                ),
                DropdownMenuItem(
                  value: RecurrencePattern.monthly,
                  child: Text(l10n.repeatMonthly),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _pattern = value ?? RecurrencePattern.weekly),
            ),
            const SizedBox(height: BtfSpace.x4),

            // First occurrence — sets the day and time for every instance.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event, color: BtfColors.lime),
              title: Text(l10n.firstMatch),
              subtitle: Text(
                DateFormat('EEEE, d MMMM • HH:mm').format(_startsAt),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.edit_calendar_outlined, size: 20),
              onTap: _pickStart,
            ),
            const Divider(),
            const SizedBox(height: BtfSpace.x3),

            // Squad — optional
            squadsAsync.when(
              data: (squads) => DropdownButtonFormField<String?>(
                initialValue: _squadId,
                decoration: InputDecoration(labelText: l10n.inviteSquad),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.noSquadOption,
                        overflow: TextOverflow.ellipsis),
                  ),
                  ...squads.map((s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child:
                            Text(s.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) => setState(() => _squadId = value),
              ),
              loading: () => const LinearProgressIndicator(
                color: BtfColors.lime,
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: BtfSpace.x4),

            // Capacity
            Text(
              '${l10n.players(_maxPlayers)}',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: BtfColors.muted),
            ),
            Slider(
              value: _maxPlayers.toDouble(),
              min: 2,
              max: 30,
              divisions: 28,
              activeColor: BtfColors.lime,
              label: '$_maxPlayers',
              onChanged: (v) => setState(() => _maxPlayers = v.round()),
            ),
            const SizedBox(height: BtfSpace.x2),

            // Skill
            Text(
              l10n.skill,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: BtfColors.muted),
            ),
            const SizedBox(height: BtfSpace.x2),
            Wrap(
              spacing: BtfSpace.x2,
              children: skillLevelLabels.entries
                  .map((e) => ChoiceChip(
                        label: Text(e.value),
                        selected: _skillLevel == e.key,
                        selectedColor: BtfColors.lime,
                        onSelected: (_) => setState(() => _skillLevel = e.key),
                      ))
                  .toList(),
            ),
            const SizedBox(height: BtfSpace.x6),

            FilledButton(
              onPressed: _submitting ? null : () => _submit(venuesAsync.value),
              style: FilledButton.styleFrom(
                backgroundColor: BtfColors.lime,
                foregroundColor: BtfColors.ink,
                padding: const EdgeInsets.symmetric(vertical: BtfSpace.x4),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(BtfColors.ink),
                      ),
                    )
                  : Text(
                      l10n.createRecurringGame,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: BtfSpace.x6),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;

    setState(() {
      _startsAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit(List<dynamic>? venues) async {
    if (!_formKey.currentState!.validate()) return;

    final venueId = _venueId ??
        (venues != null && venues.isNotEmpty ? venues.first.id as String : null);
    if (venueId == null) return;

    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref.read(seriesProvider.notifier).createSeries(
            venueId: venueId,
            title: _titleController.text.trim(),
            startsAt: _startsAt,
            rrule: _pattern.rrule,
            squadId: _squadId,
            maxPlayers: _maxPlayers,
            skillLevel: _skillLevel,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.seriesCreated),
          backgroundColor: BtfColors.limeDeep,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: BtfColors.coral,
        ),
      );
    }
  }
}
