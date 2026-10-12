import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/services/spotify_catalog_service.dart';
import 'package:kreate_ios/ui/theme/app_ambience.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/app_cover.dart';

import 'desk.dart';
import 'desk_collection.dart';

/// The pictures of the computer app: covers drawn for what has none, the
/// large blurred backdrops, and the cards that are more picture than text.

/// A cover: the picture at [url], or one drawn from [seed] (the name of the
/// thing) for what has no picture: two colors of its own and its initial,
/// so that two playlists without a cover do not look the same.
class DeskCover extends StatelessWidget {
  const DeskCover({
    super.key,
    required this.url,
    required this.seed,
    required this.size,
    this.round = false,
    this.radius = 0,
  });

  final String? url;
  final String seed;
  final double size;
  final bool round;
  final double radius;

  static const List<(Color, Color)> _pairs = [
    (Color(0xFF7B2FF7), Color(0xFFF107A3)),
    (Color(0xFF0F9B8E), Color(0xFF1D4ED8)),
    (Color(0xFFF97316), Color(0xFFDB2777)),
    (Color(0xFF16A34A), Color(0xFF0E7490)),
    (Color(0xFFDC2626), Color(0xFF7C2D12)),
    (Color(0xFF2563EB), Color(0xFF7C3AED)),
    (Color(0xFFCA8A04), Color(0xFFB91C1C)),
    (Color(0xFF0891B2), Color(0xFF4F46E5)),
  ];

  static (Color, Color) colorsOf(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _pairs[hash % _pairs.length];
  }

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url != null && url.isNotEmpty) {
      return AppCover(url: url, size: size, radius: radius, circle: round);
    }
    final (from, to) = colorsOf(seed);
    final letter = seed.trim().isEmpty ? '♪' : seed.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.46,
          fontWeight: FontWeight.w900,
          height: 1,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

/// A picture spread large and out of focus behind what is said about it,
/// darkening into the panel towards the foot.
class DeskBackdrop extends StatelessWidget {
  const DeskBackdrop({super.key, required this.url, required this.fallback, this.blur = 42});

  final String? url;
  final Color fallback;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: fallback),
        if (url != null && url.isNotEmpty)
          ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                fadeInDuration: const Duration(milliseconds: 250),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x59000000), Color(0xB3000000), Desk.panel],
              stops: [0, 0.62, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// A wide card in the colors of its picture: the picture at the left, what
/// it is beside it, and a play button under the mouse. For the things the
/// Home puts forward (the charts).
class DeskFeatureCard extends StatelessWidget {
  const DeskFeatureCard({
    super.key,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.onOpen,
  });

  final String label;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final VoidCallback onOpen;

  static const double height = 132;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AmbientTint(
      artworkUrl: coverUrl,
      fallback: cs.primary,
      builder: (context, palette) => Hover(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => GestureDetector(
          onTap: onOpen,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color.lerp(palette.surface, Colors.white, hovered ? 0.1 : 0.03)!,
                  Color.lerp(palette.deep, Desk.panel, 0.35)!,
                ],
              ),
            ),
            child: Row(
              children: [
                DeskCover(url: coverUrl, seed: title, size: height),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, height: 1.3, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.arrow_forward_rounded, size: 22, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card of a mix: the artist's picture under a veil of one color, with
/// the name written large on it.
class DeskMixCard extends StatelessWidget {
  const DeskMixCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.index,
    required this.onOpen,
  });

  final String name;
  final String? imageUrl;
  final int index;
  final VoidCallback onOpen;

  static const List<Color> _veils = [
    Color(0xFF1DB954),
    Color(0xFFE8115B),
    Color(0xFF2D46B9),
    Color(0xFFE1118C),
    Color(0xFFBC5900),
    Color(0xFF148A08),
    Color(0xFF8D67AB),
    Color(0xFF0D73EC),
  ];

  @override
  Widget build(BuildContext context) {
    final veil = _veils[index % _veils.length];
    return Hover(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedScale(
              scale: hovered ? 1.025 : 1,
              duration: const Duration(milliseconds: 140),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: veil,
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6)),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [veil.withValues(alpha: 0.08), veil.withValues(alpha: 0.94)],
                          stops: const [0.35, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'MIX',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.02,
                          letterSpacing: -0.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A genre as a block of its color, its name large and its picture tilted
/// in the corner.
class DeskGenreTile extends StatelessWidget {
  const DeskGenreTile({super.key, required this.genre, required this.width, this.height = 118});

  final SpotifyCategoryItem genre;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: () => DeskCollectionPage.openEditorial(
        id: genre.playlistId,
        title: genre.title,
        coverUrl: genre.coverUrl.isEmpty ? null : genre.coverUrl,
      ),
      child: AnimatedScale(
        scale: hovered ? 1.025 : 1,
        duration: const Duration(milliseconds: 140),
        child: Container(
          width: width,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [genre.color, Color.lerp(genre.color, Colors.black, 0.35)!],
            ),
          ),
          child: Stack(
            children: [
              if (genre.coverUrl.isNotEmpty)
                Positioned(
                  right: -16,
                  bottom: -8,
                  child: Transform.rotate(
                    angle: 0.42,
                    child: Container(
                      decoration: const BoxDecoration(
                        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 10)],
                      ),
                      child: AppCover(url: genre.coverUrl, size: height * 0.74),
                    ),
                  ),
                )
              else
                Positioned(
                  right: 6,
                  bottom: 0,
                  child: Icon(AppIcons.note, size: height * 0.6, color: Colors.white24),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  genre.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
