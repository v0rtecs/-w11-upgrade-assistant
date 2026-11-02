# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena è ora:

`Windows → Agent → HTTPS → Apps Script → PC Monitor + Reboot Sessions → API Dashboard → monitor.html`

L'Agent osserva Windows e manda heartbeat. Il backend conserva stato, riavvii, durata ed esito Windows Update. La SCAN read-only Windows 11 percorre la stessa catena e la mini console mostra il risultato sul telefono.

## Heartbeat, riavvio ed esito

Ogni 30 secondi l'Agent comunica identità, stato e boot. Quando Windows Update richiede un riavvio manda `REBOOT_PENDING`; dopo un nuovo boot manda `ONLINE_AFTER_REBOOT`. Il backend misura l'indisponibilità osservata fra ultimo contatto e rientro e conserva l'esito letto dalla cronologia Windows Update (`UPDATE_OK`, `UPDATE_OK_CON_ERRORI`, `UPDATE_FAILED`, `DA_VERIFICARE`).

## Pre-Check automatico

`Get-W11PreCheck.ps1` è una scansione in sola lettura: non cambia registro, firmware, servizi o partizioni. Controlla produttore/modello, CPU, RAM, Windows/build, BIOS, UEFI/Legacy, GPT/MBR, TPM, Secure Boot, spazio su C:, AnyDesk e reboot pendenti. L'Agent la esegue all'avvio e poi ogni 6 ore e conserva l'ultimo risultato valido.

### CPU: il nuovo pezzo della catena

Il Pre-Check v0.2 produce due campi aggiuntivi: `cpuCompatibility` e `cpuCompatibilityDetail`. La classificazione è volutamente prudente: `FAMIGLIA_COMPATIBILE` significa che la famiglia/generazione rientra nell'euristica prevista; `DA_VERIFICARE` significa che non vogliamo dare un falso verde e il modello va controllato più precisamente.

Da oggi questi due campi non restano più soltanto sul PC. Apps Script li salva nelle nuove colonne **CPU Compatibility** e **CPU Compatibility Detail** di `PC Monitor`, l'API li restituisce nell'oggetto `preCheck` e `monitor.html` li mostra direttamente nella card.

La dashboard ha anche il contatore **CPU da verificare**. Questo permette di vedere subito quante macchine richiedono un controllo CPU più preciso, senza aprire PowerShell o Google Sheets.

Esempio:

`🟢 ONLINE   🟡 ATTENZIONE`

`CPU: Intel Core i5-6500 · 🟡 DA_VERIFICARE`

`Intel Core generazione 6: modello da confrontare con elenco Microsoft`

Oppure:

`🟢 ONLINE   🟢 PRE-CHECK OK`

`CPU: Intel Core i5-8500 · 🟢 FAMIGLIA_COMPATIBILE`

`Intel Core generazione 8`

Importante: **FAMIGLIA_COMPATIBILE non è una certificazione Microsoft modello-per-modello**. Serve a ridurre i falsi verdi e a guidare il controllo, non a sostituire l'elenco ufficiale.

## Perché ONLINE e PRONTO restano separati

ONLINE/OFFLINE indica se il PC sta comunicando. Il Pre-Check indica se la macchina sembra pronta per il lavoro di upgrade. Un PC può quindi essere perfettamente online ma BLOCCATO o in ATTENZIONE.

La gerarchia delle criticità resta:

`UPDATE_FAILED → PRE-CHECK BLOCCATO → REBOOT_PENDING → OFFLINE → PRE-CHECK ATTENZIONE → normale`

## ONLINE/OFFLINE

Un PC spento non può dire di essere offline. Con heartbeat ogni 30 secondi, la centrale considera ONLINE un PC visto negli ultimi 90 secondi. Oltre quella soglia viene mostrato OFFLINE: il margine evita falsi allarmi per un singolo heartbeat perso.

## Reboot Sessions

`PC Monitor` è la fotografia LIVE, una riga per PC. `Reboot Sessions` è lo storico dei riavvii significativi. Se non abbiamo osservato `REBOOT_PENDING` ma rileviamo comunque un nuovo boot, archiviamo `RIAVVIO_RILEVATO` senza inventare che fosse causato da Windows Update.

## Stato implementazione

**Completato:** Agent v0.5; heartbeat; reboot pending; rientro; durata indisponibilità; lettura esito Windows Update; Reboot Sessions; API dashboard; ONLINE/OFFLINE server-side; mini console mobile; Pre-Check automatico; semaforo OK/ATTENZIONE/BLOCCATO; motivi visibili; compatibilità CPU prudente nel Pre-Check v0.2; **persistenza CPU compatibility nel backend; esposizione API; visualizzazione CPU e dettaglio sulla card; contatore CPU da verificare**.

**Da implementare/testare:** test end-to-end su un PC reale; verifica CPU modello-per-modello più autorevole; controlli avanzati profili/SID; autenticazione multiutente futura.

## Per Pietro: cosa abbiamo aggiunto oggi

Prima la scansione sapeva già dire «questa CPU la riconosco come famiglia plausibile» oppure «questa CPU va verificata», ma l'informazione rimaneva dentro il PC. Ora percorre tutta la strada fino al telefono.

In pratica non devi più ricordarti quale macchina montava quale processore. Apri la mini console e, sotto il Pre-Check, trovi **nome CPU, classificazione e motivo**. Il contatore in alto ti dice immediatamente quante CPU sono ancora da verificare.

Il prossimo passo tecnico sensato è rendere questa verifica più autorevole senza trasformare l'Agent in qualcosa di fragile: aggiungeremo una tabella/versione di compatibilità CPU controllabile e aggiornata separatamente dal codice dell'Agent, poi prepareremo un test end-to-end reale della catena completa.