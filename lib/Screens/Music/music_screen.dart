import 'package:flutter/material.dart';

/// Music tab — shows a styled playlist/song browsing UI.
/// Tapping any playlist or song reveals a "Coming Soon" message.
class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _card = Color(0xFF1A1A1A);
  static const Color _border = Color(0xFF2A2A2A);
  static const Color _accent = Color(0xFFFF3D00);
  static const Color _muted = Color(0xFF888888);

  static const List<_Playlist> _playlists = [
    _Playlist(
      title: 'Beast Mode',
      subtitle: '42 tracks • Heavy lifting',
      gradient: [Color(0xFFFF3D00), Color(0xFFFF6B00)],
      icon: Icons.fitness_center_rounded,
    ),
    _Playlist(
      title: 'HIIT Pump',
      subtitle: '28 tracks • High intensity',
      gradient: [Color(0xFFE91E63), Color(0xFF9C27B0)],
      icon: Icons.bolt_rounded,
    ),
    _Playlist(
      title: 'Cardio Burn',
      subtitle: '35 tracks • Run & ride',
      gradient: [Color(0xFF2196F3), Color(0xFF00BCD4)],
      icon: Icons.directions_run_rounded,
    ),
    _Playlist(
      title: 'Recovery Vibes',
      subtitle: '24 tracks • Cool down',
      gradient: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
      icon: Icons.spa_rounded,
    ),
    _Playlist(
      title: 'Focus Flow',
      subtitle: '50 tracks • Stay locked in',
      gradient: [Color(0xFF673AB7), Color(0xFF3F51B5)],
      icon: Icons.headphones_rounded,
    ),
  ];

  static const List<_Song> _songs = [
    _Song(title: 'Adrenaline Rush', artist: 'Iron Pulse', duration: '3:42'),
    _Song(title: 'Heavy Hitter', artist: 'Reps & Bass', duration: '4:18'),
    _Song(title: 'Push Through', artist: 'Cardio Kings', duration: '3:05'),
    _Song(title: 'Peak Performance', artist: 'Beat Squad', duration: '4:30'),
    _Song(title: 'No Days Off', artist: 'Grind Mode', duration: '3:55'),
    _Song(title: 'Stronger Every Set', artist: 'PR Hunters', duration: '3:21'),
  ];

  void _showComingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.rocket_launch_rounded,
                color: _accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"$name" — Coming Soon!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _card,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _border, width: 1),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          'Music',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () => _showComingSoon(context, 'Search'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            // ── Featured / Hero card ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => _showComingSoon(context, 'Featured Mix'),
                child: Container(
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF3D00), Color(0xFF7C2D00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 130,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'FEATURED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Today\'s Power Mix',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Hand-picked for your next session',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Section: Workout Playlists ─────────────────────────────────
            const _SectionHeader(title: 'Workout Playlists'),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _playlists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final p = _playlists[index];
                  return _PlaylistCard(
                    playlist: p,
                    onTap: () => _showComingSoon(context, p.title),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // ── Section: Recommended Songs ─────────────────────────────────
            const _SectionHeader(title: 'Recommended Songs'),
            const SizedBox(height: 8),
            ..._songs.asMap().entries.map((entry) {
              final song = entry.value;
              return _SongTile(
                song: song,
                onTap: () => _showComingSoon(context, song.title),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _Playlist {
  const _Playlist({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
}

class _Song {
  const _Song({
    required this.title,
    required this.artist,
    required this.duration,
  });

  final String title;
  final String artist;
  final String duration;
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, required this.onTap});

  final _Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 150,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: playlist.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -8,
                    bottom: -8,
                    child: Icon(
                      playlist.icon,
                      size: 90,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF0A0A0A),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                playlist.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                playlist.subtitle,
                style: const TextStyle(
                  color: MusicScreen._muted,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, required this.onTap});

  final _Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Album-art placeholder
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: MusicScreen._border, width: 1),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: MusicScreen._accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    style: const TextStyle(
                      color: MusicScreen._muted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              song.duration,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: MusicScreen._muted,
                size: 20,
              ),
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
