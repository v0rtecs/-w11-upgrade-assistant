# Mini console Windows Update — 2.5 (26 novembre 2026)
## Cosa abbiamo costruito
La sonda Windows legge gli esiti; il nuovo archivio SQLite li conserva per PC. Se lo stesso risultato arriva due volte, viene salvato una sola volta. Un errore della sonda non cancella la cronologia. I codici originali vengono conservati: 2 riuscito, 3 riuscito con errori, 4 fallito, 5 annullato.
## Come provarlo
Con Python 3.9+ entra nella cartella backend ed esegui:
```
python -m unittest -v test_update_history_store
```
I test usano un database temporaneo in memoria, senza toccare Windows Update.
## Limiti
Questo modulo non è ancora collegato a HTTP. Il futuro endpoint deve autenticare il PC con device_auth prima di chiamare record_batch, imporre limiti alla richiesta e usare HTTPS. La chiave di deduplicazione è un'approssimazione basata sui campi disponibili; la cronologia limitata della sonda può perdere eventi durante lunghe interruzioni. Nessun dato reale è stato raccolto. Il codice non misura ancora il reboot e non rileva installazioni in diretta.
## Prossimo passo
Endpoint POST /api/v1/update-history, autenticazione individuale obbligatoria, invio dall'Agent e test di integrazione.
