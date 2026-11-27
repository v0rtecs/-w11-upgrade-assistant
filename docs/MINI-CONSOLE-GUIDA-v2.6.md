# Mini console Windows Update — guida 2.6 (27 novembre 2026)

L'Agent è il piccolo programma sul PC; l'heartbeat è il suo segnale periodico. Il backend riceve i dati, SQLite li conserva e la dashboard li mostra.

## Novità
Il server accetta POST /api/v1/update-history con Content-Type application/json e Authorization: Bearer <chiave individuale>. Il corpo è il JSON prodotto da Get-W11UpdateHistory.ps1 con l'aggiunta di computer_id. La chiave condivisa non è ammessa per questa funzione. Il limite è 2 MiB e 100 voci. Un invio ripetuto non duplica gli esiti. Una risposta 200 con inserted=0 può indicare dati già presenti o una cronologia vuota. 401 indica credenziali non valide, 400 dati non validi, 413 dimensione eccessiva, 415 formato errato, 503 archivio indisponibile.

## Prova locale
Dalla cartella backend eseguire python -m unittest test_update_history_http -v. Il test usa un database temporaneo e un PC simulato; non tocca Windows Update. Il server reale resta su 127.0.0.1; configurare W11_DEVICE_TOKENS_FILE con il registro delle impronte delle chiavi individuali. Non esporre HTTP sulla rete. Prima della produzione servono HTTPS, limiti di connessione e richieste, protezione delle credenziali e collaudo.

## Cosa manca
Invio automatico dall'Agent, gestione dei tentativi e recupero delle voci dopo assenze prolungate, visualizzazione degli esiti, rilevazione installazione in corso, misura dei tempi di ritorno online e PWA installabile. Il tempo fra heartbeat non equivale alla durata effettiva del reboot. Il codice è da collaudare; nessun PC aziendale è stato modificato.
