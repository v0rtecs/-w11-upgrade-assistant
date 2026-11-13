# Mini console Windows Update — guida semplice, avanzamento v1.2 (13 novembre 2026)

## Che cosa stiamo costruendo
Ogni PC avrà un piccolo Agent che invia periodicamente un **heartbeat** (un «sono vivo») a un backend centrale. La dashboard/PWA mostrerà quali PC sono online, quali stanno installando aggiornamenti, quali sono in attesa di riavvio, quali sono tornati disponibili e l'esito dell'operazione. Il tempo di indisponibilità va misurato dal **primo heartbeat mancante** al **primo heartbeat di rientro**: è una stima con precisione limitata dalla frequenza degli heartbeat, non il tempo esatto impiegato dal firmware/Windows per riavviarsi.

## Passo di oggi: sostituzione atomica del catalogo CPU
Abbiamo preparato un **prototipo separato**, `agent/Install-CpuCatalogAtomic.ps1`, senza modificare l'installatore operativo. In precedenza il catalogo veniva spostato nel backup e poi sostituito: tra le due operazioni poteva risultare assente. Ora il prototipo copia e valida il nuovo file nella **stessa cartella** del catalogo, quindi usa `[IO.File]::Replace` per sostituirlo e creare il backup in un'unica operazione del filesystem.

È come sostituire una scheda in un raccoglitore in un solo gesto: chi legge trova quella vecchia oppure quella nuova, non una cartella vuota nel mezzo. Le letture già aperte possono comunque fallire in particolari condizioni (condivisione/antivirus); i tentativi di lettura dell'Agent restano utili.

## Come si prova (solo PC di laboratorio)
1. Preparare una copia della cartella `agent` e un catalogo di prova valido.
2. Verificare l'impronta SHA-256 ricevuta da un canale fidato.
3. Aprire PowerShell nella copia e lanciare:
```powershell
powershell.exe -NoProfile -File .\Install-CpuCatalogAtomic.ps1 -SourcePath "C:\Temp\cpu-catalog.json" -ExpectedSha256 "INSERIRE_HASH_SHA256_FIDATO_DI_64_CARATTERI"
```
4. Verificare il catalogo installato e il file `.bak`; ripetere con hash sbagliato e con file JSON non valido, controllando che il vecchio catalogo resti invariato.

## Limiti e sicurezza
**Non ancora collaudato su Windows reale.** `File.Replace` richiede supporto del filesystem e permessi adeguati; evitare cartelle condivise e file su volumi non compatibili. Il prototipo richiede che il catalogo di destinazione esista già, non sovrascrive backup preesistenti e non effettua download. La verifica SHA-256 prova l'integrità solo se l'hash atteso proviene da una fonte attendibile; non equivale a una firma digitale. In caso di errore durante la sostituzione occorre verificare catalogo e backup prima di ritentare. Non installare ancora sui PC aziendali.

## Prossimo passo
Scrivere test automatici che confrontino il contenuto prima/dopo la sostituzione e stressino le letture concorrenti. Poi realizzare il primo ciclo completo di heartbeat con identificativo PC pseudonimo, timestamp UTC, stato aggiornamenti e identificativo del boot, senza raccogliere dati personali non necessari. Il backend deve autenticare l'Agent e la dashboard richiedere accesso autorizzato, coerentemente con i requisiti di sicurezza aziendali.
