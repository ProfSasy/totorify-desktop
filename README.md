# Totorify per computer

Totorify per Windows e Linux: la stessa app del telefono, in una finestra
fatta per mouse e tastiera, con un menu a lato e la barra del player in
fondo.

Non è una copia dell'app del telefono. È un progetto separato che usa l'app
del telefono ([ProfSasy/totorify](https://github.com/ProfSasy/totorify),
pacchetto `kreate_ios`) come libreria: le schermate, il player, il catalogo,
la libreria e il protocollo con cui i dispositivi si parlano stanno lì. Qui
c'è solo quello che un computer fa diversamente:

- `lib/main.dart` — avvio: il motore di riproduzione per computer, il
  player, e la presenza sulla rete;
- `lib/desktop_shell.dart` — la cornice: menu a lato, pagine accanto, i
  tasti che comandano la musica;
- `lib/desktop_player_bar.dart` — la barra del player: brano, comandi,
  avanzamento, dispositivo che suona e volume;
- `windows/`, `linux/` — la finestra, il nome e l'icona su ciascun sistema.

## Come si usa

Si cerca, si sceglie e si tiene in libreria come sul telefono. In più:

- scegliendo un brano la pagina resta dov'è: la musica si segue dalla barra
  in fondo, e il player completo (testo, coda, timer) si apre cliccando il
  brano nella barra;
- la barra spaziatrice mette in pausa e riprende, quando non si sta
  scrivendo; i tasti multimediali della tastiera funzionano mentre la
  finestra è quella attiva;
- le file di copertine scorrono con la rotella (tenendo Maiusc) o
  trascinandole.

## Con gli altri dispositivi

Il computer è un dispositivo come gli altri, sulla stessa rete Wi-Fi o via
cavo:

- **manda la sua musica altrove**: l'icona dei dispositivi nella barra
  elenca le TV, i telefoni e i computer con Totorify aperto; la musica
  continua lì dal punto in cui era, e da qui la si comanda;
- **suona per gli altri**: compare nella lista dei dispositivi del telefono.
  Prima di suonare chiede conferma a chi è al computer ("consenti sempre",
  "solo questa volta", "rifiuta"), perché un portatile finisce anche su reti
  che non sono di casa. Si spegne da Impostazioni → Dispositivi, dove si
  sceglie anche il nome con cui il computer si presenta;
- **la libreria**: quella del computer resta sua; accanto compare quella del
  telefono che gli ha passato la musica per ultimo.

La prima volta Windows chiede se consentire a Totorify di comunicare sulla
rete: va consentito sulle reti private, altrimenti gli altri dispositivi non
lo trovano. Con una VPN attiva il computer può non vedere la rete di casa.

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
("Sviluppo di applicazioni desktop con C++", con il componente ATL) e
`nuget` nel percorso. Su Linux: `clang cmake ninja-build pkg-config
libgtk-3-dev liblzma-dev libmpv-dev libsecret-1-dev libjsoncpp-dev`.

## Cosa manca rispetto al telefono

- i Canvas (sono video verticali pensati per lo schermo del telefono);
- l'accesso con Google, che su computer non esiste e che è facoltativo
  ovunque; su Linux l'accesso a Spotify si fa incollando il cookie;
- i comandi nel riquadro multimediale del sistema: per ora la musica si
  comanda dalla finestra.
