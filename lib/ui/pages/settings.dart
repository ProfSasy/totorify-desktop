import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kreate_ios/services/app_folder.dart';
import 'package:kreate_ios/services/connect/connect_host.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/ui/theme/app_theme.dart' show AppTheme;

import '../app.dart';
import '../kit.dart';
import '../menus.dart';

/// The settings, as a page of the main view: what each one does on the
/// left, its switch or its button on the right.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  /// Kept the same as the version in pubspec.yaml.
  static const String version = '1.0.0';

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final StorageService _storage = StorageService.instance;

  void _log(String what) => PlaybackLogService.instance.log('UI', 'impostazioni: $what');

  Future<void> _rename() async {
    final name = await askText(
      context,
      title: 'Nome del dispositivo',
      hint: 'Come compare agli altri dispositivi',
      confirm: 'Salva',
      initial: ConnectHost.deviceName,
    );
    if (name == null || name == ConnectHost.deviceName) return;
    _log('nome del dispositivo "$name"');
    await ConnectHost.instance.rename(name);
    if (mounted) setState(() {});
  }

  Future<void> _openDataFolder() async {
    try {
      final folder = await appFolder();
      await Process.start(Platform.isWindows ? 'explorer' : 'xdg-open', [folder.path]);
    } catch (e) {
      App.toast('Impossibile aprire la cartella');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _storage.accentColorNotifier,
        _storage.libraryOwnerNotifier,
        _storage.historyNotifier,
      ]),
      builder: (context, _) {
        final phone = _storage.libraryOwnerNotifier.value;
        final trusted = _storage.connectTrusted;
        final accent = _storage.accentColorNotifier.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 56),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Impostazioni', style: Tk.title(32)),

                  const _Heading('Qualità audio'),
                  _Row(
                    'Qualità dello streaming',
                    detail: 'Alta: audio migliore, più dati. Normale: meno dati.',
                    control: _Switch(
                      value: _storage.isHighQuality,
                      onChanged: (value) async {
                        _log('qualità alta = $value');
                        await _storage.setHighQuality(value);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),

                  const _Heading('Aspetto'),
                  _Row(
                    'Colore di evidenziazione',
                    detail: 'Il colore dei pulsanti e di quello che è attivo.',
                    control: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (name, color) in AppTheme.presetColors)
                          Tooltip(
                            message: name,
                            child: Hover(
                              cursor: SystemMouseCursors.click,
                              builder: (context, hovered) => GestureDetector(
                                onTap: () {
                                  _log('colore $name');
                                  _storage.setAccentColor(color);
                                },
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: color.toARGB32() == accent.toARGB32() || hovered
                                          ? Tk.text
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const _Heading('Dispositivi'),
                  _Row(
                    'Mostra questo computer agli altri dispositivi',
                    detail:
                        'Chi usa Totorify sulla stessa rete può scegliere questo computer per '
                        'ascoltare. Prima di riprodurre ti viene sempre chiesta conferma.',
                    control: _Switch(
                      value: _storage.receivesPlayback,
                      onChanged: (value) async {
                        _log('ricevi musica = $value');
                        await _storage.setReceivesPlayback(value);
                        await ConnectHost.instance.apply();
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                  _Row(
                    'Nome del dispositivo',
                    detail: ConnectHost.deviceName,
                    control: GhostButton('Modifica', small: true, onTap: _rename),
                  ),
                  if (trusted.isNotEmpty)
                    _Row(
                      'Dispositivi autorizzati',
                      detail: trusted.values.join(', '),
                      control: GhostButton(
                        'Rimuovi tutti',
                        small: true,
                        onTap: () async {
                          _log('dimentica i dispositivi autorizzati');
                          await ConnectHost.instance.forgetTrusted();
                          if (mounted) setState(() {});
                        },
                      ),
                    ),

                  const _Heading('Libreria'),
                  if (phone != null)
                    _Row(
                      'Libreria di ${phone.name}',
                      detail:
                          'Le sue playlist compaiono accanto a quelle di questo computer. '
                          'Tornano quando il telefono si collega di nuovo.',
                      control: GhostButton(
                        'Nascondi',
                        small: true,
                        onTap: () async {
                          _log('nascondo la libreria di "${phone.name}"');
                          await _storage.forgetGuestLibrary();
                          App.toast('Libreria di ${phone.name} nascosta');
                        },
                      ),
                    ),
                  _Row(
                    'Cronologia di ascolto',
                    detail: App.songs(_storage.historyNotifier.value.length),
                    control: GhostButton(
                      'Cancella',
                      small: true,
                      onTap: () async {
                        final sure = await askSure(
                          context,
                          title: 'Cancellare la cronologia?',
                          text: 'Gli ascolti recenti e i mix creati per te ripartono da zero.',
                          confirm: 'Cancella',
                        );
                        if (!sure) return;
                        _log('cancello la cronologia');
                        await _storage.clearHistory();
                        App.toast('Cronologia cancellata');
                      },
                    ),
                  ),
                  _Row(
                    'Ricerche recenti',
                    detail: '${_storage.getRecentSearches().length} salvate',
                    control: GhostButton(
                      'Cancella',
                      small: true,
                      onTap: () async {
                        _log('cancello le ricerche recenti');
                        await _storage.clearRecentSearches();
                        if (mounted) setState(() {});
                        App.toast('Ricerche recenti cancellate');
                      },
                    ),
                  ),

                  const _Heading('Informazioni'),
                  const _Row('Versione', detail: 'Totorify per computer ${SettingsPage.version}'),
                  _Row(
                    'Dati dell\'app',
                    detail: 'Libreria, impostazioni e registro dell\'ultima sessione.',
                    control: GhostButton('Apri cartella', small: true, onTap: _openDataFolder),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 36, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Tk.text),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.title, {this.detail, this.control});

  final String title;
  final String? detail;
  final Widget? control;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14.5, color: Tk.text)),
              if (detail != null) ...[
                const SizedBox(height: 3),
                Text(detail!, style: const TextStyle(fontSize: 13, height: 1.4, color: Tk.subdued)),
              ],
            ],
          ),
        ),
        if (control != null) ...[const SizedBox(width: 24), control!],
      ],
    ),
  );
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? accent : const Color(0xFF535353),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: Tk.text, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
