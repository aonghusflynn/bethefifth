import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/user_provider.dart';
import '../../models/user.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String? _preferredPosition;
  int _skillLevel = 3;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    // Initialize form values from user data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProvider).value;
      if (user != null) {
        _nameController.text = user.displayName ?? '';
        setState(() {
          _preferredPosition = user.position ?? 'any';
          _skillLevel = user.skillLevel;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(userProvider.notifier).updateProfile(
            displayName: _nameController.text.trim(),
            position: _preferredPosition,
            skillLevel: _skillLevel,
          );
      
      setState(() {
        _hasUnsavedChanges = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player profile saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final userState = ref.watch(userProvider);
    final bookedGamesState = ref.watch(userBookedGamesProvider);

    return Scaffold(
      backgroundColor: isDark ? BtfColors.ink : BtfColors.paper,
      appBar: AppBar(
        title: const Text('PLAYER PROFILE'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_hasUnsavedChanges) {
              _showDiscardDialog();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (_hasUnsavedChanges)
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: Text(
                'SAVE',
                style: TextStyle(
                  color: isDark ? BtfColors.lime : BtfColors.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: userState.when(
        data: (user) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No player session active.'),
                  const SizedBox(height: BtfSpace.x3),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Back to Login'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(BtfSpace.x4),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Profile Header & Avatar
                  _buildProfileHeader(theme, user),
                  const SizedBox(height: BtfSpace.x4),

                  // Statistics Section
                  _buildStatsRow(theme, user, bookedGamesState.value?.length ?? 0),
                  const SizedBox(height: BtfSpace.x5),

                  // Edit Fields
                  _buildFormFields(theme, user),
                  const SizedBox(height: BtfSpace.x5),

                  // Action Buttons
                  _buildActionButtons(theme),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(BtfColors.lime),
          ),
        ),
        error: (err, stack) => Center(
          child: Text('Error loading profile: ${err.toString()}'),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, BtfUser user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: BtfColors.ink2,
          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
          child: user.photoUrl == null
              ? const Icon(Icons.person, size: 55, color: BtfColors.lime)
              : null,
        ),
        const SizedBox(height: BtfSpace.x3),
        Text(
          user.displayName ?? 'Pitch Player',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          user.email ?? 'no-email@example.com',
          style: theme.textTheme.bodyMedium?.copyWith(color: BtfColors.muted),
        ),
      ],
    );
  }

  Widget _buildStatsRow(ThemeData theme, BtfUser user, int matchesCount) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      children: [
        // Reliability Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? BtfColors.ink2 : BtfColors.paper2,
              borderRadius: BorderRadius.circular(BtfRadius.md),
              border: Border.all(
                color: isDark ? BtfColors.outline.withOpacity(0.3) : BtfColors.chalk,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 14, color: BtfColors.lime),
                    const SizedBox(width: 4),
                    Text(
                      'RELIABILITY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: BtfColors.muted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${(user.reliabilityScore * 20).toInt()}%',
                  style: BtfText.mono(
                    size: 24,
                    color: BtfColors.limeDeep,
                    letterSpacing: 0,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Free tier standard',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: BtfSpace.x3),
        
        // Matches Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? BtfColors.ink2 : BtfColors.paper2,
              borderRadius: BorderRadius.circular(BtfRadius.md),
              border: Border.all(
                color: isDark ? BtfColors.outline.withOpacity(0.3) : BtfColors.chalk,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sports_soccer_outlined, size: 14, color: BtfColors.lime),
                    const SizedBox(width: 4),
                    Text(
                      'BOOKINGS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: BtfColors.muted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$matchesCount',
                  style: BtfText.mono(
                    size: 24,
                    color: BtfColors.paper,
                    letterSpacing: 0,
                  ).copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : BtfColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Active / Seeded Matches',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields(ThemeData theme, BtfUser user) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLAYER PROFILE SETTINGS',
          style: theme.textTheme.labelSmall?.copyWith(
            color: BtfColors.muted,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: BtfSpace.x3),
        
        // Display Name
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          onChanged: (_) => _markChanged(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name cannot be blank';
            }
            return null;
          },
        ),
        const SizedBox(height: BtfSpace.x4),

        // Preferred Position Selector
        DropdownButtonFormField<String>(
          value: _preferredPosition,
          decoration: const InputDecoration(
            labelText: 'Preferred Position',
            prefixIcon: Icon(Icons.directions_run_outlined),
          ),
          dropdownColor: isDark ? BtfColors.ink2 : BtfColors.paper,
          items: positionLabels.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _preferredPosition = val;
              });
              _markChanged();
            }
          },
        ),
        const SizedBox(height: BtfSpace.x4),

        // Skill Level Selector
        Text(
          'YOUR SKILL LEVEL',
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
                _markChanged();
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
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        if (_hasUnsavedChanges) ...[
          const SizedBox(height: BtfSpace.x3),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(BtfColors.ink),
                      ),
                    )
                  : const Text('SAVE PROFILE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        const SizedBox(height: BtfSpace.x5),
        const Divider(),
        const SizedBox(height: BtfSpace.x5),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmSignOut(),
            icon: const Icon(Icons.logout, color: BtfColors.coral),
            style: OutlinedButton.styleFrom(
              foregroundColor: BtfColors.coral,
              side: const BorderSide(color: BtfColors.coral, width: 1.5),
            ),
            label: const Text('SIGN OUT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: BtfSpace.x6),
      ],
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BtfColors.ink2,
        title: const Text('Unsaved Changes', style: TextStyle(color: BtfColors.paper, fontWeight: FontWeight.bold)),
        content: const Text(
          'You have unsaved changes on your profile. Do you want to discard them?',
          style: TextStyle(color: BtfColors.chalk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('KEEP EDITING', style: TextStyle(color: BtfColors.paper)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: BtfColors.coral),
            child: const Text('DISCARD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BtfColors.ink2,
        title: const Text('Sign Out', style: TextStyle(color: BtfColors.paper, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of BeTheFifth?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: BtfColors.paper)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(userProvider.notifier).logout();
              if (mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: BtfColors.coral),
            child: const Text('SIGN OUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
