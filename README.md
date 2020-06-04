# Download von Hörspielen des deutschen öffentlichen Rundfunks

(for a shorter english description see below)

Jeden Tag werden im öffentlichen Rundfunk kostenfrei und für jeden Beitragszahler legal zugänglich Hörspiele online gesendet. Viele (leider nicht alle) werden als Podcast angeboten. Warum nicht diese runterladen und archivieren bevor sie wieder nach einem Jahr aus den Podcasts verschwinden? Manuelles runterladen und katalogisieren ist mühsam… deshalb gibt es hier die passenden Skripte :)

### Voraussetzungen

  * Ruby 2.3+
  * curl
  * ffmpeg, NodeJS und Mozilla Readability (für DLF)
  * bash, i.e. macOS or linux (Windows könnte auch über das WSL funktionieren, habs aber nicht getestet)

### Sonderfall DLF

Leider bietet der DLF die Hörspiele aus dem Hauptprogramm nicht in Form eines Podcasts an. Deshalb müssen die Hörspiele erst auf den HTML Seiten gefunden und extrahiert werden. Die Schritte sind deshalb gesondert beschrieben, da sie als Quelle nicht Podcast haben, sondern HTML-Seiten.

### Prozess

  * Download noch nicht lokal vorhandener Hörspiele
  * Vermerk der GUIDS, damit mehrfacher download verhindert wird (oft verändern sich Daten wie Titel, obwohl der Inhalt/GUID gleich bleibt)

Hin und wieder entstehen konflikte (durch geänderte Metadatan, wie gerade beschrieben). Dann werden die Ordner umbenannt in  `$name___conflict_$hash`. Da gilt es dann mal kurz reinzuschauen, ob es wirklich unterschiedliche Audiodaten sind (in 90% der Fälle sind sie gleich) und zu löschen.

### Setup

```sh
  $ bundle install
```

Und mit DLF:

```sh
  $ cd dlf-crawler && ./setup.sh
```

### Benutzung

Einfach das Skript aufrufen (der erste Download-Batch kann dauern, da > 70GB):

```sh
  $ download_podcasts.sh
```

### DLF laden

```sh
  $ download_dlf.sh
```

## Disclaimer

Die Nutzung der Script erfolgt verständlicherweise auf eigene Gefahr, in privatem Kontext und unter der Voraussetzung, dass der Nutzer Rundfunkbeitragszahler ist. Urheberrechte der Hörspielproduktion seitens Autoren, Redaktionen und Schauspieler sollten respektiert werden.

## English Description

The german public broadcasting (Öffentlicher Rundfunk) offers downloading some of their (german) audioplays via podcasts and websites. These scripts are toolset for automated downloading these audioplays if you are german citizen and therefore a monetary contributer (Beitragszahler).
