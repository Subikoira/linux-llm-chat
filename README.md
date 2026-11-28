# LLM-chat (viikko 5)

Pieni chat-sivu, jossa keskustellaan omalla palvelimella pyörivän kielimallin kanssa.
Sivu on osoitteessa http://195.148.21.71/viikko5/

Pohjana on kurssin esimerkkikoodi. Mukana on vain muutokset, joita tarvittiin, jotta sivu toimii alipolussa `/viikko5/`.

## Miten se toimii

Selain → Nginx → Gunicorn/Flask → Ollama (malli `llama3.2:1b`) ja MariaDB (keskusteluhistoria).

Ollama ja tietokanta kuuntelevat vain palvelimen sisällä. Ulos näkyy vain Nginx (portti 80) ja SSH (portti 22).

## Mitä repossa on

- `app.py`, `db.py`: sovellus
- `test_app.py`: testit (malli ja tietokanta on korvattu valeilla, joten ne toimivat ilman niitä)
- `templates/`, `static/`: sivun ulkoasu ja selaimen koodi
- `deploy/nginx/chatapp.conf`: Nginxin `/viikko5/`-pätkä
- `deploy/systemd/chatapp.service`: palvelun asetukset
- `deploy/sql/schema.sql`: tietokannan taulu
- `scripts/server-setup.sh`: palvelimen kertaluonteinen alustus
- `scripts/deploy.sh`: julkaisuskripti, jonka GitHub Actions ajaa
- `.github/workflows/ci-cd.yml`: testit ja automaattinen julkaisu

## Palvelimen asennus (kerran)

1. Kopioi `scripts/server-setup.sh` palvelimelle ja aja: `bash server-setup.sh llama3.2:1b`.
   Skripti asentaa tarvittavat ohjelmat, luo käyttäjän `chatapp`, tietokannan ja Ollaman sekä kirjoittaa salasanan tiedostoon `/etc/chatapp/chatapp.env` (vain root ja `chatapp` voivat lukea sen).
2. Lisää olemassa olevan Nginx-sivuston `server { }` -lohkoon yksi rivi: `include snippets/chatapp.conf;`
3. Tee GitHub Actionsille oma SSH-avain (ei omaa avaintasi) ja lisää repon Secretsiin:
   - `CPOUTA_HOST`: palvelimen osoite
   - `CPOUTA_USER`: `ubuntu`
   - `CPOUTA_SSH_KEY`: yksityinen avain base64-muodossa yhtenä rivinä
   - `CPOUTA_KNOWN_HOSTS`: palvelimen host key

Salaisuuksia ei ole commitoitu repoon.

## Julkaisu

Jokainen push `main`-haaraan ajaa testit ja, jos ne menevät läpi, julkaisee uuden version palvelimelle. Pull requestissa ajetaan vain testit.

Julkaisu kopioi koodin palvelimelle, päivittää Nginxin ja systemd:n asetukset ja käynnistää vain `chatapp`-palvelun. Lopuksi tarkistetaan, että `/viikko5/health` palauttaa juuri julkaistun commitin tunnisteen.

## Testit paikallisesti

```
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
ruff check .
pytest
```
