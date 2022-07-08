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
# Virtual router BGP config
#
# --------------------------------------------------------------------------------
#
# BGP peers
#

pan_vr_bgp() {

	if [ -z "$N_VR_BGP_PEER_GROUPS" ] || [ $N_VR_BGP_PEER_GROUPS -le 0 ]; then
		return 0
	fi

	echo -en "\nNetwork > VR > $VR_BGP_VR > BGP peer groups x peers ($N_VR_BGP_PEER_GROUPS x $N_VR_BGP_PEERS_PER_GROUP) "

	cat >> $CONFIG_DUMP <<-EOF
<protocol>
  <bgp>
    <peer-group>
EOF

	local i; local j; local k

	pre="peer_group"

	script_file="$pre$SCRIPT_FILE"
	xml_file="$X/$pre$XML_FILE"
	out_file="$L/$pre$OUT_FILE"
	log_file="$L/$pre$LOG_FILE"

	clean_script_file="$pre$CLEAN_SCRIPT_FILE"
	clean_xml_file="$X/$pre$CLEAN_XML_FILE"
	clean_out_file="$L/$pre$CLEAN_OUT_FILE"
	clean_log_file="$L/$pre$CLEAN_LOG_FILE"

	WGET="$wget \
		--post-file=$xml_file \
		--no-check-certificate --output-document=$out_file --append-output=$log_file"
	WGET_CLEAN="$wget \
		--post-file=$clean_xml_file \
		--no-check-certificate --output-document=$clean_out_file --append-output=$clean_log_file"

	local XPATH=""

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$PANORAMA_TEMPLATE" ]; then
			XPATH="xpath=/config/devices/entry[@name='$LHOST']/template/entry[@name='$PANORAMA_TEMPLATE']"
			template="$PANORAMA_TEMPLATE"
		elif [ -n "$PANORAMA_TEMPLATE_STACK" ]; then
			XPATH="xpath=/config/devices/entry[@name='$LHOST']/template-stack/entry[@name='$PANORAMA_TEMPLATE_STACK']"
			template="$PANORAMA_TEMPLATE_STACK (Stack)"
		else
			echo -n ERROR: Panorama template not specified
			return 1
		fi
		echo -n Template = $template
	else
		XPATH="xpath="
	fi

    xpath="$XPATH/config/devices/entry[@name='$LHOST']/network/virtual-router/entry[@name='$VR_BGP_VR']/protocol/bgp/peer-group"

	echo "echo \"Please be sure of the following before adding peer groups.\"" >> $script_file
	echo "echo" >> $script_file
	echo "echo \"1. Virtual router ($VR_BGP_VR) exists or is added first.\"" >> $script_file
	echo "echo \"2. BGP AS (e.g. 65530) has been set.\"" >> $script_file
	echo "echo \"3. Local interfaces and IP's have been configured. Check VR_BGP_PEER_LOCAL_INT.\"" >> $script_file
	echo "echo \"4. IP's are consistent with those from interface addition. Check IF_ETHERNET_IP for eth.\"" \
		>> $script_file
	echo "echo" >> $script_file

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	n=1

	for ((i = 1; i <= $N_VR_BGP_PEER_GROUPS; i++)); do
		group_name=`printf "$VR_BGP_PEER_GROUP_NAME" $i`

		if [ "$VR_BGP_PEER_GROUP_TYPE" = "ebgp" ]; then
			group_type="
                      <ebgp>
                        <remove-private-as>yes</remove-private-as>
                        <import-nexthop>original</import-nexthop>
                        <export-nexthop>resolve</export-nexthop>
                      </ebgp>"
		else
			group_type=""
		fi
		
		element="
                  <entry name='$group_name'>
                    <type>$group_type
                    </type>
                    <aggregated-confed-as-path>yes</aggregated-confed-as-path>
                    <soft-reset-with-stored-info>no</soft-reset-with-stored-info>
                    <enable>yes</enable>
                  </entry>"

		clean_element="@name='$group_name' or "

		echo -n "$element" >> $xml_file
		echo -n "$clean_element" >> $clean_xml_file

		echo "$element" >> $CONFIG_DUMP

		#
		# peers of each group
		#

		pre="peer$i"

		peer_xml_file="$X/$pre$XML_FILE"
		peer_out_file="$L/$pre$OUT_FILE"
		peer_log_file="$L/$pre$LOG_FILE"

		WGET_PEER="$wget \
			--post-file=$peer_xml_file \
			--no-check-certificate --output-document=$peer_out_file --append-output=$peer_log_file"

		xpath_peer="$xpath/entry[@name='$group_name']/peer"

		echo $WGET_PEER \"$URL\" >> $script_file
		echo -n "type=config&action=set&key=$API_KEY&$xpath_peer&element=" >> $peer_xml_file

		peers=1

		for ((j = VR_BGP_PEER_LOCAL_IP_OCTET_j; j < 256; j++)); do
			for ((k = VR_BGP_PEER_LOCAL_IP_OCTET_k; k < 256; k++)); do
				if [ $peers -gt $N_VR_BGP_PEERS_PER_GROUP ]; then
					break 2
				fi

				peer_name=`printf "$VR_BGP_PEER_NAME" $i $peers`
				peer_as="$VR_BGP_PEER_AS"
				peer_local_interface=`printf "$VR_BGP_PEER_LOCAL_INT" $peers`
				peer_local_ip=`printf "$VR_BGP_PEER_LOCAL_IP" $j $k`
				peer_peer_ip=`printf "$VR_BGP_PEER_PEER_IP" $j $k`

				element="
                      <entry name='$peer_name'>
                        <connection-options>
                          <incoming-bgp-connection>
                            <remote-port>0</remote-port>
                            <allow>yes</allow>
                          </incoming-bgp-connection>
                          <outgoing-bgp-connection>
                            <local-port>0</local-port>
                            <allow>yes</allow>
                          </outgoing-bgp-connection>
                          <multihop>0</multihop>
                          <keep-alive-interval>30</keep-alive-interval>
                          <open-delay-time>0</open-delay-time>
                          <hold-time>90</hold-time>
                          <idle-hold-time>15</idle-hold-time>
                          <min-route-adv-interval>30</min-route-adv-interval>
                        </connection-options>
                        <subsequent-address-family-identifier>
                          <unicast>yes</unicast>
                          <multicast>no</multicast>
                        </subsequent-address-family-identifier>
                        <local-address>
                          <ip>$peer_local_ip</ip>
                          <interface>$peer_local_interface</interface>
                        </local-address>
                        <peer-address>
                          <ip>$peer_peer_ip</ip>
                        </peer-address>
                        <bfd>
                          <profile>Inherit-vr-global-setting</profile>
                        </bfd>
                        <max-prefixes>5000</max-prefixes>
                        <enable>yes</enable>
                        <peer-as>$peer_as</peer-as>
                        <enable-mp-bgp>no</enable-mp-bgp>
                        <address-family-identifier>ipv4</address-family-identifier>
                        <enable-sender-side-loop-detection>yes</enable-sender-side-loop-detection>
                        <reflector-client>non-client</reflector-client>
                        <peering-type>unspecified</peering-type>
                      </entry>"

				echo -n "$element" >> $peer_xml_file

				((peers+=1))

				if ! ((n % 100)); then
					echo -n '.'
				fi

				((n+=1))
			done

			VR_BGP_PEER_LOCAL_IP_OCTET_k=0

		done
	done

	echo -n "@name='_$interface_name']" >> $clean_xml_file

	cat >> $CONFIG_DUMP <<-EOF
    </peer-group>
  </bgp>
</protocol>
EOF

}  # pan_vr_bgp()

# --------------------------------------------------------------------------------

if [ -n "$N_VR_BGP_PEER_GROUPS" ] && [ $N_VR_BGP_PEER_GROUPS -gt 0 ]; then
	pan_vr_bgp
fi

#
# End
#
