#!/bin/bash

# Path por defecto
DEFAULT_CONFIG="/etc/localCA/config.conf"
CONFIG_FILE=""

# --- Fase 1: Buscar el parámetro --config ---
temp_args=("$@")
for ((i=0; i<${#temp_args[@]}; i++)); do
    if [[ "${temp_args[$i]}" == "--config" ]]; then
        CONFIG_FILE="${temp_args[$((i+1))]}"
    fi
done

if [[ -z "$CONFIG_FILE" ]]; then CONFIG_FILE="$DEFAULT_CONFIG"; fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Error: No se encuentra el archivo de configuración en: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# --- Fase 2: Configuración de variables ---
IP_TARGET="127.0.0.1"
ADD_TO_HOSTS=false
CERT_NAME=""

# Función para verificar privilegios de sudo/root
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Error: Esta acción requiere privilegios de superusuario (sudo)."
        echo "Ejecuta el comando anteponiendo 'sudo', por ejemplo: sudo localca --installCA"
        exit 1
    fi
}

show_help() {
    echo "Uso: localca [opciones]"
    echo ""
    echo "ACCIONES:"
    echo "  --newCA            Generar Root CA local"
    echo "  --installCA        Instalar y confiar en la CA en el sistema (Requiere sudo)"
    echo "  --addSite          Crea estructura de carpetas para un sitio"
    echo "  --newCert          Generar certificado (Interactivo)"
    echo "  --setupHost        Añade el FQDN al archivo /etc/hosts (Requiere sudo)"
    echo "  --revoke           Borra certificados de un sitio"
    echo ""
    echo "PARÁMETROS:"
    echo "  --site [dominio]   Dominio base (ej. micromoni.local)"
    echo "  --cert [nombre]    Nombre de la app/cert (ej. app1)"
    echo "  --ip [dirección]   IP para el host (Default: 127.0.0.1)"
    echo "  --config [ruta]    Ruta al archivo .conf"
    echo "  --help             Muestra esta ayuda"
}

function register_host() {
    local fqdn=$1
    local ip=$2
    check_sudo
    if grep -qE "^$ip[[:space:]]+$fqdn" /etc/hosts; then
        echo "ℹ️ El FQDN $fqdn ya apunta a $ip en /etc/hosts"
    else
        echo "$ip   $fqdn" | tee -a /etc/hosts > /dev/null
        echo "✅ Mapeo completado: $ip -> $fqdn"
    fi
}

# Parseo de argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --newCA) ACTION="NEW_CA"; shift ;;
        --installCA) ACTION="INSTALL_CA"; shift ;;
        --addSite) ACTION="ADD_SITE"; shift ;;
        --newCert) ACTION="NEW_CERT"; shift ;;
        --setupHost) ADD_TO_HOSTS=true; shift ;;
        --revoke) ACTION="REVOKE"; shift ;;
        --site) SITE_NAME="$2"; shift 2 ;;
        --cert) CERT_NAME="$2"; shift 2 ;;
        --ip) IP_TARGET="$2"; shift 2 ;;
        --config) shift 2 ;;
        --help) show_help; exit 0 ;;
        *) shift ;;
    esac
done

if [[ -z "$ACTION" && "$ADD_TO_HOSTS" = true ]]; then ACTION="SETUP_HOST_ONLY"; fi

CA_PATH="$ROOT_DIR/ca"
SITES_PATH="$ROOT_DIR/sites"

case $ACTION in
    NEW_CA)
        echo "--- Generando Root CA ---"
        mkdir -p "$CA_PATH/private"
        openssl genrsa -out "$CA_PATH/private/ca.key" "$KEY_BITS"
        openssl req -x509 -new -nodes -key "$CA_PATH/private/ca.key" \
            -sha256 -days "$CA_DAYS" -out "$CA_PATH/ca.crt" \
            -subj "/C=$COUNTRY/ST=$STATE/L=Local/O=$ORG/CN=$CN_CA"
        echo "✅ CA Creada en $CA_PATH"
        echo "👉 Sugerencia: Ejecuta 'sudo localca --installCA' para confiar en ella."
        ;;

    INSTALL_CA)
        check_sudo
        echo "--- Instalando confianza del sistema ---"
        if [[ ! -f "$CA_PATH/ca.crt" ]]; then
            echo "❌ Error: No se encontró el archivo $CA_PATH/ca.crt."
            exit 1
        fi

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            cp "$CA_PATH/ca.crt" /usr/local/share/ca-certificates/localca.crt
            update-ca-certificates
            echo "✅ CA instalada exitosamente en el sistema operativo."
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "⚠️  IMPORTANTE: CONFIGURACIÓN MANUAL EN NAVEGADORES"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Navegadores como Firefox y Chrome suelen ignorar el almacén del sistema:"
            echo ""
            echo "1. Abre tu navegador y ve a 'Ajustes' o 'Configuración'."
            echo "2. Busca 'Certificados' -> 'Ver Certificados'."
            echo "3. Ve a la pestaña 'Autoridades' e importa el archivo:"
            echo "   $CA_PATH/ca.crt"
            echo "4. Marca la casilla: 'Confiar en esta CA para identificar sitios web'."
            echo "5. Reinicia el navegador para aplicar los cambios."
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            echo "⚠️ Esta acción automática solo está soportada para Linux."
        fi
        ;;

    ADD_SITE)
        if [[ -z "$SITE_NAME" ]]; then read -p "📝 Sitio/Dominio Base: " SITE_NAME; fi
        mkdir -p "$SITES_PATH/$SITE_NAME"/{cert,key,fullchain}
        echo "✅ Estructura creada en $SITES_PATH/$SITE_NAME"
        ;;

    NEW_CERT)
        if [[ -z "$SITE_NAME" ]]; then
            echo "--- Configuración de nuevo certificado ---"
            read -p "🔹 Nombre del Certificado/App (ej. app1): " CERT_NAME
            read -p "🔹 Dominio Base (ej. micromoni.local): " SITE_NAME
            read -p "🔹 IP de destino [$IP_TARGET]: " INPUT_IP
            IP_TARGET=${INPUT_IP:-$IP_TARGET}
            read -p "🔹 ¿Deseas agregar a /etc/hosts? (s/n): " RESP
            [[ "$RESP" =~ ^[Ss]$ ]] && ADD_TO_HOSTS=true
        fi

        FQDN="$CERT_NAME.$SITE_NAME"
        S_DIR="$SITES_PATH/$SITE_NAME"
        mkdir -p "$S_DIR"/{cert,key,fullchain}

        echo "--- Procesando Certificado para $FQDN ---"
        openssl genrsa -out "$S_DIR/key/$CERT_NAME.key" "$KEY_BITS"
        EXT_CONF="$S_DIR/$CERT_NAME.ext"
        echo "subjectAltName = DNS:$FQDN, DNS:*.$FQDN, IP:$IP_TARGET" > "$EXT_CONF"
        openssl req -new -key "$S_DIR/key/$CERT_NAME.key" \
            -subj "/C=$COUNTRY/ST=$STATE/O=$ORG/CN=$FQDN" -out "$S_DIR/temp.csr"
        openssl x509 -req -in "$S_DIR/temp.csr" \
            -CA "$CA_PATH/ca.crt" -CAkey "$CA_PATH/private/ca.key" \
            -CAcreateserial -out "$S_DIR/cert/$CERT_NAME.pem" \
            -days "$CERT_DAYS" -sha256 -extfile "$EXT_CONF"

        cat "$S_DIR/cert/$CERT_NAME.pem" "$CA_PATH/ca.crt" > "$S_DIR/fullchain/$CERT_NAME.pem"
        rm "$S_DIR/temp.csr" "$EXT_CONF"
        
        echo "✅ Certificado generado en: $S_DIR/fullchain/$CERT_NAME.pem"

        if [ "$ADD_TO_HOSTS" = true ]; then
            register_host "$FQDN" "$IP_TARGET"
        fi
        ;;

    SETUP_HOST_ONLY)
        if [[ -z "$CERT_NAME" ]]; then read -p "🔹 Nombre de App: " CERT_NAME; fi
        if [[ -z "$SITE_NAME" ]]; then read -p "🔹 Dominio Base: " SITE_NAME; fi
        register_host "$CERT_NAME.$SITE_NAME" "$IP_TARGET"
        ;;

    REVOKE)
        if [[ -z "$SITE_NAME" ]]; then read -p "🗑️  Dominio Base a eliminar: " SITE_NAME; fi
        rm -rf "$SITES_PATH/$SITE_NAME"
        echo "✅ Carpeta de sitio $SITE_NAME eliminada."
        ;;
    *)
        show_help
        ;;
esac