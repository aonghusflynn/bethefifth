import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/squad.dart';
import '../../providers/squads_provider.dart';

class SquadsListScreen extends ConsumerWidget {
  const SquadsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final squadsState = ref.watch(squadsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.mySquads),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(squadsProvider.notifier).refresh(),
        color: BtfColors.lime,
        child: squadsState.when(
          data: (squads) {
            if (squads.isEmpty) return _EmptyState(l10n: l10n);
            return ListView.separated(
              padding: const EdgeInsets.all(BtfSpace.x4),
              itemCount: squads.length,
              separatorBuilder: (_, __) => const SizedBox(height: BtfSpace.x3),
              itemBuilder: (context, index) =>
                  _SquadCard(squad: squads[index], l10n: l10n),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(BtfColors.lime),
            ),
          ),
          error: (err, _) => _ErrorState(
            message: err.toString(),
            onRetry: () => ref.read(squadsProvider.notifier).refresh(),
            l10n: l10n,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSquadSheet(context, ref, l10n),
        backgroundColor: BtfColors.lime,
        foregroundColor: BtfColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BtfRadius.md),
        ),
        icon: const Icon(Icons.group_add_outlined, size: 22),
        label: Text(
          l10n.newSquad,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: BtfColors.ink, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

Future<void> _showCreateSquadSheet(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final name = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: BtfSpace.x5,
        right: BtfSpace.x5,
        top: BtfSpace.x5,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + BtfSpace.x5,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.newSquad,
              style: Theme.of(ctx)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: BtfSpace.x4),
            TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.squadName,
                hintText: l10n.squadNameHint,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
            ),
            const SizedBox(height: BtfSpace.x5),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: BtfColors.lime,
                foregroundColor: BtfColors.ink,
                padding: const EdgeInsets.symmetric(vertical: BtfSpace.x4),
              ),
              child: Text(
                l10n.createSquad,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (name == null || name.isEmpty) return;

  try {
    final squad = await ref.read(squadsProvider.notifier).createSquad(name);
    if (context.mounted) context.push('/organiser/squads/${squad.id}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: BtfColors.coral),
      );
    }
  }
}

class _SquadCard extends StatelessWidget {
  final Squad squad;
  final AppLocalizations l10n;

  const _SquadCard({required this.squad, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(BtfRadius.md),
      onTap: () => context.push('/organiser/squads/${squad.id}'),
      child: Container(
        padding: const EdgeInsets.all(BtfSpace.x4),
        decoration: BoxDecoration(
          color: isDark ? BtfColors.ink2 : BtfColors.paper2,
          borderRadius: BorderRadius.circular(BtfRadius.md),
          border: Border.all(
            color: isDark ? BtfColors.outline.withOpacity(0.4) : BtfColors.chalk,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: BtfColors.lime.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_outlined,
                  color: BtfColors.limeDeep, size: 22),
            ),
            const SizedBox(width: BtfSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    squad.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.memberCountSummary(
                        squad.activeCount, squad.pendingCount),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: BtfColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: BtfColors.muted),
          ],
        ),
      ),
    );
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
            const Icon(Icons.groups_outlined, size: 56, color: BtfColors.muted),
            const SizedBox(height: BtfSpace.x4),
            Text(
              l10n.noSquadsTitle,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BtfSpace.x2),
            Text(
              l10n.noSquadsBody,
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BtfSpace.x5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: BtfColors.coral, size: 48),
            const SizedBox(height: BtfSpace.x3),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: BtfSpace.x4),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: BtfColors.lime,
                foregroundColor: BtfColors.ink,
              ),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
