# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena tecnica è:

`Windows → Agent → HTTPS → Apps Script → PC Monitor + Reboot Sessions`

L'Agent parte automaticamente con Windows, senza login. Riconosce quando Windows Update richiede un riavvio e, da oggi, il backend trasforma quei segnali in una vera **sessione di reboot** con un cronometro dell'indisponibilità osservata.

## Che cos'è l'Agent

È un piccolo programma che gira sul PC da monitorare. Non sostituisce AnyDesk e non controlla il computer: osserva e comunica. Ogni PC riceve un Agent ID permanente, per esempio `GG-7F3A91C2`, conservato in `C:\ProgramData\W11UpgradeAssistant\agent.json`.

## Heartbeat

Ogni 30 secondi l'Agent invia Agent ID, versione, nome PC, stato, data/ora, ultimo avvio di Windows, edizione e build. È come se il PC telefonasse alla centrale dicendo: «Sono questo PC, sono vivo e questo è il mio stato».

## REBOOT_PENDING

L'Agent controlla il segnale `WindowsUpdate\Auto Update\RebootRequired` nel registro di Windows. Quando Windows Update crea questo indicatore, il monitor passa da `ONLINE` a `REBOOT_PENDING` senza aspettare che il PC si spenga.

Abbiamo scelto volutamente un segnale conservativo: non etichettiamo automaticamente come aggiornamento ogni generica richiesta di reboot di Windows.

## Novità: Reboot Sessions

Il backend ora crea automaticamente il foglio `Reboot Sessions`. Non salviamo ogni heartbeat per sempre: salviamo invece l'evento importante.

Quando arriva il primo `REBOOT_PENDING`, viene aperta una sessione con un ID come `RB-12AB34CD` e stato `IN_ATTESA_RIENTRO`. Gli heartbeat successivi con lo stesso stato non creano duplicati.

Quando, dopo il riavvio, l'Agent invia `ONLINE_AFTER_REBOOT`, il backend chiude quella sessione e registra:

- PC e Agent ID;
- quando Windows Update ha richiesto il riavvio;
- l'ultimo contatto server precedente al rientro;
- l'ora in cui il PC è tornato online;
- il nuovo Boot UTC;
- i secondi e i minuti di indisponibilità osservata;
- l'esito `RIENTRATO`.

Se il backend vede `ONLINE_AFTER_REBOOT` senza aver prima ricevuto `REBOOT_PENDING`, non butta via l'informazione: registra comunque un `RIAVVIO_RILEVATO`. Questo copre, per esempio, un riavvio manuale o un segnale pending che non siamo riusciti a osservare.

## Come funziona il cronometro

Esempio:

`18:51:10  REBOOT_PENDING`

`18:53:02  ultimo heartbeat ricevuto`

`19:02:33  ONLINE_AFTER_REBOOT`

Il backend calcola:

`19:02:33 - 18:53:02 = 9 minuti e 31 secondi`

La console potrà quindi mostrare:

**COORD-OSS — rientrato — indisponibilità osservata 9m 31s**

### Perché diciamo “indisponibilità osservata”

È una distinzione importante. L'Agent gira dentro Windows: mentre il PC è spento o Windows sta applicando gli aggiornamenti, l'Agent non può parlare. Il nostro cronometro misura quindi il tempo tra l'ultimo contatto ricevuto e il primo contatto dopo il nuovo boot. Con heartbeat ogni 30 secondi, l'inizio dell'assenza ha una piccola tolleranza legata proprio a quell'intervallo.

Non fingiamo quindi di conoscere il secondo esatto mostrato dalla schermata “Aggiornamenti in corso”. Misuriamo invece una cosa verificabile e molto utile operativamente: **per quanto tempo il PC non è stato disponibile alla centrale**.

## Avvio automatico

`agent/Install-W11MonitorAgent.ps1` prepara `C:\ProgramData\W11UpgradeAssistant`, configura l'Agent e registra l'attività `W11 Upgrade Assistant Monitor`, eseguita AtStartup come SYSTEM. Non dobbiamo aspettare il login di un utente.

## Protezione della chiave

`C:\ProgramData\W11UpgradeAssistant\monitor-config.json` contiene endpoint HTTPS e chiave Agent. I permessi vengono limitati a SYSTEM e amministratori locali. La chiave reale non va salvata su GitHub; il backend conserva `MONITOR_AGENT_KEY` nelle Script Properties.

## Dopo un riavvio

L'Agent confronta il boot precedente con quello attuale. Se sono diversi, invia `ONLINE_AFTER_REBOOT`. Se la rete non è ancora pronta, continua a riprovare questo stato finché il server non lo riceve, poi torna alla rilevazione LIVE.

La sequenza completa è ora:

`ONLINE → REBOOT_PENDING → [heartbeat assente] → ONLINE_AFTER_REBOOT → ONLINE`

Il backend la trasforma in:

`sessione aperta → attesa → sessione chiusa + durata`

## Log locale

`C:\ProgramData\W11UpgradeAssistant\monitor-agent.log` registra avvio, heartbeat riusciti ed errori. La chiave non viene scritta nel log.

## PC Monitor e Reboot Sessions

`PC Monitor` è la fotografia LIVE: una riga per PC, aggiornata a ogni heartbeat.

`Reboot Sessions` è invece lo storico: una riga per riavvio significativo. Questa separazione evita di riempire il foglio con migliaia di battiti e ci permette di conservare ciò che interessa davvero.

## Cosa manca

Il prossimo passo è aggiungere la **verifica dell'esito di Windows Update** dopo il rientro. Vogliamo distinguere almeno `UPDATE_OK`, `UPDATE_FAILED` e `DA_VERIFICARE`, collegando l'esito alla sessione di reboot. Dopo quello porteremo PC Monitor e Reboot Sessions nella schermata LIVE della PWA con stati immediatamente leggibili.

## Per Pietro: cosa abbiamo ottenuto oggi

Prima il centralino sapeva che un PC voleva riavviarsi e che, prima o poi, era tornato.

Adesso prende carta e penna da solo: apre una pratica quando Windows Update chiede il riavvio, aspetta il ritorno del PC, chiude la pratica e scrive **quanto è rimasto indisponibile**.

Quindi non avremo più soltanto «è tornato». Avremo qualcosa del tipo:

**RECEPTION-02 — aggiornamento con riavvio — rientrato — 8,7 minuti di indisponibilità.**

Il prossimo salto sarà far rispondere automaticamente anche all'ultima domanda: **“È tornato, ma l'aggiornamento è riuscito?”**
