# Faucet — IPI testnet (`ipi-testnet-1`)

Faucet wydaje testowe tokeny **IPI** (denom bazowy `nipi`) na żądanie, z rate-limitem.
Rekomendujemy [`@cosmjs/faucet`](https://github.com/cosmos/cosmjs/tree/main/packages/faucet)
(oficjalny, lekki, konfigurowalny zmiennymi środowiskowymi) — ten sam obraz jest
w `devnet/docker-compose.yml` (profil `faucet`).

## Parametry sieci (SSOT)

| Parametr           | Wartość          |
|--------------------|------------------|
| chain-id           | `ipi-testnet-1`  |
| denom bazowy       | `nipi`           |
| display / symbol   | `IPI`            |
| decimals           | `9` (1 IPI = 1 000 000 000 nipi) |
| bech32 prefix      | `ipi`            |
| coinType (HD)      | `118` (`m/44'/118'/0'/0/a`) |
| RPC                | `https://rpc.testnet.ipicoin.eu` (lokalnie `http://localhost:26657`) |

## Wariant A — Docker (najprościej)

Konto `faucet` jest tworzone i zasilane przez `init-devnet.sh` (500 000 IPI w genesis).
Pobierz jego mnemonik i wstrzyknij do faucetu:

```bash
# mnemonik konta faucet (keyring 'test' — TYLKO testnet!)
ipid keys export faucet --unarmored-hex --unsafe --keyring-backend test --home ~/.ipid
# lub przy tworzeniu konta zapisz mnemonik wypisany przez 'keys add'

# .env obok docker-compose.yml (NIE commituj realnego mnemonika):
echo 'FAUCET_MNEMONIC="word1 word2 ... word24"' > devnet/.env

docker compose -f devnet/docker-compose.yml --profile faucet up -d
```

Wypłata:

```bash
curl -X POST http://localhost:8000/credit \
  -H "Content-Type: application/json" \
  -d '{"address":"ipi1...", "denom":"IPI"}'
```

Status / dostępne tokeny: `GET http://localhost:8000/status`.

## Wariant B — bez Dockera

```bash
npm i -g @cosmjs/faucet

export FAUCET_CONCURRENCY=2
export FAUCET_PORT=8000
export FAUCET_MEMO="IPI testnet faucet"
export FAUCET_GAS_PRICE=0nipi
export FAUCET_GAS_LIMIT=100000
export FAUCET_ADDRESS_PREFIX=ipi
export FAUCET_PATH_PATTERN="m/44'/118'/0'/0/a"
# denom bazowy 'nipi' z 9 miejscami -> 1 IPI = 1e9 nipi.
# Format: NAZWA=fractionalDigits,minorDenom (patrz dokumentacja @cosmjs/faucet)
export FAUCET_TOKENS="IPI"
export FAUCET_MNEMONIC="<mnemonik konta faucet>"

# wypłata 100 IPI = 100 000 000 000 nipi na żądanie
export FAUCET_CREDIT_AMOUNT_IPI=100
export FAUCET_REFILL_FACTOR=20
export FAUCET_REFILL_THRESHOLD=20

cosmos-faucet start http://localhost:26657
```

## Rate-limiting

`@cosmjs/faucet` ogranicza wypłaty per adres na podstawie salda docelowego:
gdy adres ma już >= `FAUCET_CREDIT_AMOUNT` danego tokena, żądanie jest odrzucane.
Do publicznego wystawienia postaw faucet za reverse-proxy (nginx/Caddy) z limitem
per-IP, np.:

```nginx
limit_req_zone $binary_remote_addr zone=faucet:10m rate=6r/m;
server {
  listen 443 ssl;
  server_name faucet.testnet.ipicoin.eu;
  location /credit {
    limit_req zone=faucet burst=3 nodelay;
    proxy_pass http://127.0.0.1:8000;
  }
  location /status { proxy_pass http://127.0.0.1:8000; }
}
```

## Frontend

Minimalny frontend: strona z polem na adres `ipi1...` i przyciskiem robiącym
`POST /credit`. Można hostować statycznie na `faucet.testnet.ipicoin.eu`
i kierować do endpointu `/credit` powyżej.

## Bezpieczeństwo

- To **testnet** — tokeny bez wartości. Mimo to **nie** commituj realnego mnemonika faucetu.
- Trzymaj mnemonik w `devnet/.env` (dodane do `.gitignore`) lub w sekrecie CI/hostingu.
- Utrzymuj zapas na koncie faucet; `init-devnet.sh` alokuje 500 000 IPI w genesis.
