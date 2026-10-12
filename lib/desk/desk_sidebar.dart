import 'package:flutter/material.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/song_options_sheet.dart' show playlistCoverUrl;

import 'desk.dart';
import 'desk_art.dart';
import 'desk_artist.dart';
import 'desk_collection.dart';
import 'desk_menus.dart';
import 'desk_widgets.dart';

/// The library, always at the left of the window: the liked songs, the
/// playlists and the followed artists, a click away from any page. It
/// folds down to its covers alone.
class DeskSidebar extends StatefulWidget {
  const DeskSidebar({super.key});

  static const double width = 300;
  static const double collapsedWidth = 72;

  @override
  State<DeskSidebar> createState() => _DeskSidebarState();
}

class _DeskSidebarState extends State<DeskSidebar> {
  /// 'playlist', 'artisti', or null for everything.
  String? _filter;

  void _add(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final choice = await deskMenu<String>(context, box.localToGlobal(Offset(0, box.size.height)), [
      const PopupMenuItem(
        value: 'new',
        height: 40,
        child: Text('Nuova playlist', style: TextStyle(fontSize: 13.5)),
      ),
      const PopupMenuItem(
        value: 'import',
        height: 40,
        child: Text('Importa da un link', style: TextStyle(fontSize: 13.5)),
      ),
    ]);
    if (!context.mounted) return;
    if (choice == 'new') {
      await deskCreatePlaylist(context);
    } else if (choice == 'import') {
      await deskImportPlaylist(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: Desk.libraryCollapsed,
      builder: (context, collapsed, _) => Container(
        width: collapsed ? DeskSidebar.collapsedWidth : DeskSidebar.width,
        decoration: BoxDecoration(
          color: Desk.panel,
          borderRadius: BorderRadius.circular(Desk.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            storage.playlistsNotifier,
            storage.favoritesNotifier,
            storage.followedArtistsNotifier,
            storage.libraryOwnerNotifier,
          ]),
          builder: (context, _) {
            final showPlaylists = _filter == null || _filter == 'playlist';
            final showArtists = _filter == null || _filter == 'artisti';
            final liked = storage.favoritesNotifier.value.length;
            final items = <_Item>[
              if (showPlaylists) ...[
                _Item(
                  title: 'Brani che ti piacciono',
                  subtitle: 'Playlist • ${Desk.songs(liked)}',
                  cover: const DeskLikedCover(size: 48),
                  onOpen: DeskCollectionPage.openLiked,
                ),
                for (final playlist in Desk.playlists())
                  _Item(
                    title: playlist.title,
                    subtitle:
                        'Playlist • ${Desk.whose(playlist.id) ?? Desk.songs(playlist.songs.length)}',
                    cover: DeskCover(
                      url: playlistCoverUrl(playlist),
                      seed: playlist.title,
                      size: 48,
                    ),
                    onOpen: () => DeskCollectionPage.openPlaylist(playlist.id),
                    onMenu: (at) => deskPlaylistMenu(context, at, playlist),
                  ),
              ],
              if (showArtists)
                for (final artist in storage.followedArtistsNotifier.value)
                  _Item(
                    title: artist.name,
                    subtitle: 'Artista',
                    cover: DeskCover(
                      url: artist.imageUrl,
                      seed: artist.name,
                      size: 48,
                      round: true,
                    ),
                    onOpen: () => Desk.nav.open(DeskArtistPage(artist: artist)),
                  ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Its name, and what makes something new ──────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(collapsed ? 0 : 16, 12, collapsed ? 0 : 10, 6),
                  child: Row(
                    mainAxisAlignment: collapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      DeskIconButton(
                        icon: AppIcons.playlist,
                        tooltip: collapsed ? 'Apri la tua libreria' : 'Riduci la tua libreria',
                        size: 24,
                        onTap: () => Desk.libraryCollapsed.value = !collapsed,
                      ),
                      if (!collapsed) ...[
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'La tua libreria',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Builder(
                          builder: (context) => DeskIconButton(
                            icon: AppIcons.add,
                            tooltip: 'Crea una playlist',
                            size: 22,
                            filled: true,
                            onTap: () => _add(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Row(
                      children: [
                        DeskChip(
                          label: 'Playlist',
                          selected: _filter == 'playlist',
                          onTap: () =>
                              setState(() => _filter = _filter == 'playlist' ? null : 'playlist'),
                        ),
                        const SizedBox(width: 8),
                        DeskChip(
                          label: 'Artisti',
                          selected: _filter == 'artisti',
                          onTap: () =>
                              setState(() => _filter = _filter == 'artisti' ? null : 'artisti'),
                        ),
                      ],
                    ),
                  ),

                // ── What is in it ───────────────────────────────────────────
                Expanded(
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Non segui ancora nessun artista. Apri la pagina di un artista e '
                            'scegli "Segui".',
                            style: TextStyle(fontSize: 13, height: 1.4, color: Colors.white60),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemExtent: 64,
                          itemCount: items.length,
                          itemBuilder: (context, index) =>
                              _Entry(item: items[index], collapsed: collapsed),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Item {
  const _Item({
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.onOpen,
    this.onMenu,
  });

  final String title;
  final String subtitle;
  final Widget cover;
  final VoidCallback onOpen;
  final void Function(Offset at)? onMenu;
}

class _Entry extends StatelessWidget {
  const _Entry({required this.item, required this.collapsed});

  final _Item item;
  final bool collapsed;

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
          // Folded, the list is as wide as a cover and little more.
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 4 : 8, vertical: 8),
          decoration: BoxDecoration(
            color: hovered ? Desk.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(width: 48, height: 48, child: item.cover),
              ),
              if (!collapsed) ...[
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
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Colors.white60),
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
    return collapsed
        ? Tooltip(
            message: '${item.title}\n${item.subtitle}',
            waitDuration: const Duration(milliseconds: 400),
            child: row,
          )
        : row;
  }
}
