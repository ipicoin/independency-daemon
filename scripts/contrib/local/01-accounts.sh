#!/bin/bash
set -o errexit -o nounset -o pipefail

BASE_ACCOUNT=$(ipid keys show validator -a --keyring-backend=test)
ipid q auth account "$BASE_ACCOUNT" -o json | jq

echo "## Add new account"
ipid keys add fred --keyring-backend=test

echo "## Check balance"
NEW_ACCOUNT=$(ipid keys show fred -a --keyring-backend=test)
ipid q bank balances "$NEW_ACCOUNT" -o json || true

echo "## Transfer tokens"
ipid tx bank send validator "$NEW_ACCOUNT" 1nipi --gas 1000000 -y --chain-id=testing --node=http://localhost:26657 -b sync -o json --keyring-backend=test | jq

echo "## Check balance again"
ipid q bank balances "$NEW_ACCOUNT" -o json | jq
