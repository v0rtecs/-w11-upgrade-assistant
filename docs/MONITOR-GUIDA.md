# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La PWA esistente continua a gestire la checklist operativa e Google Sheets. Il Monitor ha ora un vero ponte di rete: `agent/W11MonitorAgent.ps1` v0.2 sa inviare gli heartbeat al backend Apps Script e `Code.gs` sa autenticarli con una credenziale dedicata.

La catena è quindi diventata:

`Windows → Agent → HTTPS → Apps Script → PC Monitor`

La dashboard LIVE sul telefono è il prossimo anello.

## Che cos'è l'Agent

È un piccolo programma che gira sul PC da monitorare. Non sostituisce AnyDesk e non controlla il computer: osserva e comunica.

Ogni PC riceve al primo avvio un identificativo permanente, per esempio `GG-7F3A91C2`. Viene conservato in `C:\ProgramData\W11UpgradeAssistant\agent.json`, quindi il PC rimane riconoscibile anche se il suo nome Windows cambia.

## Il battito: heartbeat

Ogni 30 secondi l'Agent invia un messaggio molto piccolo con Agent ID, versione Agent, nome PC, stato, data e ora, ultimo avvio di Windows, edizione e build di Windows.

È l'equivalente del PC che telefona alla centrale e dice: «Sono GG-7F3A91C2, sono COORD-OSS, sono acceso e questo è il mio stato».

## La novità della v0.2: il ponte è reale

La v0.1 costruiva il messaggio ma lo mostrava soltanto localmente. La v0.2 usa HTTPS per spedirlo davvero all'endpoint Apps Script configurato.

La configurazione locale vive in:

`C:\ProgramData\W11UpgradeAssistant\monitor-config.json`

Formato previsto:

```json
{
  "endpoint": "URL-DELLA-WEB-APP-APPS-SCRIPT",
  "agentKey": "CHIAVE-AGENT-GENERATA-IN-MODO-CASUALE"
}
```

La chiave reale NON deve essere salvata nel repository GitHub.

## Perché abbiamo due chiavi

La PWA e gli Agent sono due cose diverse. La PWA continua a usare la propria chiave di sincronizzazione. Gli Agent usano invece `MONITOR_AGENT_KEY`.

Nel backend la chiave Agent non viene scritta nel sorgente `Code.gs`: viene conservata nelle Script Properties di Apps Script. Questo evita di pubblicare una credenziale nel repository.

In italiano normale: è come avere una chiave per la porta dell'ufficio e una diversa per il locale tecnico. Se una viene cambiata, non dobbiamo necessariamente cambiare anche l'altra.

Il backend inoltre lavora in modalità fail-closed: se `MONITOR_AGENT_KEY` non è stata configurata, rifiuta tutti gli heartbeat invece di accettarli senza controllo.

## Cosa succede se Internet non è pronto dopo il riavvio

Questo è un dettaglio importante. Windows può essere già partito mentre Wi-Fi/LAN o DNS non sono ancora pronti.

Se il primo heartbeat fallisce, l'Agent NON si chiude. Scrive l'errore nel log locale e riprova dopo 30 secondi.

Ancora più importante: se deve comunicare `ONLINE_AFTER_REBOOT`, conserva quello stato finché il backend non lo riceve con successo. Solo dopo passa a `ONLINE`.

Così non perdiamo l'informazione più importante proprio perché la rete si è svegliata dieci secondi dopo Windows.

## Log locale

Per diagnosticare un PC senza indovinare, l'Agent scrive un piccolo log in:

`C:\ProgramData\W11UpgradeAssistant\monitor-agent.log`

Registra avvio, heartbeat riusciti ed errori di collegamento. La chiave Agent non viene scritta nel log.

## Dove finiscono i battiti

Il backend usa il foglio separato `PC Monitor`. Ogni Agent occupa una sola riga: un nuovo heartbeat aggiorna la stessa riga invece di aggiungerne una ogni 30 secondi.

Le colonne sono:

`Agent ID | PC | Agent Version | Stato | Ultimo contatto server | Timestamp Agent UTC | Boot UTC | Windows | Build`

`Ultimo contatto server` viene scritto dal backend, non dal PC. Così un orologio Windows sbagliato non altera lo stato LIVE.

## Come riconosce un riavvio

L'Agent salva l'ultimo boot in `C:\ProgramData\W11UpgradeAssistant\state.json`. Quando riparte confronta il boot precedente con quello attuale. Se sono diversi, invia `ONLINE_AFTER_REBOOT`.

Questo ci permette di distinguere un PC che torna dopo un vero riavvio da un normale heartbeat.

## Cosa manca prima del primo test reale

Servono tre operazioni di configurazione, non nuovo codice:

1. impostare `MONITOR_AGENT_KEY` nelle Script Properties del progetto Apps Script;
2. distribuire/deployare la nuova versione di `Code.gs` come Web App;
3. creare `monitor-config.json` su un solo PC pilota con URL Web App e chiave Agent.

Solo dopo conviene installare l'Agent come servizio/attività automatica. Prima testeremo un singolo PC, così qualsiasi errore resta circoscritto.

## Per Pietro: cosa abbiamo ottenuto oggi

Prima avevamo costruito due telefoni che non erano ancora collegati. L'Agent sapeva cosa dire e il backend sapeva cosa ascoltare, ma tra i due mancava la linea.

Ora la linea esiste ed è protetta da una chiave dedicata.

Quando faremo il test pilota, il risultato atteso sarà molto semplice:

`COORD-OSS → heartbeat → Apps Script → riga PC Monitor aggiornata`

Da lì potremo finalmente costruire la schermata del telefono con pallini verdi, arancioni e rossi basati su dati reali.
