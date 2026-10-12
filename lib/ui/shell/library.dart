import 'package:flutter/material.dart';
import 'package:kreate_ios/services/storage_service.dart';

import '../app.dart';
import '../kit.dart';
import '../menus.dart';
import '../pages/artist.dart';
import '../pages/collection.dart';

/// The library, always at the left of the window: the liked songs pinned
/// at the top, then the playlists and the followed artists, a click away
/// from any page. It folds down to its covers.
class LibraryPanel extends StatefulWidget {
  const LibraryPanel({super.key, this.narrow = false});

  /// The window has no room for it open: it stays folded.
  final bool narrow;

  static const double width = 320;
  static const double foldedWidth = 72;

  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<LibraryPanel> {
  /// 'playlist', 'artisti', or null for everything.
  String? _kind;

  /// What is typed to find something in the library; null while the field
  /// is closed.
  String? _filter;

  Future<void> _create(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final choice = await openMenu(context, box.localToGlobal(Offset(0, box.size.height + 4)), [
      menuItem('new', Ic.playlist, 'Crea una nuova playlist'),
      menuItem('import', Ic.link, 'Importa playlist da un link'),
    ]);
    if (!context.mounted) return;
    if (choice == 'new') {
      await createPlaylist(context);
    } else if (choice == 'import') {
      await importPlaylist(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final storage = StorageService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: App.libraryFolded,
      builder: (context, chosen, _) => _panel(context, chosen || widget.narrow, accent, storage),
    );
  }

  Widget _panel(BuildContext context, bool folded, Color accent, StorageService storage) {
    return Container(
      width: folded ? LibraryPanel.foldedWidth : LibraryPanel.width,
      decoration: BoxDecoration(color: Tk.panel, borderRadius: BorderRadius.circular(Tk.radius)),
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          storage.playlistsNotifier,
          storage.favoritesNotifier,
          storage.followedArtistsNotifier,
          storage.libraryOwnerNotifier,
        ]),
        builder: (context, _) {
          final wanted = (_filter ?? '').trim().toLowerCase();
          bool matches(String name) => wanted.isEmpty || name.toLowerCase().contains(wanted);
          final liked = storage.favoritesNotifier.value.length;
          final items = <_Item>[
            if (_kind != 'artisti') ...[
              if (matches('Brani che ti piacciono'))
                _Item(
                  title: 'Brani che ti piacciono',
                  subtitle: 'Playlist • ${App.songs(liked)}',
                  pinned: true,
                  art: const LikedArt(size: 48),
                  onOpen: CollectionPage.openLiked,
                ),
              for (final playlist in App.playlists())
                if (matches(playlist.title))
                  _Item(
                    title: playlist.title,
                    subtitle: 'Playlist • ${App.owner(playlist.id)}',
                    art: Artwork(url: App.coverOf(playlist), seed: playlist.title, size: 48),
                    onOpen: () => CollectionPage.openPlaylist(playlist.id),
                    onMenu: (at) => playlistMenu(context, at, playlist),
                  ),
            ],
            if (_kind != 'playlist')
              for (final artist in storage.followedArtistsNotifier.value)
                if (matches(artist.name))
                  _Item(
                    title: artist.name,
                    subtitle: 'Artista',
                    art: Artwork(url: artist.imageUrl, seed: artist.name, size: 48, round: true),
                    onOpen: () => App.nav.open(ArtistPage(artist: artist)),
                  ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Its name, and what makes something new ──────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(folded ? 0 : 12, 10, folded ? 0 : 12, 4),
                child: Row(
                  mainAxisAlignment: folded ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: folded ? 'Espandi la tua libreria' : 'Comprimi la tua libreria',
                      child: Hover(
                        cursor: SystemMouseCursors.click,
                        builder: (context, hovered) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => App.libraryFolded.value = !folded,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  folded ? Ic.library : Ic.libraryOn,
                                  size: 24,
                                  color: hovered ? Tk.text : Tk.subdued,
                                ),
                                if (!folded) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    'La tua libreria',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: hovered ? Tk.text : Tk.subdued,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!folded) ...[
                      const Spacer(),
                      Builder(
                        builder: (context) => Tooltip(
                          message: 'Crea una playlist',
                          child: Hover(
                            cursor: SystemMouseCursors.click,
                            builder: (context, hovered) => GestureDetector(
                              onTap: () => _create(context),
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: hovered ? Tk.hover : Tk.raised,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Ic.plus, size: 14, color: Tk.text),
                                    SizedBox(width: 7),
                                    Text('Crea', style: Tk.label),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!folded) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Row(
                    children: [
                      Pill(
                        'Playlist',
                        selected: _kind == 'playlist',
                        onTap: () =>
                            setState(() => _kind = _kind == 'playlist' ? null : 'playlist'),
                      ),
                      const SizedBox(width: 8),
                      Pill(
                        'Artisti',
                        selected: _kind == 'artisti',
                        onTap: () => setState(() => _kind = _kind == 'artisti' ? null : 'artisti'),
                      ),
                    ],
                  ),
                ),
                // ── A way to find something in it ─────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 16, 4),
                  child: SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        IconBtn(
                          Ic.search,
                          tip: 'Cerca nella tua libreria',
                          size: 17,
                          on: _filter != null,
                          onTap: () => setState(() => _filter = _filter == null ? '' : null),
                        ),
                        if (_filter != null)
                          Expanded(
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: Tk.hover,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextField(
                                autofocus: true,
                                onChanged: (text) => setState(() => _filter = text),
                                style: const TextStyle(fontSize: 13.5, color: Tk.text),
                                decoration: const InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: 'Cerca nella tua libreria',
                                  hintStyle: TextStyle(fontSize: 13.5, color: Tk.faint),
                                ),
                              ),
                            ),
                          )
                        else ...[
                          const Spacer(),
                          const Text(
                            'Recenti',
                            style: TextStyle(fontSize: 13.5, color: Tk.subdued),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // ── What is in it ───────────────────────────────────────────
              Expanded(
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          wanted.isNotEmpty
                              ? 'Nessun risultato per "${_filter!.trim()}" nella tua libreria.'
                              : 'Segui il tuo primo artista: lo trovi qui.',
                          style: const TextStyle(fontSize: 13.5, height: 1.45, color: Tk.subdued),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemExtent: 64,
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _Entry(item: items[index], folded: folded, accent: accent),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Item {
  const _Item({
    required this.title,
    required this.subtitle,
    required this.art,
    required this.onOpen,
    this.onMenu,
    this.pinned = false,
  });

  final String title;
  final String subtitle;
  final Widget art;
  final VoidCallback onOpen;
  final void Function(Offset at)? onMenu;
  final bool pinned;
}

class _Entry extends StatelessWidget {
  const _Entry({required this.item, required this.folded, required this.accent});

  final _Item item;
  final bool folded;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final row = Hover(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.onOpen,
        onSecondaryTapUp: item.onMenu == null
            ? null
            : (details) => item.onMenu!(details.globalPosition),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: folded ? 4 : 8, vertical: 8),
          decoration: BoxDecoration(
            color: hovered ? Tk.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: folded ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              SizedBox(width: 48, height: 48, child: item.art),
              if (!folded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, color: Tk.text),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (item.pinned) ...[
                            Icon(Ic.pin, size: 13, color: accent),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Tk.subdued),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return folded ? Tooltip(message: '${item.title}\n${item.subtitle}', child: row) : row;
  }
}
