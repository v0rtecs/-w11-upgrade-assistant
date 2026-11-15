# Mini console Windows Update — guida semplice v1.4 (15 novembre 2026)

## La novità di oggi: riconoscere un riavvio vero
Ogni PC comunica periodicamente con la centrale (heartbeat). Ma se smette di rispondere, non sappiamo subito se è stato riavviato, spento o se è caduta la rete.

Il nuovo script `agent/Get-W11BootIdentity.ps1` legge **l'ora dell'ultimo avvio di Windows** e produce un piccolo messaggio JSON. Non installa nulla e non modifica Windows Update.

## Esempio
- Ore 10:00: il PC comunica, avvio Windows registrato alle 08:00.
- Ore 10:02: il PC non comunica più.
- Ore 10:06: il PC torna a comunicare, avvio Windows registrato alle 10:04.

La centrale confronta i due valori di avvio. Se sono differenti, abbiamo una **evidenza di nuovo avvio**; se sono uguali, probabilmente c'è stata un'interruzione di rete o del servizio Agent. L'assenza di heartbeat da sola non dimostra un riavvio.

## Come provare in sicurezza
Aprire PowerShell sul PC di test e lanciare:

```powershell
powershell.exe -NoProfile -File .\Get-W11BootIdentity.ps1
```

L'output è una sola riga JSON. `boot_id` rappresenta l'ora dell'avvio Windows in UTC; `observed_at_utc` è l'ora della misurazione. `uptime_seconds` indica da quanto tempo il sistema è acceso. Se la lettura fallisce, viene restituito `probe_status: error` senza fingere un riavvio.

## Come la useremo nella console
Il backend dovrà conservare l'ultimo `boot_id` per ogni PC e confrontarlo al heartbeat successivo. Se cambia, registrerà un evento `BOOT_CHANGED` con l'ora di avvio stimata. Il tempo senza contatto sarà calcolato tra ultimo heartbeat ricevuto e primo heartbeat di ritorno: **non è la durata esatta del reboot**, ma un intervallo che comprende eventuali problemi di rete e il ritardo di rilevazione.

Per identificare l'esito degli aggiornamenti servirà leggere separatamente la cronologia Windows Update. Un nuovo avvio non significa automaticamente aggiornamento riuscito.

## Sicurezza e limiti
Solo lettura, nessun riavvio remoto, nessuna credenziale nel JSON, nessuna modifica a impostazioni o servizi. Il nome del PC può essere un identificativo sensibile: trasmetterlo solo al backend autorizzato su HTTPS con autenticazione, accessi limitati e conservazione definita. La precisione dell'ora dipende dall'orologio del PC; ibernazione e avvio rapido possono rendere l'interpretazione più complessa.

**Stato:** script e guida disponibili nel repository; test su Windows reale e integrazione backend/PWA ancora da eseguire. Prossimo passo: memorizzare i boot_id nel backend e produrre eventi di riavvio senza duplicati.
