# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena principale è:

`Windows → Agent → HTTPS → Apps Script → PC Monitor + Reboot Sessions → API Dashboard → monitor.html`

L'Agent osserva Windows e manda heartbeat. Il backend conserva stato, riavvii, durata ed esito Windows Update. `monitor.html` trasforma questi dati in schede leggibili dal telefono.

Con l'Agent v0.5 anche la SCAN Windows 11 read-only percorre tutta la catena:

`PC → Get-W11PreCheck.ps1 → Agent → heartbeat → Apps Script → PC Monitor → API Dashboard → semaforo sulla card`

Il backend conserva l'ultimo Pre-Check valido per ogni PC e la mini console ora lo mostra direttamente.

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

### Cosa fa la centrale con il Pre-Check

Apps Script riconosce l'oggetto `preCheck` ricevuto dall'Agent e conserva in `PC Monitor` data/ora, stato, blocker/warning, produttore/modello/CPU, RAM, firmware, partizionamento, TPM, Secure Boot e spazio libero.

Se un heartbeat successivo non contiene `preCheck`, il backend mantiene l'ultimo risultato conosciuto. L'API Dashboard restituisce l'oggetto `preCheck` e i contatori `preCheckBlocked` e `preCheckWarning`.

## La mini console mobile

`monitor.html` mostra ora sette contatori: PC totali, online, offline, reboot pending, update falliti, **Pre-Check bloccati** e **Pre-Check in attenzione**.

Ogni card mostra due stati distinti: connettività (`ONLINE/OFFLINE`) e semaforo di preparazione Windows 11 (`PRE-CHECK OK`, `ATTENZIONE`, `BLOCCATO` oppure `N/D`). Sotto il semaforo vengono mostrati, quando disponibili, firmware, partizionamento, TPM, Secure Boot, spazio libero e data della scansione. I motivi di blocco e gli avvisi sono evidenziati senza dover aprire Google Sheets.

La gerarchia delle criticità è ora:

`UPDATE_FAILED → PRE-CHECK BLOCCATO → REBOOT_PENDING → OFFLINE → PRE-CHECK ATTENZIONE → normale`

Questa scelta serve a portare in cima prima ciò che richiede un intervento concreto. Un PC online ma tecnicamente bloccato per l'upgrade non deve perdersi in fondo alla lista soltanto perché sta rispondendo correttamente agli heartbeat.

La pagina continua ad aggiornarsi automaticamente ogni 30 secondi ed è disponibile anche l'aggiornamento manuale.

La console usa una `MONITOR_DASHBOARD_KEY` separata dalla chiave degli Agent. Nella versione prototipo la chiave dashboard è conservata nel `localStorage` del dispositivo; prima di una distribuzione multiutente servirà autenticazione vera.

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

**Completato:** Agent **v0.5**; heartbeat; reboot richiesto; rientro dopo nuovo boot; misura indisponibilità; lettura cronologia Windows Update; persistenza esito; Reboot Sessions; API dashboard; ONLINE/OFFLINE server-side; chiave dashboard separata; UI mobile `monitor.html`; prima SCAN read-only; esecuzione automatica del Pre-Check all'avvio e ogni 6 ore; risultato Pre-Check allegato agli heartbeat; persistenza del Pre-Check; mantenimento dell'ultimo risultato; esposizione nell'API; contatori BLOCCATO/ATTENZIONE; **semaforo Pre-Check sulle card; motivi di blocco/warning visibili; ordinamento della console aggiornato in base alla gravità del Pre-Check**.

**Da implementare/testare:** test end-to-end su un PC reale; controllo preciso della compatibilità CPU Windows 11; controlli avanzati profili/SID; autenticazione multiutente futura.

**Prossimo passo tecnico:** rendere il Pre-Check più affidabile aggiungendo il controllo della CPU rispetto ai requisiti Windows 11 senza trasformare il nostro semaforo in una falsa certificazione; poi testare l'intera catena su un PC reale.

## Per Pietro: cosa stiamo costruendo

La centrale non ti dice più soltanto se il PC è acceso. Adesso ti dice anche, a colpo d'occhio, **se quel computer sembra pronto per il lavoro di upgrade**.

Sulla stessa scheda puoi vedere per esempio:

`🟢 ONLINE   🔴 BLOCCATO`

`Legacy · MBR · TPM 2.0 · 78 GB liberi`

`Blocco: firmware non UEFI · disco di sistema non GPT`

Questo è utile perché ONLINE e PRONTO sono due cose completamente diverse. Un computer può funzionare perfettamente durante la giornata ma avere una configurazione che ci impedisce di procedere serenamente con Windows 11. Ora la mini console rende questa differenza immediatamente visibile e porta automaticamente quel PC fra le prime macchine da controllare.