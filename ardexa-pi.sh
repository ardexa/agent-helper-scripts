#!/bin/bash

usage() {
    echo "Usage: $0 [-w <ssid>] <ardexa_installer_or_agentPack> <pi_root_dir>"
    echo "  -w      Setup wifi. SSID is case sensitive. Will ask for password"
}

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

SSID=""
PASSWORD=one

while getopts ":w:" opt; do
    case $opt in
    w)
    SSID="$OPTARG"
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done

shift $((OPTIND-1))
if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

if [[ ! -f $1 ]]; then
    echo "ERROR: $1 isn't a regular file" >&2
    echo
    usage
    exit 1
fi

if [[ ! -d $2 ]] || [[ ! -d $2/opt ]] || [[ ! -d $2/etc/cron.d ]]; then
    echo "ERROR: $2 doesn't look like a raspberry pi root folder" >&2
    echo
    usage
    exit 1
fi

if [[ ! -z "$SSID" ]]; then
    if [[ ! -f $2/etc/wpa_supplicant/wpa_supplicant.conf ]]; then
        echo "ERROR: $2 doesn't look like a raspberry pi root folder" >&2
        echo
        usage
        exit 1
    fi
    while [[ -z "$PASSWORD" ]] || [[ "$PASSWORD" != "$PASSWORD2" ]]; do
        if [[ ! -z "$PASSWORD2" ]]; then
            echo "Passwords didn't match, please try again"
        fi
        echo "Please enter the wifi password for '$SSID':"
        read -s PASSWORD
        echo "Please enter the password again:"
        read -s PASSWORD2
    done
    cat >> $2/etc/wpa_supplicant/wpa_supplicant.conf <<END_WPA

network={
    ssid="${SSID}"
    psk="${PASSWORD}"
}
END_WPA
fi 

# Copy the deb into place
rm $2/opt/ardexa*deb
if [ ${1: -4} == ".deb" ]; then
    cp $1 $2/opt/ardexa.deb
elif [ ${1: -4} == ".zip" ]; then
    unzip -j $1 "*.deb" -d $2/opt/ &>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: $2 doesn't look like a raspberry pi root folder" >&2
        echo
        usage
        exit 1
    fi
    mv $2/opt/ardexa*deb $2/opt/ardexa.deb
fi

cat > $2/etc/cron.d/install_ardexa <<END_CRON
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
@reboot root dpkg -i /opt/ardexa.deb && rm /etc/cron.d/install_ardexa >> /var/log/ardexa-install.log 2>&1
END_CRON
