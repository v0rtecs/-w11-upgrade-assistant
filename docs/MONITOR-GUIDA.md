# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La PWA esistente continua a gestire la checklist operativa e la sincronizzazione con Google Sheets. Il nuovo componente `agent/W11MonitorAgent.ps1` è il primo prototipo dell'Agent automatico.

## Che cos'è l'Agent

È un piccolo programma che gira sul PC da monitorare. Non sostituisce AnyDesk e non controlla il computer: per ora osserva e comunica.

Ogni PC riceve al primo avvio un identificativo permanente, per esempio `GG-7F3A91C2`. L'identificativo viene salvato in `C:\ProgramData\W11UpgradeAssistant\agent.json`, quindi il PC rimane riconoscibile anche se il suo nome Windows viene cambiato.

## Il battito: heartbeat

Ogni 30 secondi l'Agent costruisce un messaggio chiamato heartbeat. Contiene solo informazioni utili al monitoraggio:

- Agent ID;
- versione dell'Agent;
- nome del PC;
- stato;
- data e ora;
- ultimo avvio di Windows;
- edizione e build di Windows.

Nella versione 0.1 il messaggio viene soltanto mostrato localmente. Non viene ancora spedito su Internet: prima definiamo il punto di ricezione e l'autenticazione del backend.

## Come riconosce un riavvio

Windows conserva l'ora del proprio ultimo avvio. L'Agent salva quell'ora in `C:\ProgramData\W11UpgradeAssistant\state.json`.

Quando parte nuovamente confronta:

`ultimo avvio precedente` → `ultimo avvio attuale`

Se sono diversi, significa che nel frattempo Windows è stato riavviato. Il primo heartbeat viene quindi marcato `ONLINE_AFTER_REBOOT`; quelli successivi tornano a `ONLINE`.

Questo è importante perché ci permette di sapere con certezza che il PC è tornato operativo senza doverlo guardare con AnyDesk.

## Cosa abbiamo davvero oggi

La catena attuale è:

`Windows → Agent → identità permanente → rilevazione nuovo boot → heartbeat locale`

La catena che vogliamo ottenere è:

`Windows → Agent → backend → dashboard/PWA sul telefono`

## Cosa manca ancora

Il prossimo passo è aggiungere al backend un endpoint dedicato agli heartbeat. L'Agent potrà allora inviare il proprio JSON ogni 30 secondi e la PWA potrà calcolare `ONLINE`, `OFFLINE`, `REBOOTING` e `REBOOT_TIMEOUT` in base all'ultimo contatto.

Dopo questo aggiungeremo la lettura degli eventi Windows Update per distinguere un normale riavvio da un riavvio causato da un aggiornamento e verificarne l'esito.

## Principio di sicurezza

L'Agent deve avere privilegi minimi. Non invieremo password AnyDesk, documenti, nomi di file o contenuti personali. Gli heartbeat conterranno solo telemetria tecnica necessaria alla console.
