# BITX Attack Check

Detector si autoblocker pentru servere Virtualmin cu firewalld.

Analizeaza logurile Virtualmin, identifica probe/scannere web, probe WordPress, erori FastCGI si semnale OOM, iar in modul `--block` poate adauga reguli runtime DROP in firewalld.

## Structura instalata

```text
/opt/bitx-attack-check/
├── bitx-attack-check
├── bitx-attack-check.conf
└── data/
    ├── blocks.json
    └── history.json
```

Unitatile systemd sunt instalate in `/etc/systemd/system/`.

## Instalare

Cloneaza repository-ul, apoi:

```bash
cd /root
git clone https://github.com/bitxro/bitx-attack-check.git
cd bitx-attack-check
chmod +x install.sh
sudo ./install.sh
```

Installerul:
- instaleaza aplicatia in `/opt/bitx-attack-check`;
- pastreaza configul local existent la upgrade;
- la migrare, importa automat `/etc/bitx-attack-check.conf` daca exista;
- importa `/var/lib/bitx-attack-check/blocks.json` daca noul state nu exista;
- instaleaza si activeaza timerul systemd;
- ruleaza un dry-run la final.

## Update simplu, fara modificarea setarilor locale

Dupa instalarea versiunii care include updaterul, ruleaza ca root:

```bash
bitx-attack-check --update
```

Sau alege `11) Update din GitHub` din meniu. Updaterul cloneaza temporar ramura main din repository-ul oficial, verifica sintaxa Python si comanda de ajutor, apoi inlocuieste atomic numai executabilul instalat. Configuratia, whitelist-ul, Telegram, blocks.json si history.json nu sunt copiate din Git si raman locale. Este necesar Git si acces HTTPS la GitHub. Nu schimba unitatile systemd.

Executabilul anterior este pastrat ca `bitx-attack-check.previous`. Daca verificarea comenzii de ajutor dupa instalare esueaza, updaterul restaureaza automat executabilul precedent. Aceasta verificare nu garanteaza detectarea tuturor erorilor functionale.

Pentru prima trecere de la o versiune fara updater, pe fiecare server:

```bash
cd /root/bitx-attack-check-src &&
git pull --ff-only &&
python3 -m py_compile bitx-attack-check &&
install -o root -g root -m 0755 bitx-attack-check /opt/bitx-attack-check/bitx-attack-check &&
bitx-attack-check --help
```

## Protectie pentru Googlebot si Bingbot

Protectia este activa automat, inainte de orice blocare si de actualizarea istoricului de recidiva. Foloseste exclusiv listele oficiale de crawlere, nu toate IP-urile Google/Microsoft si nu User-Agent:

- Google: https://developers.google.com/static/crawling/ipranges/common-crawlers.json
- Bing: https://www.bing.com/toolbox/bingbot.json

Listele sunt preluate la prima verificare a unui candidat, apoi reimprospatate dupa 24h. Cache-ul local din data/ este utilizabil maximum 7 zile daca descarcarea esueaza. Suporta IPv4 si IPv6. Verificarea DNS inversa si directa confirma suplimentar hostname-uri sub googlebot.com sau search.msn.com, inclusiv IP-uri noi care nu apar in cache. DNS are limita de 5 secunde pentru fiecare IP; rezultatele sunt memorate pe durata rularii.

In raport, `CRAWLER-GOOGLE` si `CRAWLER-BING` indica exceptii de la blocare, inclusiv in dry-run. Daca lipseste o lista utilizabila si DNS nu poate confirma sau infirma identitatea, apare `CHECK-FAILED`: banul este amanat pana la o rulare ulterioara, fara schimbarea istoricului. Daca ambele liste sunt disponibile, un IP absent din liste si neconfirmat prin DNS ramane eligibil pentru blocare. Erorile descarcarii sunt afisate si in logurile systemd.

Verificare individuala (sau optiunea 12 din meniu):

```bash
bitx-attack-check --check-crawler IP
```

Banurile deja active nu sunt eliminate automat. Verifica IP-ul si foloseste explicit `--unblock IP` daca este un crawler legitim. Site-urile din spatele unui proxy trebuie sa inregistreze IP-ul real al clientului printr-o configuratie de proxy de incredere.

## Configurare

Fisierul activ este:

```text
/opt/bitx-attack-check/bitx-attack-check.conf
```

Porneste de la `bitx-attack-check.conf.example`. Repository-ul nu contine IP-uri in whitelist si nu contine credentiale Telegram. Acestea se configureaza local din meniul interactiv.

## Whitelist / IP-uri permise

Format recomandat:

```ini
IGNORE_IP=192.0.2.10|External monitoring
```

`IGNORE_IP=` poate fi repetat. Textul dupa `|` este descrierea IP-ului. Formatul vechi `IGNORE_IPS=ip1,ip2` ramane suportat pentru compatibilitate.

## Export / import whitelist

Din meniul `Whitelist` poti exporta lista intr-un fisier JSON si o poti importa pe alt server. Importul face merge cu lista locala: nu sterge intrarile existente si nu adauga duplicate. Exportul contine numai IP-urile si descrierile din whitelist; tokenul Telegram, Chat ID-ul si celelalte setari locale nu sunt incluse.

Comenzi directe:

```bash
bitx-attack-check --export-whitelist /root/bitx-whitelist-export.json
bitx-attack-check --import-whitelist /root/bitx-whitelist-export.json
```

## Utilizare

Porneste meniul interactiv:

```bash
bitx-attack-check
```

Meniul permite analiza rapida, analiza cu auto-block, analiza unui domeniu, afisarea si deblocarea IP-urilor, administrarea whitelist-ului, configurarea notificarilor Telegram, verificarea timerului si afisarea logurilor systemd.

## Telegram

Din meniul interactiv, optiunea `Telegram` permite configurarea locala a Bot Token si Chat ID, activarea/dezactivarea notificarilor si trimiterea unui mesaj de test. Credentialele sunt salvate numai in fisierul local `/opt/bitx-attack-check/bitx-attack-check.conf`, care are permisiuni `0600` si nu este inclus in repository.

Cand modul `--block` adauga cu succes un IP nou in firewalld, scriptul trimite o notificare cu serverul, IP-ul, durata blocarii, numarul recidivei si motivul. Nu trimite notificari pentru dry-run sau pentru IP-uri deja blocate.

## Ban progresiv

IP-urile care revin dupa expirarea unei blocari primesc automat perioade mai lungi: prima blocare `24h`, a doua `7 zile`, a treia `30 zile`, iar de la a patra `90 zile`. Istoricul recidivelor este pastrat separat in `data/history.json`, astfel incat expirarea sau deblocarea unui IP nu sterge istoricul. Daca IP-ul nu mai este blocat timp de 90 de zile, recidiva se reseteaza si urmatoarea blocare porneste din nou de la 24h.

Comenzile directe raman disponibile pentru automatizare si administrare:

```bash
bitx-attack-check 60 --dry-run
bitx-attack-check 15 --block
bitx-attack-check --blocked
bitx-attack-check --unblock IP
bitx-attack-check --whitelist
bitx-attack-check -h
```

## Systemd

```bash
systemctl status bitx-attack-check.timer
systemctl status bitx-attack-check.service
journalctl -u bitx-attack-check.service
```

Timerul ruleaza la fiecare 10 minute si verifica ultimele 15 minute.

## Dezinstalare

Pastreaza configul si state-ul:

```bash
sudo ./uninstall.sh
```

Stergere completa a instalarii din `/opt`:

```bash
sudo ./uninstall.sh --purge
```

Regulile firewalld runtime deja create nu sunt eliminate automat de uninstall; pot expira conform timeout-ului sau pot fi eliminate explicit inainte de purge.

## Fisiere din repository

- `bitx-attack-check` - aplicatia
- `install.sh` - installer
- `uninstall.sh` - dezinstalare
- `bitx-attack-check.conf.example` - configuratie exemplu
- `.gitignore` - exclude configuratii locale si fisiere temporare
