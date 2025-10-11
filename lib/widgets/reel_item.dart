// lib/widgets/reel_item.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelItem extends StatelessWidget {
  final Map<String, dynamic> video;
  final VideoPlayerController? controller;
  final bool isActive;
  final void Function(Map<String, dynamic>) onTapProfile;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const ReelItem({
    super.key,
    required this.video,
    required this.controller,
    required this.isActive,
    required this.onTapProfile,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final uploader = (video['uploader'] as Map<String, dynamic>?) ?? {};
    final username = '${uploader['name'] ?? 'Unknown'}';
    final avatar = '${uploader['avatar'] ?? ''}';
    final title = '${video['title'] ?? ''}';
    final description = '${video['description'] ?? ''}';
    final likesCount = _asInt(video['likes_count'] ?? video['likesCount']);
    final viewsCount = _asInt(video['views_count'] ?? video['viewsCount']);
    final url = '${video['url'] ?? ''}';
    final thumb = '${video['thumbnail_url'] ?? ''}';

    // Combine title + description for caption
    final caption = [
      if (title.trim().isNotEmpty) title.trim(),
      if (description.trim().isNotEmpty) description.trim(),
    ].join('\n');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player or thumbnail
        if (controller != null && controller!.value.isInitialized)
          GestureDetector(
            onTap: () {
              if (controller!.value.isPlaying) {
                controller!.pause();
              } else {
                controller!.play();
              }
            },
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller!.value.size.height,
                child: VideoPlayer(controller!),
              ),
            ),
          )
        else
        // Thumbnail fallback
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              image: thumb.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(thumb),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

        // Gradient overlays for readability
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),

        // Bottom-left: Profile + Caption
        Positioned(
          bottom: 80,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile row
              GestureDetector(
                onTap: () => onTapProfile(uploader),
                child: Row(
                  children: [
                    _AvatarCircle(name: username, avatarUrl: avatar, size: 36),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Bottom-right: Action buttons (like, comment, share)
        Positioned(
          bottom: 80,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: Icons.favorite_border,
                label: _formatCount(likesCount),
                onTap: onLike,
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: _formatCount(viewsCount),
                onTap: onComment,
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.send_outlined,
                label: '',
                onTap: onShare,
              ),
            ],
          ),
        ),

        // Play/Pause indicator (center, subtle)
        if (controller != null && controller!.value.isInitialized)
          Center(
            child: AnimatedOpacity(
              opacity: controller!.value.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _asInt(dynamic x) {
    if (x == null) return 0;
    if (x is int) return x;
    if (x is num) return x.toInt();
    return int.tryParse('$x') ?? 0;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/* ------------------------------ action button ------------------------------ */

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ------------------------------ avatar helper ------------------------------ */

class _AvatarCircle extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final double size;

  const _AvatarCircle({
    required this.name,
    required this.avatarUrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final initials = () {
      final n = name.trim();
      if (n.isEmpty) return 'U';
      final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      return parts.length >= 2
          ? (parts.first[0] + parts.last[0]).toUpperCase()
          : n[0].toUpperCase();
    }();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        color: Colors.grey.shade800,
        image: avatarUrl.isNotEmpty
            ? DecorationImage(
          image: NetworkImage(avatarUrl),
          fit: BoxFit.cover,
        )
            : null,
      ),
      alignment: Alignment.center,
      child: avatarUrl.isEmpty
          ? Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      )
          : null,
    );
  }
}