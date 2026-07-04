# Kanoniczne parametry genesis sieci IPI

Autorytatywny zestaw parametrów modułów genesis dla sieci **IPI** (fork `wasmd`,
Cosmos SDK v0.54, gov v1, moduł `wasm`). Ten dokument jest źródłem prawdy dla
skryptu [`patch-genesis.sh`](./patch-genesis.sh); wartości oznaczone
**DRAFT — decyzja DAO** są wyłącznie propozycjami startowymi i podlegają
zatwierdzeniu przez governance przed launchem (a po launchu zmianie przez
`MsgUpdateParams` / param-change proposal).

> Uwaga o zakresie: to NIE jest kompletny plik genesis. Kolekcje (`balances`,
> `supply`, `gen_txs`, `accounts`, alokacje) uzupełnia się komendami
> `ipid genesis add-genesis-account / gentx / collect-gentxs`. Tu dokumentujemy
> wyłącznie **parametry modułów**.

## 1. Tożsamość sieci (SSOT chainconfig)

| Pole              | Mainnet          | Testnet          |
|-------------------|------------------|------------------|
| chain-id          | `ipi-mainnet-2`  | `ipi-testnet-1`  |
| denom bazowy      | `nipi` (exp 0)   | `nipi` (exp 0)   |
| denom display     | `ipi` (exp 9)    | `ipi` (exp 9)    |
| symbol            | `IPI`            | `IPI`            |
| bech32 prefix     | `ipi`            | `ipi`            |
| coinType (SLIP44) | `118`            | `118`            |

Relacja jednostek: **1 ipi = 10^9 nipi** (9 miejsc dziesiętnych).

## 2. Parametry modułów

### staking (`.app_state.staking.params`)
| Parametr             | Mainnet    | Testnet    | Status |
|----------------------|------------|------------|--------|
| `bond_denom`         | `nipi`     | `nipi`     | KANON  |
| `unbonding_time`     | `1814400s` (21 dni) | `1209600s` (14 dni) | DRAFT |
| `min_commission_rate`| `0.05`     | `0.05`     | DRAFT  |

### mint (`.app_state.mint.params`, `.app_state.mint.minter`)
| Parametr               | Wartość  | Status |
|------------------------|----------|--------|
| `mint_denom`           | `nipi`   | KANON  |
| `inflation_min`        | `0.07` (7%)  | DRAFT — spójne z manifestem |
| `inflation_max`        | `0.20` (20%) | DRAFT — spójne z manifestem |
| `goal_bonded`          | `0.67` (67%) | DRAFT — spójne z manifestem |
| `inflation_rate_change`| `0.13`   | DRAFT  |
| `minter.inflation` (start) | `0.13` | DRAFT |
| `blocks_per_year`      | `6311520`| DRAFT  |

### gov v1 (`.app_state.gov.params`)
| Parametr                  | Mainnet                 | Testnet             | Status |
|---------------------------|-------------------------|---------------------|--------|
| `min_deposit`             | `10000000000000 nipi` (10 000 ipi) | `10000000000 nipi` (10 ipi) | DRAFT |
| `expedited_min_deposit`   | `50000000000000 nipi` (50 000 ipi) | `50000000000 nipi` (50 ipi) | DRAFT |
| `max_deposit_period`      | `1209600s` (14 dni)     | `172800s` (2 dni)   | DRAFT |
| `voting_period`           | `432000s` (5 dni)       | `172800s` (2 dni)   | DRAFT |
| `expedited_voting_period` | `86400s` (1 dzień)      | `86400s` (1 dzień)  | DRAFT |

Denom wszystkich depozytów: `nipi`. Pozostałe pola (`quorum`, `threshold`,
`veto_threshold`, `burn_*`) — wartości domyślne SDK, do przeglądu przez DAO.

> Moduł `crisis` został USUNIĘTY z Cosmos SDK ≥0.52 — nie występuje w `app.go`
> tego łańcucha, więc genesis nie zawiera `.app_state.crisis`. Nie ustawiamy
> `constant_fee` (byłby martwym, ignorowanym wpisem).

### distribution (`.app_state.distribution.params`)
| Parametr        | Wartość | Status |
|-----------------|---------|--------|
| `community_tax` | `0.02` (2%) | DRAFT |

### bank — metadane denom (`.app_state.bank.denom_metadata[0]`)
```json
{
  "description": "The native staking and governance token of the IPI network.",
  "denom_units": [
    { "denom": "nipi", "exponent": 0, "aliases": ["nanoipi"] },
    { "denom": "ipi",  "exponent": 9, "aliases": [] }
  ],
  "base": "nipi",
  "display": "ipi",
  "name": "IPI",
  "symbol": "IPI"
}
```
> `display` = `ipi` (małe) zgodnie z chainconfig SSOT; `symbol` = `IPI` (wielkie)
> to nazwa handlowa tokena. To świadoma decyzja różniąca się od skróconego
> szkicu w `devnet/genesis.template.json` (który używał `IPI` jako display) —
> kanonem launchu jest ten dokument.

### wasm — parametry (`.app_state.wasm.params`) — **PERMISSIONED NA START**
| Parametr                          | Wartość startowa | Status |
|-----------------------------------|------------------|--------|
| `code_upload_access.permission`   | `Nobody`         | KANON (bezpieczny launch) |
| `code_upload_access.addresses`    | `[]`             | —      |
| `instantiate_default_permission`  | `Everybody`      | DRAFT  |

Uzasadnienie: na starcie **upload kodu WASM tylko przez governance**
(`Nobody` => `StoreCode` wyłącznie via proposal), co chroni sieć przed wgraniem
niezaudytowanego kodu w pierwszej fazie. Po uploadzie zatwierdzonego kodu
jego instancjonowanie jest otwarte (`Everybody`), chyba że dany code ustawi
własną politykę. Dozwolone wartości `permission`: `Nobody`, `Everybody`,
`AnyOfAddresses` (dla `AnyOfAddresses` wymagana niepusta lista `addresses`).

Alternatywa dla launchu przez multisig/fundację: `code_upload_access =
AnyOfAddresses` z adresem launch-multisig (skrypt: `WASM_UPLOAD=AnyOfAddresses
WASM_UPLOAD_ADDRS=ipi1...`). Decyzja DAO.

## 3. Mapowanie na skrypt

Wszystkie powyższe wartości nakłada [`patch-genesis.sh`](./patch-genesis.sh) na
świeży `ipid init` genesis. Wartości czasowe/ekonomiczne dobierane są przez
zmienną `NETWORK` (`mainnet`/`testnet`); denom, prefix i struktura metadanych są
wspólne. Zobacz [`README.md`](./README.md) po instrukcję użycia.
