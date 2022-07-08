#!/bin/bash
#
#
# pan-os_api v1.2 [2022062201]
#
# Scripts to generate PA/Panorama config
#
#   by Terence LEE <telee@paloaltonetworks.com>
#
# Details at https://github.com/telee0/pan-os_api.git
#
# --------------------------------------------------------------------------------
#

usage="
Usage: $0 [-h] [-c] [-f] param_file\n
\n
c: clean\n
f: use config from param_file\n
h: help\n"

echo

while getopts :hcf: opt; do
	case "$opt" in
	c)
		echo "Please use individual -clean.sh under the job directory."
		;;
	f)
		param_file="$OPTARG"
		;;
	h|?)
		echo -e $usage
		exit 1
		;;
	esac
done

if [ -n "$param_file" ]; then
	if [ -f "$param_file" ]; then
		echo param_file = $param_file
		. "$param_file"
	else
		echo "$param_file: file error"
		exit 1
	fi
else
	echo -e $usage
	exit 1
fi

# --------------------------------------------------------------------------------
#
# Check first if required programs exist in the environment.
#

#progs="wget xml_grep xml_pp"
progs="wget xml_grep"

for p in $progs; do
	if ! command -v $p &> /dev/null; then
		echo
		echo "$p: required but not found. Take the steps to install $p."
		echo
		case "$p" in
			wget)
				echo 'CentOS 7/8: $ sudo yum install wget'
				echo 'Ubuntu: $ sudo apt install wget'
				echo
				;;
			xml_grep)
				echo 'CentOS 7: $ sudo yum install perl-XML-Twig'
				echo 'CentOS 8: $ sudo dnf --enablerepo=powertools install perl-XML-Twig'
				echo 'Ubuntu: $ sudo apt install xml-twig-tools'
				echo
				;;
		esac
		exit 1
	fi
done

# --------------------------------------------------------------------------------
#
# Paths for config files and data
#

script_path=$(realpath $0)
 
SCRIPT_HOME=$(dirname $script_path)
echo
echo "SCRIPT_HOME = $SCRIPT_HOME"

#
# set the data path and change to it
#

WORK_DIR="$$"

X="xml"
L="logs"

mkdir -p "$WORK_DIR"
mkdir -p "$WORK_DIR/$X"
mkdir -p "$WORK_DIR/$L"


P="PA2"

WORK_DIR2="$WORK_DIR/$P"

mkdir -p "$WORK_DIR2"
mkdir -p "$WORK_DIR2/$X"
mkdir -p "$WORK_DIR2/$L"

cd $WORK_DIR

# echo "Config scripts saved under the job directory $WORK_DIR"

# --------------------------------------------------------------------------------

SCRIPT_FILE=".sh"
XML_FILE=".xml"
OUT_FILE=".log.xml"
LOG_FILE=".log"

CLEAN_SCRIPT_FILE="-clean.sh"
CLEAN_XML_FILE="-clean.xml"
CLEAN_OUT_FILE="-clean.log.xml"
CLEAN_LOG_FILE="-clean.log"

CONFIG_DUMP="$X/config.xml.dump"

# wget="wget --tries=2 --timeout=10 --dns-timeout=10 --connect-timeout=10"
wget="wget --tries=2 --timeout=5"

# --------------------------------------------------------------------------------
#
# API key
#

. $SCRIPT_HOME/pan_api.sh

if [ -z "$API_KEY" ]; then
	exit 1
fi

#
# xpath for Panorama template
#

XPATH_TPL=""

if [ "$TARGET" = "PANORAMA" ]; then

	echo target = Panorama

	if [ -n "$PANORAMA_DEVICE_GROUP" ]; then
		echo "$param_file: default DG $PANORAMA_DEVICE_GROUP."
	fi
	if [ -n "$PANORAMA_TEMPLATE" ]; then
		XPATH_TPL="xpath=/config/devices/entry[@name='$LHOST']/template/entry[@name='$PANORAMA_TEMPLATE']"
		echo "$param_file: default template/stack $PANORAMA_TEMPLATE."
	elif [ -n "$PANORAMA_TEMPLATE_STACK" ]; then
		XPATH_TPL="xpath=/config/devices/entry[@name='$LHOST']/template-stack/entry[@name='$PANORAMA_TEMPLATE_STACK']"
		echo "$param_file: default template/stack $PANORAMA_TEMPLATE_STACK."
	else
		echo "$param_file: template/stack not set for target Panorama."
	fi
	if [ -n "$PANORAMA_TEMPLATE" ] && [ -n "$PANORAMA_TEMPLATE_STACK" ]; then
		echo "$param_file: template has precedence over stack if both set."
	fi
fi

# --------------------------------------------------------------------------------
#
# Initialize the config file
#

URL="https://$PA/api"
URL2="https://$PA2/api"

cat > $CONFIG_DUMP <<-EOF
<?xml version="1.0"?>
<config version="9.1.0" urldb="paloaltonetworks">
EOF

# --------------------------------------------------------------------------------
#
# Panorama device groups and templates
#

cat >> $CONFIG_DUMP <<-EOF
  <devices>
    <entry name="$LHOST">
EOF

. $SCRIPT_HOME/pan_device_groups.sh
. $SCRIPT_HOME/pan_templates.sh

cat >> $CONFIG_DUMP <<-EOF
    </entry>
  </devices>
EOF

# --------------------------------------------------------------------------------
#
# Objects: Addresses, address groups, services, custom URL categories
#

cat >> $CONFIG_DUMP <<-EOF
  <devices>
    <entry name="$LHOST">
      <vsys>
        <entry name="$VSYS">
EOF

. $SCRIPT_HOME/pan_obj_addr.sh
. $SCRIPT_HOME/pan_obj_addr_groups.sh
. $SCRIPT_HOME/pan_obj_svc.sh
. $SCRIPT_HOME/pan_obj_svc_groups.sh
. $SCRIPT_HOME/pan_obj_url.sh

cat >> $CONFIG_DUMP <<-EOF
        </entry>
      </vsys>
    </entry>
  </devices>
EOF

# --------------------------------------------------------------------------------
#
# Network Zones and interfaces - Ethernet/Loopback/Tunnel
#

cat >> $CONFIG_DUMP <<-EOF
  <devices>
    <entry name="$LHOST">
      <vsys>
        <entry name="$VSYS">
EOF

. $SCRIPT_HOME/pan_net_zones.sh

cat >> $CONFIG_DUMP <<-EOF
        </entry>
      </vsys>
    </entry>
  </devices>
EOF

cat >> $CONFIG_DUMP <<-EOF
  <devices>
    <entry name="$LHOST">
      <network>
        <interface>
EOF

. $SCRIPT_HOME/pan_net_if_eth.sh
. $SCRIPT_HOME/pan_net_if_lo.sh
. $SCRIPT_HOME/pan_net_if_tun.sh

cat >> $CONFIG_DUMP <<-EOF
        </interface>
      </network>
    </entry>
  </devices>
EOF

# --------------------------------------------------------------------------------
#
# Policies - Security, NAT, PBF, etc.
#

cat >> $CONFIG_DUMP <<-EOF
  <devices>
    <entry name="$LHOST">
      <vsys>
        <entry name="$VSYS">
          <rulebase>
EOF

. $SCRIPT_HOME/pan_rules_sec.sh
. $SCRIPT_HOME/pan_rules_nat.sh
. $SCRIPT_HOME/pan_rules_pbf.sh

cat >> $CONFIG_DUMP <<-EOF
          <rulebase>
        </entry>
      </vsys>
    </entry>
  </devices>
EOF

# --------------------------------------------------------------------------------
#
# VPN configuration - IKE gateways, IPSec tunnels
#

cat >> $CONFIG_DUMP <<-EOF
  <devices>
    <entry name="$LHOST">
      <network>
EOF

. $SCRIPT_HOME/pan_vpn_ike_gw.sh
. $SCRIPT_HOME/pan_vpn_ipsec_tun.sh

cat >> $CONFIG_DUMP <<-EOF
      </network>
    </entry>
  </devices>
EOF

#
# Virtual router config
#

cat >> $CONFIG_DUMP <<-EOF
  <devices>
    <entry name="$LHOST">
      <network>
        <virtual-router>
          <entry name="$DEFAULT_VR">
EOF

. $SCRIPT_HOME/pan_vr_static.sh
. $SCRIPT_HOME/pan_vr_bgp.sh

cat >> $CONFIG_DUMP <<-EOF
          </entry>
        </virtual-router>
      </network>
    </entry>
  </devices>
EOF

# --------------------------------------------------------------------------------
#
# Local users
#
. $SCRIPT_HOME/pan_local_users.sh

# User-ID IP-user mappings
#
. $SCRIPT_HOME/pan_uid.sh

# --------------------------------------------------------------------------------
#
# Generate the final script for config import and load (with merge)
#

script_file="config$SCRIPT_FILE"
xml_file="$X/config$XML_FILE"
out_file="$L/config$OUT_FILE"
log_file="$L/config$LOG_FILE"

echo -e "\n\nGenerating $script_file and $xml_file.. This takes a while."

WGET="$wget \
	--post-file=$xml_file \
	--no-check-certificate --output-document=$out_file --append-output=$log_file"

URL="https://$PA/api/?type=import&category=configuration&client=wget&file-name=$xml_file&key=$API_KEY"

# echo $WGET \"$URL\" >> $script_file

# xml_pp $CONFIG_DUMP > $xml_file

cat >> $CONFIG_DUMP <<-EOF
</config>
EOF

#
# generate the master script ./config.sh to include items
#

if [ -n "$CONFIG_ITEMS" ]; then
	for item in $CONFIG_ITEMS; do
		echo "sh ./$item.sh" >> $script_file
	done
fi

# --------------------------------------------------------------------------------

echo
echo "Config scripts and data are saved under the job directory $WORK_DIR"
echo
echo "Please run $WORK_DIR/config.sh or individual $WORK_DIR/*.sh in proper order. (e.g. zones before interfaces)"
echo

exit

#
# End
#
