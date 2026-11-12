# Windows 11 Pre-Check — guida semplice per Pietro

## A cosa serve

`agent/Get-W11PreCheck.ps1` è la SCAN locale e **sola lettura** del progetto. Risponde a una domanda pratica: **prima di iniziare un upgrade, questo PC presenta già qualcosa che merita attenzione?**

Lo script non installa aggiornamenti, non cambia BIOS/UEFI, non abilita Secure Boot, non converte MBR in GPT, non modifica il registro e non riavvia il PC. Osserva e restituisce un risultato JSON che l'Agent può portare alla centrale.

## Cosa controlla

La SCAN raccoglie produttore e modello, CPU, RAM, Windows/build, BIOS, modalità UEFI/Legacy, GPT/MBR, TPM e versione, Secure Boot, spazio libero su C:, AnyDesk e presenza di un riavvio pendente.

Dalla **v0.2** controlla anche la famiglia della CPU. Per Intel Core riconosce automaticamente le generazioni moderne (dall'ottava in poi); per AMD Ryzen riconosce prudentemente le serie moderne; riconosce inoltre Snapdragon X. Il risultato viene salvato come `FAMIGLIA_COMPATIBILE` oppure `DA_VERIFICARE`, insieme a una spiegazione leggibile.

## Perché la CPU non diventa subito un sì/no assoluto

Microsoft pubblica elenchi di processori supportati per Windows 11, ma gli elenchi sono modello-per-modello e possono essere aggiornati nel tempo. Per questo il nostro script **non inventa una certificazione** partendo soltanto dal nome commerciale della CPU.

Se riconosce chiaramente una famiglia moderna, scrive `FAMIGLIA_COMPATIBILE`. Se il processore è vecchio, particolare o non riconosciuto, scrive `DA_VERIFICARE` e porta il Pre-Check in `ATTENZIONE`, non in `BLOCCATO`.

Questo evita due errori opposti: dare un verde a una CPU che non abbiamo verificato oppure bloccare un PC che potrebbe rientrare in un'eccezione supportata.

## Il semaforo

- `OK`: nei controlli implementati non è emerso nulla che richieda intervento.
- `ATTENZIONE`: non dichiariamo l'upgrade impossibile, ma c'è qualcosa da verificare, per esempio CPU non classificata, Secure Boot disattivato, AnyDesk assente, spazio ridotto o reboot pendente.
- `BLOCCATO`: è emerso un requisito importante non soddisfatto, per esempio firmware non UEFI, disco non GPT, TPM assente/inferiore a 2.0, meno di 30 GB liberi o meno di 4 GB di RAM.

Il semaforo resta volutamente prudente: **non equivale alla certificazione ufficiale Microsoft di compatibilità Windows 11**.

## Esempio pratico

Un PC con `Intel Core i5-8500`, UEFI, GPT, TPM 2.0 e spazio sufficiente può produrre:

`cpuCompatibility: FAMIGLIA_COMPATIBILE`

`cpuCompatibilityDetail: Intel Core generazione 8`

Un processore che la nostra regola non sa classificare produce invece:

`cpuCompatibility: DA_VERIFICARE`

La console non lo nasconde dietro un falso verde: Pietro vede `ATTENZIONE` e sa che quel modello CPU va controllato prima dell'upgrade.

## Come funziona nel progetto

Il Pre-Check viene eseguito dall'Agent con cadenza lenta, perché TPM, firmware, RAM e disco non cambiano ogni 30 secondi. Il backend conserva l'ultimo risultato valido e la dashboard separa due concetti diversi: **ONLINE/OFFLINE** indica se il PC sta comunicando; **OK/ATTENZIONE/BLOCCATO** indica invece la situazione del Pre-Check.

La catena è quindi:

`PC → Pre-Check → Agent → heartbeat → backend → PC Monitor → API Dashboard → card mobile`

## Cosa abbiamo migliorato con la v0.2

Prima la CPU veniva soltanto raccolta come testo. Ora partecipa realmente alla valutazione e, soprattutto, un processore non classificato impedisce un `OK` ingannevole. Il formato del risultato passa a `schemaVersion = 2` e aggiunge `cpuCompatibility` e `cpuCompatibilityDetail`.

## Prossimo passo

Portare i due nuovi campi CPU attraverso backend e API fino alla card mobile. In seguito potremo sostituire il controllo per famiglia con un catalogo/versione aggiornabile basato sugli elenchi Microsoft, mantenendo comunque una modalità `DA_VERIFICARE` per i casi non certi.

## Aggiornamento v0.3 — catalogo CPU separato (3 novembre 2026)

La CPU viene ora confrontata con il file `agent/cpu-catalog.json`, distinto dallo script. Questo è il primo passo per aggiornare le regole senza riscrivere la SCAN. Il catalogo ha una versione e un elenco `exactCpuNames` di nomi completi: niente scorciatoie basate soltanto sulla generazione.

**Per ora l'elenco è intenzionalmente vuoto.** Non abbiamo ancora validato e inserito modelli specifici contro le liste ufficiali Microsoft. Di conseguenza tutte le CPU restituiscono `DA_VERIFICARE` e il semaforo rimane almeno giallo. Non è un guasto: è una protezione contro falsi verdi. Quando inseriremo nomi esatti verificati, una corrispondenza darà `CATALOGO_LOCALE`, che **non significa certificazione ufficiale**.

Se il file manca, è corrotto o ha uno schema inatteso, lo script continua senza bloccare gli heartbeat: segnala `DA_VERIFICARE` con il motivo e la versione del catalogo (`ASSENTE` o `ERRORE`). La SCAN resta in sola lettura. Il JSON del Pre-Check ora è `schemaVersion = 3` e include `cpuCatalogVersion` oltre ai campi già noti.

**Come aggiornarlo:** verificare un modello CPU completo sugli elenchi Microsoft appropriati alla versione Windows 11, inserirne il nome esatto in `exactCpuNames`, aggiornare `catalogVersion`, validare il JSON e distribuire il solo catalogo insieme ai file dell'Agent. La distribuzione automatica non è ancora implementata: oggi il file deve essere copiato accanto allo script su ciascun PC.

**Prossimo passo:** creare una procedura controllata di aggiornamento e validazione del catalogo, poi fare test reali con CPU note, sconosciute e file mancante. Il vecchio controllo euristico per generazione resta nel codice ma non è più utilizzato per decidere il semaforo.

## Aggiornamento v0.4 — controllo del catalogo prima della distribuzione (4 novembre 2026)

Abbiamo aggiunto `agent/Validate-CpuCatalog.ps1`. È un **controllore offline**: legge il catalogo, verifica che sia JSON valido, che contenga i campi previsti, una versione riconoscibile e un elenco di CPU senza voci vuote o duplicate. Non installa nulla e non modifica i computer.

**Come usarlo:** apri PowerShell nella cartella `agent` ed esegui `powershell.exe -NoProfile -File .\Validate-CpuCatalog.ps1`. Se compare **VALIDO**, il file è strutturalmente corretto; se compare **NON VALIDO**, non distribuirlo. Il comando termina con codice 0 in caso di successo e 1 in caso di errore, utile anche per futuri controlli automatici.

**Attenzione:** VALIDO **non significa che le CPU elencate siano ufficialmente supportate**. Il controllo non confronta i nomi con Microsoft: verifica solo il formato e i duplicati. Per aggiungere una CPU occorre prima documentare la verifica manuale sul relativo elenco ufficiale e sulla versione di Windows 11 interessata. L'elenco iniziale rimane vuoto. Non è stata ancora implementata la distribuzione automatica.

**Prossimo passo:** aggiungere test automatici con cataloghi volutamente difettosi e correggere la normalizzazione dei nomi CPU nel Pre-Check; poi preparare un aggiornamento del catalogo con verifica d'integrità e rollback.


## Aggiornamento v0.5 — catalogo CPU a prova di errore (6 novembre 2026)

Abbiamo chiuso una falla: prima il controllo manuale del catalogo era piu rigoroso della SCAN eseguita sui PC. Ora **la SCAN controlla anche versione, policy, tipo di elenco, nomi vuoti e duplicati** prima di utilizzare una CPU del catalogo. Inoltre uniforma gli spazi nei nomi: `Intel  Core` e `Intel Core` sono trattati nello stesso modo.

**In pratica:** se qualcuno copia per sbaglio un catalogo incompleto o modificato male, la SCAN non dara un verde per quella CPU. Restituira `DA_VERIFICARE` e `cpuCatalogVersion = ERRORE`. Il PC continua comunque a inviare heartbeat: non perdiamo il monitoraggio per un problema nel catalogo.

Abbiamo aggiunto `agent/Test-CpuCatalog.ps1`: da PowerShell nella cartella `agent`, esegui `powershell.exe -NoProfile -File .\Test-CpuCatalog.ps1`. Il programma crea cataloghi temporanei validi e volutamente sbagliati, prova il validatore e li elimina. La scritta `Tutti i test superati` indica che il validatore ha reagito come previsto. **Questi test non dimostrano ancora che la SCAN funzioni su tutti i PC Windows**: occorre un test reale con cataloghi corretti, corrotti e assenti.

**Prossimo passo:** test end-to-end del Pre-Check su Windows e successivamente distribuzione sicura del catalogo, con controllo integrita e ripristino della versione precedente. L'elenco CPU resta intenzionalmente vuoto finche non avremo verificato i singoli modelli.


## Aggiornamento v0.6 — installazione controllata del catalogo (7 novembre 2026)

Abbiamo aggiunto `agent/Install-CpuCatalog.ps1`: serve per sostituire il catalogo CPU **senza toccare Windows Update o riavviare il PC**. Non scarica nulla da Internet: il file nuovo va ottenuto prima da una fonte affidabile.

**Come funziona:** controlla che il file sia esattamente quello previsto tramite impronta SHA-256; lo copia in un file temporaneo; usa il validatore esistente; conserva il catalogo precedente come `.bak`; installa il nuovo; ricontrolla. Se l'installazione fallisce dopo aver creato il backup, tenta di ripristinare il vecchio catalogo. Se esiste gia un `.bak` o `.new`, si ferma per non sovrascrivere materiale utile.

**Per Pietro:** l'impronta SHA-256 e come un codice di riconoscimento del file: va ricevuta separatamente da un canale attendibile, non copiata dallo stesso file potenzialmente compromesso. Da PowerShell nella cartella `agent`:

```powershell
powershell.exe -NoProfile -File .\Install-CpuCatalog.ps1 -SourcePath "C:\Temp\cpu-catalog.json" -ExpectedSha256 "INSERIRE_QUI_64_CARATTERI_ESATTI"
```

L'impronta di un file puo essere calcolata con `Get-FileHash C:\Temp\cpu-catalog.json -Algorithm SHA256`, ma **calcolarla localmente e riutilizzarla senza confronto con un valore fidato non garantisce l'autenticita**.

Il backup `.bak` resta sul disco dopo il successo e richiede una gestione esplicita prima del prossimo aggiornamento. Non abbiamo ancora implementato download automatico, autenticazione del distributore, firma digitale o protezione da downgrade: **questa e una procedura locale controllata, non ancora un aggiornamento remoto sicuro**. La sostituzione non e atomica rispetto a letture concorrenti dell'Agent: programmarla quando la SCAN non e in esecuzione. Test Windows e prove di guasto/ripristino ancora da eseguire.


## Aggiornamento v0.7 — prove automatiche dell'installatore (8 novembre 2026)

Abbiamo aggiunto `agent/Test-InstallCpuCatalog.ps1`. È una **palestra di prova**: crea una cartella temporanea, simula cataloghi nuovi e vecchi, lancia l'installatore e controlla il risultato. **Non tocca il catalogo CPU effettivamente usato dai PC.**

Per eseguirlo, apri PowerShell nella cartella `agent` ed esegui:

```powershell
powershell.exe -NoProfile -File .\Test-InstallCpuCatalog.ps1
```

Le cinque prove coprono: aggiornamento valido con backup; impronta SHA-256 sbagliata; JSON danneggiato; backup già presente; file temporaneo già presente. Ogni prova controlla anche che il catalogo precedente non sia stato alterato quando l'installazione viene rifiutata. Se tutto va bene compare `5 superati, 0 falliti` e il comando restituisce codice 0.

**Cosa non dimostrano ancora questi test:** non simulano un'interruzione improvvisa dell'alimentazione, un guasto al disco o un errore dopo la creazione del backup; non verificano la concorrenza con una scansione in corso. Il codice dei test è stato aggiunto, ma va ancora eseguito su Windows: finché non vediamo l'esito, non possiamo dichiarare le prove superate.

**Perché serve:** prima di distribuire il catalogo a decine di computer, vogliamo verificare in modo ripetibile che un errore non distrugga le informazioni già presenti. Prossima tappa: prova del ripristino con guasto controllato e gestione dei file .bak rimasti dopo un aggiornamento riuscito.


## Aggiornamento v0.8 — prova reale della logica di ripristino (9 novembre 2026)

L'installatore accetta ora l'opzione **solo per test** `-TestFailAfterBackup`. Dopo aver spostato il vecchio catalogo nel backup, genera volontariamente un errore: il normale gestore degli errori deve riportare il catalogo originale al suo posto. Non usare questa opzione durante installazioni operative.

Il file `agent/Test-InstallCpuCatalog.ps1` comprende ora **sei** scenari, incluso il guasto controllato. La sesta prova verifica che l'installazione fallisca, che il contenuto originale torni identico e che non rimangano file temporanei o backup della prova. Esegui dalla cartella `agent`:

```powershell
powershell.exe -NoProfile -File .\Test-InstallCpuCatalog.ps1
```

Il risultato atteso è `6 superati, 0 falliti`. **Attenzione:** il codice è stato aggiornato, ma i test devono ancora essere eseguiti su Windows; non dichiararli superati prima della prova. Questo guasto simulato non dimostra la resistenza a blackout, disco guasto o scansioni contemporanee. In produzione l'installazione rimane manuale e va pianificata fuori dalla scansione Pre-Check.

**Perché è utile:** se un aggiornamento si interrompe *dopo* aver messo da parte il catalogo precedente, vogliamo verificare che il programma sappia recuperarlo, anziché lasciare la macchina senza catalogo. Prossimo passo: gestione sicura dei backup dopo successo e verifica delle letture concorrenti.


## Aggiornamento v0.9 — archiviazione prudente dei backup (10 novembre 2026)

Dopo un aggiornamento riuscito, l'installatore conserva il vecchio catalogo come `.bak`. È una protezione utile, ma un `.bak` lasciato accanto al file attivo impedisce la successiva installazione. Abbiamo quindi aggiunto `agent/Archive-CpuCatalogBackup.ps1`: **non cancella il backup**, lo sposta in una cartella di archivio, con data, ora e parte dell'impronta SHA-256 nel nome.

Prima di spostarlo verifica che il catalogo attivo esista e sia valido, che il backup sia valido e che non sia presente un file `.new` (possibile installazione incompleta). Se qualcosa non torna, si ferma e lascia tutto com'è. L'archiviazione è **manuale**: non avviene automaticamente dopo l'installazione, perché vogliamo prima confermare che il nuovo catalogo funzioni.

**Procedura consigliata:** dopo l'aggiornamento e la verifica del Pre-Check, apri PowerShell nella cartella `agent`. Prima simula l'operazione:

```powershell
powershell.exe -NoProfile -File .\\Archive-CpuCatalogBackup.ps1 -WhatIf
```

Se la destinazione indicata è corretta, esegui senza `-WhatIf`:

```powershell
powershell.exe -NoProfile -File .\\Archive-CpuCatalogBackup.ps1
```

Il backup precedente resta recuperabile in `agent/catalog-backups`, mentre il nome `.bak` si libera per il prossimo aggiornamento. **Non è un sistema di rollback automatico** e non risolve blackout o letture concorrenti. Non abbiamo ancora eseguito test Windows reali: prima dell'uso su PC aziendali occorre un collaudo su una cartella di prova. Evitare di condividere i cataloghi e i backup fuori dai canali IT autorizzati.


## Aggiornamento v1.0 — lettura robusta durante la sostituzione (11 novembre 2026)

**Problema:** mentre l'installatore sposta il vecchio catalogo in backup e mette al suo posto quello nuovo, per un breve istante il file potrebbe non esserci. Una scansione avviata proprio in quell'istante potrebbe segnalare erroneamente un catalogo assente.

**Soluzione:** `Get-W11PreCheck.ps1` ora tenta di leggere e interpretare il catalogo fino a **tre volte**, aspettando 150 millisecondi tra i tentativi falliti. Se il file ricompare, usa il contenuto letto; se continua a mancare o non e leggibile, mostra `DA_VERIFICARE` con `cpuCatalogVersion = ERRORE`. La scansione non scrive mai nel catalogo.

**Per Pietro:** e come controllare nuovamente un documento che un collega sta sostituendo, prima di segnalare che e scomparso. Non nascondiamo pero un problema persistente: dopo tre tentativi resta l'avviso giallo.

**Limite importante:** questo intervento riduce gli avvisi temporanei, **non rende atomica l'installazione** e non garantisce coerenza se il file cambia tra due letture. La validazione strutturale viene comunque eseguita prima di accettare i dati. Non sono stati ancora effettuati test su Windows reale. Fino al collaudo, programmare le installazioni fuori dagli orari della scansione.

**Prossimo passo:** test di concorrenza in una cartella isolata, con scansioni ripetute durante l'aggiornamento, e successiva sostituzione atomica del file ove supportata dal filesystem.


## Aggiornamento v1.1 — prova di concorrenza isolata (12 novembre 2026)

Abbiamo aggiunto `agent/Test-CpuCatalogConcurrency.ps1`: simula un lettore che apre ripetutamente un catalogo mentre l'installatore lo sostituisce. Lavora **solo in una cartella temporanea**: non modifica il catalogo operativo e non avvia Windows Update.

Da PowerShell, nella cartella `agent`, esegui:

```powershell
powershell.exe -NoProfile -File .\Test-CpuCatalogConcurrency.ps1 -ReadCount 200
```

Il test conta tre tipi di lettura: **Valid** (vecchia o nuova versione coerente), **Missing** (file momentaneamente assente), **Invalid** (JSON non valido o versione inattesa). Un numero positivo di Missing dimostra che la sostituzione non e atomica; zero Missing **non prova** che non possa verificarsi. Qualsiasi Invalid fa fallire il test. La prova verifica la concorrenza con un lettore sintetico, **non** il Pre-Check completo né un blackout. Il codice deve ancora essere eseguito su Windows: non dichiarare i test superati finche non abbiamo un risultato reale.

**Perche ci serve:** vogliamo capire se un controllo avviato durante un aggiornamento del catalogo possa osservare un file mancante o incoerente, prima di distribuire la procedura su molti PC. Il prossimo miglioramento sara una sostituzione atomica con gestione esplicita del recupero dopo guasto, seguita da test end-to-end Agent → backend → dashboard.
