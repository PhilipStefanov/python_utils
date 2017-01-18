#!/usr/bin/env bash

# List of Python dependencies
dependencies=(
build-essential
libbz2-dev
tk-dev
libssl-dev
libsqlite3-dev
libncurses-dev
libreadline-dev
libgdbm-dev
liblzma-dev
)

# List of PIP packages to install
packages=(
virtualenvwrapper
readline
requests
lxml
jupyter
)

# Function to install Python dependencies
function install_dependencies() {
local input="Y"
read -t 10 -p "Choose [Yy/Nn](Default Y): " input
case "$input" in
  [Yy]|'')
    for dependency in "${dependencies[@]}"; do
      sudo apt-get install "$dependency"
    done;
    ;;
  [Nn]*)
    return 0
    ;;
  *) echo "Not valid entry. Please try again."; install_dependencies
    ;;
esac
}

# Function to update PIP and install additional packages
function update() {
local input="Y"
read -t 10 -p "Choose [Yy/Nn](Default Y): " input
case "$input" in
  [Yy]|'')
# NOTE: DEPRECATION: The default format will switch to columns in the future
    pip3 list --outdated | cut -d ' ' -f1 | xargs -n1 pip3 install --upgrade
    for package in "${packages[@]}"; do
      pip3 install "$package"
    done
    ;;
  [Nn]*)
    printf -- "\nOutdated packages:\n"
    pip3 list --outdated
    return 0
    ;;
  *) echo "Not valid entry. Please try again."; update;
    ;;
esac
}

[[ -z $1 ]] && {
  printf -- "\nPython version is required e.g 3.5.0 3.6.0\n"
  exit 1
}

VERSION="$1"

printf -- "\nList available packages:\n"

if (( $(curl -s https://www.python.org/ftp/python/"${VERSION}"/ \
    | grep -coE 'href="([^"#]+.tar.xz)"'                        \
    | cut -d'"' -f2) == 0 )); then
  printf -- "\nNo packages found make sure version number is correct! Exiting\n"
  exit 1
else
  curl -s https://www.python.org/ftp/python/"${VERSION}"/ \
    | grep -oE 'href="([^"#]+.tar.xz)"'                   \
    | cut -d'"' -f2
fi

read -p "Choose revision to install: " input;
TAR=$(echo $input | grep -Pio '(?<=python-).*(?=.tar.xz)')

printf -- "\nInstall dependencies:\n"
printf -- '%s\n' "${dependencies[@]}"
install_dependencies

printf -- "\nChecking if $HOME/bin is in PATH if not add it...\n\n"
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
  export "PATH=$HOME/bin:${PATH}"
  echo "PATH=$HOME/bin:\"\${PATH}\"" >> "${HOME}"/.bashrc
  printf -- "\n$HOME/bin added to ~/.bashrc\n\n"
fi

if [[ -d ${HOME}/bin/python/${TAR} ]]; then
  rm -rf "${HOME}"/bin/python/"${TAR}"
else
  mkdir -pv "${HOME}"/bin/python/"${TAR}"
fi

cd "${HOME}"/bin/ || exit 1
printf -- "\nDownloading $input...\n\n"
curl https://www.python.org/ftp/python/"${VERSION}"/Python-"${TAR}".tar.xz \
  > Python-"${TAR}".tar.xz
printf -- "\nDownloading DONE\n\n"
printf -- "\nExtracting $input...\n\n"
tar xf Python-"${TAR}".tar.xz
cd Python-"${TAR}" || exit 1
printf -- "\nExtracting DONE\n\n"

printf -- "\nConfiguring...\n\n"
./configure --prefix="${HOME}"/bin/python/"${TAR}" 1>/dev/null
printf -- "\nSilent Make...\n\n"
make -s
make altinstall 1>/dev/null

printf -- "\nCreating symlinks in ${HOME}/bin for python3, pip3, virtualenv...\n\n"
if [[ -f "${HOME}"/bin/python/"${TAR}"/bin/python$(cut -c1-3 <<<"$VERSION") ]]; then
  ln -sfv "${HOME}"/bin/python/"${TAR}"/bin/python$(cut -c1-3 <<<"$VERSION") "${HOME}"/bin/python3
  ln -sfv "${HOME}"/bin/python/"${TAR}"/bin/pip$(cut -c1-3 <<<"$VERSION") "${HOME}"/bin/pip3
  ln -sfv "${HOME}"/bin/python/"${TAR}"/bin/virtualenv "${HOME}"/bin/virtualenv
else
  printf -- "\nWarning BIN files not found in "${HOME}"/bin/python/"${TAR}"/bin/ Exiting\n\n"
  exit 1
fi

printf -- "\nUpdate pip and install:\n\n"
printf -- '%s\n' "${packages[@]}"
update;

printf -- "\n\nPip version:\n";
pip3 --version

rm -rf "${HOME}"/bin/Python-"${TAR}".tar.xz
rm -rf "${HOME}"/bin/Python-"${TAR}"
printf -- "\nCleanup source files DONE\n\n"

cat <<EOF
Useful changes inside .bashrc:
export VIRTUALENVWRAPPER_PYTHON="${HOME}/bin/python3"
export PYTHONSTARTUP="${HOME}/.pythonstartup"
export WORKON_HOME="${HOME}/bin/.venvs"
export PROJECT_HOME="${HOME}/projects"
source ${HOME}/bin/python/${TAR}/bin/virtualenvwrapper.sh
EOF
