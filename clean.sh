#/bin/bash
#
# pan-os_api v1.2 [2022062201]
#
# Scripts to generate PA/Panorama config
#
#   by Terence LEE <telee@paloaltonetworks.com>
#
# Details at https://github.com/telee0/pan-os_api.git
#

RM="rm -f"

script_path=$(realpath $0)
script_dir=$(dirname $script_path)

echo
echo "dir = $script_dir"

cd $script_dir

echo
read -n 1 -p "Press any key to proceed or ^C to stop now.."

echo
echo
echo "Removing job directories.."
echo

#
# check before use
#

$RM -r job-[0-9]*

