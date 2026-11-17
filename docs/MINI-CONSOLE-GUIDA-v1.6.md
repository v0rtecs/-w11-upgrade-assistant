# Mini console Windows Update — guida semplice v1.6 (17 novembre 2026)

## La novità di oggi: una porta d'ingresso per gli heartbeat
Abbiamo aggiunto `backend/heartbeat_server.py`. È un piccolo servizio Python che riceve il messaggio «sono qui» dal PC, verifica una chiave segreta e passa i dati al registratore `boot_events.py` della v1.5. Il database conserva l'ultimo avvio e registra un cambio di avvio senza duplicati.

## Come immaginare il sistema
- **Agent**: il messaggero sul computer, che legge l'avvio di Windows.
- **Heartbeat**: il messaggio periodico con identificativo PC, orario di osservazione e avvio.
- **Backend**: la reception centrale; controlla la chiave e archivia il messaggio.
- **Dashboard/PWA**: il pannello da smartphone; non è ancora collegato.

Un riavvio rilevato non prova che un aggiornamento sia riuscito. La durata senza heartbeat è soltanto una stima dell'indisponibilità.

## Sicurezza: attenzione importante
Il servizio ascolta **solo su 127.0.0.1 (localhost)**, in HTTP. **Non è un endpoint HTTPS pubblico**: per collegare i PC aziendali serve prima un reverse proxy HTTPS correttamente configurato (TLS, limitazioni di rete, rate limit, autenticazione e gestione delle chiavi). Non aprire la porta 8765 sulla rete. La chiave condivisa è una soluzione da laboratorio; in produzione occorrono credenziali individuali per dispositivo, revoca e rotazione.

## Prova locale (non sui PC aziendali)
Richiede Python 3.9+ e nessuna libreria aggiuntiva. Dalla cartella `backend`, in PowerShell:

```powershell
$env:W11_AGENT_TOKEN = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
python .\heartbeat_server.py
```

In una seconda finestra PowerShell, con **la stessa chiave** impostata manualmente, inviare un heartbeat di prova:

```powershell
$body = @{computer_id="PC-LAB"; observed_at_utc=(Get-Date).ToUniversalTime().ToString("o"); probe_status="ok"; boot_id=(Get-Date).AddHours(-2).ToUniversalTime().ToString("o")} | ConvertTo-Json
Invoke-RestMethod -Uri "http://127.0.0.1:8765/api/v1/heartbeat" -Method Post -ContentType "application/json" -Headers @{Authorization="Bearer $env:W11_AGENT_TOKEN"} -Body $body
```

Il risultato atteso al primo messaggio è `first_seen`. Il database locale viene creato come `w11-heartbeats.sqlite3`. Non inserire mai la chiave in screenshot o repository.

## Protezioni e limiti
Il server rifiuta chiavi errate, JSON non valido, contenuti oltre 4 KiB e percorsi diversi da `/api/v1/heartbeat`. Usa confronti delle chiavi a tempo costante e non registra i corpi dei messaggi. La v1.6 **non** comprende TLS, agent automatico, dashboard, esito degli update o durata precisa del reboot. Nessun test Windows reale è stato eseguito in questa fase.

## Prossimo passo
Test automatici HTTP e credenziali per singolo PC, poi connessione dell'Agent attraverso HTTPS e visualizzazione degli stati sulla dashboard.
