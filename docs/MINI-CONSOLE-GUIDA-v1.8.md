# Mini console Windows Update — guida semplice v1.8 (19 novembre 2026)

## Cosa stiamo costruendo
Un piccolo programma (Agent) su ogni PC comunica periodicamente con una centrale (backend). La centrale conserva gli ultimi contatti e riconosce quando Windows è stato riavviato. In futuro una pagina utilizzabile dal telefono (PWA) mostrerà quali PC sono online, quali hanno completato gli aggiornamenti e quali richiedono attenzione.

## Novità: una chiave diversa per ogni PC
Prima tutti i computer condividevano una sola password tecnica. Ora il server può usare un registro che associa **ogni identificativo PC** all'impronta SHA-256 della sua chiave personale. Se un PC viene dismesso, si elimina la sua voce: gli altri continuano a funzionare. La chiave non viene conservata in chiaro sul server, ma deve essere protetta anche sul PC.

Il server legge il percorso del registro dalla variabile `W11_DEVICE_TOKENS_FILE`. Se la variabile non è impostata, rimane disponibile la precedente modalità con chiave condivisa `W11_AGENT_TOKEN`, **solo per prove locali**. Con il registro attivo, il server controlla che la chiave corrisponda proprio al `computer_id` dichiarato dal messaggio.

### Preparazione del registro (esempio)
Generare per ogni PC un segreto casuale di almeno 32 caratteri, preferibilmente 32 byte casuali rappresentati in esadecimale. Inserire nel JSON soltanto il digest SHA-256, non il segreto:

```json
{"reception-01":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
```

Il valore `aaaa...` è **solo un segnaposto**, non una chiave utilizzabile. Salvare il file fuori dal repository, con accesso limitato all'account del servizio. Non pubblicare mai le chiavi né il registro operativo su GitHub.

### Come eseguire i test
Dalla cartella `backend`: `python -m unittest test_device_auth.py`.
Per avviare il server in modalità registro, impostare `W11_DEVICE_TOKENS_FILE` sul percorso del JSON e poi eseguire `python heartbeat_server.py`. Il servizio resta in ascolto soltanto su `127.0.0.1`.

## Cosa manca
Questa versione **non è pronta per la rete aziendale**: manca HTTPS tramite proxy, distribuzione sicura dei segreti, rotazione delle credenziali, collaudo Windows e gestione amministrativa dei PC. Non installa aggiornamenti e non riavvia macchine. Il tempo offline fra due heartbeat è una stima, non il tempo esatto del riavvio. L'esito Windows Update va ancora raccolto e correlato agli eventi di avvio.

## Prossimo passo
Test HTTP completi con due PC simulati e credenziali differenti, poi Agent Windows con invio autenticato e dashboard di sola lettura.
