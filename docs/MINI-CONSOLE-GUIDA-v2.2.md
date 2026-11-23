# Mini console Windows Update — guida semplice v2.2 (23 novembre 2026)

## Che cosa abbiamo aggiunto oggi?
Una piccola **API di sola lettura** per la futura dashboard. In parole semplici: è uno sportello del server che, dopo aver verificato una password tecnica dedicata agli operatori, restituisce un elenco dei PC monitorati in formato JSON.

## Come funziona?
1. L'Agent Windows manda periodicamente un **heartbeat**: «sono qui, questo è il mio ultimo avvio».
2. Il backend lo salva nel database SQLite.
3. Il modulo `dashboard_snapshot.py` riassume quali PC hanno comunicato negli ultimi 180 secondi.
4. La nuova `dashboard_api.py` permette di leggere il riepilogo tramite `GET /api/v1/dashboard`.
5. In futuro la PWA mostrerà questi dati con schede chiare e avvisi.

**Attenzione:** «nessun contatto recente» non significa necessariamente «PC spento»: può essere la rete o l'Agent. La durata fra due heartbeat non è la durata esatta del reboot.

## Perché un token separato?
Le chiavi dei PC servono a **inviare** dati. Il token della dashboard serve a **leggerli**. Non vanno confusi: se una chiave di un PC viene compromessa, non deve permettere di vedere tutti gli altri.

## Come provarlo in laboratorio
Requisiti: Python 3.9+ e database creato dal backend precedente.

Aprire un terminale nella cartella `backend` ed eseguire:

```powershell
python -m unittest test_dashboard_api.py
$env:W11_DASHBOARD_TOKEN = "sostituire-con-una-chiave-casuale-di-almeno-32-caratteri"
$env:W11_DB_PATH = "w11-heartbeats.sqlite3"
python dashboard_api.py
```

Da un altro terminale, sullo **stesso computer**:

```powershell
$headers = @{ Authorization = "Bearer $env:W11_DASHBOARD_TOKEN" }
Invoke-RestMethod -Uri "http://127.0.0.1:8766/api/v1/dashboard" -Headers $headers
```

Il token va impostato anche nel secondo terminale, oppure passato da un ambiente di test sicuro. Non pubblicarlo in screenshot, repository o log.

## Limiti e sicurezza
- Server vincolato a `127.0.0.1`: non accessibile direttamente da altri PC.
- **Niente HTTPS integrato**: per l'accesso da telefono serviranno reverse proxy HTTPS, autenticazione operatori più robusta e controllo degli accessi.
- Nessuna funzione che installa aggiornamenti, esegue comandi o riavvia i PC.
- L'API restituisce identificativi e orari: sono informazioni operative da proteggere.
- La PWA non deve conservare token amministrativi nel codice JavaScript o nel localStorage: meglio una sessione gestita dal server con cookie HttpOnly/Secure/SameSite e protezione CSRF dove applicabile.
- Non ancora collaudato su PC Windows aziendali.

## Cosa manca?
Integrare autenticazione operatore e HTTPS, realizzare l'interfaccia mobile, raccogliere gli esiti Windows Update e stimare in modo corretto il tempo di indisponibilità durante i riavvii.
