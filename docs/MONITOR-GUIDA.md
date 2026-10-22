# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena tecnica è:

`Windows → Agent → HTTPS → Apps Script → PC Monitor`

L'Agent parte automaticamente con Windows, senza login, e dalla versione 0.3 riconosce anche quando **Windows Update ha già stabilito che serve un riavvio**.

## Che cos'è l'Agent

È un piccolo programma che gira sul PC da monitorare. Non sostituisce AnyDesk e non controlla il computer: osserva e comunica. Ogni PC riceve un Agent ID permanente, per esempio `GG-7F3A91C2`, conservato in `C:\ProgramData\W11UpgradeAssistant\agent.json`.

## Heartbeat

Ogni 30 secondi l'Agent invia Agent ID, versione, nome PC, stato, data/ora, ultimo avvio di Windows, edizione e build. È come se il PC telefonasse alla centrale dicendo: «Sono questo PC, sono vivo e questo è il mio stato».

## Novità v0.3: REBOOT_PENDING

L'Agent controlla il segnale `WindowsUpdate\Auto Update\RebootRequired` nel registro di Windows. Quando Windows Update crea questo indicatore, il monitor passa da:

`ONLINE`

a:

`REBOOT_PENDING`

senza aspettare che il PC si spenga.

In italiano normale: prima sapevamo che il PC si era riavviato soltanto quando lo vedevamo tornare. Adesso riusciamo anche a sentirgli dire prima: **«Ho finito una fase dell'aggiornamento e Windows Update vuole che mi riavvii.»**

Questo è prezioso perché, se poco dopo spariscono gli heartbeat, il backend avrà un forte indizio che l'assenza è collegata all'aggiornamento e non a un cavo staccato o a uno spegnimento casuale.

Abbiamo scelto volutamente un segnale conservativo: per ora `REBOOT_PENDING` riguarda il marcatore specifico di Windows Update. Non etichettiamo automaticamente come aggiornamento ogni generica richiesta di reboot di Windows.

## Avvio automatico

`agent/Install-W11MonitorAgent.ps1` prepara `C:\ProgramData\W11UpgradeAssistant`, configura l'Agent e registra l'attività `W11 Upgrade Assistant Monitor`, eseguita AtStartup come SYSTEM. Non dobbiamo aspettare il login di un utente.

## Protezione della chiave

`C:\ProgramData\W11UpgradeAssistant\monitor-config.json` contiene endpoint HTTPS e chiave Agent. I permessi vengono limitati a SYSTEM e amministratori locali. La chiave reale non va salvata su GitHub; il backend conserva `MONITOR_AGENT_KEY` nelle Script Properties.

## Dopo un riavvio

L'Agent confronta il boot precedente con quello attuale. Se sono diversi, invia `ONLINE_AFTER_REBOOT`. Se la rete non è ancora pronta, continua a riprovare questo stato finché il server non lo riceve, poi torna alla rilevazione LIVE.

La sequenza che vogliamo osservare diventa quindi:

`ONLINE → REBOOT_PENDING → [heartbeat assente durante reboot] → ONLINE_AFTER_REBOOT → ONLINE`

Questo ci dà già gli estremi necessari per calcolare il tempo di indisponibilità osservato.

## Esempio pratico

`18:42  ONLINE`

`18:51  REBOOT_PENDING`

`18:53  ultimo heartbeat prima del riavvio`

`19:02  ONLINE_AFTER_REBOOT`

La console potrà mostrare qualcosa come:

**Aggiornamento con riavvio — PC tornato online — indisponibilità osservata circa 9 minuti.**

È importante chiamarla inizialmente “indisponibilità osservata”: non pretendiamo di conoscere il secondo esatto in cui firmware/Windows hanno iniziato e terminato ogni fase mentre l'Agent non poteva funzionare.

## Log locale

`C:\ProgramData\W11UpgradeAssistant\monitor-agent.log` registra avvio, heartbeat riusciti ed errori. La chiave non viene scritta nel log.

## PC Monitor

Ogni Agent occupa una riga nel foglio `PC Monitor`; ogni heartbeat aggiorna quella riga. L'ultimo contatto è stabilito dal server, non dall'orologio del PC.

## Cosa manca

I prossimi passi sono: far conservare al backend gli **eventi importanti** separatamente dagli heartbeat; trasformare `REBOOT_PENDING + perdita heartbeat + ONLINE_AFTER_REBOOT` in una sessione di reboot con durata; verificare l'esito dell'aggiornamento; infine mostrare tutto nella schermata LIVE della PWA.

## Per Pietro: cosa abbiamo ottenuto oggi

Prima il nostro “centralino” poteva capire: «il PC era vivo, è sparito, poi è tornato».

Adesso il PC può avvisare prima: **«Windows Update mi chiede un riavvio.»** Questo rende molto più intelligente ciò che succederà dopo: quando il battito sparisce, non dobbiamo trattarlo immediatamente come un guasto. È il primo pezzo che ci permette di distinguere un normale reboot da un PC misteriosamente offline.
