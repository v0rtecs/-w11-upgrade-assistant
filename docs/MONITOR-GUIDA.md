# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena tecnica è:

`Windows → Agent → HTTPS → Apps Script → PC Monitor + Reboot Sessions`

L'Agent parte automaticamente con Windows, senza login. Riconosce quando Windows Update richiede un riavvio, il backend misura l'indisponibilità e ora l'Agent v0.4 sa anche leggere la cronologia di Windows Update dopo il nuovo avvio.

## Che cos'è l'Agent

È un piccolo programma PowerShell che osserva e comunica. Ogni PC ha un Agent ID permanente in `C:\ProgramData\W11UpgradeAssistant\agent.json`. Non controlla il PC e non installa aggiornamenti.

## Heartbeat e riavvio

Ogni 30 secondi l'Agent invia identità, nome PC, stato, data/ora, boot, Windows e build. Quando compare il marcatore specifico di Windows Update `RebootRequired`, invia `REBOOT_PENDING`. Dopo un nuovo boot invia `ONLINE_AFTER_REBOOT` finché il server non lo riceve.

La sequenza è:

`ONLINE → REBOOT_PENDING → [PC indisponibile] → ONLINE_AFTER_REBOOT → ONLINE`

Il backend trasforma questa sequenza in una Reboot Session e misura il tempo fra ultimo contatto e rientro.

## Novità v0.4: è riuscito davvero?

Al rientro non ci basta più sapere che Windows si è riacceso. L'Agent interroga la cronologia locale di Windows Update tramite l'interfaccia di Windows Update e cerca le installazioni completate attorno al nuovo boot.

Il risultato viene classificato in modo prudente:

- `UPDATE_OK`: Windows registra l'installazione come riuscita;
- `UPDATE_OK_CON_ERRORI`: completata, ma Windows segnala errori;
- `UPDATE_FAILED`: fallita o interrotta;
- `DA_VERIFICARE`: non abbiamo una prova abbastanza chiara per attribuire un esito.

Insieme allo stato l'Agent può inviare titolo dell'aggiornamento, codice risultato e data registrata da Windows Update.

### Perché DA_VERIFICARE è importante

Non vogliamo che la console dica «aggiornamento riuscito» solo perché il PC è tornato online. Un riavvio può avvenire per altri motivi e la cronologia può non contenere un evento abbastanza vicino. In quel caso la risposta corretta è `DA_VERIFICARE`, non una supposizione.

Per ora l'Agent considera una finestra prudenziale di sei ore prima del boot e controlla fino a 50 eventi recenti. È una prima euristica: durante i test reali la renderemo più precisa collegando l'aggiornamento osservato prima del reboot con quello registrato dopo.

## Reboot Sessions

`PC Monitor` è la fotografia LIVE: una riga per PC. `Reboot Sessions` è lo storico dei riavvii significativi. Il cronometro misura l'**indisponibilità osservata**, non pretende di conoscere il secondo esatto mostrato nella schermata “Aggiornamenti in corso”.

Esempio futuro completo:

`18:51  REBOOT_PENDING`

`18:53  ultimo heartbeat`

`19:02  ONLINE_AFTER_REBOOT`

`19:02  UPDATE_OK — KBxxxxxxx`

Console: **COORD-OSS — rientrato — 9m 31s — aggiornamento riuscito**.

## Affidabilità

Il risultato post-riavvio viene calcolato una volta per quel boot e viaggia insieme a `ONLINE_AFTER_REBOOT`. Se la rete non è ancora disponibile, l'Agent continua a ritentare; il dato viene considerato consegnato solo quando il backend risponde correttamente.

## Avvio e sicurezza

`agent/Install-W11MonitorAgent.ps1` registra l'Agent come attività AtStartup eseguita da SYSTEM. Endpoint e chiave sono in `monitor-config.json`, protetto per SYSTEM e amministratori locali. La chiave reale non viene salvata nel repository.

## Stato dell'implementazione

**Fatto nel codice oggi:** Agent v0.4, lettura della cronologia Windows Update e aggiunta dei campi `updateStatus`, `updateTitle`, `updateResultCode`, `updateDateUtc` al heartbeat post-riavvio.

**Ancora da completare:** il backend deve salvare questi quattro nuovi campi dentro `PC Monitor` e `Reboot Sessions`. L'aggiornamento del backend non è stato applicato in questa sessione, quindi non dichiariamo questa parte finita finché non è realmente nel repository.

Dopo questo collegamento porteremo esito e durata nella PWA mobile con indicatori immediati.

## Per Pietro: cosa significa

Prima la centrale poteva dire: «il PC è tornato dopo 9 minuti».

Adesso il PC, appena torna, può anche guardare il proprio registro di Windows Update e aggiungere: «Windows dice che l'installazione è riuscita», «è fallita» oppure «non ho abbastanza elementi: controllami».

È un passaggio importante perché separa due domande diverse: **il PC è tornato?** e **l'aggiornamento è andato bene?**. La mini console sta iniziando a rispondere a entrambe, senza inventare certezze che Windows non ci dà.
