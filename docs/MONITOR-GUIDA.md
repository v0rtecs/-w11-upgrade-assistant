# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La PWA esistente continua a gestire la checklist operativa e la sincronizzazione con Google Sheets. Il componente `agent/W11MonitorAgent.ps1` è il primo prototipo dell'Agent automatico.

Ora abbiamo progettato e implementato anche il primo punto di arrivo degli heartbeat nel backend Apps Script. `Code.gs` riconosce i messaggi con `type: heartbeat` e li tiene separati dalle normali sessioni della checklist.

## Che cos'è l'Agent

È un piccolo programma che gira sul PC da monitorare. Non sostituisce AnyDesk e non controlla il computer: osserva e comunica.

Ogni PC riceve al primo avvio un identificativo permanente, per esempio `GG-7F3A91C2`. L'identificativo viene salvato in `C:\ProgramData\W11UpgradeAssistant\agent.json`, quindi il PC rimane riconoscibile anche se il suo nome Windows viene cambiato.

## Il battito: heartbeat

Ogni 30 secondi l'Agent costruisce un messaggio chiamato heartbeat. Contiene solo informazioni utili al monitoraggio: Agent ID, versione Agent, nome PC, stato, data e ora, ultimo avvio di Windows, edizione e build di Windows.

Il backend adesso sa già ricevere questo formato. Il prossimo collegamento consiste nell'attivare nell'Agent il POST verso l'URL Apps Script con una credenziale dedicata al monitor.

## Dove finiscono i battiti

Il backend usa un foglio separato chiamato `PC Monitor`. Se non esiste, Apps Script lo crea automaticamente al primo heartbeat.

Ogni Agent occupa una sola riga. Un nuovo heartbeat aggiorna quella riga invece di aggiungerne una ogni 30 secondi. Questo è importante: 30 PC con un battito ogni 30 secondi produrrebbero 86.400 righe al giorno. Per la schermata LIVE ci serve invece solo l'ultimo stato conosciuto di ogni PC.

Le colonne previste sono:

`Agent ID | PC | Agent Version | Stato | Ultimo contatto server | Timestamp Agent UTC | Boot UTC | Windows | Build`

`Ultimo contatto server` viene scritto dal backend, non dal PC. Così un orologio Windows impostato male non può far sembrare un computer online quando non lo è.

## Come la dashboard saprà se un PC è online

Il principio sarà semplicissimo. Se l'ultimo contatto server è recente, il PC è ONLINE. Se gli heartbeat smettono di arrivare, la dashboard guarda da quanto tempo manca il battito e quale stato aveva comunicato il PC prima di sparire.

Per esempio:

- heartbeat recente → `ONLINE`;
- heartbeat assente dopo un riavvio annunciato → `REBOOTING`;
- assenza troppo lunga dopo il riavvio → `REBOOT_TIMEOUT`;
- heartbeat che ricompare con nuovo boot → `ONLINE_AFTER_REBOOT`.

## Come riconosce un riavvio

Windows conserva l'ora del proprio ultimo avvio. L'Agent salva quell'ora in `C:\ProgramData\W11UpgradeAssistant\state.json`.

Quando parte nuovamente confronta `ultimo avvio precedente` con `ultimo avvio attuale`. Se sono diversi, il primo heartbeat viene marcato `ONLINE_AFTER_REBOOT`; quelli successivi tornano a `ONLINE`.

## Perché non salviamo tutti gli heartbeat

Un heartbeat è come chiedere continuamente «sei vivo?». Non ha senso conservare per sempre ogni singolo «sì».

`PC Monitor` sarà quindi la fotografia LIVE: una riga per PC, continuamente aggiornata. Più avanti creeremo un secondo registro storico soltanto per gli eventi importanti: inizio aggiornamento, riavvio, rientro, successo, errore e timeout. Così potremo calcolare durata dei reboot e statistiche senza riempire inutilmente Google Sheets.

## La catena del progetto

Oggi abbiamo:

`Windows → Agent → heartbeat costruito`

`backend → ricezione heartbeat → riga PC Monitor`

Manca il collegamento di rete tra i due e poi la visualizzazione LIVE nella PWA:

`Windows → Agent → backend → PC Monitor → dashboard telefono`

## Principio di sicurezza

L'Agent deve avere privilegi minimi. Non invieremo password AnyDesk, documenti, nomi di file o contenuti personali. Inoltre la credenziale usata dagli Agent non dovrebbe essere la stessa chiave utilizzata dalla PWA: prima di attivare l'invio reale separeremo le due autorizzazioni.
