# Mini console Windows Update — guida semplice v1.7 (18 novembre 2026)

## Che cosa stiamo costruendo?
Un piccolo programma (Agent) su ogni PC raccoglierà informazioni sullo stato di Windows Update e invierà un messaggio periodico, chiamato **heartbeat**, a un server centrale (backend). Una dashboard consultabile dal telefono mostrerà quali PC rispondono, quali hanno cambiato avvio e quali richiedono attenzione.

## Novità v1.7: proviamo davvero il collegamento HTTP
Abbiamo aggiunto `backend/test_heartbeat_server.py`: avvia il server **solo sul computer di prova**, con porta casuale, e gli invia richieste come farebbe un Agent. Usa un database temporaneo, poi lo elimina.

Verifica:
1. richiesta senza password o con password sbagliata: rifiutata;
2. indirizzo sbagliato, formato non JSON, JSON non valido, messaggio troppo grande: rifiutati;
3. primo contatto: registrato;
4. stesso messaggio ripetuto: non produce un secondo evento;
5. identificativo di avvio cambiato: viene registrato un BOOT_CHANGED;
6. errore della sonda: non viene inventato un riavvio.

## Come eseguire la prova
Occorre Python 3.9 o successivo. Dal percorso principale del progetto:

```powershell
cd backend
python -m unittest -v test_heartbeat_server.py
```

Il test non aggiorna Windows, non riavvia nulla e non contatta computer aziendali. Usa esclusivamente la connessione locale 127.0.0.1. Se i test falliscono, non distribuire il server.

## Cosa significa per te
Se il PC Reception smette di rispondere e poi torna con un avvio Windows differente, possiamo riconoscere il cambio di avvio. **Non sappiamo ancora quanto sia durato esattamente il reboot:** il periodo senza heartbeat è solo una stima di indisponibilità. Inoltre, BOOT_CHANGED non prova che un aggiornamento Windows sia riuscito.

## Limiti e prossimi passi
Il server corrente usa un'unica chiave segreta per tutti gli Agent e HTTP locale: **non esporlo direttamente alla rete**. Occorrono HTTPS tramite reverse proxy, credenziali individuali, protezione contro replay e gestione delle chiavi. Poi realizzeremo la lettura degli esiti Windows Update, la durata stimata del reboot e la dashboard/PWA mobile.

**Stato:** test scritto e pubblicato; esecuzione su Windows reale e collaudo end-to-end ancora da effettuare.
