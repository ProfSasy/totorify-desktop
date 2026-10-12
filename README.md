# Totorify per computer

Totorify per Windows e Linux: un'app scritta per il computer, con una
finestra, il mouse e la tastiera. La finestra non ha la barra del titolo del
sistema: la barra in alto la sposta e porta i pulsanti per ridurla,
ingrandirla e chiuderla, insieme alla ricerca. La libreria sta sempre a
sinistra, la pagina al centro, il player in fondo, e a destra si aprono la
vista "In riproduzione", la coda e i dispositivi.

Dell'app del telefono
([ProfSasy/totorify](https://github.com/ProfSasy/totorify), pacchetto
`kreate_ios`) usa solo quello che non si vede: il player, il catalogo, la
libreria, i testi e il protocollo con cui i dispositivi si parlano. Tutto
quello che si vede è suo, in `lib/ui/`:

- `kit.dart` — colori, misure, icone e tema, e i pezzi piccoli di cui sono
  fatte le pagine (pulsanti, copertine, avvisi);
- `app.dart` — quello che ogni parte della finestra usa: il player, le
  pagine aperte con il loro indietro e avanti, la ricerca, la vista a destra;
- `widgets.dart`, `menus.dart` — schede, righe dei brani, menu del tasto
  destro, finestre di dialogo;
- `shell/` — la finestra: `title_bar.dart` (barra in alto), `library.dart`
  (la tua libreria), `side_view.dart` (in riproduzione, coda, dispositivi),
  `player_bar.dart` (il player), `shell.dart` (come stanno insieme, i tasti);
- `pages/` — le pagine: `home.dart`, `search.dart`, `collection.dart`
  (playlist e album, con la tabella dei brani), `artist.dart`, `lyrics.dart`,
  `settings.dart`.

`lib/main.dart` è l'avvio; `windows/` e `linux/` sono la finestra, il nome e
l'icona su ciascun sistema.

## Come si usa

- **Per muoversi**: le frecce in alto a sinistra (o Alt + freccia, o i tasti
  laterali del mouse) tornano indietro e avanti tra le pagine aperte, ognuna
  com'era. La casa porta alla Home.
- **Per cercare**: si scrive nel campo in alto (Ctrl + K ci porta il
  cursore) e i risultati arrivano mentre si scrive; il pulsante accanto apre
  "Sfoglia tutto".
- **Per ascoltare**: doppio click su un brano, o il pulsante verde di una
  playlist, di un album, di un artista. La pagina resta dov'è.
- **Tasto destro** su un brano: aggiungi alla playlist, salva in Brani che ti
  piacciono, aggiungi in coda, riproduci subito dopo, vai all'artista. Su una
  playlist della libreria: modifica nome, elimina.
- **"Crea"**, nella libreria, crea una playlist o ne importa una da un link
  di Spotify o di YouTube Music. La libreria si comprime alle sole copertine
  cliccando sul suo nome.
- **In basso a destra**: la vista "In riproduzione", i testi a tutta pagina
  (cliccando un verso si salta lì), la coda, i dispositivi, il volume.
- **La barra spaziatrice** mette in pausa e riprende, quando non si sta
  scrivendo; i tasti multimediali funzionano mentre la finestra è attiva.
- **Le impostazioni** (l'ingranaggio in alto a destra) sono una pagina:
  qualità audio, colore, dispositivi, libreria.

## Con gli altri dispositivi

Il computer è un dispositivo come gli altri, sulla stessa rete Wi-Fi o via
cavo:

- **manda la sua musica altrove**: "Connetti a un dispositivo", nel player,
  elenca le TV, i telefoni e i computer con Totorify aperto; la musica
  continua lì dal punto in cui era, e da qui la si comanda;
- **suona per gli altri**: compare nella lista dei dispositivi del telefono.
  Prima di suonare chiede conferma a chi è al computer ("Consenti sempre",
  "Solo questa volta", "Rifiuta"), perché un portatile finisce anche su reti
  che non sono di casa. Si spegne da Impostazioni → Dispositivi, dove si
  sceglie anche il nome con cui il computer si presenta;
- **la libreria**: quella del computer resta sua; accanto compare quella del
  telefono che gli ha passato la musica per ultimo.

La prima volta Windows chiede se consentire a Totorify di comunicare sulla
rete: va consentito sulle reti private, altrimenti gli altri dispositivi non
lo trovano. Con una VPN attiva il computer può non vedere la rete di casa, e
sulle reti pubbliche (università, hotel) i dispositivi non si vedono tra loro.

## Dove tiene i dati

Nella cartella che il sistema dà alle app: `%APPDATA%\ProfSasy\Totorify` su
Windows, `~/.local/share/com.profsasy.totorify` su Linux. Lì ci sono la
libreria, le impostazioni, i brani scaricati e `totorify_log.txt`, il
registro dell'ultima sessione, utile quando qualcosa non va.

## Come si ottiene

Ogni modifica viene compilata da GitHub (scheda *Actions*): in fondo alla
pagina di ciascuna esecuzione ci sono `Totorify-Windows` e due versioni per
Linux.

- **Windows**: estrarre la cartella e avviare `totorify.exe`. Serve Windows
  10 o successivo, a 64 bit.
- **Linux**: estrarre l'archivio e avviare `totorify/totorify`. Serve la
  libreria di mpv: `Totorify-Linux-libmpv2` per le distribuzioni recenti
  (Ubuntu 24.04 e simili: `sudo apt install libmpv2`), `Totorify-Linux-libmpv1`
  per quelle di qualche anno fa (Ubuntu 22.04 e simili: `sudo apt install
  libmpv1`). Perché gli altri dispositivi lo trovino da soli serve Avahi, che
  le distribuzioni per computer hanno già.

## Come si compila

Serve Flutter, e l'app del telefono accanto a questo progetto, in una
cartella di nome `kreate-ios`:

```
git clone https://github.com/ProfSasy/totorify kreate-ios
git clone https://github.com/ProfSasy/totorify-desktop
cd totorify-desktop
flutter build windows --release     # oppure: flutter build linux --release
```

Su Windows servono gli strumenti di compilazione di Visual Studio
2022 ("Sviluppo di applicazioni desktop con C++", con il componente ATL) e
`nuget` nel percorso. Su Linux: `clang cmake ninja-build pkg-config
libgtk-3-dev liblzma-dev libmpv-dev libsecret-1-dev libjsoncpp-dev
libasound2-dev`.

## Cosa manca rispetto al telefono

- i Canvas (video verticali pensati per lo schermo del telefono) e i brani
  scaricati per l'ascolto senza rete;
- il timer di spegnimento e la scelta di una fonte audio alternativa;
- l'accesso con un account (Google, Spotify): su computer la libreria è
  quella del computer, più quella del telefono che si collega;
- i comandi nel riquadro multimediale del sistema: per ora la musica si
  comanda dalla finestra.
