# Mini console Windows Update – guida v2.3 (24 novembre 2026)

## Cosa abbiamo costruito
La prima schermata web responsive legge il riepilogo già prodotto dal backend. Mostra numero di PC, contatti recenti, assenze di contatto e ultimo riavvio rilevato. Non installa aggiornamenti né invia comandi.

## Prova locale
Avvia il ricevitore heartbeat e configura il database e W11_DASHBOARD_TOKEN come nella guida v2.2. Dalla cartella backend avvia python dashboard_preview.py. Apri http://127.0.0.1:8766/ sullo stesso computer e inserisci la chiave di consultazione. Il server sostituisce dashboard_api.py durante la prova: non avviarli contemporaneamente sulla stessa porta.
La pagina aggiorna i dati ogni 30 secondi quando visibile; la chiave resta in memoria e viene cancellata alla disconnessione. Nessuna chiave è inclusa nel codice o salvata nel browser.

## Come interpretare i dati
Contatto recente significa heartbeat entro la soglia del backend (180 secondi). Assenza di contatto non dimostra che il PC sia spento. Il riavvio rilevato indica un cambio di identità di avvio, non il successo di Windows Update. Non mostriamo ancora la durata del reboot.

## Limiti e prossimo passo
Solo loopback: non esporre il server alla LAN o a Internet. Non è ancora una PWA installabile. Prima dell'accesso mobile reale servono HTTPS, sessioni operatore e autorizzazioni. Collaudare la pagina con database di prova, chiave errata, perdita di rete e disconnessione; verificare che i dati spariscano in caso di errore. Prossimo sviluppo: raccolta degli esiti Windows Update e misura separata del tempo senza contatto.
