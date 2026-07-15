# Migracja IPI: `ipicoin/ipid` → `ipicoin/independency-daemon`

Dokument opisuje migrację tożsamości/brandingu IPI ze starego forka wasmd
(`ipicoin/ipid`) do świeżego forka (`ipicoin/independency-daemon`) oraz
dokończenie rebrandingu `wasmd` → `ipi`/`ipid`. Realizuje issue #1
(migracja ipid → wasmd).

## Źródło

- **Stary fork:** [`ipicoin/ipid`](https://github.com/ipicoin/ipid) — fork wasmd
  na Cosmos SDK **v0.47**, branch `master`, ostatni commit 2024-10-05.
- **Nowy fork (tu):** `ipicoin/independency-daemon` — świeży fork wasmd na
  Cosmos SDK **v0.54**, CometBFT v0.39, wasmvm v3, branch `main`.

Ścieżka modułu Go pozostaje **`github.com/CosmWasm/wasmd`** (tak jak w `ipid`).
Rename ścieżki modułu to osobne, duże zadanie (setki importów) — patrz Follow-up.

## Co przeniesione z `ipid` (żywa delta)

Kompletna, żywa delta IPI w `ipid` sprowadzała się do jednej zmiany:

- **Bech32 prefix `ipi`** — ustawiony w `app/app.go` (`Bech32Prefix = "ipi"`)
  oraz w ldflags Makefile (`app.Bech32Prefix=ipi`). Pozostałe warianty prefiksu
  (`Bech32PrefixAccAddr`, `...ValAddr`, `...ConsPub` itd.) derywują się
  automatycznie z `Bech32Prefix` — nie ruszane.

## Co dokończone (rebrand `wasmd` → `ipi`/`ipid`)

Rebrand w `ipid` był niepełny; tutaj został dokończony zgodnie z SSOT:

- `app/app.go`:
  - `appName`: `"WasmApp"` → `"ipi"`
  - `NodeDir`: `".wasmd"` → `".ipid"`
  - `Bech32Prefix`: `"wasm"` → `"ipi"`
- `Makefile` — ldflags:
  - `version.Name`: `wasm` → `ipi`
  - `version.AppName`: `wasmd` → `ipid`
  - `app.Bech32Prefix`: `wasm` → `ipi`
  - targety `build`/`build-windows-client`/`install`/`draw-deps`:
    `build/wasmd` → `build/ipid`, `./cmd/wasmd` → `./cmd/ipid`
- Katalog binarki: `cmd/wasmd` → `cmd/ipid` (`git mv`). Importy wewnątrz
  pozostają `github.com/CosmWasm/wasmd/...` (ścieżka modułu niezmieniona).
- `Dockerfile`: obraz `cosmwasm/wasmd` → `ipicoin/ipid` (komentarze), budowany
  i kopiowany plik `build/ipid`, `COPY ... /usr/bin/ipid`,
  `CMD ["/usr/bin/ipid","version"]`. libwasmvm/porty bez zmian.

Uwaga: symbole Go pakietu wasmd (`NewWasmApp`, `WasmApp`, `wasmtypes` itp.)
oraz odwołania do ścieżki modułu `github.com/CosmWasm/wasmd` pozostają
niezmienione — to identyfikatory kodu, nie branding, i zależą od renamu modułu.

## Co ŚWIADOMIE NIE przeniesione i dlaczego

- **`UpgradePIPI`** — w `ipid` to **zakomentowany** (`/*func...*/`) legacy
  in-code mint 100M „ipi" na height 1023230 dla chainID „ipi". Martwy kod,
  nieaktywny, związany ze starym chainID. Nie przenoszony.
- **Denom „ipi" / chainID „ipi"** — zastąpione przez SSOT: denom bazowy
  `nipi` (9 miejsc dziesiętnych), chain-id `ipi-mainnet-2`. Te wartości należą
  do **genesis**, nie do kodu — nie są hardkodowane w `app.go`.
- **Zewnętrzny prywatny skrypt Docker** — prywatny artefakt
  deweloperski, poza zakresem publicznego forka.

## Follow-up

- **Rename ścieżki modułu Go** `github.com/CosmWasm/wasmd` → docelowa ścieżka
  IPI — osobny task (setki importów w całym repo, wpływ na `go.mod`, ldflags,
  gci prefix w Makefile). Świadomie odłożone.
- Konfiguracja genesis (denom `nipi`, chain-id `ipi-mainnet-2`) — poza zakresem
  tego PR (należy do chainconfig/genesis).
