# Mini console Windows Update — guida semplice

## Dove siamo arrivati

La catena è ora:

`Windows → Agent → HTTPS → Apps Script → PC Monitor + Reboot Sessions → API Dashboard → futura PWA`

L'Agent osserva Windows e manda heartbeat. Il backend conserva stato, riavvii, durata ed esito Windows Update. Da oggi esiste anche il primo **endpoint pensato apposta per la dashboard**: il telefono non dovrà capire le righe di Google Sheet, riceverà già una fotografia sintetica dei PC.

## Che cos'è l'Agent

È un piccolo programma PowerShell che osserva e comunica. Ogni PC ha un Agent ID permanente in `C:\ProgramData\W11UpgradeAssistant\agent.json`. Parte automaticamente con Windows come SYSTEM. Non prende il controllo del PC e non installa aggiornamenti.

## Heartbeat e riavvio

Ogni 30 secondi l'Agent comunica identità, PC, stato, boot, Windows e build. Quando Windows Update richiede un riavvio manda `REBOOT_PENDING`; dopo il nuovo boot manda `ONLINE_AFTER_REBOOT` finché il server conferma la ricezione.

`ONLINE → REBOOT_PENDING → [PC indisponibile] → ONLINE_AFTER_REBOOT → ONLINE`

Il backend trasforma questa sequenza in una Reboot Session e misura l'**indisponibilità osservata** fra ultimo contatto e rientro.

## Esito Windows Update

Dopo il reboot l'Agent legge la cronologia locale di Windows Update. La classificazione resta prudente:

- `UPDATE_OK`: installazione riuscita;
- `UPDATE_OK_CON_ERRORI`: completata ma con errori segnalati;
- `UPDATE_FAILED`: fallita/interrotta;
- `DA_VERIFICARE`: non abbiamo prove sufficienti per attribuire un esito.

Backend e Reboot Sessions conservano anche titolo update, result code e data dell'evento.

## Novità: prima API della dashboard

`Code.gs` espone ora una vista JSON dedicata alla futura PWA. Non restituisce il foglio grezzo: costruisce una scheda già pronta per ogni PC con:

`PC | ONLINE/OFFLINE | ultimo contatto | stato Agent | reboot pending | Windows/build | ultimo esito update | ultimo reboot e durata`

Restituisce anche un riepilogo generale:

`totale PC | online | offline | reboot pending | update falliti`

### Come decidiamo ONLINE/OFFLINE

Questa distinzione non viene affidata allo stato scritto dall'Agent, perché un PC spento non può mandare un messaggio dicendo «sono offline».

La centrale guarda invece **quanto tempo è passato dall'ultimo heartbeat ricevuto dal server**. L'Agent parla ogni 30 secondi; per ora consideriamo ONLINE un PC visto negli ultimi **90 secondi**. Oltre quella soglia la dashboard lo presenta come OFFLINE.

Questo margine evita che un singolo heartbeat perso faccia lampeggiare inutilmente il PC da verde a rosso.

### Sicurezza della dashboard

L'API non usa la chiave degli Agent. Ha una chiave separata, salvata nelle Script Properties con nome `MONITOR_DASHBOARD_KEY`. In questo modo la futura PWA può avere accesso in sola lettura alla fotografia sintetica senza conoscere la credenziale usata dai PC per inviare heartbeat.

La chiamata prevista è concettualmente:

`Web App Apps Script ? api=dashboard & key=CHIAVE_DASHBOARD`

La chiave reale non va inserita nel repository.

## Perché questa API è importante

Prima la futura app avrebbe dovuto leggere un Google Sheet e capire da sola quali colonne significassero cosa. Sarebbe stato fragile: ogni modifica al foglio avrebbe potuto rompere la PWA.

Ora Apps Script fa da **traduttore**. Il foglio resta il nostro archivio semplice; la PWA riceve invece un formato stabile e pensato per lo schermo del telefono.

Esempio di ciò che potremo mostrare:

`COORD-OSS   🟢 ONLINE   ultimo contatto 18 s fa`

`Ultimo reboot: 9,5 min   ✅ UPDATE_OK`

oppure:

`RECEPTION-02   🔴 OFFLINE   ultimo contatto 14 min fa`

## Reboot Sessions

`PC Monitor` è la fotografia LIVE, una riga per PC. `Reboot Sessions` è lo storico permanente dei riavvii significativi. Anche se `REBOOT_PENDING` non fosse stato osservato, un nuovo boot può essere archiviato come `RIAVVIO_RILEVATO` senza inventare che fosse causato da Windows Update.

## Stato dell'implementazione

**Completato:** Agent v0.4; heartbeat; riconoscimento reboot richiesto; rientro dopo nuovo boot; misura indisponibilità; lettura cronologia Windows Update; persistenza dell'esito; Reboot Sessions; prima API dati per dashboard; calcolo server-side ONLINE/OFFLINE; chiave dashboard separata.

**Da testare sul campo:** soglia ONLINE di 90 secondi, associazione dell'update al reboot e comportamento con rete lenta/PC in sospensione.

**Prossimo passo:** costruire la prima pagina PWA mobile che consumi questa API e mostri le card dei PC con priorità visiva: problemi prima, PC sani dopo.

## Per Pietro: cosa abbiamo costruito oggi

Finora avevamo costruito soprattutto la **centrale che capisce cosa succede**. Oggi abbiamo aggiunto il suo sportello di lettura.

Pensa al foglio come al magazzino: contiene tutti i dati. L'API Dashboard è l'addetto che prende quei dati e risponde al telefono con una frase già ordinata: «questi PC sono online, questi offline, questo aspetta un riavvio, questo ha fallito un update e questo ha impiegato 9,5 minuti a tornare».

Questo ci permette di costruire la PWA senza legarla alla struttura interna del foglio. Il prossimo passaggio sarà quindi finalmente molto visibile: **la prima schermata della mini console sul telefono**.
