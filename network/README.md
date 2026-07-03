# `network/` — kanoniczne parametry launchu sieci IPI

Ten katalog dostarcza **autorytatywne, weryfikowalne parametry genesis** dla
oficjalnych sieci IPI (mainnet `ipi-mainnet-2`, testnet `ipi-testnet-1`).
Denom bazowy: `nipi`. Denom display: `ipi` (1 ipi = 10^9 nipi).

## Zawartość

| Plik | Rola |
|------|------|
| [`genesis-params.md`](./genesis-params.md) | Udokumentowany, autorytatywny zestaw parametrów modułów (staking/mint/gov/crisis/distribution/bank/wasm) dla mainnet i testnet. Źródło prawdy. |
| [`patch-genesis.sh`](./patch-genesis.sh) | Idempotentny skrypt `jq` nakładający te parametry na świeży `ipid init` genesis. Parametryzowany `NETWORK`/`CHAIN_ID`/`DENOM`. |
| `README.md` | Ten plik. |

## Użycie (init → patch → validate)

```bash
# 1. Inicjalizacja węzła (przykład: testnet)
ipid init "moj-node" --chain-id ipi-testnet-1 --default-denom nipi

# 2. Nałożenie kanonicznych parametrów
NETWORK=testnet CHAIN_ID=ipi-testnet-1 \
  ./network/patch-genesis.sh ~/.ipid/config/genesis.json

# 3. (opcjonalnie) walidacja binarką
ipid genesis validate ~/.ipid/config/genesis.json
```

Dla mainnet:
```bash
ipid init "moj-node" --chain-id ipi-mainnet-2 --default-denom nipi
NETWORK=mainnet ./network/patch-genesis.sh ~/.ipid/config/genesis.json
```

Skrypt:
- sprawdza obecność `jq` (twardy wymóg),
- robi **backup** (`genesis.json.bak.<timestamp>`) przed zmianą,
- nakłada parametry idempotentnie (kolejne uruchomienia = ten sam wynik),
- wypisuje kontrolę denom we wszystkich modułach,
- uruchamia `ipid genesis validate` **tylko jeśli** binarka jest w PATH
  (bez builda Go krok jest pomijany — to normalne).

### Wariant permissioned-upload przez multisig
```bash
WASM_UPLOAD=AnyOfAddresses WASM_UPLOAD_ADDRS=ipi1abc...,ipi1def... \
  NETWORK=mainnet ./network/patch-genesis.sh ~/.ipid/config/genesis.json
```

## Różnica: `network/` vs `devnet/`

| | `devnet/` (PR #3) | `network/` (ten PR) |
|---|---|---|
| Cel | **quick-start** dev, pojedynczy węzeł, `docker-compose` | **kanoniczne** parametry launchu publicznych sieci |
| Odbiorca | deweloper na laptopie | operatorzy walidatorów / koordynacja genesis |
| WASM upload | `Everybody` (wygoda) | `Nobody` (permissioned, bezpieczny launch) |
| Okresy gov | sekundy (`120s`) | dni (testnet 2 dni, mainnet 5 dni) |
| Artefakt | gotowy `genesis.template.json` + `init-devnet.sh` | dokument params + idempotentny patcher na `ipid init` |

`devnet/` i `network/` **nie kolidują** — to osobne katalogi o różnym
przeznaczeniu.

## Mapowanie na chainconfig SSOT

| Klucz SSOT        | Wartość          | Gdzie w genesis |
|-------------------|------------------|-----------------|
| chain-id mainnet  | `ipi-mainnet-2`  | `.chain_id` |
| chain-id testnet  | `ipi-testnet-1`  | `.chain_id` |
| denom bazowy      | `nipi`           | `staking.bond_denom`, `mint.mint_denom`, `crisis.constant_fee.denom`, `gov.*_deposit[].denom`, `bank.denom_metadata[0].base` |
| denom display     | `ipi` (exp 9)    | `bank.denom_metadata[0].display` |
| symbol            | `IPI`            | `bank.denom_metadata[0].symbol` |
| prefix bech32     | `ipi`            | (kod rebrandu, PR #4/#5 — nie w genesis) |
| coinType          | `118`            | (kod / klient — nie w genesis) |

> Prefix bech32 i coinType należą do kodu (rebrand PR #4/#5), nie do genesis —
> dokumentujemy je tu tylko dla kompletności SSOT.
