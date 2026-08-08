import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/booking.dart';

/// The bottom action bar of the match screen.
///
/// Which control appears depends entirely on where the player stands with this
/// game. The `invited` case is the one that matters most: the player has been
/// asked but hasn't answered, so they need yes/no — showing them a cancel
/// button would be wrong, and showing a join button would double-book them.
class AttendanceBar extends StatelessWidget {
  final Booking? booking;
  final bool isFull;
  final ValueChanged<bool> onRespond;
  final VoidCallback onCancel;
  final VoidCallback onJoin;

  const AttendanceBar({
    super.key,
    required this.booking,
    required this.isFull,
    required this.onRespond,
    required this.onCancel,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (booking?.status == 'invited') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.attendanceQuestion,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.attendancePrompt,
            style: theme.textTheme.bodySmall?.copyWith(color: BtfColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BtfSpace.x3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onRespond(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BtfColors.coral,
                    side: const BorderSide(color: BtfColors.coral, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(
                    l10n.cantMakeIt,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: BtfSpace.x3),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onRespond(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: BtfColors.lime,
                    foregroundColor: BtfColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    l10n.imIn,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (booking != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (booking!.status == 'waitlisted') ...[
            Text(
              l10n.waitlistedBody,
              style: theme.textTheme.bodySmall?.copyWith(color: BtfColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BtfSpace.x3),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: BtfColors.coral,
                side: const BorderSide(color: BtfColors.coral, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'CANCEL BOOKING',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onJoin,
        style: FilledButton.styleFrom(
          backgroundColor: isFull ? BtfColors.warning : BtfColors.lime,
          foregroundColor: BtfColors.ink,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          isFull ? 'JOIN WAITLIST QUEUE' : 'BE THE 5TH!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
