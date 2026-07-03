#!/usr/bin/env bash
#
# patch-genesis.sh — nakłada KANONICZNE parametry genesis sieci IPI na świeży
# genesis wygenerowany przez `ipid init`. Idempotentny (kolejne uruchomienia
# dają ten sam wynik). Zgodny z Cosmos SDK v0.50+/v0.54 (gov v1) + moduł wasm.
#
# SSOT (repo chainconfig):
#   - chain-id mainnet : ipi-mainnet-2
#   - chain-id testnet : ipi-testnet-1
#   - denom bazowy     : nipi  (exp 0)
#   - denom display    : ipi   (exp 9)  => 1 ipi = 10^9 nipi
#   - symbol           : IPI
#   - bech32 prefix    : ipi
#   - coinType         : 118
#
# Użycie:
#   ipid init <moniker> --chain-id ipi-testnet-1 --default-denom nipi
#   NETWORK=testnet CHAIN_ID=ipi-testnet-1 ./network/patch-genesis.sh ~/.ipid/config/genesis.json
#   ipid genesis validate ~/.ipid/config/genesis.json   # opcjonalnie
#
# Zmienne środowiskowe (wszystkie mają wartości domyślne):
#   NETWORK   mainnet | testnet          (domyślnie: testnet)
#   CHAIN_ID  identyfikator łańcucha      (domyślnie: zależnie od NETWORK)
#   DENOM     denom bazowy               (domyślnie: nipi)
#   DISPLAY   denom display              (domyślnie: ipi)
#   SYMBOL    symbol tokena              (domyślnie: IPI)
#   EXPONENT  liczba miejsc dziesiętnych (domyślnie: 9)
#   WASM_UPLOAD   Nobody | Everybody | AnyOfAddresses  (domyślnie: Nobody)
#   WASM_UPLOAD_ADDRS  CSV adresów gdy AnyOfAddresses  (domyślnie: puste)
#   WASM_INSTANTIATE   Nobody | Everybody | AnyOfAddresses (domyślnie: Everybody)
#   BIN       nazwa binarki do walidacji (domyślnie: ipid)
#
set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Argumenty / walidacja środowiska
# ---------------------------------------------------------------------------
GENESIS="${1:-}"
if [[ -z "${GENESIS}" ]]; then
  echo "BŁĄD: podaj ścieżkę do genesis.json jako pierwszy argument." >&2
  echo "Przykład: NETWORK=testnet $0 ~/.ipid/config/genesis.json" >&2
  exit 2
fi
if [[ ! -f "${GENESIS}" ]]; then
  echo "BŁĄD: plik genesis nie istnieje: ${GENESIS}" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "BŁĄD: wymagane jest 'jq' (nie znaleziono w PATH)." >&2
  exit 3
fi

NETWORK="${NETWORK:-testnet}"
case "${NETWORK}" in
  mainnet) DEFAULT_CHAIN_ID="ipi-mainnet-2" ;;
  testnet) DEFAULT_CHAIN_ID="ipi-testnet-1" ;;
  *) echo "BŁĄD: NETWORK musi być 'mainnet' lub 'testnet' (jest: ${NETWORK})." >&2; exit 2 ;;
esac

CHAIN_ID="${CHAIN_ID:-${DEFAULT_CHAIN_ID}}"
DENOM="${DENOM:-nipi}"
DISPLAY="${DISPLAY:-ipi}"
SYMBOL="${SYMBOL:-IPI}"
EXPONENT="${EXPONENT:-9}"
WASM_UPLOAD="${WASM_UPLOAD:-Nobody}"
WASM_UPLOAD_ADDRS="${WASM_UPLOAD_ADDRS:-}"
WASM_INSTANTIATE="${WASM_INSTANTIATE:-Everybody}"
BIN="${BIN:-ipid}"

# Parametry czasowe (DRAFT — decyzja DAO). Mainnet dłuższe, testnet krótsze.
if [[ "${NETWORK}" == "mainnet" ]]; then
  VOTING_PERIOD="432000s"            # 5 dni
  EXPEDITED_VOTING_PERIOD="86400s"   # 1 dzień
  MAX_DEPOSIT_PERIOD="1209600s"      # 14 dni
  UNBONDING_TIME="1814400s"          # 21 dni
  MIN_DEPOSIT_AMT="10000000000000"      # 10 000 ipi (10^13 nipi)   DRAFT
  EXPEDITED_MIN_DEPOSIT_AMT="50000000000000" # 50 000 ipi          DRAFT
  CONSTANT_FEE_AMT="1000000000000000"   # 1 000 000 ipi            DRAFT
else
  VOTING_PERIOD="172800s"            # 2 dni
  EXPEDITED_VOTING_PERIOD="86400s"   # 1 dzień
  MAX_DEPOSIT_PERIOD="172800s"       # 2 dni
  UNBONDING_TIME="1209600s"          # 14 dni
  MIN_DEPOSIT_AMT="10000000000"         # 10 ipi                   DRAFT
  EXPEDITED_MIN_DEPOSIT_AMT="50000000000"    # 50 ipi              DRAFT
  CONSTANT_FEE_AMT="1000000000000"      # 1 000 ipi                DRAFT
fi

# Ekonomia inflacji (DRAFT — decyzja DAO), spójna z manifestem: 7% / 20% / 67%.
INFLATION_MIN="0.070000000000000000"
INFLATION_MAX="0.200000000000000000"
GOAL_BONDED="0.670000000000000000"
INFLATION_RATE_CHANGE="0.130000000000000000"
INITIAL_INFLATION="0.130000000000000000"
BLOCKS_PER_YEAR="6311520"
COMMUNITY_TAX="0.020000000000000000"
MIN_COMMISSION_RATE="0.050000000000000000"

echo "==> Patchuję genesis: ${GENESIS}"
echo "    NETWORK=${NETWORK}  CHAIN_ID=${CHAIN_ID}  DENOM=${DENOM}  DISPLAY=${DISPLAY} (exp ${EXPONENT})"
echo "    wasm.code_upload_access=${WASM_UPLOAD}  instantiate_default=${WASM_INSTANTIATE}"

# ---------------------------------------------------------------------------
# 1. Backup
# ---------------------------------------------------------------------------
BACKUP="${GENESIS}.bak.$(date +%Y%m%d%H%M%S)"
cp "${GENESIS}" "${BACKUP}"
echo "==> Backup: ${BACKUP}"

# ---------------------------------------------------------------------------
# 2. Budowa obiektu wasm.code_upload_access (addresses puste chyba że AnyOfAddresses)
# ---------------------------------------------------------------------------
if [[ "${WASM_UPLOAD}" == "AnyOfAddresses" && -n "${WASM_UPLOAD_ADDRS}" ]]; then
  UPLOAD_ADDRS_JSON=$(printf '%s' "${WASM_UPLOAD_ADDRS}" | jq -R 'split(",") | map(select(length>0))')
else
  UPLOAD_ADDRS_JSON='[]'
fi

# ---------------------------------------------------------------------------
# 3. Właściwy patch jq (idempotentny — nadpisuje wartości bez względu na stan)
# ---------------------------------------------------------------------------
TMP="${GENESIS}.tmp.$$"
jq \
  --arg chain_id "${CHAIN_ID}" \
  --arg denom "${DENOM}" \
  --arg display "${DISPLAY}" \
  --arg symbol "${SYMBOL}" \
  --argjson exponent "${EXPONENT}" \
  --arg unbonding "${UNBONDING_TIME}" \
  --arg min_comm "${MIN_COMMISSION_RATE}" \
  --arg infl_min "${INFLATION_MIN}" \
  --arg infl_max "${INFLATION_MAX}" \
  --arg goal_bonded "${GOAL_BONDED}" \
  --arg infl_change "${INFLATION_RATE_CHANGE}" \
  --arg infl_init "${INITIAL_INFLATION}" \
  --arg bpy "${BLOCKS_PER_YEAR}" \
  --arg min_dep "${MIN_DEPOSIT_AMT}" \
  --arg exp_min_dep "${EXPEDITED_MIN_DEPOSIT_AMT}" \
  --arg max_dep_period "${MAX_DEPOSIT_PERIOD}" \
  --arg voting "${VOTING_PERIOD}" \
  --arg exp_voting "${EXPEDITED_VOTING_PERIOD}" \
  --arg constfee "${CONSTANT_FEE_AMT}" \
  --arg comm_tax "${COMMUNITY_TAX}" \
  --arg wasm_upload "${WASM_UPLOAD}" \
  --argjson wasm_upload_addrs "${UPLOAD_ADDRS_JSON}" \
  --arg wasm_instantiate "${WASM_INSTANTIATE}" \
'
  # --- chain_id ---
  .chain_id = $chain_id

  # --- staking ---
  | .app_state.staking.params.bond_denom       = $denom
  | .app_state.staking.params.unbonding_time    = $unbonding
  | .app_state.staking.params.min_commission_rate = $min_comm

  # --- mint ---
  | .app_state.mint.params.mint_denom           = $denom
  | .app_state.mint.params.inflation_min        = $infl_min
  | .app_state.mint.params.inflation_max        = $infl_max
  | .app_state.mint.params.goal_bonded          = $goal_bonded
  | .app_state.mint.params.inflation_rate_change = $infl_change
  | .app_state.mint.params.blocks_per_year      = $bpy
  | .app_state.mint.minter.inflation            = $infl_init

  # --- gov (v1) ---
  | .app_state.gov.params.min_deposit           = [ { "denom": $denom, "amount": $min_dep } ]
  | .app_state.gov.params.expedited_min_deposit = [ { "denom": $denom, "amount": $exp_min_dep } ]
  | .app_state.gov.params.max_deposit_period    = $max_dep_period
  | .app_state.gov.params.voting_period         = $voting
  | .app_state.gov.params.expedited_voting_period = $exp_voting

  # --- crisis ---
  | .app_state.crisis.constant_fee              = { "denom": $denom, "amount": $constfee }

  # --- distribution ---
  | .app_state.distribution.params.community_tax = $comm_tax

  # --- bank denom_metadata (nadpisuje jednym kanonicznym wpisem) ---
  | .app_state.bank.denom_metadata = [ {
        "description": "The native staking and governance token of the IPI network.",
        "denom_units": [
          { "denom": $denom,   "exponent": 0,         "aliases": [ ("nano" + $display) ] },
          { "denom": $display, "exponent": $exponent, "aliases": [] }
        ],
        "base": $denom,
        "display": $display,
        "name": $symbol,
        "symbol": $symbol
    } ]

  # --- wasm params (permissioned na start) ---
  | .app_state.wasm.params.code_upload_access = {
        "permission": $wasm_upload,
        "addresses": $wasm_upload_addrs
    }
  | .app_state.wasm.params.instantiate_default_permission = $wasm_instantiate
' "${GENESIS}" > "${TMP}"

mv "${TMP}" "${GENESIS}"
echo "==> Zapatchowano."

# ---------------------------------------------------------------------------
# 4. Szybka weryfikacja spójności denom (bez node'a)
# ---------------------------------------------------------------------------
echo "==> Weryfikacja denom (oczekiwane: ${DENOM}):"
jq -r '
  "  staking.bond_denom   = " + .app_state.staking.params.bond_denom,
  "  mint.mint_denom      = " + .app_state.mint.params.mint_denom,
  "  gov.min_deposit[0]   = " + .app_state.gov.params.min_deposit[0].denom,
  "  crisis.constant_fee  = " + .app_state.crisis.constant_fee.denom,
  "  bank.metadata.base   = " + .app_state.bank.denom_metadata[0].base,
  "  wasm.code_upload     = " + .app_state.wasm.params.code_upload_access.permission,
  "  chain_id             = " + .chain_id
' "${GENESIS}"

# ---------------------------------------------------------------------------
# 5. Walidacja binarką (opcjonalna — tylko gdy ipid dostępne)
# ---------------------------------------------------------------------------
if command -v "${BIN}" >/dev/null 2>&1; then
  echo "==> ${BIN} genesis validate:"
  "${BIN}" genesis validate "${GENESIS}" || {
    echo "OSTRZEŻENIE: walidacja binarką nie powiodła się (sprawdź genesis)." >&2
    exit 1
  }
else
  echo "==> Pomijam 'genesis validate' — binarka '${BIN}' niedostępna (to OK bez builda Go)."
fi

echo "==> GOTOWE."
