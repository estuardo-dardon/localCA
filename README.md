# localCA

Bash tool to create and manage a **local Certificate Authority (CA)** and issue TLS certificates for development environments.

## Quick Start (3 commands)

```bash
bash bin/localCA.sh --newCA --config ./config/config.conf
sudo bash bin/localCA.sh --installCA --config ./config/config.conf
sudo bash bin/localCA.sh --newCert --site milab.local --cert api --setupHost --ip 127.0.0.1 --config ./config/config.conf
```

Expected result: local CA created and trusted on Linux, certificate issued for `api.milab.local`, and host registered in `/etc/hosts`.

## Current Features

- Generate a local root CA (`--newCA`).
- Install and trust the CA in Linux (`--installCA`, requires `sudo`).
- Create the folder structure for a site (`--addSite`).
- Generate app/FQDN certificates (`--newCert`) in CLI or interactive mode.
- Register FQDN in `/etc/hosts` (`--setupHost`, requires `sudo`).
- Remove site certificate files (`--revoke`).

## Project Structure

```text
bin/
  localCA.sh
config/
  config.conf
sites/
```

Generated structure inside `ROOT_DIR`:

```text
ca/
  ca.crt
  ca.srl
  private/
    ca.key
sites/
  <site>/
    cert/
    key/
    fullchain/
```

## Requirements

- Linux with Bash.
- OpenSSL installed (`openssl`).
- Write permissions in `ROOT_DIR`.
- `sudo` for `--installCA` and `/etc/hosts` changes (`--setupHost`).

## System Installation

To install the command globally on Linux:

1) Copy the script to `/usr/local/bin/localCA`:

```bash
sudo cp bin/localCA.sh /usr/local/bin/localCA
```

2) Grant execute permissions:

```bash
sudo chmod +x /usr/local/bin/localCA
```

3) Create the configuration directory:

```bash
sudo mkdir -p /etc/localCA
```

4) Copy the configuration file:

```bash
sudo cp config/config.conf /etc/localCA/config.conf
```

5) Edit `/etc/localCA/config.conf` based on your needs (for example: `ROOT_DIR`, `CA_DAYS`, `CERT_DAYS`, `ORG`, `CN_CA`).

Example:

```bash
sudo nano /etc/localCA/config.conf
```

## Configuration

By default, the script looks for:

`/etc/localCA/config.conf`

You can also provide a custom path with `--config`.

Example `config/config.conf`:

```bash
ROOT_DIR="/path/to/certificate/base"
KEY_BITS=2048
CA_DAYS=3650
CERT_DAYS=825
COUNTRY="GT"
STATE="Guatemala"
ORG="Development Lab"
CN_CA="My Local Root Authority"
```

## Usage

```bash
bash bin/localCA.sh [options]
```

or if already installed in your `PATH`:

```bash
localCA [options]
```

### Actions

- `--newCA`: generate the local root CA.
- `--installCA`: install the CA into the system trust store (Linux).
- `--addSite`: create the structure for a base domain.
- `--newCert`: generate a certificate for an app/FQDN.
- `--setupHost`: add the FQDN to `/etc/hosts`.
- `--revoke`: delete a site folder.
- `--help`: show help.

### Parameters

- `--site <domain>`: base domain (for example `milab.local`).
- `--cert <name>`: app/certificate name (for example `api`).
- `--ip <address>`: IP for SAN/hosts (default `127.0.0.1`).
- `--config <path>`: configuration file path.

## Workflows

### 1) Create the root CA

```bash
bash bin/localCA.sh --newCA --config ./config/config.conf
```

### 2) Trust the CA on Linux

```bash
sudo localCA --installCA --config ./config/config.conf
```

> Note: the script also prints a guide for manual CA import in browsers.

### 3) Create site structure

```bash
bash bin/localCA.sh --addSite --site milab.local --config ./config/config.conf
```

### 4) Generate certificate (non-interactive mode)

Example for `api.milab.local`:

```bash
bash bin/localCA.sh --newCert --site milab.local --cert api --ip 127.0.0.1 --config ./config/config.conf
```

### 5) Generate certificate + register hosts

```bash
sudo localCA --newCert --site milab.local --cert api --setupHost --ip 127.0.0.1 --config ./config/config.conf
```

### 6) Register hosts only

```bash
sudo localCA --setupHost --site milab.local --cert api --ip 127.0.0.1 --config ./config/config.conf
```

### 7) Revoke site

```bash
bash bin/localCA.sh --revoke --site milab.local --config ./config/config.conf
```

## Generated Files per Certificate

For `--site milab.local --cert api`, the generated files are:

- `sites/milab.local/key/api.key`
- `sites/milab.local/cert/api.pem`
- `sites/milab.local/fullchain/api.pem`

Resulting FQDN: `api.milab.local`.

## Interactive Mode

If you run `--newCert` without parameters, the script asks for:

- Certificate/app name.
- Base domain.
- Target IP.
- Whether to add the host entry in `/etc/hosts`.

## Troubleshooting

- **Configuration file not found**
  - Check `--config` or create `/etc/localCA/config.conf`.
- **Permission error on `/etc/hosts` or trust store**
  - Run with `sudo` (`--setupHost` and `--installCA`).
- **CA not found while signing**
  - Run `--newCA` first.

## Donate

If this project helps you, you can support development with a PayPal donation:

- PayPal: https://paypal.me/estuardodardon


## Security

This project is intended for **local development** only. Do not use in production.