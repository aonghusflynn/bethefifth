import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/games_provider.dart';
import '../../providers/user_provider.dart';

class GamesListScreen extends ConsumerWidget {
  const GamesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gamesState = ref.watch(gamesProvider);
    final userState = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      drawer: const _OrganiserDrawer(),
      appBar: AppBar(
        title: Text(
          'BeTheFifth',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: CircleAvatar(
              backgroundColor: BtfColors.ink2,
              radius: 18,
              backgroundImage: userState.value?.photoUrl != null
                  ? NetworkImage(userState.value!.photoUrl!)
                  : null,
              child: userState.value?.photoUrl == null
                  ? const Icon(Icons.person, color: BtfColors.lime, size: 20)
                  : null,
            ),
          ),
          const SizedBox(width: BtfSpace.x3),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(gamesProvider.notifier).refresh(),
        color: BtfColors.lime,
        backgroundColor: BtfColors.ink,
        child: gamesState.when(
          data: (games) {
            if (games.isEmpty) {
              return _buildEmptyState(context, theme);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(BtfSpace.x4),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return _buildGameCard(context, theme, game);
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(BtfColors.lime),
            ),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(BtfSpace.x5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: BtfColors.coral, size: 48),
                  const SizedBox(height: BtfSpace.x3),
                  Text('Failed to load games: ${err.toString()}', textAlign: TextAlign.center),
                  const SizedBox(height: BtfSpace.x3),
                  ElevatedButton(
                    onPressed: () => ref.read(gamesProvider.notifier).refresh(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BtfColors.lime,
                      foregroundColor: BtfColors.ink,
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/organiser/create-game'),
        backgroundColor: BtfColors.lime,
        foregroundColor: BtfColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BtfRadius.md)),
        icon: const Icon(Icons.add_circle_outline, size: 22, color: BtfColors.ink),
        label: Text(
          'Post Game',
          style: theme.textTheme.titleMedium?.copyWith(
            color: BtfColors.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: BtfSpace.x6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(BtfSpace.x5),
              decoration: BoxDecoration(
                color: BtfColors.chalk.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_soccer_outlined,
                size: 64,
                color: BtfColors.muted,
              ),
            ),
            const SizedBox(height: BtfSpace.x5),
            Text(
              'No Open Games Nearby',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: BtfSpace.x2),
            Text(
              'Be the initiator! Organise a match in Dublin, invite your crew, and post it to fill the waitlist roster.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BtfColors.muted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BtfSpace.x5),
            ElevatedButton(
              onPressed: () => context.push('/organiser/create-game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BtfColors.lime,
                foregroundColor: BtfColors.ink,
                padding: const EdgeInsets.symmetric(horizontal: BtfSpace.x5, vertical: BtfSpace.x3),
                shape: const StadiumBorder(),
              ),
              child: const Text('Post First Game', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, ThemeData theme, dynamic game) {
    final isDark = theme.brightness == Brightness.dark;
    final startsAtFormatted = DateFormat('EEEE, MMMM d • HH:mm').format(game.startsAt);
    final slotsRemaining = game.maxPlayers - game.currentPlayers;
    final isFull = game.status == 'full' || slotsRemaining <= 0;

    String venueName = 'Dublin Stadium Pitch';
    if (game.venueId == '00000000-0000-0000-0000-000000000001') venueName = 'Irishtown Stadium (4G)';
    if (game.venueId == '00000000-0000-0000-0000-000000000002') venueName = 'Sandymount YMCA';
    if (game.venueId == '00000000-0000-0000-0000-000000000003') venueName = 'Herbert Park Pitch';
    if (game.venueId == '00000000-0000-0000-0000-000000000004') venueName = 'Ringsend Park Pitch';

    return Card(
      margin: const EdgeInsets.only(bottom: BtfSpace.x4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BtfRadius.md),
        side: BorderSide(
          color: isDark ? BtfColors.ink2 : BtfColors.chalk.withOpacity(0.5),
          width: 1,
        ),
      ),
      color: isDark ? BtfColors.ink2.withOpacity(0.5) : BtfColors.paper.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(BtfRadius.md),
        onTap: () => context.push('/games/${game.id}'),
        child: Padding(
          padding: const EdgeInsets.all(BtfSpace.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: BtfSpace.x2, vertical: BtfSpace.x1),
                    decoration: BoxDecoration(
                      color: isFull ? BtfColors.coral.withOpacity(0.1) : BtfColors.lime.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(BtfRadius.xs),
                    ),
                    child: Text(
                      isFull
                          ? 'WAITLIST ONLY'
                          : '$slotsRemaining OF ${game.maxPlayers} SLOTS FREE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isFull ? BtfColors.coral : BtfColors.limeDeep,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildSkillLevelBadge(theme, game.skillLevel),
                ],
              ),
              const SizedBox(height: BtfSpace.x3),
              
              Text(
                game.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: BtfSpace.x1),
              
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: BtfColors.muted),
                  const SizedBox(width: BtfSpace.x1),
                  Text(
                    venueName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: BtfColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BtfSpace.x3),
              
              const Divider(height: 1, color: Colors.grey),
              const SizedBox(height: BtfSpace.x3),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: BtfColors.lime),
                      const SizedBox(width: BtfSpace.x2),
                      Text(
                        startsAtFormatted,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'FREE',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: BtfColors.limeDeep,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillLevelBadge(ThemeData theme, int level) {
    String label = 'Casual';
    Color color = Colors.green;
    if (level == 1) { label = 'Beginner'; color = Colors.blue; }
    if (level == 2) { label = 'Casual'; color = Colors.teal; }
    if (level == 3) { label = 'Intermediate'; color = Colors.orange; }
    if (level == 4) { label = 'Competitive'; color = BtfColors.coral; }
    if (level == 5) { label = 'Elite'; color = Colors.purple; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BtfSpace.x2, vertical: BtfSpace.x1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(BtfRadius.xs),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }
}

/// Entry point to the organiser tools. Kept in a drawer so the games list
/// stays focused on discovery, which is what most players open the app for.
class _OrganiserDrawer extends StatelessWidget {
  const _OrganiserDrawer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(BtfSpace.x5),
              child: Row(
                children: [
                  const Icon(Icons.sports_soccer,
                      color: BtfColors.lime, size: 28),
                  const SizedBox(width: BtfSpace.x3),
                  Text(
                    l10n.organiserTools,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(l10n.mySquads),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/organiser/squads');
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(l10n.recurringGames),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/organiser/series');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(l10n.createGame),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/organiser/create-game');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.profile),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile');
              },
            ),
          ],
        ),
      ),
    );
  }
}
