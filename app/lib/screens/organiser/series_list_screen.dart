import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';

class SeriesListScreen extends ConsumerWidget {
  const SeriesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final seriesState = ref.watch(seriesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.recurringGames),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(seriesProvider.notifier).refresh(),
        color: BtfColors.lime,
        child: seriesState.when(
          data: (allSeries) {
            if (allSeries.isEmpty) return _EmptyState(l10n: l10n);
            return ListView.separated(
              padding: const EdgeInsets.all(BtfSpace.x4),
              itemCount: allSeries.length,
              separatorBuilder: (_, __) => const SizedBox(height: BtfSpace.x3),
              itemBuilder: (context, index) => _SeriesCard(
                series: allSeries[index],
                l10n: l10n,
                onTogglePause: () => _togglePause(
                  context,
                  ref,
                  allSeries[index],
                ),
                onDelete: () => _delete(context, ref, allSeries[index], l10n),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(BtfColors.lime),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(BtfSpace.x5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: BtfColors.coral, size: 48),
                  const SizedBox(height: BtfSpace.x3),
                  Text(err.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: BtfSpace.x4),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(seriesProvider.notifier).refresh(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BtfColors.lime,
                      foregroundColor: BtfColors.ink,
                    ),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/organiser/series/create'),
        backgroundColor: BtfColors.lime,
        foregroundColor: BtfColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BtfRadius.md),
        ),
        icon: const Icon(Icons.repeat, size: 22),
        label: Text(
          l10n.newRecurringGame,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: BtfColors.ink, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _togglePause(
    BuildContext context,
    WidgetRef ref,
    GameSeries series,
  ) async {
    try {
      await ref
          .read(seriesProvider.notifier)
          .setActive(series.id, isActive: !series.isActive);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: BtfColors.coral,
          ),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    GameSeries series,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSeries),
        content: Text(l10n.deleteSeriesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: BtfColors.coral),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(seriesProvider.notifier).deleteSeries(series.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: BtfColors.coral,
          ),
        );
      }
    }
  }
}

class _SeriesCard extends StatelessWidget {
  final GameSeries series;
  final AppLocalizations l10n;
  final VoidCallback onTogglePause;
  final VoidCallback onDelete;

  const _SeriesCard({
    required this.series,
    required this.l10n,
    required this.onTogglePause,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pattern = RecurrencePattern.fromRrule(series.rrule);

    return Container(
      padding: const EdgeInsets.all(BtfSpace.x4),
      decoration: BoxDecoration(
        color: isDark ? BtfColors.ink2 : BtfColors.paper2,
        borderRadius: BorderRadius.circular(BtfRadius.md),
        border: Border.all(
          color: series.isActive
              ? (isDark ? BtfColors.outline.withOpacity(0.4) : BtfColors.chalk)
              : BtfColors.warning.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  series.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (!series.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: BtfSpace.x2, vertical: 2),
                  decoration: BoxDecoration(
                    color: BtfColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(BtfRadius.xs),
                  ),
                  child: Text(
                    l10n.seriesPaused.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: BtfColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: BtfSpace.x2),
          Row(
            children: [
              const Icon(Icons.repeat, size: 14, color: BtfColors.lime),
              const SizedBox(width: BtfSpace.x2),
              Text(
                _patternLabel(pattern, l10n),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: BtfColors.muted),
              const SizedBox(width: BtfSpace.x2),
              Text(
                DateFormat('EEEE • HH:mm').format(series.startsAt.toLocal()),
                style:
                    theme.textTheme.bodySmall?.copyWith(color: BtfColors.muted),
              ),
            ],
          ),
          if (series.squadId == null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.public, size: 14, color: BtfColors.muted),
                const SizedBox(width: BtfSpace.x2),
                Expanded(
                  child: Text(
                    l10n.noSquadOption,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: BtfColors.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: BtfSpace.x3),
          const Divider(height: 1),
          const SizedBox(height: BtfSpace.x2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onTogglePause,
                icon: Icon(
                  series.isActive ? Icons.pause : Icons.play_arrow,
                  size: 18,
                ),
                label: Text(
                  series.isActive ? l10n.pauseSeries : l10n.resumeSeries,
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                style: TextButton.styleFrom(foregroundColor: BtfColors.coral),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.delete),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _patternLabel(RecurrencePattern pattern, AppLocalizations l10n) {
    switch (pattern) {
      case RecurrencePattern.weekly:
        return l10n.repeatWeekly;
      case RecurrencePattern.fortnightly:
        return l10n.repeatFortnightly;
      case RecurrencePattern.monthly:
        return l10n.repeatMonthly;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: BtfSpace.x6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.repeat, size: 56, color: BtfColors.muted),
            const SizedBox(height: BtfSpace.x4),
            Text(
              l10n.noSeriesTitle,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BtfSpace.x2),
            Text(
              l10n.noSeriesBody,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: BtfColors.muted, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
