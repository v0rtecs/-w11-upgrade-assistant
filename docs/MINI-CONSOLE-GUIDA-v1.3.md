# Mini console Windows Update — guida semplice v1.3 (14 novembre 2026)

## Il progetto in parole semplici
Un piccolo programma su ciascun PC (Agent) invierà periodicamente un segnale di presenza (heartbeat) a un server (backend). La pagina consultabile da smartphone (dashboard/PWA) mostrerà PC online/offline, aggiornamenti, riavvii ed eventuali errori. Non è ancora un sistema distribuito sui PC aziendali.

## Novità v1.3: test automatici per il cambio sicuro del catalogo CPU
Abbiamo aggiunto `agent/Test-CpuCatalogAtomic.ps1`. Crea una cartella temporanea e prova l'installatore atomico senza toccare i file reali. Controlla quattro casi: cambio riuscito con backup identico al precedente; rifiuto quando esiste già un backup; rifiuto di un file con SHA-256 sbagliato; rifiuto di un JSON danneggiato. Confronta gli hash dei file per verificare che non siano cambiati inaspettatamente.

**Come provarlo:** su un PC Windows di laboratorio, aprire PowerShell nella cartella `agent` ed eseguire:

```powershell
powershell.exe -NoProfile -File .\Test-CpuCatalogAtomic.ps1
```

Il risultato atteso sono quattro righe PASS. Se un controllo fallisce, il programma segnala l'errore e restituisce un codice non riuscito. La cartella di prova viene rimossa anche in caso di errore.

## Cosa significa «atomico»
È una sostituzione del file in un'unica operazione del filesystem: chi legge dovrebbe vedere la vecchia o la nuova versione, senza un intervallo intenzionale in cui il file non esiste. Non garantisce il successo in presenza di blocchi, permessi insufficienti, antivirus o guasti fisici.

## Limiti attuali
Il test è stato **scritto ma non eseguito su Windows reale**. Non simula interruzioni di corrente, blocchi esclusivi, scritture concorrenti né crash a metà operazione. Nessuna installazione automatica è autorizzata sui PC aziendali. Il catalogo CPU è un componente del Pre-Check, non il cuore del monitoraggio.

## Prossima priorità: ciclo heartbeat e riavvio
Per ogni PC invieremo un identificativo pseudonimo, un timestamp UTC, un identificativo di avvio e lo stato di Windows Update. Il backend distinguerà perdita di contatto, cambio di boot e rientro online. La durata tra ultimo contatto e primo rientro sarà **una stima dell'indisponibilità**, non una misura esatta del reboot. Servono autenticazione dell'Agent, HTTPS, controllo degli accessi, minimizzazione dei dati e test prima di qualsiasi uso aziendale.
