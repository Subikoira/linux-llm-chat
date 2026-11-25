#!/usr/bin/env bash
# Kertaluonteinen palvelimen alustus cPouta-virtuaalikoneelle (Ubuntu 22.04/24.04).
# Aja palvelimella oletuskäyttäjänä (ubuntu):
#   bash server-setup.sh [ollama-malli]
# Esim: bash server-setup.sh llama3.2:1b
# Skripti on idempotentti: sen voi ajaa uudelleen.
set -euo pipefail

MODEL="${1:-llama3.2:1b}"
DEPLOY_USER="${DEPLOY_USER:-$(whoami)}"
APP_ROOT=/opt/chatapp
ENV_DIR=/etc/chatapp
ENV_FILE=$ENV_DIR/chatapp.env
DB_NAME=chatapp
DB_USER=chatapp

echo "==> Asennetaan paketit (Nginx, MariaDB, Python, rsync)"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    nginx mariadb-server python3-venv python3-pip rsync curl openssl

echo "==> Luodaan palvelukäyttäjä 'chatapp' ja hakemistot"
if ! id chatapp &>/dev/null; then
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin chatapp
fi
sudo mkdir -p "$APP_ROOT/app" "$ENV_DIR"
# Deploy-käyttäjä (GitHub Actions SSH:lla) omistaa koodin; palvelu lukee sitä.
sudo chown -R "$DEPLOY_USER:$DEPLOY_USER" "$APP_ROOT"
sudo chmod 755 "$APP_ROOT" "$APP_ROOT/app"

echo "==> MariaDB: tietokanta ja käyttäjä"
sudo systemctl enable --now mariadb
if [ ! -f "$ENV_FILE" ]; then
    DB_PASSWORD="$(openssl rand -hex 24)"
    sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

    echo "==> Kirjoitetaan $ENV_FILE"
    sudo tee "$ENV_FILE" >/dev/null <<ENV
# Sovelluksen ympäristömuuttujat (luotu server-setup.sh:lla)
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
OLLAMA_URL=http://127.0.0.1:11434
OLLAMA_MODEL=$MODEL
HISTORY_LIMIT=10
ENV
    sudo chown root:chatapp "$ENV_FILE"
    sudo chmod 640 "$ENV_FILE"
else
    echo "    $ENV_FILE on jo olemassa – ei muuteta salasanaa."
    sudo sed -i "s|^OLLAMA_MODEL=.*|OLLAMA_MODEL=$MODEL|" "$ENV_FILE"
fi

echo "==> Ollama"
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
fi
sudo systemctl enable --now ollama
# Odotetaan että Ollaman API vastaa
for _ in $(seq 1 30); do
    curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break
    sleep 2
done
echo "==> Ladataan malli $MODEL (voi kestää useita minuutteja)"
ollama pull "$MODEL"

echo "==> Nginx päälle"
sudo systemctl enable --now nginx

cat <<DONE

Valmis! Seuraavaksi:
  1. Lisää GitHub-repon Secrets: CPOUTA_HOST, CPOUTA_USER ($DEPLOY_USER), CPOUTA_SSH_KEY
  2. git push -> GitHub Actions ajaa testit ja deployaa koodin hakemistoon $APP_ROOT/app
  3. Avaa selaimessa http://<floating-ip>/viikko5/

DONE
