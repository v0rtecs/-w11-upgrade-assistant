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
