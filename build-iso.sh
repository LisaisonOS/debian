#!/bin/bash
# =============================================================================
# Debain OS ISO Build Script
# Version: 1.0.0
# Author: Sylvain Deguire (VA2OPS)
#
# Quick launcher for ISO builds
# =============================================================================

set -e

cd ~/liaisonos/build/debian-iso
sudo lb clean
cd ~/liaisonos
./setup-iso.sh
