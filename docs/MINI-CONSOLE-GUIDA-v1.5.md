# Mini console Windows Update — guida semplice v1.5 (16 novembre 2026)

## Novità: la centrale ricorda quando un PC si riavvia
Abbiamo aggiunto `backend/boot_events.py`: un componente Python che riceve i dati di avvio già prodotti dall'Agent, conserva l'ultimo contatto e registra il cambio di avvio una sola volta.

**Esempio:** alle 10:00 il PC comunica con avvio alle 08:00. Alle 10:06 torna online e comunica un avvio alle 10:04. Il backend memorizza l'evento `BOOT_CHANGED`. Se lo stesso dato viene reinviato, non crea un secondo evento.

## Tre termini semplici
- **Heartbeat**: il messaggio periodico «sono qui» inviato dal PC.
- **Backend**: il programma centrale che riceve e conserva i messaggi.
- **Boot ID**: l'ora dell'ultimo avvio di Windows, usata per distinguere due sessioni.

## Protezioni incluse
Il database SQLite conserva per ciascun PC l'ultimo avvio e l'ultima osservazione. Le osservazioni vecchie non sovrascrivono quelle nuove. Un errore della sonda non viene interpretato come riavvio. Un vincolo di unicità evita eventi duplicati. Le scritture sono transazionali.

## Cosa NON significa ancora
Non è un server web, non riceve ancora messaggi in rete e non espone una PWA. Per uso aziendale occorreranno HTTPS, autenticazione dell'Agent, identificativi affidabili, autorizzazioni e conservazione dei dati. Il nome PC non è una credenziale. Il cambiamento dell'ora di avvio non dimostra che Windows Update sia riuscito. L'intervallo senza heartbeat non equivale alla durata precisa del riavvio.

## Prova in ambiente isolato
Richiede Python 3.9+ e nessuna libreria esterna. Da una cartella che contiene `backend`:

```bash
python -m unittest discover -s backend -p "test_*.py"
```

I test simulano il primo contatto, un riavvio, un messaggio duplicato, un messaggio vecchio e un errore di lettura. Non riavviano PC e non modificano Windows Update.

## Prossimo passo
Creare un endpoint HTTPS autenticato che passi gli heartbeat a questo componente, poi mostrare sulla dashboard l'ultimo contatto e gli eventi di riavvio. In una fase successiva confronteremo la cronologia degli aggiornamenti per distinguere installazione riuscita, fallita e riavvio richiesto.

**Stato:** codice e guida nel repository; integrazione end-to-end e test su Windows reali ancora da eseguire.
