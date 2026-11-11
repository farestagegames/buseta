#!/bin/sh
# Creates the Play upload keystore outside the repository and, optionally, saves
# its password in the macOS login Keychain for tools/build_release.sh.
# Run it yourself in a terminal: keytool and security ask for the password, so it
# never appears on the command line, in a file or in shell history.
cd "$(dirname "$0")/.." || exit 1
KEYSTORE="${UPLOAD_KEYSTORE:-$HOME/Keys/city-bus-shift-upload.jks}"
ALIAS="${UPLOAD_KEY_ALIAS:-upload}"
KEYCHAIN_ITEM="city-bus-shift-upload"
KEYTOOL="$PWD/.tools/jdk/Contents/Home/bin/keytool"
if [ -f "$KEYSTORE" ]; then
	echo "$KEYSTORE already exists. Not overwriting it."
	exit 1
fi
mkdir -p "$(dirname "$KEYSTORE")"
chmod 700 "$(dirname "$KEYSTORE")"
echo "Creating $KEYSTORE (alias '$ALIAS')."
echo "Choose a strong password and write it down somewhere safe (a password manager)."
echo "PKCS12 keystores use the same password for the store and the key."
"$KEYTOOL" -genkeypair -v -storetype PKCS12 -keystore "$KEYSTORE" -alias "$ALIAS" \
	-keyalg RSA -keysize 4096 -validity 10000 -dname "CN=City Bus Shift, O=City Bus Shift" || exit 1
chmod 600 "$KEYSTORE"
printf 'Save the password in your macOS login Keychain for build_release.sh? [y/N] '
read -r ANSWER
case "$ANSWER" in
	y|Y|yes)
		echo "Type the same keystore password (twice) when asked."
		security add-generic-password -U -a "$USER" -s "$KEYCHAIN_ITEM" -w
		;;
esac
echo "Done. Back up $KEYSTORE now (see RELEASE.md)."
