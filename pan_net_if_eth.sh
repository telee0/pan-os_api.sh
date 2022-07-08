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
# Network interfaces - Ethernet
#

pan_net_if_eth() {

	if [ -z "$N_NET_IF_ETHERNET" ] || [ $N_NET_IF_ETHERNET -le 0 ]; then
		return 0
	fi

	echo -en "\nNetwork > Interfaces > Ethernet ($N_NET_IF_ETHERNET) with zone and VR assigned "

	cat >> $CONFIG_DUMP <<-EOF
<ethernet>
EOF

	local i; local j

	pre="ethernet"

	script_file="$pre$SCRIPT_FILE"
	xml_file="$X/$pre$XML_FILE"
	out_file="$L/$pre$OUT_FILE"
	log_file="$L/$pre$LOG_FILE"
	clean_script_file="$pre$CLEAN_SCRIPT_FILE"
	clean_xml_file="$X/$pre$CLEAN_XML_FILE"
	clean_out_file="$L/$pre$CLEAN_OUT_FILE"
	clean_log_file="$L/$pre$CLEAN_LOG_FILE"

	# vsys
	#
	vsys_xml_file="$X/$pre-vsys$XML_FILE"
	vsys_out_file="$L/$pre-vsys$OUT_FILE"
	vsys_log_file="$L/$pre-vsys$LOG_FILE"
	clean_vsys_xml_file="$X/$pre-vsys$CLEAN_XML_FILE"
	clean_vsys_out_file="$L/$pre-vsys$CLEAN_OUT_FILE"
	clean_vsys_log_file="$L/$pre-vsys$CLEAN_LOG_FILE"

	# zone
	#
	zone_xml_file="$X/$pre-zone$XML_FILE"
	zone_out_file="$L/$pre-zone$OUT_FILE"
	zone_log_file="$L/$pre-zone$LOG_FILE"
	clean_zone_xml_file="$X/$pre-zone$CLEAN_XML_FILE"
	clean_zone_out_file="$L/$pre-zone$CLEAN_OUT_FILE"
	clean_zone_log_file="$L/$pre-zone$CLEAN_LOG_FILE"

	# vr
	#
	vr_xml_file="$X/$pre-vr$XML_FILE"
	vr_out_file="$L/$pre-vr$OUT_FILE"
	vr_log_file="$L/$pre-vr$LOG_FILE"
	clean_vr_xml_file="$X/$pre-vr$CLEAN_XML_FILE"
	clean_vr_out_file="$L/$pre-vr$CLEAN_OUT_FILE"
	clean_vr_log_file="$L/$pre-vr$CLEAN_LOG_FILE"

	WGET="$wget \
		--post-file=$xml_file \
		--no-check-certificate --output-document=$out_file --append-output=$log_file"
	WGET_CLEAN="$wget \
		--post-file=$clean_xml_file \
		--no-check-certificate --output-document=$clean_out_file --append-output=$clean_log_file"

	# vsys
	#
	WGET_VSYS="$wget \
		--post-file=$vsys_xml_file \
		--no-check-certificate --output-document=$vsys_out_file --append-output=$vsys_log_file"
	WGET_VSYS_CLEAN="$wget \
		--post-file=$clean_vsys_xml_file \
		--no-check-certificate --output-document=$clean_vsys_out_file --append-output=$clean_vsys_log_file"

	# zone
	#
	WGET_ZONE="$wget \
		--post-file=$zone_xml_file \
		--no-check-certificate --output-document=$zone_out_file --append-output=$zone_log_file"
	WGET_ZONE_CLEAN="$wget \
		--post-file=$clean_zone_xml_file \
		--no-check-certificate --output-document=$clean_zone_out_file --append-output=$clean_zone_log_file"

	# vr
	#
	WGET_VR="$wget \
		--post-file=$vr_xml_file \
		--no-check-certificate --output-document=$vr_out_file --append-output=$vr_log_file"
	WGET_VR_CLEAN="$wget \
		--post-file=$clean_vr_xml_file \
		--no-check-certificate --output-document=$clean_vr_out_file --append-output=$clean_vr_log_file"

	#
	# xpath for interfaces, vsys, zone and vr
	#

	local XPATH=""

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$PANORAMA_TEMPLATE" ]; then
			XPATH="xpath=/config/devices/entry[@name='$LHOST']/template/entry[@name='$PANORAMA_TEMPLATE']"
			tpl="$PANORAMA_TEMPLATE"
		elif [ -n "$PANORAMA_TEMPLATE_STACK" ]; then
			XPATH="xpath=/config/devices/entry[@name='$LHOST']/template-stack/entry[@name='$PANORAMA_TEMPLATE_STACK']"
			tpl="$PANORAMA_TEMPLATE_STACK (Stack, which may not support interfaces)"
		else
			echo -n ERROR: Panorama template not specified
			return 1
		fi
		echo -n Template = $tpl
	else
		XPATH="xpath="
	fi

	xpath="$XPATH/config/devices/entry[@name='$LHOST']/network/interface/ethernet/entry[@name='$IF_ETHERNET_NAME']/layer3/units"
	xpath_vsys="$XPATH/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/import/network/interface"
	xpath_zone="$XPATH/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/zone/entry[@name='$IF_ETHERNET_ZONE']/network/layer3"
	xpath_vr="$XPATH/config/devices/entry[@name='$LHOST']/network/virtual-router/entry[@name='$IF_ETHERNET_VR']/interface"

	echo $WGET \"$URL\" >> $script_file
	echo $WGET_VSYS \"$URL\" >> $script_file
	echo $WGET_ZONE \"$URL\" >> $script_file
	echo $WGET_VR \"$URL\" >> $script_file

	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath_vsys&element=" >> $vsys_xml_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath_zone&element=" >> $zone_xml_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath_vr&element=" >> $vr_xml_file

	echo $WGET_VR_CLEAN \"$URL\" >> $clean_script_file
	echo $WGET_ZONE_CLEAN \"$URL\" >> $clean_script_file
	echo $WGET_VSYS_CLEAN \"$URL\" >> $clean_script_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file

	echo -n "type=config&action=delete&key=$API_KEY&$xpath_vr/member[" >> $clean_vr_xml_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath_zone/member[" >> $clean_zone_xml_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath_vsys/member[" >> $clean_vsys_xml_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	interfaces=1

	for ((i = $IF_ETHERNET_IP_OCTET_i; i < 256; i++)); do
		for ((j = $IF_ETHERNET_IP_OCTET_j; j < 256; j++)); do
			if [ $interfaces -gt $N_NET_IF_ETHERNET ]; then
				break 1
			fi

			interface_name=`printf "$IF_ETHERNET_NAME.%d" $interfaces`
			interface_ip=`printf "$IF_ETHERNET_IP" $i $j`

			element="
                  <entry name='$interface_name'>
                    <ipv6>
                      <neighbor-discovery>
                        <router-advertisement>
                          <enable>no</enable>
                        </router-advertisement>
                      </neighbor-discovery>
                    </ipv6>
                    <ndp-proxy>
                      <enabled>no</enabled>
                    </ndp-proxy>
                    <adjust-tcp-mss>
                      <enable>no</enable>
                    </adjust-tcp-mss>
                    <ip>
                      <entry name='$interface_ip'/>
                    </ip>
                    <tag>$interfaces</tag>
                  </entry>"

			clean_element="@name='$interface_name' or "

			echo -n "$element" >> $xml_file
			echo -n "$clean_element" >> $clean_xml_file

			# vsys
			#
			vsys_element="<member>$interface_name</member>"
			clean_element="text()='$interface_name' or "
			echo -n "$vsys_element" >> $vsys_xml_file
			echo -n "$clean_element" >> $clean_vsys_xml_file

			# zone
			#
			zone_element="<member>$interface_name</member>"
			clean_element="text()='$interface_name' or "
			echo -n "$zone_element" >> $zone_xml_file
			echo -n "$clean_element" >> $clean_zone_xml_file

			# vr
			#
			vr_element="<member>$interface_name</member>"
			clean_element="text()='$interface_name' or "
			echo -n "$vr_element" >> $vr_xml_file
			echo -n "$clean_element" >> $clean_vr_xml_file

			# ---

			echo "$element" >> $CONFIG_DUMP

			if ! ((interfaces % 100)); then
				echo -n '.'
			fi

			((interfaces+=1))
		done

		IF_ETHERNET_IP_OCTET_j=0

	done

	echo -n "@name='_$interface_name']" >> $clean_xml_file
	echo -n "text()='_$interface_name']" >> $clean_vsys_xml_file
	echo -n "text()='_$interface_name']" >> $clean_zone_xml_file
	echo -n "text()='_$interface_name']" >> $clean_vr_xml_file

	cat >> $CONFIG_DUMP <<-EOF
</ethernet>
EOF

}  # pan_net_if_eth()

# --------------------------------------------------------------------------------

if [ -n "$N_NET_IF_ETHERNET" ] && [ $N_NET_IF_ETHERNET -gt 0 ]; then

	unset script_file

	pan_net_if_eth

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
