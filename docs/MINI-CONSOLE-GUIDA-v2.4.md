# Mini console Windows Update – guida v2.4 (25 novembre 2026)

## Cosa abbiamo costruito
L'Agent dispone di una nuova sonda di sola lettura che consulta la cronologia locale di Windows Update tramite l'interfaccia COM Microsoft.Update.Session. Non cerca nuovi aggiornamenti, non scarica, non installa e non riavvia. Legge al massimo 20 voci recenti per impostazione predefinita (massimo 100), escludendo le disinstallazioni.

## Come provarla
Su un PC Windows di laboratorio, aprire Windows PowerShell 5.1 nella cartella agent ed eseguire:
```powershell
.\Get-W11UpdateHistory.ps1 -Limit 20
```
Il risultato è JSON. Confrontare titolo, data e risultato con Impostazioni > Windows Update > Cronologia aggiornamenti. Verificare anche una macchina con cronologia vuota e una lettura non disponibile. Una lettura fallita produce probe_status=error e codice di uscita 1; una cronologia vuota leggibile produce ok. Non modificare le politiche di esecuzione aziendali per la prova.

## Interpretazione
Codici WUA: 0 non iniziato, 1 in corso, 2 riuscito, 3 riuscito con errori, 4 fallito, 5 annullato. Conserviamo anche identificativo, revisione, data e HRESULT (codice diagnostico). La cronologia non è una misura in tempo reale dell'installazione, non dimostra che un riavvio sia richiesto o completato e non garantisce una copertura completa degli aggiornamenti. La finestra è limitata alle ultime N voci complessive, prima del filtro per installazione.

## Prossimo collegamento
La sonda è autonoma: non invia ancora dati al backend. Progettare un endpoint autenticato separato dall'heartbeat (che ha un limite di 4 KiB), con invii paginati e deduplicazione per PC, identificativo, revisione, data e risultato. Non sovrascrivere l'ultimo stato valido se la sonda fallisce. Registrare la data di ricezione del server separatamente dalla data locale. Non interpretare l'assenza di voci come successo.

Per il reboot distingueremo intervallo fra ultimo heartbeat e primo heartbeat dopo cambio di avvio, tempo dall'avvio al primo contatto e durata di avvio misurata da telemetria Windows, se disponibile. Sono misure diverse.

## Stato
Codice pubblicato, non collaudato su Windows. Dashboard ancora locale, nessun PC aziendale modificato. Prima della produzione: HTTPS, credenziali protette, sessioni operatore, test integrati e verifica delle politiche IT.
