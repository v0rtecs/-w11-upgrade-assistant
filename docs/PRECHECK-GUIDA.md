# Windows 11 Pre-Check — guida semplice per Pietro

## Cosa abbiamo aggiunto

È disponibile `agent/Get-W11PreCheck.ps1`, la prima SCAN locale e **sola lettura** del progetto. Il suo compito è rispondere a una domanda semplice: **prima di iniziare un upgrade, questo PC presenta già qualcosa che merita attenzione?**

Lo script non installa aggiornamenti, non cambia il BIOS/UEFI, non abilita Secure Boot, non converte MBR in GPT, non modifica il registro e non riavvia il PC. Osserva e restituisce un risultato JSON che, nel prossimo collegamento, potrà essere inviato dal Monitor Agent alla centrale.

## Cosa controlla oggi

La SCAN raccoglie produttore e modello, CPU, RAM, Windows/build, versione BIOS, modalità firmware UEFI/Legacy, stile del disco di sistema GPT/MBR, TPM e relativa versione, Secure Boot, spazio libero su C:, presenza di AnyDesk e presenza di un riavvio pendente.

## Il semaforo

Il risultato sintetico usa tre stati:

- `OK`: nei controlli implementati non è emerso nulla che richieda intervento.
- `ATTENZIONE`: l'upgrade non viene dichiarato impossibile, ma c'è qualcosa da verificare, per esempio Secure Boot disattivato, AnyDesk non rilevato, spazio ridotto o un reboot già pendente.
- `BLOCCATO`: è emerso un requisito importante non soddisfatto, per esempio firmware non UEFI, disco di sistema non GPT, TPM assente/inferiore a 2.0, meno di 30 GB liberi o meno di 4 GB di RAM.

Questo semaforo è volutamente prudente: **non equivale ancora alla certificazione ufficiale di compatibilità Windows 11**. In particolare la compatibilità precisa del modello CPU richiederà un controllo dedicato. Serve invece a trovare in anticipo i problemi pratici più comuni senza disturbare il PC.

## Perché è separato dall'Agent

Per questa prima versione la SCAN è un file autonomo. È una scelta intenzionale: possiamo provarla su alcuni PC e verificare che i dati siano corretti senza toccare il ciclo heartbeat già funzionante. Quando sarà validata, l'Agent la eseguirà periodicamente (non ogni 30 secondi) e invierà alla centrale il risultato sintetico e i dettagli.

Non avrebbe senso ripetere TPM, firmware, RAM e disco a ogni heartbeat: cambiano raramente. La futura frequenza sarà quindi molto più lenta e il backend conserverà `lastPreCheckUtc`.

## Come leggere il risultato

Esempio:

`status: ATTENZIONE`

`warnings: ["Secure Boot disattivato", "Riavvio già pendente"]`

significa: **il PC sta funzionando e la SCAN non ha trovato un blocco certo, ma prima dell'upgrade Pietro sa già quali due cose controllare.**

La futura card mobile potrà mostrare direttamente:

`🟡 RECEPTION-02 — ATTENZIONE`

`Secure Boot disattivato · reboot pendente`

senza dover aprire PowerShell o leggere Google Sheets.

## Stato del progetto dopo questo passo

La catena di monitoraggio resta operativa come progettata: Agent → heartbeat → backend → Reboot Sessions → API → mini console. In parallelo abbiamo ora il primo sensore Pre-Check reale e read-only.

Il prossimo passo tecnico è **integrare questa SCAN nell'Agent con una cadenza lenta e inviarla al backend**, aggiungendo `preCheckStatus`, `lastPreCheckUtc`, blockers e warnings alla fotografia del PC. Solo dopo la validazione dei dati la porteremo sulle card della PWA.
