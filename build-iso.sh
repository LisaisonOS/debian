#!/bin/bash
# =============================================================================
# EmComm-Tools ISO Build Script
# Version: 1.0.0
# Author: Sylvain Deguire (VA2OPS)
#
# Quick launcher for ISO builds
# =============================================================================

set -e

cd ~/emcomm-tools/build/emcomm-debian-iso
sudo lb clean
cd ~/emcomm-tools
./setup-emcomm-iso.sh
