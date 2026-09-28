# BITX Attack Check

Detector si autoblocker pentru servere Virtualmin cu firewalld.

Analizeaza logurile Virtualmin, identifica probe/scannere web, probe WordPress, erori FastCGI si semnale OOM, iar in modul `--block` poate adauga reguli runtime DROP in firewalld.

## Structura instalata

```text
/opt/bitx-attack-check/
├── bitx-attack-check
├── bitx-attack-check.conf
└── data/
    └── blocks.json
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

## Configurare

Fisierul activ este:

```text
/opt/bitx-attack-check/bitx-attack-check.conf
```

Porneste de la `bitx-attack-check.conf.example`. Adauga IP-urile de incredere in `IGNORE_IPS`.

## Whitelist / IP-uri permise

Format recomandat:

```ini
IGNORE_IP=127.0.0.1|localhost
IGNORE_IP=::1|localhost IPv6
IGNORE_IP=192.0.2.10|External monitoring
```

`IGNORE_IP=` poate fi repetat. Textul dupa `|` este descrierea IP-ului. Formatul vechi `IGNORE_IPS=ip1,ip2` ramane suportat pentru compatibilitate.

## Utilizare

Porneste meniul interactiv:

```bash
bitx-attack-check
```

Meniul permite analiza rapida, analiza cu auto-block, analiza unui domeniu, afisarea si deblocarea IP-urilor, administrarea whitelist-ului, verificarea timerului si afisarea logurilor systemd.

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
