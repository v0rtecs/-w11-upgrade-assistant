# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena principale è:

`Windows → Agent → HTTPS → Apps Script → PC Monitor + Reboot Sessions → API Dashboard → monitor.html`

L'Agent osserva Windows e manda heartbeat. Il backend conserva stato, riavvii, durata ed esito Windows Update. `monitor.html` trasforma questi dati in schede leggibili dal telefono.

Con l'Agent v0.5 anche la SCAN Windows 11 read-only percorre ora la catena fino alla centrale:

`PC → Get-W11PreCheck.ps1 → Agent → heartbeat → Apps Script → PC Monitor → API Dashboard`

Il backend conserva l'ultimo Pre-Check valido per ogni PC e lo espone all'API. Il prossimo passaggio è puramente visivo: mostrare il semaforo e i motivi direttamente sulle card di `monitor.html`.

## Che cos'è l'Agent

È un piccolo programma PowerShell che osserva e comunica. Ogni PC ha un Agent ID permanente in `C:\ProgramData\W11UpgradeAssistant\agent.json`. Parte automaticamente con Windows come SYSTEM. Non prende il controllo del PC e non installa aggiornamenti.

## Heartbeat e riavvio

Ogni 30 secondi l'Agent comunica identità, PC, stato, boot, Windows e build. Quando Windows Update richiede un riavvio manda `REBOOT_PENDING`; dopo il nuovo boot manda `ONLINE_AFTER_REBOOT` finché il server conferma la ricezione.

`ONLINE → REBOOT_PENDING → [PC indisponibile] → ONLINE_AFTER_REBOOT → ONLINE`

Il backend trasforma questa sequenza in una Reboot Session e misura l'**indisponibilità osservata** fra ultimo contatto e rientro.

## Esito Windows Update

Dopo il reboot l'Agent legge la cronologia locale di Windows Update. La classificazione resta prudente: `UPDATE_OK`, `UPDATE_OK_CON_ERRORI`, `UPDATE_FAILED` oppure `DA_VERIFICARE`. Backend e Reboot Sessions conservano anche titolo update, result code e data dell'evento.

## Pre-Check automatico

`Get-W11PreCheck.ps1` controlla in sola lettura produttore/modello, CPU, RAM, Windows/build, BIOS, UEFI/Legacy, GPT/MBR, TPM, Secure Boot, spazio libero su C:, AnyDesk e reboot pendenti. Produce `OK`, `ATTENZIONE` o `BLOCCATO`, più l'elenco dei motivi.

L'Agent esegue automaticamente questa scansione all'avvio e poi ogni **6 ore**. Non la eseguiamo ogni 30 secondi perché TPM, firmware, RAM e partizionamento non cambiano continuamente.

Fra una scansione e l'altra l'Agent conserva in memoria l'ultimo risultato valido e lo allega agli heartbeat. Se una scansione fallisce, non cancella immediatamente il precedente risultato valido: registra l'errore nel log e riprova al ciclo previsto.

### Cosa fa adesso la centrale con il Pre-Check

Apps Script riconosce l'oggetto `preCheck` ricevuto dall'Agent e conserva in `PC Monitor`:

- data/ora della scansione;
- stato `OK`, `ATTENZIONE` o `BLOCCATO`;
- blocker e warning;
- produttore, modello e CPU;
- RAM;
- firmware UEFI/Legacy e GPT/MBR;
- versione TPM e stato Secure Boot;
- spazio libero su C:.

Se un heartbeat successivo non contiene `preCheck`, il backend **mantiene l'ultimo risultato conosciuto** invece di cancellarlo. Questo è importante perché il controllo completo viene eseguito ogni sei ore, mentre gli heartbeat arrivano ogni 30 secondi.

L'API Dashboard restituisce ora un oggetto `preCheck` per ciascun PC e aggiunge due contatori generali: `preCheckBlocked` e `preCheckWarning`. In questo modo l'interfaccia non dovrà ricostruire o reinterpretare i dati grezzi del foglio.

## La mini console mobile

`monitor.html` mostra cinque contatori: PC totali, online, offline, reboot pending e update falliti. Sotto crea una card per ogni PC con ultimo contatto, Windows/build, esito update e durata dell'ultimo reboot.

Le eccezioni vengono portate in cima con priorità `UPDATE_FAILED → REBOOT_PENDING → OFFLINE → ONLINE`. La pagina si aggiorna automaticamente ogni 30 secondi ed è disponibile anche un aggiornamento manuale.

La console usa una `MONITOR_DASHBOARD_KEY` separata dalla chiave degli Agent. Nella versione prototipo la chiave dashboard è conservata nel `localStorage` del dispositivo; prima di una distribuzione multiutente servirà autenticazione vera.

Il backend è già pronto a fornire alla UI anche il Pre-Check. Manca soltanto la resa grafica del semaforo e dei motivi nelle card.

## Come decidiamo ONLINE/OFFLINE

Un PC spento non può comunicare «sono offline». La centrale guarda quanto tempo è passato dall'ultimo heartbeat. Con heartbeat ogni 30 secondi consideriamo ONLINE un PC visto negli ultimi 90 secondi; oltre la soglia viene mostrato OFFLINE. Il margine evita falsi allarmi per un singolo heartbeat perso.

## Reboot Sessions

`PC Monitor` è la fotografia LIVE, una riga per PC. `Reboot Sessions` è lo storico permanente dei riavvii significativi. Anche se `REBOOT_PENDING` non fosse stato osservato, un nuovo boot può essere archiviato come `RIAVVIO_RILEVATO` senza inventare che fosse causato da Windows Update.

# Windows 11 Pre-Check

Il modulo resta diviso in tre livelli per evitare che una scansione sicura possa trasformarsi accidentalmente in manutenzione invasiva.

### 1. SCAN — sicura durante il lavoro

Read-only. La prima implementazione reale copre hardware, firmware, disco, TPM/Secure Boot, spazio, AnyDesk e reboot pending. I controlli più avanzati su servizi Windows Update, ISO e anomalie `ProfileList`/SID verranno aggiunti progressivamente, sempre senza modifiche automatiche.

### 2. DIAGNOSTICA COMPLETA

Potrà comprendere SFC, DISM e raccolta log. L'interfaccia dovrà distinguere una percentuale semplicemente ferma da un processo realmente sospetto usando indicatori di attività, con stati `ATTIVO`, `DA VERIFICARE`, `POSSIBILE BLOCCO`.

### 3. PREPARAZIONE / UPGRADE

Solo a PC libero: eventuali correzioni approvate, preparazione Windows Update, copia/montaggio ISO, Windows Setup e monitoraggio dei riavvii. Nessuna correzione distruttiva deve partire automaticamente dalla sola SCAN.

Il flusso desiderato resta:

`SCAN durante il lavoro → anomalie preventive → manutenzione solo dove serve → upgrade → reboot/rientro/esito`

## Stato dell'implementazione

**Completato:** Agent **v0.5**; heartbeat; reboot richiesto; rientro dopo nuovo boot; misura indisponibilità; lettura cronologia Windows Update; persistenza esito; Reboot Sessions; API dashboard; ONLINE/OFFLINE server-side; chiave dashboard separata; UI mobile `monitor.html`; prima SCAN read-only; esecuzione automatica del Pre-Check all'avvio e ogni 6 ore; risultato Pre-Check allegato agli heartbeat; **persistenza del Pre-Check in `PC Monitor`; mantenimento dell'ultimo Pre-Check se un heartbeat non lo contiene; esposizione Pre-Check nell'API Dashboard; contatori BLOCCATO/ATTENZIONE lato API**.

**Da implementare/testare:** semaforo `OK/ATTENZIONE/BLOCCATO` sulle card; test end-to-end su un PC reale; controlli avanzati profili/SID; autenticazione multiutente futura.

**Prossimo passo tecnico:** aggiornare `monitor.html` per usare `preCheck.status`, mostrare blocker/warning in modo compatto e portare i PC `BLOCCATO` o `ATTENZIONE` nella gerarchia delle priorità della console.

## Per Pietro: cosa stiamo costruendo

La centrale non deve limitarsi a dirti se un PC è acceso. Deve dirti anche se è **pronto per essere aggiornato**.

Ora il PC esegue il controllo preliminare e la centrale sa conservarlo. In pratica ogni macchina può dire: «sono online e il mio ultimo controllo dice UEFI sì, GPT sì, TPM 2.0 sì, spazio sufficiente: OK», oppure «sono online ma sono BLOCCATO perché il disco non è GPT».

La differenza rispetto al passaggio precedente è importante: quel foglietto diagnostico non rimane più soltanto dentro l'Agent. È arrivato fino al backend e all'API. Nel prossimo passaggio lo renderemo immediatamente visibile sul telefono con il semaforo verde/giallo/rosso e con il motivo, senza dover aprire Google Sheets.