# Mini console Windows Update — guida semplice v2.0 (21 novembre 2026)

## Che cosa abbiamo costruito oggi?
Un piccolo programma PowerShell, `agent/Send-W11Heartbeat.ps1`, che legge l'identificativo dell'ultimo avvio di Windows tramite `Get-W11BootIdentity.ps1` e lo invia al server già predisposto. È un **prototipo**, non un servizio installato sui PC.

## A cosa serve?
Ogni PC invia periodicamente un messaggio («sono qui, questo è il mio ultimo avvio»). Il backend conserva i messaggi e riconosce un avvio diverso dal precedente. In seguito la dashboard mostrerà chi è online, chi è tornato dopo un riavvio e chi non comunica più.

## Prova controllata
1. Predisporre il backend Python e una credenziale individuale registrata nel file di autenticazione del server. Non usare chiavi reali nel repository.
2. Sul PC di prova, salvare il token in un file leggibile solo dall'account che esegue lo script e dagli amministratori (ACL NTFS). Non metterlo negli argomenti del comando.
3. Collocare `Send-W11Heartbeat.ps1` e `Get-W11BootIdentity.ps1` nella stessa cartella.
4. In PowerShell, dalla cartella agent, eseguire:
   ` .\Send-W11Heartbeat.ps1 -ServerUrl 'http://127.0.0.1:8765' -TokenFile 'C:\ProgramData\W11Monitor\token.txt' `
   L'indirizzo HTTP è consentito **solo** per test sullo stesso computer. Per comunicazioni di rete serve HTTPS con certificato valido e un reverse proxy davanti al backend, che deve restare su 127.0.0.1.
5. Il risultato JSON contiene `success` e, in caso di errore, `HEARTBEAT_SEND_FAILED`. Non contiene la chiave.

## Cosa NON fa
Non installa aggiornamenti, non riavvia Windows, non controlla ancora il successo di Windows Update e non calcola ancora la durata esatta di un reboot. Un intervallo senza heartbeat non equivale necessariamente a tempo di riavvio: può essere anche un problema di rete.

## Prima di usarlo in azienda
Test su Windows PowerShell 5.1; HTTPS, gestione sicura delle credenziali e permessi NTFS; scheduler con intervallo e jitter; verifica della compatibilità del payload col backend; log senza segreti; test di interruzione rete, timeout e riavvio. Evitare la distribuzione massiva finché questi controlli non sono completati.

## Prossimo passo
Scrivere test automatici del sender (endpoint locale simulato, credenziali errate, timeout e TLS) e poi integrare l'esito degli aggiornamenti Windows.
