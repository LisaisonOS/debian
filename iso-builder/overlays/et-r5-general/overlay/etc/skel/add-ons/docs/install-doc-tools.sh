#!/bin/bash
# Author  : Gaston Gonzalez
# Date    : 2 April 2025
# Updated : 24 April 2025
# Purpose : Installs documentation tooling
set -e

RUBY_VERSION="3.3.8"

if [[ "${EUID}" -eq 0 ]]; then
  echo "This script be run as your normal user, not as root."
  exit 1
fi

if [[ ! -e ~/.rbenv ]]; then
  echo "Install 'rbenv' into your home directory..."
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv

  echo "Adding 'rbenv' into your path..."
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
  echo 'eval "$(rbenv init - bash)"' >> ~/.bash_profile

  echo "Adding 'ruby-build' plugin..."
  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

source ~/.bash_profile


echo "Installing Ruby ${RUBY_VERSION}..."
rbenv install ${RUBY_VERSION}
rbenv global ${RUBY_VERSION}

echo "Using ruby version: $(ruby -v)"
echo "Using gem version: $(gem -v)"

ruby -v | grep "${RUBY_VERSION}"
if [[ $? -ne 0 ]]; then
  "The documentation tool requires Ruby ${RUBY_VERSION}."
  exit 1
fi
