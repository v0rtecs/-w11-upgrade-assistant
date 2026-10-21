# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena tecnica è ora:

`Windows → Agent → HTTPS → Apps Script → PC Monitor`

In più abbiamo risolto un punto essenziale: **l'Agent può partire da solo ad ogni avvio di Windows**, senza login dell'utente e senza che qualcuno debba aprire PowerShell.

## Che cos'è l'Agent

È un piccolo programma che gira sul PC da monitorare. Non sostituisce AnyDesk e non controlla il computer: osserva e comunica.

Ogni PC riceve al primo avvio un identificativo permanente, per esempio `GG-7F3A91C2`, conservato in `C:\ProgramData\W11UpgradeAssistant\agent.json`.

## Il battito: heartbeat

Ogni 30 secondi l'Agent invia un piccolo messaggio con Agent ID, versione Agent, nome PC, stato, data e ora, ultimo avvio di Windows, edizione e build di Windows.

È l'equivalente del PC che telefona alla centrale e dice: «Sono GG-7F3A91C2, sono COORD-OSS, sono acceso e questo è il mio stato».

## Novità: avvio automatico

Il file `agent/Install-W11MonitorAgent.ps1` prepara il PC pilota. Copia l'Agent in `C:\ProgramData\W11UpgradeAssistant`, crea la configurazione e registra una Attività pianificata di Windows chiamata `W11 Upgrade Assistant Monitor`.

L'attività parte **AtStartup**, cioè quando parte Windows, e gira con l'account di sistema `SYSTEM`. Questo è importante: non dobbiamo aspettare che Pietro o un collega faccia login.

In italiano normale: prima il nostro addetto al monitoraggio doveva essere chiamato manualmente. Adesso ha la sveglia incorporata. Appena Windows si alza, si alza anche lui.

L'installer avvia inoltre subito l'Agent, quindi per il primo test non serve riavviare il PC.

## Perché usiamo un'Attività pianificata

Per il prototipo è più semplice e trasparente di costruire subito un vero Windows Service. Windows la gestisce nativamente, può eseguirla come SYSTEM e può rilanciarla se il processo termina.

La configurazione prevede fino a 5 tentativi di riavvio del processo, distanziati di un minuto. L'Agent non ha un limite di durata imposto dal task.

Se in seguito vorremo trasformarlo in un servizio Windows vero e proprio, potremo farlo senza cambiare il protocollo heartbeat o il backend.

## Protezione della chiave Agent

La configurazione locale vive in:

`C:\ProgramData\W11UpgradeAssistant\monitor-config.json`

Contiene endpoint HTTPS e chiave Agent. L'installer restringe i permessi del file a `SYSTEM` e agli amministratori locali, così un normale utente del PC non dovrebbe poter leggere la credenziale.

La chiave reale non deve mai essere salvata nel repository GitHub.

Il backend conserva `MONITOR_AGENT_KEY` nelle Script Properties di Apps Script e lavora in modalità fail-closed: se la chiave non è configurata, rifiuta gli heartbeat.

## Cosa succede se Internet non è pronto dopo il riavvio

Se il primo heartbeat fallisce, l'Agent non si chiude: registra l'errore e riprova dopo 30 secondi.

Se deve comunicare `ONLINE_AFTER_REBOOT`, conserva quello stato finché il backend non lo riceve con successo. Solo dopo passa a `ONLINE`.

Questo evita di perdere l'informazione del rientro solo perché LAN, Wi-Fi o DNS si sono avviati qualche secondo dopo Windows.

## Log locale

Il log è:

`C:\ProgramData\W11UpgradeAssistant\monitor-agent.log`

Registra avvio, heartbeat riusciti ed errori di collegamento. La chiave Agent non viene scritta nel log.

## Dove finiscono i battiti

Il backend usa il foglio `PC Monitor`. Ogni Agent occupa una sola riga; un nuovo heartbeat aggiorna quella riga invece di aggiungerne una ogni 30 secondi.

Le colonne previste sono:

`Agent ID | PC | Agent Version | Stato | Ultimo contatto server | Timestamp Agent UTC | Boot UTC | Windows | Build`

L'ultimo contatto viene stabilito dal server, non dall'orologio del PC.

## Come riconosce un riavvio

L'Agent salva l'ultimo boot in `C:\ProgramData\W11UpgradeAssistant\state.json`. Quando riparte confronta il boot precedente con quello attuale. Se sono diversi invia `ONLINE_AFTER_REBOOT`.

## Come installeremo il PC pilota

Quando endpoint Apps Script e `MONITOR_AGENT_KEY` saranno pronti, da PowerShell aperto come amministratore useremo l'installer passando quei due valori. L'installer controlla che l'endpoint sia HTTPS e che la chiave abbia almeno 24 caratteri.

Il risultato atteso è:

`Avvio Windows → Task SYSTEM → Agent → heartbeat → Apps Script → PC Monitor`

Da quel momento l'Agent non dipende più dall'utente collegato al PC.

## Cosa manca

Prima del test reale dobbiamo ancora:

1. impostare `MONITOR_AGENT_KEY` nelle Script Properties di Apps Script;
2. deployare il backend aggiornato come Web App;
3. eseguire l'installer su un solo PC pilota;
4. verificare heartbeat e rientro dopo un riavvio reale;
5. costruire la schermata LIVE della PWA con stati verde/arancione/rosso.

## Per Pietro: cosa abbiamo ottenuto con questo passo

Questa modifica sembra piccola, ma è fondamentale per il progetto.

Se il monitor richiedesse di aprire manualmente un programma dopo ogni reboot, non potrebbe mai controllare seriamente i reboot di Windows Update.

Ora invece Windows può riavviarsi, arrivare alla schermata di accesso senza che nessuno tocchi il PC e l'Agent è già in funzione. È esattamente il comportamento necessario per poter dire dal telefono: «questo PC è tornato vivo».
