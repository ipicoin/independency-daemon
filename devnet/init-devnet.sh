#!/usr/bin/env bash
#
# init-devnet.sh — inicjalizacja pojedynczego węzła devnet/testnet IPI.
#
# Tworzy świeży katalog domowy węzła, genesis z parametrami IPI (SSOT),
# konto walidatora, gentx i collect-gentxs. Wynik: gotowy do `ipid start`.
#
# Zgodny z CLI wasmd / Cosmos SDK v0.54 (grupa poleceń `genesis`).
#
# UWAGA: docelowa binarka to `ipid` (po migracji ipid->wasmd, issue #1).
# Do czasu migracji binarka nosi nazwę `wasmd` — ustaw wtedy IPID_BIN=wasmd.
#
set -o errexit -o nounset -o pipefail

# ----------------------------------------------------------------------------
# Parametry SSOT (chainconfig IPI). Nadpisywalne przez zmienne środowiskowe.
# ----------------------------------------------------------------------------
IPID_BIN="${IPID_BIN:-ipid}"                 # nazwa binarki (ipid | wasmd)
CHAIN_ID="${CHAIN_ID:-ipi-testnet-1}"        # testnet: ipi-testnet-1 / mainnet: ipi-mainnet-2
DENOM="${DENOM:-nipi}"                        # denom bazowy (9 decimals => 1 IPI = 1e9 nipi)
MONIKER="${MONIKER:-ipi-devnet-node}"
HOME_DIR="${HOME_DIR:-$HOME/.ipid}"
KEYRING="${KEYRING:-test}"                    # keyring 'test' — TYLKO devnet, brak hasła
VAL_KEY="${VAL_KEY:-validator}"

# Alokacje (w nipi). 1 IPI = 1_000_000_000 nipi.
VAL_BALANCE="${VAL_BALANCE:-1000000000000000nipi}"   # 1 000 000 IPI dla walidatora
VAL_SELF_DELEGATION="${VAL_SELF_DELEGATION:-250000000000000nipi}"  # 250 000 IPI self-bond
FAUCET_BALANCE="${FAUCET_BALANCE:-500000000000000nipi}"  # 500 000 IPI dla faucetu

# Szybkie bloki na devnet (ok. 1s). Ustaw BLOCK_TIME dla innej wartości.
BLOCK_TIME="${BLOCK_TIME:-1s}"

echo ">> IPI devnet init"
echo "   binarka:   $IPID_BIN"
echo "   chain-id:  $CHAIN_ID"
echo "   denom:     $DENOM"
echo "   home:      $HOME_DIR"
echo "   keyring:   $KEYRING"

if ! command -v "$IPID_BIN" >/dev/null 2>&1; then
  echo "!! Nie znaleziono binarki '$IPID_BIN' w PATH."
  echo "   Zbuduj ją: 'make build' (powstanie build/wasmd) i ustaw IPID_BIN=wasmd,"
  echo "   albo dodaj build/ do PATH."
  exit 1
fi

BIN() { "$IPID_BIN" --home "$HOME_DIR" "$@"; }

# ----------------------------------------------------------------------------
# 0. Czysty start (opcjonalnie). Ustaw KEEP_HOME=1 aby nie kasować.
# ----------------------------------------------------------------------------
if [ "${KEEP_HOME:-0}" != "1" ] && [ -d "$HOME_DIR" ]; then
  echo ">> Kasuję istniejący $HOME_DIR (ustaw KEEP_HOME=1 aby zachować)"
  rm -rf "$HOME_DIR"
fi

# ----------------------------------------------------------------------------
# 1. init — tworzy config + wstępny genesis
# ----------------------------------------------------------------------------
BIN init "$MONIKER" --chain-id "$CHAIN_ID" --default-denom "$DENOM"

GENESIS="$HOME_DIR/config/genesis.json"

# ----------------------------------------------------------------------------
# 2. Parametry genesis (bond_denom, gov, mint, crisis) — zgodne z manifestem.
#    Preferujemy jq; fallback na sed dla bond_denom.
# ----------------------------------------------------------------------------
patch_genesis() {
  if command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp)"
    jq \
      --arg d "$DENOM" \
      '
      .app_state.staking.params.bond_denom = $d
      | .app_state.mint.params.mint_denom = $d
      | .app_state.crisis.constant_fee.denom = $d
      | .app_state.gov.params.min_deposit[0].denom = $d
      | .app_state.gov.params.expedited_min_deposit[0].denom = $d
      | .app_state.gov.params.min_deposit[0].amount = "10000000000"
      | .app_state.gov.params.voting_period = "120s"
      | .app_state.gov.params.expedited_voting_period = "60s"
      ' "$GENESIS" > "$tmp" && mv "$tmp" "$GENESIS"
  else
    echo ">> jq niedostępne — patchuję bond_denom przez sed (uproszczone)"
    sed -i.bak "s/\"stake\"/\"$DENOM\"/g" "$GENESIS" && rm -f "$GENESIS.bak"
  fi
}
patch_genesis

# ----------------------------------------------------------------------------
# 3. Konto walidatora + (opcjonalnie) faucet
# ----------------------------------------------------------------------------
if ! BIN keys show "$VAL_KEY" --keyring-backend "$KEYRING" >/dev/null 2>&1; then
  BIN keys add "$VAL_KEY" --keyring-backend "$KEYRING"
fi
BIN genesis add-genesis-account "$VAL_KEY" "$VAL_BALANCE" --keyring-backend "$KEYRING"

if [ "${WITH_FAUCET:-1}" = "1" ]; then
  if ! BIN keys show faucet --keyring-backend "$KEYRING" >/dev/null 2>&1; then
    BIN keys add faucet --keyring-backend "$KEYRING"
  fi
  BIN genesis add-genesis-account faucet "$FAUCET_BALANCE" --keyring-backend "$KEYRING"
fi

# Dodatkowe konta z argumentów: ./init-devnet.sh alice bob
for name in "$@"; do
  echo ">> Dodaję konto: $name"
  if ! BIN keys show "$name" --keyring-backend "$KEYRING" >/dev/null 2>&1; then
    BIN keys add "$name" --keyring-backend "$KEYRING"
  fi
  BIN genesis add-genesis-account "$name" "1000000000000nipi" --keyring-backend "$KEYRING"
done

# ----------------------------------------------------------------------------
# 4. gentx (walidator startowy) + collect-gentxs
# ----------------------------------------------------------------------------
BIN genesis gentx "$VAL_KEY" "$VAL_SELF_DELEGATION" \
  --chain-id "$CHAIN_ID" \
  --keyring-backend "$KEYRING" \
  --moniker "$MONIKER"

BIN genesis collect-gentxs
BIN genesis validate-genesis || BIN genesis validate

# ----------------------------------------------------------------------------
# 5. Konfiguracja node'a (czas bloku, CORS, otwarte endpointy RPC/REST/gRPC)
# ----------------------------------------------------------------------------
CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

# szybkie bloki
sed -i.bak "s/^timeout_commit = .*/timeout_commit = \"$BLOCK_TIME\"/" "$CONFIG_TOML" && rm -f "$CONFIG_TOML.bak"
# RPC nasłuch na wszystkich interfejsach (devnet)
sed -i.bak 's#^laddr = "tcp://127.0.0.1:26657"#laddr = "tcp://0.0.0.0:26657"#' "$CONFIG_TOML" && rm -f "$CONFIG_TOML.bak"
# CORS dla RPC
sed -i.bak 's/^cors_allowed_origins = \[\]/cors_allowed_origins = ["*"]/' "$CONFIG_TOML" && rm -f "$CONFIG_TOML.bak"

# REST API + gRPC on
sed -i.bak 's/^enable = false/enable = true/' "$APP_TOML" && rm -f "$APP_TOML.bak"
sed -i.bak 's#^address = "tcp://localhost:1317"#address = "tcp://0.0.0.0:1317"#' "$APP_TOML" && rm -f "$APP_TOML.bak"
# minimalne opłaty (0 na devnet)
sed -i.bak "s/^minimum-gas-prices = .*/minimum-gas-prices = \"0$DENOM\"/" "$APP_TOML" && rm -f "$APP_TOML.bak"

echo ""
echo ">> Gotowe. Uruchom węzeł:"
echo "   $IPID_BIN start --home $HOME_DIR"
echo ""
echo ">> RPC:  http://localhost:26657   REST: http://localhost:1317   gRPC: localhost:9090"
echo ">> Adres walidatora:"
BIN keys show "$VAL_KEY" -a --keyring-backend "$KEYRING" || true
if [ "${WITH_FAUCET:-1}" = "1" ]; then
  echo ">> Adres faucetu:"
  BIN keys show faucet -a --keyring-backend "$KEYRING" || true
fi
