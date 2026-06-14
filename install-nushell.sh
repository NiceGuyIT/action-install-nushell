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

# Not needed but makes this script flexible.
BINARY=nu
GH_HOST=github.com
GH_API=api.github.com
REPO=nushell
OWNER=nushell
# Install to /usr/local/bin, which precedes /usr/bin on PATH. Some runners (the
# openSUSE base) ship a preinstalled nu in /usr/local/bin; installing here
# overrides it so the requested version is the one that resolves, rather than
# being shadowed by the preinstalled copy in an earlier PATH entry.
INSTALL_DIR=/usr/local/bin/

# Elevate only when needed. Self-hosted Forgejo/Gitea containers usually run as
# root, where INSTALL_DIR is writable and sudo is often not installed. GitHub
# hosted runners run as a non-root user with passwordless sudo. Pick sudo only
# in the second case so the same script works in both.
if [ "$(id -u)" -eq 0 ]
then
	SUDO=""
elif command -v sudo >/dev/null 2>&1
then
	SUDO="sudo"
else
	echo "Not running as root and sudo is not available; cannot install to ${INSTALL_DIR}" >&2
	exit 1
fi

# jq is only needed to resolve the "latest" version from the GitHub API. Some
# images (e.g. the openSUSE base) do not ship it, so install it on demand via
# whichever package manager is present. This is a no-op when jq already exists.
ensure_jq() {
	if command -v jq >/dev/null 2>&1
	then
		return 0
	fi
	if command -v zypper >/dev/null 2>&1
	then
		${SUDO} zypper --non-interactive install jq
	elif command -v apt-get >/dev/null 2>&1
	then
		${SUDO} apt-get update && ${SUDO} apt-get install --yes jq
	elif command -v apk >/dev/null 2>&1
	then
		${SUDO} apk add --no-cache jq
	elif command -v dnf >/dev/null 2>&1
	then
		${SUDO} dnf install --assumeyes jq
	else
		echo "jq is required to resolve the latest version but no supported package manager (zypper, apt-get, apk, dnf) was found" >&2
		exit 1
	fi
}

if [ "${INSTALL_NUSHELL_VERSION}" = "latest" ]
then
	ensure_jq
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
${SUDO} cp "${tmp_dir}"/nu* "${INSTALL_DIR}"
rm -r "${tmp_dir}"

if [ "${INSTALL_SET_DEFAULT}" = "true" ]
then
	if [ -x "${INSTALL_DIR}nu" ]
	then
		${SUDO} chsh --shell ${INSTALL_DIR}nu "${USER}"
	fi
fi

# Create the config directory so we don't have to check when registering the plugins.
# shellcheck disable=SC2016
nu --commands 'mkdir ($nu.default-config-dir)'

if [ "${INSTALL_REGISTER_PLUGINS}" = "true" ]
then
	# Pass INSTALL_DIR through the environment so nu can build the glob from it
	# while $it / $nu stay literal inside the single-quoted command.
	# shellcheck disable=SC2016
	INSTALL_DIR="${INSTALL_DIR}" nu --commands 'glob $"($env.INSTALL_DIR)nu_plugin_*"
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
