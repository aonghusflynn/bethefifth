import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/squad.dart';
import '../../providers/squads_provider.dart';

class SquadDetailScreen extends ConsumerWidget {
  final String squadId;

  const SquadDetailScreen({super.key, required this.squadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final squadState = ref.watch(squadDetailProvider(squadId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(squadState.value?.name ?? l10n.mySquads),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (squadState.value != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'rename') {
                  await _renameSquad(context, ref, squadState.value!, l10n);
                } else if (value == 'delete') {
                  await _deleteSquad(context, ref, l10n);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.renameSquad)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    l10n.deleteSquad,
                    style: const TextStyle(color: BtfColors.coral),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: squadState.when(
        data: (squad) {
          if (squad == null) {
            return Center(child: Text(l10n.noSquadsTitle));
          }
          return ListView(
            padding: const EdgeInsets.all(BtfSpace.x4),
            children: [
              _SummaryCard(squad: squad, l10n: l10n),
              const SizedBox(height: BtfSpace.x5),
              Text(
                l10n.squadMembersHeading.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: BtfColors.muted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: BtfSpace.x2),
              if (squad.members.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: BtfSpace.x5),
                  child: Text(
                    l10n.squadEmptyMembers,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: BtfColors.muted, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...squad.members.map(
                  (m) => _MemberTile(
                    member: m,
                    l10n: l10n,
                    onRemove: () => _removeMember(context, ref, m, l10n),
                  ),
                ),
              const SizedBox(height: BtfSpace.x6),
            ],
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
                      ref.invalidate(squadDetailProvider(squadId)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberSheet(context, ref, l10n),
        backgroundColor: BtfColors.lime,
        foregroundColor: BtfColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BtfRadius.md),
        ),
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 22),
        label: Text(
          l10n.addMember,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: BtfColors.ink, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _showAddMemberSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submitted = await showModalBottomSheet<bool>(
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
                l10n.addMember,
                style: Theme.of(ctx)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: BtfSpace.x4),
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.memberName),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
              ),
              const SizedBox(height: BtfSpace.x4),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.memberEmail,
                  helperText: l10n.memberEmailHint,
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return null; // email is optional
                  // Deliberately loose — the backend validates properly.
                  final looksLikeEmail =
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                  return looksLikeEmail ? null : l10n.invalidEmail;
                },
              ),
              const SizedBox(height: BtfSpace.x5),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: BtfColors.lime,
                  foregroundColor: BtfColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: BtfSpace.x4),
                ),
                child: Text(
                  l10n.add,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (submitted != true) return;

    try {
      await ref.read(squadDetailProvider(squadId).notifier).addMember(
            displayName: nameController.text.trim(),
            email: emailController.text.trim(),
          );
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    SquadMember member,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removePlayer),
        content: Text(l10n.removePlayerConfirm(member.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: BtfColors.coral),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(squadDetailProvider(squadId).notifier)
          .removeMember(member.id);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _renameSquad(
    BuildContext context,
    WidgetRef ref,
    Squad squad,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController(text: squad.name);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameSquad),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.squadName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await ref.read(squadDetailProvider(squadId).notifier).rename(name);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _deleteSquad(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSquad),
        content: Text(l10n.deleteSquadConfirm),
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
      await ref.read(squadsProvider.notifier).deleteSquad(squadId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: BtfColors.coral,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Squad squad;
  final AppLocalizations l10n;

  const _SummaryCard({required this.squad, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BtfSpace.x4),
      decoration: BoxDecoration(
        color: isDark ? BtfColors.ink2 : BtfColors.paper2,
        borderRadius: BorderRadius.circular(BtfRadius.lg),
        border: Border.all(
          color: isDark ? BtfColors.outline.withOpacity(0.4) : BtfColors.chalk,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined,
              color: BtfColors.limeDeep, size: 28),
          const SizedBox(width: BtfSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  squad.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.memberCountSummary(
                      squad.activeCount, squad.pendingCount),
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: BtfColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final SquadMember member;
  final AppLocalizations l10n;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.l10n,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: BtfSpace.x2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BtfSpace.x3,
          vertical: BtfSpace.x3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BtfRadius.sm),
          border: Border.all(
            color: member.isPending
                ? BtfColors.warning.withOpacity(0.35)
                : BtfColors.outline.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: member.isPending
                  ? BtfColors.warning.withOpacity(0.15)
                  : BtfColors.lime.withOpacity(0.18),
              child: Text(
                _initials(member.displayName),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: member.isPending
                      ? BtfColors.warning
                      : BtfColors.limeDeep,
                ),
              ),
            ),
            const SizedBox(width: BtfSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (member.inviteEmail != null)
                    Text(
                      member.inviteEmail!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: BtfColors.muted),
                    ),
                  if (member.isPending) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.hourglass_top,
                            size: 11, color: BtfColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          l10n.pendingInvite,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: BtfColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18, color: BtfColors.muted),
              tooltip: l10n.remove,
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
