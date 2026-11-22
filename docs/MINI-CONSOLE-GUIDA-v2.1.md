# Mini console Windows Update — guida semplice v2.1
22 novembre 2026

## Cosa abbiamo aggiunto
Il backend può preparare un **riepilogo di sola lettura** per la futura dashboard mobile. Il nuovo file `backend/dashboard_snapshot.py` legge il database SQLite già utilizzato dagli heartbeat: non installa aggiornamenti, non riavvia PC e non modifica dati.

## Come leggerlo
- **Online** significa che abbiamo ricevuto un'osservazione recente (entro 180 secondi, valore configurabile). Non garantisce che il PC sia raggiungibile proprio in questo istante.
- **Nessun contatto recente** significa soltanto che il messaggio manca da più di 180 secondi: il PC potrebbe essere spento, in riavvio, senza rete o con Agent fermo.
- **Ultimo riavvio rilevato** è l'ora in cui il backend ha registrato un cambio dell'identificativo di avvio; non è necessariamente l'ora esatta del riavvio.
- **Durata del riavvio**: non ancora disponibile. Non va inventata sottraendo due heartbeat: quella differenza è un intervallo senza osservazioni, non la durata effettiva del boot.
- **Esito Windows Update**: non ancora integrato. Un riavvio non prova che un aggiornamento sia riuscito.

## Dove sono i file
`backend/dashboard_snapshot.py`: produce un dizionario pronto per essere convertito in JSON.
`backend/test_dashboard_snapshot.py`: prova PC recenti, PC senza contatto, riavvii ed errori di configurazione.

## Come provarli
Su un computer di test con Python 3.9 o successivo, aprire un terminale nella cartella `backend` ed eseguire:
```bash
python -m unittest test_dashboard_snapshot.py
```
Questa prova utilizza un database temporaneo in memoria. Non contatta i PC aziendali.

## Come funziona il progetto
1. L'Agent Windows legge lo stato del computer e invia periodicamente un heartbeat.
2. Il backend autentica il messaggio e conserva i dati in SQLite.
3. Questo nuovo componente prepara il riepilogo per la futura schermata sul telefono.
4. Più avanti una API HTTPS protetta esporrà il riepilogo alla PWA, con autenticazione distinta da quella degli Agent.

## Prossimi passi
Verificare i test in un ambiente Python reale; aggiungere un endpoint di sola lettura autenticato per gli amministratori; collegare la PWA; raccogliere gli esiti Windows Update e distinguere intervallo senza contatto e durata del riavvio.

**Stato:** prototipo non ancora pronto per la rete aziendale. Nessun PC è stato modificato.
