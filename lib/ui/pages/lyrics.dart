import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/models/lyrics_model.dart';
import 'package:kreate_ios/services/lyrics_service.dart';
import 'package:kreate_ios/ui/theme/app_ambience.dart';

import '../app.dart';
import '../kit.dart';

/// The text of the song that is playing, over the whole main view, on the
/// color of its cover: the line being sung is white, and a click on a line
/// goes there.
class LyricsPage extends StatefulWidget {
  const LyricsPage({super.key});

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  StreamSubscription<MediaItem?>? _songs;
  String? _songId;
  Lyrics? _lyrics;
  bool _loading = false;
  int _line = -1;
  final List<GlobalKey> _keys = [];

  @override
  void initState() {
    super.initState();
    _songs = App.player.mediaItem.listen((_) => _load());
    App.player.positionNotifier.addListener(_follow);
    _load();
  }

  @override
  void dispose() {
    _songs?.cancel();
    App.player.positionNotifier.removeListener(_follow);
    super.dispose();
  }

  Future<void> _load() async {
    final song = App.player.currentSong;
    if (song?.id == _songId) return;
    _songId = song?.id;
    _keys.clear();
    setState(() {
      _lyrics = null;
      _line = -1;
      _loading = song != null;
    });
    if (song == null) return;
    Lyrics lyrics;
    try {
      lyrics = await LyricsService.instance.getLyrics(song);
    } catch (e) {
      debugPrint('LyricsPage._load: $e');
      lyrics = Lyrics.empty;
    }
    if (!mounted || _songId != song.id) return;
    _keys.addAll([for (final _ in lyrics.syncedLyrics) GlobalKey()]);
    setState(() {
      _lyrics = lyrics;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _follow(again: true);
    });
  }

  /// The line being sung is lit, and kept in sight.
  void _follow({bool again = false}) {
    final lines = _lyrics?.syncedLyrics ?? const <LyricLine>[];
    if (lines.isEmpty) return;
    final position = App.player.positionNotifier.value;
    var line = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time > position) break;
      line = i;
    }
    if (line == _line && !again) return;
    if (line != _line) setState(() => _line = line);
    final target = line >= 0 && line < _keys.length ? _keys[line].currentContext : null;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.38,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _text() {
    if (_songId == null) {
      return const Notice(
        icon: Ic.lyrics,
        title: 'Riproduci un brano per vederne il testo',
        text: 'Il testo scorre qui a tempo con la musica.',
      );
    }
    if (_loading) return const Notice();
    final lyrics = _lyrics;
    if (lyrics == null || lyrics.isEmpty) {
      return const Notice(
        icon: Ic.lyrics,
        title: 'Il testo di questo brano non è disponibile',
        text: 'Non lo abbiamo ancora trovato. Riprova più tardi.',
      );
    }
    final synced = lyrics.syncedLyrics;
    if (synced.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(64, 56, 64, 80),
        child: SelectableText(
          lyrics.plainLyrics,
          style: const TextStyle(
            fontSize: 26,
            height: 1.55,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Tk.text,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(64, 56, 64, 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, line) in synced.indexed)
            Hover(
              key: index < _keys.length ? _keys[index] : null,
              cursor: SystemMouseCursors.click,
              builder: (context, hovered) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => App.player.seek(line.time),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    line.text.isEmpty ? '♪' : line.text,
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: index == _line || hovered
                          ? Tk.text
                          : (index < _line ? const Color(0x99FFFFFF) : const Color(0xB3000000)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return StreamBuilder<MediaItem?>(
      stream: App.player.mediaItem,
      initialData: App.player.mediaItem.value,
      builder: (context, snapshot) => AmbientTint(
        artworkUrl: snapshot.data?.artUri?.toString(),
        fallback: accent,
        builder: (context, palette) => AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          color: Color.lerp(palette.accent, palette.surface, 0.62),
          child: _text(),
        ),
      ),
    );
  }
}
