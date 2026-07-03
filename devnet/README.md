# IPI devnet / testnet — tooling

Narzędzia do postawienia lokalnego devnetu i publicznego testnetu **IPI**
na bazie binarki `ipid` (fork `wasmd` / Cosmos SDK v0.54 + CosmWasm).

> **Status:** [PRE-ALPHA]. Realizuje issue #2 (Fala 1). Migracja rdzenia
> `ipid`→`wasmd` to osobne issue #1 — do jej zakończenia binarka nosi nazwę
> `wasmd`; ustaw wtedy `IPID_BIN=wasmd`. Roadmapa:
> https://github.com/ipicoin/universal-independency-declaration/issues/1

## Parametry sieci (SSOT — chainconfig)

| Parametr        | Testnet         | Mainnet         |
|-----------------|-----------------|-----------------|
| chain-id        | `ipi-testnet-1` | `ipi-mainnet-2` |
| denom bazowy    | `nipi`          | `nipi`          |
| display / symbol| `IPI`           | `IPI`           |
| decimals        | `9` (1 IPI = 1e9 nipi) | `9`      |
| bech32 prefix   | `ipi`           | `ipi`           |
| coinType (HD)   | `118`           | `118`           |
| endpointy       | `*.testnet.ipicoin.eu` | `*.ipicoin.eu` |

## Zawartość

| Plik                    | Opis |
|-------------------------|------|
| `init-devnet.sh`        | Inicjalizacja pojedynczego węzła: init, genesis, konto walidatora, gentx, collect-gentxs, konfiguracja RPC/REST/gRPC. |
| `genesis.template.json` | Referencyjny szkielet genesis z docelowymi parametrami modułów (staking/gov/mint/bank metadata/wasm). |
| `docker-compose.yml`    | Węzeł `ipid` + opcjonalny faucet (profil `faucet`). |
| `faucet.md`             | Konfiguracja faucetu testnet (`@cosmjs/faucet`), rate-limit, frontend. |

## Wymagania

- Zbudowana binarka. Z rootu repo:
  ```bash
  make build              # powstaje build/wasmd
  export PATH="$PWD/build:$PATH"
  export IPID_BIN=wasmd   # do czasu migracji #1
  ```
- `jq` (zalecane, dla pełnego patchowania genesis; fallback na `sed`).
- Do wariantu kontenerowego: Docker + Docker Compose.

## 1. Lokalny devnet — jeden węzeł

```bash
# inicjalizacja (kasuje ~/.ipid; KEEP_HOME=1 by zachować)
./devnet/init-devnet.sh

# opcjonalnie z dodatkowymi kontami:
./devnet/init-devnet.sh alice bob

# start
ipid start --home ~/.ipid          # lub: wasmd start --home ~/.ipid
```

Po starcie sieć produkuje bloki. Endpointy:

- RPC (CometBFT): `http://localhost:26657` — sprawdź `curl -s localhost:26657/status`
- REST/API: `http://localhost:1317`
- gRPC: `localhost:9090`

Adresy walidatora i faucetu wypisze `init-devnet.sh` na końcu.

## 2. Devnet w Dockerze

```bash
docker build -t ipicoin/ipid:devnet .            # z rootu repo
docker compose -f devnet/docker-compose.yml up -d
# z faucetem:
docker compose -f devnet/docker-compose.yml --profile faucet up -d
```

Reset danych: `docker compose -f devnet/docker-compose.yml down -v`.

## 3. Faucet

Patrz [`faucet.md`](./faucet.md). Skrót (Docker):

```bash
# mnemonik konta 'faucet' -> devnet/.env (NIE commituj realnego)
docker compose -f devnet/docker-compose.yml --profile faucet up -d
curl -X POST http://localhost:8000/credit \
  -H "Content-Type: application/json" \
  -d '{"address":"ipi1...", "denom":"IPI"}'
```

## 4. Dołączenie własnego walidatora / node'a

Na docelowym publicznym testnecie (`ipi-testnet-1`):

```bash
# 1. init pod właściwy chain-id
ipid init "<twoj-moniker>" --chain-id ipi-testnet-1 --default-denom nipi

# 2. pobierz opublikowany genesis sieci
curl -s https://rpc.testnet.ipicoin.eu/genesis \
  | jq '.result.genesis' > ~/.ipid/config/genesis.json
ipid genesis validate-genesis

# 3. persistent_peers / seeds (config/config.toml)
#    Format: <node_id>@host:26656 (node_id: `ipid comet show-node-id`)
sed -i 's/^persistent_peers = .*/persistent_peers = "<seed_id>@seed1.testnet.ipicoin.eu:26656,<seed_id2>@seed2.testnet.ipicoin.eu:26656"/' ~/.ipid/config/config.toml

# 4. start (sync)
ipid start --home ~/.ipid
```

Aby zostać walidatorem po zsynchronizowaniu:

```bash
ipid tx staking create-validator ./validator.json \
  --chain-id ipi-testnet-1 --from <klucz> \
  --keyring-backend test --gas auto --gas-adjustment 1.3 --fees 2000nipi
```

Szczegóły pól `validator.json` (pubkey, amount w `nipi`, commission) — patrz
dokumentacja Cosmos SDK `create-validator`.

## Uwaga o zgodności

Skrypty używają grupy poleceń `genesis` (Cosmos SDK v0.50+/v0.54): `init`,
`genesis add-genesis-account`, `genesis gentx`, `genesis collect-gentxs`,
`genesis validate-genesis`. Keyring `test` jest użyty wyłącznie dla devnetu —
na produkcji użyj `file`/`os` i zabezpiecz klucze.
