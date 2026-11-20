# Mini console Windows Update — guida semplice v1.9
20 novembre 2026

## Che cosa stiamo costruendo?
Un piccolo programma (Agent) sui PC invierà periodicamente un segnale, detto **heartbeat**, a un server centrale (backend). Una dashboard consultabile anche da telefono mostrerà l'ultimo contatto, gli aggiornamenti Windows, i riavvii e le anomalie. La dashboard non è ancora operativa.

## Il passo di oggi: verificare che ogni PC abbia la propria chiave
Il server già supporta una chiave diversa per ogni PC. Abbiamo aggiunto `backend/test_device_http.py`: avvia un server soltanto sul computer di prova, simula due PC e verifica che ciascuno possa comunicare solo con la propria chiave.

Le prove coprono: accesso valido per due PC; tentativi di impersonare un altro PC; revoca di una sola chiave senza interrompere l'altro PC; nessuna scrittura nel database per un messaggio respinto.

Abbiamo anche corretto la preparazione dei test HTTP precedenti: ora il server simulato riceve esplicitamente l'impostazione `device_registry = None`, necessaria per la modalità con chiave condivisa.

## Come provarlo (su macchina di sviluppo)
Da una console nella cartella `backend`:

```powershell
python -m unittest -v test_device_http test_heartbeat_server
```

Sono test locali: non contattano PC aziendali e non installano aggiornamenti. I test devono ancora essere eseguiti su Windows reale.

## Che cosa significa per Pietro?
Se un computer viene dismesso o perde la sua credenziale, possiamo impedirgli di inviare nuovi dati senza dover cambiare la chiave degli altri PC. Non è una protezione completa: prima dell'uso aziendale servono HTTPS, distribuzione sicura delle chiavi, permessi sul file del registro e una procedura di rotazione delle credenziali.

## Cosa manca
1. Agent Windows che invia realmente gli heartbeat.
2. HTTPS e autenticazione amministrativa della dashboard.
3. Lettura degli esiti Windows Update e associazione agli eventi di riavvio.
4. Calcolo distinto di tempo senza contatto e durata effettiva del reboot.
5. Dashboard/PWA e collaudo end-to-end.

**Stato:** implementazione e documentazione pubblicate, test Windows reale non ancora verificati. Nessun intervento sui PC aziendali.
