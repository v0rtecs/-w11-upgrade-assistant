# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena è ora:

`Windows → Agent → HTTPS → Apps Script → PC Monitor + Reboot Sessions → API Dashboard → futura PWA`

L'Agent osserva Windows e manda heartbeat. Il backend conserva stato, riavvii, durata ed esito Windows Update. Esiste anche un endpoint pensato apposta per la dashboard: il telefono non dovrà capire le righe di Google Sheet, riceverà già una fotografia sintetica dei PC.

Il progetto viene ora esteso con un secondo obiettivo: **preparare e diagnosticare i PC prima dell'upgrade a Windows 11**, riducendo al minimo i controlli manuali via AnyDesk.

## Che cos'è l'Agent

È un piccolo programma PowerShell che osserva e comunica. Ogni PC ha un Agent ID permanente in `C:\ProgramData\W11UpgradeAssistant\agent.json`. Parte automaticamente con Windows come SYSTEM. Non prende il controllo del PC e non installa aggiornamenti.

## Heartbeat e riavvio

Ogni 30 secondi l'Agent comunica identità, PC, stato, boot, Windows e build. Quando Windows Update richiede un riavvio manda `REBOOT_PENDING`; dopo il nuovo boot manda `ONLINE_AFTER_REBOOT` finché il server conferma la ricezione.

`ONLINE → REBOOT_PENDING → [PC indisponibile] → ONLINE_AFTER_REBOOT → ONLINE`

Il backend trasforma questa sequenza in una Reboot Session e misura l'**indisponibilità osservata** fra ultimo contatto e rientro.

## Esito Windows Update

Dopo il reboot l'Agent legge la cronologia locale di Windows Update. La classificazione resta prudente:

- `UPDATE_OK`: installazione riuscita;
- `UPDATE_OK_CON_ERRORI`: completata ma con errori segnalati;
- `UPDATE_FAILED`: fallita/interrotta;
- `DA_VERIFICARE`: non abbiamo prove sufficienti per attribuire un esito.

Backend e Reboot Sessions conservano anche titolo update, result code e data dell'evento.

# Nuovo modulo: Windows 11 Pre-Check

L'Upgrade Assistant deve poter eseguire una **scansione preliminare non invasiva anche mentre l'operatore sta lavorando sul PC**. Lo scopo è arrivare alla sessione di manutenzione sapendo già se il computer è pronto oppure quale problema deve essere corretto.

La diagnostica viene divisa in tre livelli, in modo che un controllo sicuro non possa accidentalmente trasformarsi in una manutenzione invasiva.

## 1. SCAN — sicura durante il lavoro

Questa modalità deve essere principalmente read-only e non deve riavviare il PC, fermare servizi, cancellare cache o modificare il registro.

Controlli previsti:

- produttore e modello del PC;
- CPU, RAM e versione/build di Windows;
- modalità firmware UEFI/Legacy;
- schema disco GPT/MBR;
- presenza, versione e stato TPM;
- stato Secure Boot;
- spazio libero sul disco di sistema;
- stato di AnyDesk e tipo di avvio del relativo servizio;
- stato dei principali servizi Windows Update;
- presenza di riavvii pendenti;
- presenza e percorso della ISO Windows 11, quando configurata;
- inventario software utile alla diagnosi;
- anomalie evidenti dei profili utente nel `ProfileList`;
- SID non risolvibili/orfani;
- più SID che puntano allo stesso `ProfileImagePath`;
- profili `.bak` o chiavi anomale che possono interferire con la migrazione;
- controlli preliminari utili sui driver e sullo stato del sistema.

Il controllo dei profili è considerato importante perché una configurazione incoerente può superare i normali controlli hardware e far fallire Windows Setup solo durante la fase di migrazione dei dati.

La modalità SCAN **segnala soltanto** l'anomalia: non elimina chiavi del registro e non modifica profili automaticamente.

## 2. DIAGNOSTICA COMPLETA — possibile durante il lavoro, ma più pesante

Comprende i controlli della SCAN e può aggiungere verifiche che usano CPU e disco, per esempio:

- `sfc /scannow`;
- DISM di verifica/riparazione dell'immagine Windows;
- controlli più approfonditi sullo stato dei componenti;
- raccolta di log diagnostici.

Queste operazioni non richiedono necessariamente che l'utente esca da Windows, ma possono rallentare il PC. L'interfaccia deve quindi avvisare chiaramente prima di avviarle.

Le percentuali mostrate da strumenti come SFC non devono essere interpretate come avanzamento lineare: il processo può rimanere a lungo su una percentuale e poi avanzare rapidamente. L'Assistant dovrà distinguere, quando possibile, tra processo realmente bloccato e processo ancora attivo.

### Monitoraggio intelligente dell'attività

Durante SFC, DISM, copia ISO, Windows Setup e Windows Update, l'Assistant non deve basarsi soltanto sulla percentuale visualizzata. Deve raccogliere anche indicatori di attività reale, quando disponibili, come variazione del tempo CPU dei processi interessati, attività recente, presenza dei processi/servizi attesi e tempo trascorso dall'ultimo segnale utile.

L'interfaccia dovrà poter mostrare, per esempio:

```text
SFC /SCANNOW
51%

STATO: IN ESECUZIONE
Attività manutenzione rilevata
TiWorker CPU: +12 sec
Ultima attività: 3 sec fa
Tempo trascorso: 14:32
```

La classificazione prevista è:

- `ATTIVO` / verde: attività recente rilevata, anche se la percentuale non cambia;
- `DA VERIFICARE` / giallo: nessuna variazione significativa per un intervallo prolungato;
- `POSSIBILE BLOCCO` / rosso: assenza prolungata di più indicatori di attività, senza concludere automaticamente che il processo sia certamente bloccato.

Le soglie dovranno essere conservative e specifiche per operazione. Una percentuale ferma, da sola, **non deve mai generare un errore**.

Lo stesso modello di monitoraggio dovrà essere riutilizzabile per SFC, DISM, trasferimento della ISO, Windows Setup e Windows Update, così da rendere leggibile da remoto la differenza tra un'operazione lenta e un'operazione che richiede intervento.

## 3. PREPARAZIONE / UPGRADE — PC libero

Questa modalità può effettuare modifiche e deve essere usata quando l'operatore ha terminato il lavoro.

Può comprendere:

- pulizia o ripristino dei componenti Windows Update;
- eventuali correzioni approvate dei profili utente;
- modifiche necessarie a UEFI/Secure Boot quando supportate e autorizzate;
- copia/montaggio della ISO;
- avvio di Windows Setup;
- gestione dei riavvii e monitoraggio del rientro online.

Nessuna correzione distruttiva o modifica ai profili deve essere eseguita automaticamente sulla sola base della SCAN.

## Esito sintetico del Pre-Check

L'obiettivo è produrre un risultato leggibile in pochi secondi, per esempio:

```text
WINDOWS 11 UPGRADE ASSISTANT

PC:          LENOVO 21KK
Windows:     Windows 10 Pro
CPU:         Ryzen 5 7530U

[OK] UEFI
[OK] Disco GPT
[OK] TPM 2.0
[OK] Secure Boot
[OK] Spazio disco
[OK] AnyDesk: Running / Automatic
[OK] Profili utente
[OK] ISO Windows 11

RISULTATO: PC PRONTO PER WINDOWS 11
```

In presenza di una configurazione incoerente dei profili, invece:

```text
[ERRORE] PROFILI UTENTE

C:\Users\NomeUtente associato a più SID.
Uno o più SID risultano non risolvibili oppure sono presenti chiavi anomale/.bak.

RISULTATO: UPGRADE BLOCCATO
Correggere il profilo prima di procedere.
```

L'Assistant dovrà classificare i risultati almeno come `OK`, `ATTENZIONE` ed `ERRORE/BLOCCANTE`, conservando il dettaglio tecnico per l'helpdesk.

## Principio operativo

Il flusso desiderato diventa:

`SCAN durante il normale lavoro → individuazione preventiva anomalie → manutenzione solo sui PC che la richiedono → upgrade → monitoraggio reboot/rientro/esito`

L'obiettivo pratico è ridurre la sessione AnyDesk a un intervento sulle sole eccezioni, invece di ripetere manualmente la stessa serie di comandi su ogni PC.

## API della dashboard

`Code.gs` espone una vista JSON dedicata alla futura PWA. Non restituisce il foglio grezzo: costruisce una scheda già pronta per ogni PC con:

`PC | ONLINE/OFFLINE | ultimo contatto | stato Agent | reboot pending | Windows/build | ultimo esito update | ultimo reboot e durata`

Restituisce anche un riepilogo generale:

`totale PC | online | offline | reboot pending | update falliti`

In futuro la stessa dashboard potrà mostrare anche lo stato del Pre-Check (`PRONTO`, `ATTENZIONE`, `BLOCCATO`) senza confonderlo con lo stato live dell'Agent.

### Come decidiamo ONLINE/OFFLINE

Questa distinzione non viene affidata allo stato scritto dall'Agent, perché un PC spento non può mandare un messaggio dicendo «sono offline».

La centrale guarda invece **quanto tempo è passato dall'ultimo heartbeat ricevuto dal server**. L'Agent parla ogni 30 secondi; per ora consideriamo ONLINE un PC visto negli ultimi **90 secondi**. Oltre quella soglia la dashboard lo presenta come OFFLINE.

Questo margine evita che un singolo heartbeat perso faccia lampeggiare inutilmente il PC da verde a rosso.

### Sicurezza della dashboard

L'API non usa la chiave degli Agent. Ha una chiave separata, salvata nelle Script Properties con nome `MONITOR_DASHBOARD_KEY`. In questo modo la futura PWA può avere accesso in sola lettura alla fotografia sintetica senza conoscere la credenziale usata dai PC per inviare heartbeat.

La chiamata prevista è concettualmente:

`Web App Apps Script ? api=dashboard & key=CHIAVE_DASHBOARD`

La chiave reale non va inserita nel repository.

## Reboot Sessions

`PC Monitor` è la fotografia LIVE, una riga per PC. `Reboot Sessions` è lo storico permanente dei riavvii significativi. Anche se `REBOOT_PENDING` non fosse stato osservato, un nuovo boot può essere archiviato come `RIAVVIO_RILEVATO` senza inventare che fosse causato da Windows Update.

## Stato dell'implementazione

**Completato:** Agent v0.4; heartbeat; riconoscimento reboot richiesto; rientro dopo nuovo boot; misura indisponibilità; lettura cronologia Windows Update; persistenza dell'esito; Reboot Sessions; prima API dati per dashboard; calcolo server-side ONLINE/OFFLINE; chiave dashboard separata.

**Progettato:** modulo Windows 11 Pre-Check a tre livelli (`SCAN`, `DIAGNOSTICA`, `PREPARAZIONE/UPGRADE`); controlli hardware/firmware; controllo AnyDesk; rilevazione preventiva delle anomalie `ProfileList` e dei SID; classificazione `OK/ATTENZIONE/BLOCCATO`; monitoraggio intelligente dell'attività di SFC/DISM/copia ISO/Setup/Windows Update con stati `ATTIVO`, `DA VERIFICARE` e `POSSIBILE BLOCCO`.

**Da implementare/testare:** raccolta effettiva dei dati Pre-Check nell'Agent/desktop app, monitor attività dei processi, invio al backend, visualizzazione nella dashboard, test su PC reali e verifica delle prestazioni della SCAN mentre l'operatore lavora.

**Prossimi passi:** implementare prima la SCAN read-only e il controllo profili; poi esporre il risultato alla dashboard. SFC/DISM e le azioni correttive resteranno separate dalla scansione silenziosa. Il monitor attività verrà condiviso dalle operazioni lunghe per evitare falsi allarmi basati sulla sola percentuale.

## Per Pietro: cosa stiamo costruendo

Il progetto non è più soltanto una centrale che osserva Windows Update. Sta diventando un assistente operativo per l'intero ciclo di upgrade.

L'idea è semplice: mentre il PC viene normalmente utilizzato, l'Assistant può già raccogliere i controlli sicuri e dirci se la macchina è pronta. Quando arriva il momento dell'intervento remoto, non dobbiamo ricominciare da zero: lavoriamo soltanto sulle anomalie già individuate, avviamo l'upgrade e poi lasciamo all'Agent il compito di confermare riavvio, rientro online ed esito.
