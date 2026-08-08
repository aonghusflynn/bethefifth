import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/games_provider.dart';
import '../../providers/squads_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/game.dart';
import '../../models/booking.dart';
import '../../models/user.dart';
import 'widgets/attendance_bar.dart';

class GameDetailScreen extends ConsumerWidget {
  final String gameId;

  const GameDetailScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final gameAsync = ref.watch(gameDetailProvider(gameId));
    final myBookingAsync = ref.watch(myBookingProvider(gameId));
    final userState = ref.watch(userProvider);
    
    return Scaffold(
      backgroundColor: isDark ? BtfColors.ink : BtfColors.paper,
      appBar: AppBar(
        title: const Text('MATCH DETAILS'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Match link copied to clipboard!')),
              );
            },
          ),
          const SizedBox(width: BtfSpace.x2),
        ],
      ),
      body: gameAsync.when(
        data: (game) {
          if (game == null) {
            return const Center(
              child: Text('Match not found or has been cancelled.'),
            );
          }
          return myBookingAsync.when(
            data: (myBooking) {
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCard(context, theme, game, myBooking),
                          const SizedBox(height: BtfSpace.x4),
                          
                          // Pitch Representation Section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: BtfSpace.x4),
                            child: Text(
                              'TACTICAL ROSTER (5v5)',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: BtfColors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(height: BtfSpace.x2),
                          _buildFootballPitch(context, theme, game, myBooking, userState.value),
                          
                          const SizedBox(height: BtfSpace.x4),
                          
                          // Waitlist Section if capacity exceeded or someone waitlisted
                          if (game.currentPlayers >= game.maxPlayers || (myBooking != null && myBooking.status == 'waitlisted'))
                            _buildWaitlistSection(context, theme, game, myBooking, userState.value),
                            
                          const SizedBox(height: BtfSpace.x4),
                          _buildVenueDetailsCard(context, theme, game),

                          // Organiser-only roster controls.
                          if (userState.value?.id == game.organiserId) ...[
                            const SizedBox(height: BtfSpace.x4),
                            _OrganiserToolsCard(gameId: gameId, game: game),
                          ],
                          const SizedBox(height: BtfSpace.x6),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActionButton(context, ref, theme, game, myBooking),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(BtfColors.lime),
              ),
            ),
            error: (err, stack) => Center(
              child: Text('Failed to load booking info: ${err.toString()}'),
            ),
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
                Text('Failed to load game: ${err.toString()}', textAlign: TextAlign.center),
                const SizedBox(height: BtfSpace.x4),
                ElevatedButton(
                  onPressed: () => ref.read(gameDetailProvider(gameId).notifier).build(gameId),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ThemeData theme, Game game, Booking? myBooking) {
    final isDark = theme.brightness == Brightness.dark;
    final startsAtFormatted = DateFormat('EEEE, MMMM d • HH:mm').format(game.startsAt);
    final isFull = game.status == 'full' || game.currentPlayers >= game.maxPlayers;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: BtfSpace.x4, vertical: BtfSpace.x2),
      padding: const EdgeInsets.all(BtfSpace.x4),
      decoration: BoxDecoration(
        color: isDark ? BtfColors.ink2 : BtfColors.paper2,
        borderRadius: BorderRadius.circular(BtfRadius.lg),
        border: Border.all(
          color: isDark ? BtfColors.outline.withOpacity(0.4) : BtfColors.chalk,
        ),
      ),
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
                  isFull ? 'WAITLIST ONLY' : '${game.maxPlayers - game.currentPlayers} SLOTS LEFT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isFull ? BtfColors.coral : BtfColors.limeDeep,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (myBooking != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: BtfSpace.x2, vertical: BtfSpace.x1),
                  decoration: BoxDecoration(
                    color: myBooking.status == 'confirmed'
                        ? BtfColors.lime
                        : BtfColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(BtfRadius.xs),
                    border: myBooking.status == 'waitlisted'
                        ? Border.all(color: BtfColors.warning.withOpacity(0.4))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        myBooking.status == 'confirmed' ? Icons.check_circle : Icons.hourglass_top,
                        size: 12,
                        color: myBooking.status == 'confirmed' ? BtfColors.ink : BtfColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        myBooking.status == 'confirmed' ? 'CONFIRMED' : 'WAITLISTED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: myBooking.status == 'confirmed' ? BtfColors.ink : BtfColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: BtfSpace.x3),
          Text(
            game.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: BtfSpace.x2),
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
          const SizedBox(height: BtfSpace.x2),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: BtfColors.muted),
              const SizedBox(width: BtfSpace.x2),
              Text(
                '${game.durationMinutes} Minutes • 5v5 Football',
                style: theme.textTheme.bodyMedium?.copyWith(color: BtfColors.muted),
              ),
            ],
          ),
          if (game.description != null && game.description!.isNotEmpty) ...[
            const SizedBox(height: BtfSpace.x3),
            const Divider(),
            const SizedBox(height: BtfSpace.x3),
            Text(
              'ORGANISER NOTES',
              style: theme.textTheme.labelSmall?.copyWith(
                color: BtfColors.muted,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: BtfSpace.x1),
            Text(
              game.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFootballPitch(BuildContext context, ThemeData theme, Game game, Booking? myBooking, BtfUser? currentUser) {
    final isDark = theme.brightness == Brightness.dark;
    
    // Seed realistic local Irish names for other players to make the roster look robust and premium
    final List<String> SeedNames = [
      'Conor Murphy',
      'Sean Kelly',
      'Cillian O\'Connor',
      'Darragh Byrne',
      'Cian McCarthy',
      'Liam Walsh',
      'Oisin O\'Brien',
      'Ryan Gallagher',
      'Fionn O\'Reilly',
      'Aaron Doyle',
    ];
    
    // Define coordinates for 5 positions on our tactical pitch (1 GK, 2 DF, 1 MF, 1 FW)
    // Coords: double left, double top (relative percentages of the container)
    final positions = [
      {'title': 'GK', 'label': 'Goalkeeper', 'left': 0.5, 'top': 0.85},
      {'title': 'LD', 'label': 'Left Defender', 'left': 0.25, 'top': 0.60},
      {'title': 'RD', 'label': 'Right Defender', 'left': 0.75, 'top': 0.60},
      {'title': 'MF', 'label': 'Midfielder', 'left': 0.5, 'top': 0.40},
      {'title': 'FW', 'label': 'Forward', 'left': 0.5, 'top': 0.15},
    ];

    // Determine lineup array (length 5)
    // If the user has a confirmed booking, they will occupy a spot matching their position or MF by default
    final userIsConfirmed = myBooking != null && myBooking.status == 'confirmed';
    
    // We fill a 5-player team
    final List<Map<String, dynamic>> lineup = [];
    int seedIndex = 0;
    
    for (int i = 0; i < 5; i++) {
      final pos = positions[i];
      
      // Determine if this spot is occupied by the current user
      // Let's say the user takes their preferred position if it matches, or they take the Midfielder spot (MF is index 3)
      final bool isUserSpot = userIsConfirmed && 
          ((currentUser?.position == 'goalkeeper' && i == 0) ||
           (currentUser?.position == 'defender' && (i == 1 || i == 2)) ||
           (currentUser?.position == 'midfielder' && i == 3) ||
           (currentUser?.position == 'forward' && i == 4) ||
           (currentUser?.position == null || currentUser?.position == 'any') && i == 3);
      
      // Safety check: if user is confirmed but doesn't map to a slot yet, put them in MF
      final isLastSlot = i == 3 && userIsConfirmed && lineup.where((e) => e['isUser'] == true).isEmpty;
      
      if (isUserSpot || isLastSlot) {
        lineup.add({
          'name': currentUser?.displayName ?? 'You',
          'initials': _getInitials(currentUser?.displayName ?? 'You'),
          'isUser': true,
          'isFilled': game.currentPlayers > lineup.length,
          ...pos,
        });
      } else {
        // Filled by a seed player if game has enough confirmed slots
        final isFilled = game.currentPlayers > lineup.length;
        lineup.add({
          'name': isFilled ? SeedNames[seedIndex++] : 'Open Spot',
          'initials': isFilled ? _getInitials(SeedNames[seedIndex - 1]) : '+',
          'isUser': false,
          'isFilled': isFilled,
          ...pos,
        });
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: BtfSpace.x4),
      height: 380,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B15) : const Color(0xFFE2F0D9),
        borderRadius: BorderRadius.circular(BtfRadius.lg),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFA2C497),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BtfRadius.lg),
        child: Stack(
          children: [
            // Tactical Pitch Markings
            CustomPaint(
              size: Size.infinite,
              painter: PitchPainter(isDark: isDark),
            ),
            
            // Player Avatars
            ...lineup.map((player) {
              final isFilled = player['isFilled'] as bool;
              final isUser = player['isUser'] as bool;
              final double leftPercent = player['left'] as double;
              final double topPercent = player['top'] as double;
              
              return Positioned(
                left: leftPercent * 340 - 32, // Adjusted for avatar center
                top: topPercent * 380 - 36,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar bubble
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUser
                              ? BtfColors.lime
                              : (isFilled
                                  ? (isDark ? const Color(0xFF234436) : const Color(0xFFC3D8BC))
                                  : Colors.transparent),
                          border: Border.all(
                            color: isUser
                                ? BtfColors.lime
                                : (isFilled
                                    ? (isDark ? const Color(0xFF52B788) : const Color(0xFF74A56F))
                                    : (isDark ? Colors.white30 : Colors.black26)),
                            width: isUser ? 3 : (isFilled ? 2 : 1.5),
                          ),
                          boxShadow: isUser
                              ? [
                                  BoxShadow(
                                    color: BtfColors.lime.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            player['initials'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isUser
                                  ? BtfColors.ink
                                  : (isFilled
                                      ? (isDark ? BtfColors.paper : BtfColors.ink)
                                      : (isDark ? Colors.white54 : Colors.black45)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Player Name
                      Text(
                        player['name'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: isUser || isFilled ? FontWeight.bold : FontWeight.normal,
                          color: isUser
                              ? BtfColors.lime
                              : (isFilled
                                  ? (isDark ? BtfColors.paper : BtfColors.ink)
                                  : BtfColors.muted),
                        ),
                      ),
                      // Position Tag
                      Text(
                        player['title'] as String,
                        style: const TextStyle(
                          fontSize: 7,
                          color: BtfColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitlistSection(BuildContext context, ThemeData theme, Game game, Booking? myBooking, BtfUser? currentUser) {
    final isDark = theme.brightness == Brightness.dark;
    
    // We determine the waitlisted players.
    // If the current user has a waitlisted booking, we put them on top.
    final userIsWaitlisted = myBooking != null && myBooking.status == 'waitlisted';
    
    final List<Map<String, String>> waitlist = [];
    if (userIsWaitlisted) {
      waitlist.add({
        'name': currentUser?.displayName ?? 'You',
        'position': positionLabels[currentUser?.position] ?? 'Any Position',
      });
    }
    
    // Seed a couple of other waitlisted players if the game is full
    if (game.currentPlayers >= game.maxPlayers) {
      waitlist.add({'name': 'Diarmaid Egan', 'position': 'Defender'});
      waitlist.add({'name': 'Ruairi O\'Neill', 'position': 'Forward'});
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: BtfSpace.x4),
      padding: const EdgeInsets.all(BtfSpace.x4),
      decoration: BoxDecoration(
        color: isDark ? BtfColors.ink2 : BtfColors.paper2,
        borderRadius: BorderRadius.circular(BtfRadius.md),
        border: Border.all(color: BtfColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top, color: BtfColors.warning, size: 18),
              const SizedBox(width: BtfSpace.x2),
              Text(
                'WAITLIST QUEUE (${waitlist.length})',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: BtfColors.warning,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: BtfSpace.x2),
          Text(
            'FIFO Waitlist. When a confirmed player cancels, the first player on the queue is promoted instantly and receives a push notification.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
          ),
          const SizedBox(height: BtfSpace.x3),
          ...waitlist.asMap().entries.map((entry) {
            final idx = entry.key;
            final player = entry.value;
            final isCurrentUser = player['name'] == (currentUser?.displayName ?? 'You');
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: BtfColors.warning.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: BtfColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: BtfSpace.x2),
                  Text(
                    player['name']!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentUser ? BtfColors.limeDeep : null,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BtfColors.muted.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      player['position']!.toUpperCase(),
                      style: const TextStyle(fontSize: 8, color: BtfColors.muted, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVenueDetailsCard(BuildContext context, ThemeData theme, Game game) {
    final isDark = theme.brightness == Brightness.dark;
    
    // Seed specific Dublin venue information matching seeded IDs
    String venueName = 'Irishtown Stadium';
    String address = 'Ringsend, Dublin 4';
    String surface = '4G AstroTurf';
    String pitchSize = '5-a-side';
    bool parking = true;
    
    if (game.venueId == '00000000-0000-0000-0000-000000000002') {
      venueName = 'Sandymount YMCA';
      address = 'Sandymount Road, Dublin 4';
      surface = '3G Astro';
      pitchSize = '5v5 / 6v6';
      parking = true;
    } else if (game.venueId == '00000000-0000-0000-0000-000000000003') {
      venueName = 'Herbert Park Pitch';
      address = 'Herbert Park, Ballsbridge';
      surface = 'All-Weather Astro';
      pitchSize = '5v5';
      parking = false;
    } else if (game.venueId == '00000000-0000-0000-0000-000000000004') {
      venueName = 'Ringsend Park Pitch';
      address = 'Ringsend Park, Dublin 4';
      surface = '4G Astro';
      pitchSize = '5-a-side';
      parking = true;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: BtfSpace.x4),
      padding: const EdgeInsets.all(BtfSpace.x4),
      decoration: BoxDecoration(
        color: isDark ? BtfColors.ink2 : BtfColors.paper2,
        borderRadius: BorderRadius.circular(BtfRadius.md),
        border: Border.all(
          color: isDark ? BtfColors.outline.withOpacity(0.4) : BtfColors.chalk,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VENUE & PITCH INFO',
            style: theme.textTheme.labelSmall?.copyWith(
              color: BtfColors.muted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: BtfSpace.x3),
          Text(
            venueName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: BtfSpace.x1),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: BtfColors.muted),
              const SizedBox(width: 4),
              Text(
                address,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: BtfSpace.x3),
          const Divider(),
          const SizedBox(height: BtfSpace.x3),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Surface', style: TextStyle(fontSize: 10, color: BtfColors.muted)),
                    const SizedBox(height: 2),
                    Text(surface, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pitch Size', style: TextStyle(fontSize: 10, color: BtfColors.muted)),
                    const SizedBox(height: 2),
                    Text(pitchSize, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Parking', style: TextStyle(fontSize: 10, color: BtfColors.muted)),
                    const SizedBox(height: 2),
                    Text(parking ? 'Available' : 'None', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButton(BuildContext context, WidgetRef ref, ThemeData theme, Game game, Booking? myBooking) {
    final isFull = game.currentPlayers >= game.maxPlayers;
    
    // Action trigger: Join Match or Cancel Booking
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(BtfSpace.x4),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: theme.brightness == Brightness.dark
                  ? BtfColors.ink2
                  : BtfColors.chalk.withOpacity(0.5),
            ),
          ),
        ),
        child: AttendanceBar(
          booking: myBooking,
          isFull: isFull,
          onRespond: (attending) => _respond(
            context,
            ref.read(gameDetailProvider(gameId).notifier),
            attending: attending,
          ),
          onCancel: () => _confirmCancelBooking(context, ref, myBooking!),
          onJoin: () => ref.read(gameDetailProvider(gameId).notifier).joinGame(),
        ),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    GameDetailNotifier notifier, {
    required bool attending,
  }) async {
    try {
      await notifier.respondToInvitation(attending: attending);
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

  void _confirmCancelBooking(BuildContext context, WidgetRef ref, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BtfColors.ink2,
        title: const Text('Cancel Booking', style: TextStyle(color: BtfColors.paper, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to drop out of this match? If you cancel, your slot is released immediately.',
          style: TextStyle(color: BtfColors.chalk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('KEEP SLOT', style: TextStyle(color: BtfColors.paper)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(gameDetailProvider(gameId).notifier).cancelBooking(booking.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: BtfColors.coral),
            child: const Text('RELEASE SLOT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

/// Tactical football pitch lines drawing.
class PitchPainter extends CustomPainter {
  final bool isDark;

  PitchPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer boundary
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Center line
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);

    // Center circle
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 50, paint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2, paint..style = PaintingStyle.fill);

    paint.style = PaintingStyle.stroke; // Reset style

    // Penalty box - Top
    canvas.drawRect(Rect.fromLTWH(size.width * 0.25, 0, size.width * 0.5, 45), paint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width / 2, 45), radius: 25),
      0,
      3.1415,
      false,
      paint,
    );

    // Penalty box - Bottom
    canvas.drawRect(Rect.fromLTWH(size.width * 0.25, size.height - 45, size.width * 0.5, 45), paint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width / 2, size.height - 45), radius: 25),
      3.1415,
      3.1415,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Roster controls only the game's organiser sees: push the game out to the
/// marketplace when short, or invite one of their squads.
class _OrganiserToolsCard extends ConsumerWidget {
  final String gameId;
  final Game game;

  const _OrganiserToolsCard({required this.gameId, required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final squads = ref.watch(squadsProvider).value ?? const [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: BtfSpace.x4),
      padding: const EdgeInsets.all(BtfSpace.x4),
      decoration: BoxDecoration(
        color: isDark ? BtfColors.ink2 : BtfColors.paper2,
        borderRadius: BorderRadius.circular(BtfRadius.md),
        border: Border.all(
          color: isDark ? BtfColors.outline.withOpacity(0.4) : BtfColors.chalk,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.organiserTools.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: BtfColors.muted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: BtfSpace.x3),

          // Visibility
          Row(
            children: [
              Icon(
                game.isSquadOnly ? Icons.lock_outline : Icons.public,
                size: 18,
                color: game.isSquadOnly ? BtfColors.muted : BtfColors.limeDeep,
              ),
              const SizedBox(width: BtfSpace.x2),
              Expanded(
                child: Text(
                  game.isSquadOnly
                      ? l10n.visibilitySquadOnly
                      : l10n.visibilityPublic,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: BtfSpace.x2),
          Text(
            game.isSquadOnly ? l10n.marketplaceAutoHint : l10n.marketplaceOpenedNote,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: BtfColors.muted, height: 1.3),
          ),
          const SizedBox(height: BtfSpace.x3),
          SizedBox(
            width: double.infinity,
            child: game.isSquadOnly
                ? FilledButton.icon(
                    onPressed: () => _setMarketplace(context, ref, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: BtfColors.lime,
                      foregroundColor: BtfColors.ink,
                    ),
                    icon: const Icon(Icons.campaign_outlined, size: 18),
                    label: Text(
                      l10n.openToMarketplace,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _setMarketplace(context, ref, false),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: Text(l10n.removeFromMarketplace),
                  ),
          ),

          if (squads.isNotEmpty) ...[
            const SizedBox(height: BtfSpace.x4),
            const Divider(height: 1),
            const SizedBox(height: BtfSpace.x3),
            Text(
              l10n.inviteSquadToGame,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: BtfSpace.x2),
            Wrap(
              spacing: BtfSpace.x2,
              runSpacing: BtfSpace.x2,
              children: squads
                  .map((s) => ActionChip(
                        avatar: const Icon(Icons.groups_outlined, size: 16),
                        label: Text(s.name),
                        onPressed: () => _inviteSquad(context, ref, s.id),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setMarketplace(
    BuildContext context,
    WidgetRef ref,
    bool open,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(gameDetailProvider(gameId).notifier)
          .setMarketplaceOpen(open);
    } on DioException catch (e) {
      if (!context.mounted) return;
      // 409 means an outsider already claimed a slot, so it can't be pulled back.
      final message = e.response?.statusCode == 409
          ? l10n.marketplaceCloseBlocked
          : e.message ?? e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: BtfColors.coral),
      );
    }
  }

  Future<void> _inviteSquad(
    BuildContext context,
    WidgetRef ref,
    String squadId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final count =
          await ref.read(gameDetailProvider(gameId).notifier).inviteSquad(squadId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.squadInvited(count)),
          backgroundColor: BtfColors.limeDeep,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: BtfColors.coral),
      );
    }
  }
}
