# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena è ora:

`Windows → Agent → HTTPS → Apps Script → PC Monitor + Reboot Sessions → API Dashboard → monitor.html`

L'Agent osserva Windows e manda heartbeat. Il backend conserva stato, riavvii, durata ed esito Windows Update. La prima schermata mobile della mini console è ora implementata in `monitor.html`: legge l'API Dashboard e trasforma i dati in schede leggibili dal telefono.

## Che cos'è l'Agent

È un piccolo programma PowerShell che osserva e comunica. Ogni PC ha un Agent ID permanente in `C:\ProgramData\W11UpgradeAssistant\agent.json`. Parte automaticamente con Windows come SYSTEM. Non prende il controllo del PC e non installa aggiornamenti.

## Heartbeat e riavvio

Ogni 30 secondi l'Agent comunica identità, PC, stato, boot, Windows e build. Quando Windows Update richiede un riavvio manda `REBOOT_PENDING`; dopo il nuovo boot manda `ONLINE_AFTER_REBOOT` finché il server conferma la ricezione.

`ONLINE → REBOOT_PENDING → [PC indisponibile] → ONLINE_AFTER_REBOOT → ONLINE`

Il backend trasforma questa sequenza in una Reboot Session e misura l'**indisponibilità osservata** fra ultimo contatto e rientro.

## Esito Windows Update

Dopo il reboot l'Agent legge la cronologia locale di Windows Update. La classificazione resta prudente: `UPDATE_OK`, `UPDATE_OK_CON_ERRORI`, `UPDATE_FAILED` oppure `DA_VERIFICARE`. Backend e Reboot Sessions conservano anche titolo update, result code e data dell'evento.

## La prima mini console mobile

`monitor.html` è la prima interfaccia operativa dedicata al monitoraggio. Non sostituisce la checklist principale: è una vista rapida da telefono.

Mostra in alto cinque contatori: PC totali, online, offline, reboot pending e update falliti. Sotto crea una card per ogni PC con ultimo contatto, Windows/build, esito update e durata dell'ultimo reboot.

I PC non vengono mostrati soltanto in ordine alfabetico: la console porta automaticamente in cima le eccezioni con questa priorità:

`UPDATE_FAILED → REBOOT_PENDING → OFFLINE → ONLINE`

In questo modo Pietro non deve scorrere tutti i PC per capire dove intervenire.

La pagina si aggiorna automaticamente ogni 30 secondi, cioè con la stessa scala temporale dell'heartbeat. È disponibile anche un pulsante di aggiornamento manuale.

### Configurazione sul telefono

La mini console chiede due dati una sola volta: URL della Web App Apps Script e `MONITOR_DASHBOARD_KEY`. Li conserva nel `localStorage` del dispositivo e li riutilizza ai successivi accessi. La chiave degli Agent resta separata e non viene esposta alla dashboard.

Nota di sicurezza: questa prima versione è pensata per uso personale/controllato. Salvare la chiave dashboard nel browser è pratico, ma non è ancora l'architettura finale per una distribuzione ampia a più operatori. Prima di un rilascio multiutente dovremo introdurre autenticazione e autorizzazioni vere, senza una chiave condivisa nel client.

## Come decidiamo ONLINE/OFFLINE

Un PC spento non può comunicare «sono offline». La centrale guarda quanto tempo è passato dall'ultimo heartbeat ricevuto dal server. L'Agent parla ogni 30 secondi; consideriamo ONLINE un PC visto negli ultimi 90 secondi. Oltre la soglia la dashboard lo presenta come OFFLINE. Il margine evita falsi allarmi per un singolo heartbeat perso.

## Reboot Sessions

`PC Monitor` è la fotografia LIVE, una riga per PC. `Reboot Sessions` è lo storico permanente dei riavvii significativi. Anche se `REBOOT_PENDING` non fosse stato osservato, un nuovo boot può essere archiviato come `RIAVVIO_RILEVATO` senza inventare che fosse causato da Windows Update.

# Windows 11 Pre-Check

Il secondo obiettivo resta preparare e diagnosticare i PC prima dell'upgrade a Windows 11. Il modulo è diviso in tre livelli per evitare che una scansione sicura possa trasformarsi accidentalmente in manutenzione invasiva.

### 1. SCAN — sicura durante il lavoro

Read-only: produttore/modello, CPU/RAM/build, UEFI/Legacy, GPT/MBR, TPM, Secure Boot, spazio disco, AnyDesk, servizi Windows Update, reboot pendenti, ISO configurata, inventario utile, anomalie `ProfileList`, SID orfani/duplicati, chiavi `.bak` e controlli preliminari di sistema. Segnala soltanto: non modifica registro o profili.

### 2. DIAGNOSTICA COMPLETA

Può comprendere SFC, DISM e raccolta log. L'interfaccia dovrà distinguere una percentuale semplicemente ferma da un processo realmente sospetto usando indicatori di attività, con stati `ATTIVO`, `DA VERIFICARE`, `POSSIBILE BLOCCO`.

### 3. PREPARAZIONE / UPGRADE

Solo a PC libero: eventuali correzioni approvate, preparazione Windows Update, copia/montaggio ISO, Windows Setup e monitoraggio dei riavvii. Nessuna correzione distruttiva deve partire automaticamente dalla sola SCAN.

Il flusso desiderato resta:

`SCAN durante il lavoro → anomalie preventive → manutenzione solo dove serve → upgrade → reboot/rientro/esito`

## Stato dell'implementazione

**Completato:** Agent v0.4; heartbeat; reboot richiesto; rientro dopo nuovo boot; misura indisponibilità; lettura cronologia Windows Update; persistenza esito; Reboot Sessions; API dashboard; ONLINE/OFFLINE server-side; chiave dashboard separata; **prima UI mobile `monitor.html` con auto-refresh e ordinamento per criticità**.

**Progettato:** Windows 11 Pre-Check a tre livelli; controlli hardware/firmware; AnyDesk; anomalie profili/SID; classificazione `OK/ATTENZIONE/BLOCCATO`; monitor intelligente delle operazioni lunghe.

**Da implementare/testare:** test end-to-end della nuova dashboard contro la Web App pubblicata; raccolta effettiva Pre-Check nell'Agent; invio Pre-Check al backend; visualizzazione Pre-Check nella console; autenticazione multiutente futura.

**Prossimo passo tecnico:** implementare la prima `SCAN` read-only nell'Agent, iniziando dai controlli che non modificano nulla (hardware, firmware, disco, TPM/Secure Boot, spazio, AnyDesk e reboot pending), quindi aggiungere il risultato sintetico all'API e alla card del PC.

## Per Pietro: cosa stiamo costruendo

La centrale adesso ha finalmente anche una faccia. Aprendo la mini console dal telefono non devi leggere Google Sheets: vedi subito quanti PC stanno bene e, soprattutto, quelli che richiedono attenzione. Un aggiornamento fallito viene portato in cima, poi vengono i PC che aspettano un riavvio e quelli offline.

Dietro quella schermata continua a lavorare la parte più importante: ogni PC manda il proprio battito alla centrale, la centrale ricostruisce i riavvii e conserva l'esito di Windows Update. Il passo successivo farà la stessa cosa **prima** dell'upgrade: l'Agent controllerà in anticipo se il PC è pronto, senza disturbare chi lo sta usando.