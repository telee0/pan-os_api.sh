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
# IKE gateways between devices A and B
#

pan_vpn_ike_gw_aux() {

	local pre="$1"
	local path="$2"
	local site="$3"

	pushd $path > /dev/null

	# files for ike gateways
	#

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

	# $xpath set in the calling function

 	local url

	if [ "$site" = "A" ]; then
		url="$URL"
	else
		url="$URL2"
	fi

	echo "echo \"Please be sure of the following before adding IKE gateways.\"" >> $script_file
	echo "echo" >> $script_file
	echo "echo \"1. Local interface and IP have been configured.\"" >> $script_file
	echo "echo \"2. Peer is reachable. (routing)\"" >> $script_file
	echo "echo" >> $script_file
	echo $WGET \"$url\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file

	echo $WGET_CLEAN \"$url\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	popd > /dev/null

	# paths normalized for the calling functions
	#

	xml_file="$path/$xml_file"
	clean_xml_file="$path/$clean_xml_file"
}


pan_vpn_ike_gw() {

	if [ -z "$N_NET_IKE" ] || [ $N_NET_IKE -le 0 ]; then
		return 0
	fi

	echo -en "\nNetwork > IKE Gateways ($N_NET_IKE) "

	cat >> $CONFIG_DUMP <<-EOF
<ike>
  <gateway>
EOF

	local i; local j

	# ------------------------------------------------------------

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

	xpath="$XPATH/config/devices/entry[@name='$LHOST']/network/ike/gateway"

	# ------------------------------------------------------------

	local path_A="."; local path_B="$P"

	pre="ike_gw"

	#
	# site A

	pan_vpn_ike_gw_aux "$pre" "$path_A" "A"

	xml_file_A="$xml_file"
	clean_xml_file_A="$clean_xml_file"

	#
	# site B

	pan_vpn_ike_gw_aux "$pre" "$path_B" "B"

	xml_file_B="$xml_file"
	clean_xml_file_B="$clean_xml_file"

	# ------------------------------------------------------------
	#
	# Settings common to all IKE gateways
	#

	if [ "$IKE_VERSION" = "ikev1" ]; then
		ike_version=""
	else
		ike_version="<version>$IKE_VERSION</version>"
	fi

	if [ "$IKE_CRYPTO_PROFILE" = "default" ]; then
		ike_crypto_profile=""
	else
		ike_crypto_profile="<ike-crypto-profile>$IKE_CRYPTO_PROFILE</ike-crypto-profile>"
	fi

	ike=1

	for ((i = 0; i < 256; i++)); do
		for ((j = 0; j < 256; j++)); do
			if [ $ike -gt $N_NET_IKE ]; then
            	break 1
    	    fi

			ike_name=`printf "$IKE_NAME" $ike`
			ike_interface=`printf "$IKE_INTERFACE" $ike`

			#
			# Local and peer addresses. Change accordingly.
			#

			ike_ip_local=`printf "$IKE_IP_LOCAL" $i $j`
			ike_ip_peer=`printf "$IKE_IP_PEER" $i $j`

			element_A="
            <entry name='$ike_name'>
              <authentication>
                <pre-shared-key>
                  <key>$IKE_PRESHARED_KEY</key>
                </pre-shared-key>
              </authentication>
              <protocol>
                <ikev1>
                  <dpd>
                    <enable>yes</enable>
                  </dpd>
                  $ike_crypto_profile
                </ikev1>
                <ikev2>
                  <dpd>
                    <enable>yes</enable>
                  </dpd>
                  $ike_crypto_profile
                </ikev2>
                $ike_version
              </protocol>
              <protocol-common>
                <nat-traversal>
                  <enable>no</enable>
                </nat-traversal>
                <fragmentation>
                  <enable>no</enable>
                </fragmentation>
              </protocol-common>
              <local-address>
                <interface>$ike_interface</interface>
                <ip>$ike_ip_local$IKE_IP_LOCAL_PREFIX</ip>
              </local-address>
              <peer-address>
                <ip>$ike_ip_peer</ip>
              </peer-address>
            </entry>"

			element_B="
            <entry name='$ike_name'>
              <authentication>
                <pre-shared-key>
                  <key>$IKE_PRESHARED_KEY</key>
                </pre-shared-key>
              </authentication>
              <protocol>
                <ikev1>
                  <dpd>
                    <enable>yes</enable>
                  </dpd>
                  $ike_crypto_profile
                </ikev1>
                <ikev2>
                  <dpd>
                    <enable>yes</enable>
                  </dpd>
                  $ike_crypto_profile
                </ikev2>
                $ike_version
              </protocol>
              <protocol-common>
                <nat-traversal>
                  <enable>no</enable>
                </nat-traversal>
                <fragmentation>
                  <enable>no</enable>
                </fragmentation>
              </protocol-common>
              <local-address>
                <interface>$ike_interface</interface>
                <ip>$ike_ip_peer$IKE_IP_PEER_PREFIX</ip>
              </local-address>
              <peer-address>
                <ip>$ike_ip_local</ip>
              </peer-address>
            </entry>"

			clean_element="@name='$ike_name' or "

			echo -n "$element_A" >> $xml_file_A
			echo -n "$clean_element" >> $clean_xml_file_A

			echo -n "$element_B" >> $xml_file_B
			echo -n "$clean_element" >> $clean_xml_file_B

			echo "$element_A" >> $CONFIG_DUMP

			if ! ((ike % 100)); then
				echo -n '.'
			fi

			((ike+=1))
		done
	done

	echo -n "@name='_$ike_name']" >> $clean_xml_file_A
	echo -n "@name='_$ike_name']" >> $clean_xml_file_B

	cat >> $CONFIG_DUMP <<-EOF
  </gateway>
</ike>
EOF

}  # pan_vpn_ike_gw()

# --------------------------------------------------------------------------------

if [ -n "$N_NET_IKE" ] && [ $N_NET_IKE -gt 0 ]; then

	unset script_file

	pan_vpn_ike_gw

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
