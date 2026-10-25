# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena tecnica è:

`Windows → Agent → HTTPS → Apps Script → PC Monitor + Reboot Sessions`

L'Agent parte automaticamente con Windows, senza login. Riconosce quando Windows Update richiede un riavvio, il backend misura l'indisponibilità e l'Agent v0.4 legge anche la cronologia di Windows Update dopo il nuovo avvio.

**Novità:** il collegamento è ora completo anche lato backend. I dati sull'esito dell'aggiornamento non si fermano più all'Agent: Apps Script li salva realmente nei fogli di monitoraggio.

## Che cos'è l'Agent

È un piccolo programma PowerShell che osserva e comunica. Ogni PC ha un Agent ID permanente in `C:\ProgramData\W11UpgradeAssistant\agent.json`. Non controlla il PC e non installa aggiornamenti.

## Heartbeat e riavvio

Ogni 30 secondi l'Agent invia identità, nome PC, stato, data/ora, boot, Windows e build. Quando compare il marcatore specifico di Windows Update `RebootRequired`, invia `REBOOT_PENDING`. Dopo un nuovo boot invia `ONLINE_AFTER_REBOOT` finché il server non lo riceve.

La sequenza è:

`ONLINE → REBOOT_PENDING → [PC indisponibile] → ONLINE_AFTER_REBOOT → ONLINE`

Il backend trasforma questa sequenza in una Reboot Session e misura il tempo fra ultimo contatto e rientro.

## Esito Windows Update

Al rientro non ci basta sapere che Windows si è riacceso. L'Agent interroga la cronologia locale di Windows Update e cerca le installazioni completate attorno al nuovo boot.

Il risultato viene classificato in modo prudente:

- `UPDATE_OK`: Windows registra l'installazione come riuscita;
- `UPDATE_OK_CON_ERRORI`: completata, ma Windows segnala errori;
- `UPDATE_FAILED`: fallita o interrotta;
- `DA_VERIFICARE`: non abbiamo una prova abbastanza chiara per attribuire un esito.

Insieme allo stato l'Agent invia titolo dell'aggiornamento, codice risultato e data registrata da Windows Update.

### Perché DA_VERIFICARE è importante

Non vogliamo che la console dica «aggiornamento riuscito» solo perché il PC è tornato online. Un riavvio può avvenire per altri motivi e la cronologia può non contenere un evento abbastanza vicino. In quel caso la risposta corretta è `DA_VERIFICARE`, non una supposizione.

Per ora l'Agent considera una finestra prudenziale di sei ore prima del boot e controlla fino a 50 eventi recenti. È una prima euristica: durante i test reali la renderemo più precisa collegando l'aggiornamento osservato prima del reboot con quello registrato dopo.

## Novità backend: il dato arriva davvero alla centrale

`Code.gs` ora riceve e conserva quattro campi aggiuntivi:

- `Update Status`
- `Update Title`
- `Update Result Code`
- `Update Date UTC`

Questi campi vengono salvati sia in **PC Monitor**, cioè la fotografia LIVE del computer, sia nella relativa **Reboot Session**, cioè lo storico permanente di quel riavvio.

Il backend aggiorna automaticamente anche le intestazioni dei fogli già esistenti: non serve ricreare manualmente `PC Monitor` o `Reboot Sessions` per aggiungere le nuove colonne.

Quando arriva `ONLINE_AFTER_REBOOT`, la sessione viene chiusa conservando insieme:

`durata indisponibilità + nuovo boot + esito update + titolo update + codice risultato + data update`

L'esito sintetico della Reboot Session incorpora anche la classificazione, per esempio `RIENTRATO_UPDATE_OK` oppure `RIENTRATO_UPDATE_FAILED`.

## Reboot Sessions

`PC Monitor` è la fotografia LIVE: una riga per PC. `Reboot Sessions` è lo storico dei riavvii significativi. Il cronometro misura l'**indisponibilità osservata**, non pretende di conoscere il secondo esatto mostrato nella schermata “Aggiornamenti in corso”.

Esempio completo:

`18:51  REBOOT_PENDING`

`18:53  ultimo heartbeat`

`19:02  ONLINE_AFTER_REBOOT`

`19:02  UPDATE_OK — KBxxxxxxx`

Console: **COORD-OSS — rientrato — 9m 31s — aggiornamento riuscito**.

Anche se `REBOOT_PENDING` non fosse stato osservato, il backend non perde il nuovo boot: crea una sessione `RIAVVIO_RILEVATO` e conserva comunque l'eventuale informazione di Windows Update.

## Affidabilità

Il risultato post-riavvio viene calcolato una volta per quel boot e viaggia insieme a `ONLINE_AFTER_REBOOT`. Se la rete non è ancora disponibile, l'Agent continua a ritentare; il dato viene considerato consegnato solo quando il backend risponde correttamente.

## Avvio e sicurezza

`agent/Install-W11MonitorAgent.ps1` registra l'Agent come attività AtStartup eseguita da SYSTEM. Endpoint e chiave sono in `monitor-config.json`, protetto per SYSTEM e amministratori locali. La chiave reale non viene salvata nel repository.

## Stato dell'implementazione

**Completato:** Agent v0.4, lettura cronologia Windows Update, invio dei quattro campi di esito, ricezione backend e persistenza in `PC Monitor` e `Reboot Sessions`.

**Prossimo passo:** preparare il primo endpoint dati per la PWA/dashboard, in modo che il telefono possa leggere uno stato già sintetizzato senza dover interpretare direttamente le righe del foglio.

L'idea sarà esporre per ogni PC qualcosa di simile a:

`PC | online/offline | ultimo contatto | reboot pending | durata ultimo reboot | esito ultimo update`

## Per Pietro: cosa significa

Prima avevamo costruito il PC che, appena tornava, sapeva dire: «Windows Update è riuscito / fallito / da verificare».

Ora abbiamo collegato anche l'ultimo metro del percorso: **la centrale riceve quella risposta e la conserva accanto alla durata del riavvio**.

Quindi non abbiamo più due pezzi separati. Abbiamo una catena completa:

**Windows si aggiorna → chiede il riavvio → il PC sparisce → torna → controlla il risultato → comunica il risultato → la centrale lo archivia.**

Il prossimo lavoro non sarà più capire cosa è successo al PC: sarà soprattutto mostrarlo bene sul telefono, con una dashboard immediata e leggibile.
