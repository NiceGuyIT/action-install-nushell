#!/usr/bin/env sh

# Exit on error
set -e
# Errors on  undefined variables
set -u
# Print commands before execution
set -x

# Input parameters
INSTALL_SET_DEFAULT=$(echo "${SET_DEFAULT:=false}" | tr '[:upper:]' '[:lower:]')
INSTALL_NUSHELL_VERSION=$(echo "${NUSHELL_VERSION:=latest}" | tr '[:upper:]' '[:lower:]')
INSTALL_REGISTER_PLUGINS=$(echo "${REGISTER_PLUGINS:=false}" | tr '[:upper:]' '[:lower:]')
INSTALL_CREATE_CONFIG=$(echo "${CREATE_CONFIG:=false}" | tr '[:upper:]' '[:lower:]')

# Not needed but makes this script flexible.
BINARY=nu
GH_HOST=github.com
GH_API=api.github.com
REPO=nushell
OWNER=nushell
INSTALL_DIR=/usr/bin/

if [ "${INSTALL_NUSHELL_VERSION}" = "latest" ]
then
	# TODO: Check the rate limits: https://api.github.com/rate_limit
	version_url="https://${GH_API}/repos/${OWNER}/${REPO}/releases/latest"
	VERSION=$(curl --silent --location --output - "${version_url}" | jq -r '.name')
else
	VERSION=${INSTALL_NUSHELL_VERSION}
fi

# Get environment
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
FILENAME="${BINARY}-${VERSION}-${arch}-unknown-${os}-musl.tar.gz"

tmp_dir=$(mktemp --directory)
url="https://${GH_HOST}/${OWNER}/${REPO}/releases/download/${VERSION}/${FILENAME}"
curl --silent --location --output - "${url}" | tar --strip-components 1 --directory="${tmp_dir}" --extract --gzip --file -
cp "${tmp_dir}"/nu* "${INSTALL_DIR}"
rm -r "${tmp_dir}"

if [ "${INSTALL_SET_DEFAULT}" = "true" ]
then
	if [ -x "${INSTALL_DIR}nu" ]
	then
		chsh --shell ${INSTALL_DIR}nu "${USER}"
	fi
fi

# Create the config directory so we don't have to check when creating the config or registering the plugins.
# shellcheck disable=SC2016
nu --commands 'mkdir ($nu.default-config-dir)'

if [ "${INSTALL_CREATE_CONFIG}" = "true" ]
then
	if [ -x "${INSTALL_DIR}nu" ]
	then
		# shellcheck disable=SC2016
		nu --commands '
			config nu --default | save --raw --force ($nu.config-path);
			config env --default | save --raw --force ($nu.env-path)'
	fi
fi

if [ "${INSTALL_REGISTER_PLUGINS}" = "true" ]
then
	# shellcheck disable=SC2016
	# TODO: ${INSTALL_DIR} will not be expanded. Should double quotes be used for expansion?
	nu --commands 'glob /usr/bin/nu_plugin_*
    	| where $it !~ "example|custom_values|stress_internal"
    	| each {|it|
    		plugin add --plugin-config $nu.plugin-path $it;
    		$"Registered plugin: ($it)"
		}'

	echo ""
	# List the registered plugins
	nu --commands 'plugin list'
fi

# Dump the Nushell version and config info for debugging purposes
nu --commands 'version'
# shellcheck disable=SC2016
nu --commands '$nu'
