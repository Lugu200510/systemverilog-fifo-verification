#!/bin/csh

module unload vcs/R-2020.12-SP2-4
module unload verdi/R-2020.12-SP2-4

module load vcs/V-2023.12-SP1-1
module load verdi/V-2023.12-SP2-1

rehash

echo
echo "Loaded modules:"
module list

echo
echo "Tool paths:"
which vcs
which verdi
which urg
which gvim

echo
echo "DISPLAY:"
printenv DISPLAY

echo
echo "EDA environment loaded successfully."