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
# IPSec tunnels between devices A and B
#

pan_vpn_ipsec_tun_aux() {

	local pre="$1"
	local path="$2"
	local site="$3"

	pushd $path > /dev/null

	# files for ipsec tunnels
	#

	script_file="$pre$SCRIPT_FILE"
	xml_file="$X/$pre$XML_FILE"
	out_file="$L/$pre$OUT_FILE"
	log_file="$L/$pre$LOG_FILE"
	clean_script_file="$pre$CLEAN_SCRIPT_FILE"
	clean_xml_file="$X/$pre$CLEAN_XML_FILE"
	clean_out_file="$L/$pre$CLEAN_OUT_FILE"
	clean_log_file="$L/$pre$CLEAN_LOG_FILE"

	# files for vr static routes
	#

	if [ "$IPSEC_ROUTE_ADD" = "yes" ]; then
		route_script_file="$script_file"
		clean_route_script_file="$clean_script_file"
	else
		route_script_file="$pre-route$SCRIPT_FILE"
		clean_route_script_file="$pre-route$CLEAN_SCRIPT_FILE"
	fi

	route_xml_file="$X/$pre-route$XML_FILE"
	route_out_file="$L/$pre-route$OUT_FILE"
	route_log_file="$L/$pre-route$LOG_FILE"
	clean_route_xml_file="$X/$pre$CLEAN_XML_FILE"
	clean_route_out_file="$L/$pre$CLEAN_OUT_FILE"
	clean_route_log_file="$L/$pre$CLEAN_LOG_FILE"

	# command line for ipsec tunnels
	#

	WGET="$wget \
		--post-file=$xml_file \
		--no-check-certificate --output-document=$out_file --append-output=$log_file"
	WGET_CLEAN="$wget \
		--post-file=$clean_xml_file \
		--no-check-certificate --output-document=$clean_out_file --append-output=$clean_log_file"

	# command line for vr static routes
	#

	WGET_ROUTE="$wget \
		--post-file=$route_xml_file \
		--no-check-certificate --output-document=$route_out_file --append-output=$route_log_file"
	WGET_ROUTE_CLEAN="$wget \
		--post-file=$clean_route_xml_file \
		--no-check-certificate --output-document=$clean_route_out_file --append-output=$clean_route_log_file"

	# $xpath and $xpath_route in the calling function
	#

	local url

	if [ "$site" = "A" ]; then
		url="$URL"
	else
		url="$URL2"
	fi

	echo "echo \"Please be sure tunnel interfaces and IKE gatway (1) are in place.\"" >> $script_file
	echo $WGET \"$url\" >> $script_file
	echo $WGET_ROUTE \"$url\" >> $route_script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath_route&element=" >> $route_xml_file

	echo $WGET_ROUTE_CLEAN \"$url\" >> $clean_route_script_file
	echo $WGET_CLEAN \"$url\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath_route/entry[" >> $clean_route_xml_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	popd > /dev/null

	# paths normalized for the calling functions
	#

	xml_file="$path/$xml_file"
	clean_xml_file="$path/$clean_xml_file"
	route_xml_file="$path/$route_xml_file"
	clean_route_xml_file="$path/$clean_route_xml_file"
}


pan_vpn_ipsec_tun() {

	if [ -z "$N_NET_IPSEC" ] || [ $N_NET_IPSEC -le 0 ]; then
		return 0
	fi

	echo -en "\nNetwork > IPSec Tunnels ($N_NET_IPSEC) with static routes through tunnels "

	cat >> $CONFIG_DUMP <<-EOF
<network>
  <tunnel>
    <ipsec>
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

	xpath="$XPATH/config/devices/entry[@name='$LHOST']/network/tunnel/ipsec"
	xpath_route="$XPATH/config/devices/entry[@name='$LHOST']/network/virtual-router/entry[@name='$IPSEC_VR']/routing-table/ip/static-route"

	# ------------------------------------------------------------

	local path_A="."; local path_B="$P"

	pre="ipsec_tun"

	#
	# site A

	pan_vpn_ipsec_tun_aux "$pre" "$path_A" "A"
	
	xml_file_A="$xml_file"
	clean_xml_file_A="$clean_xml_file"
	route_xml_file_A="$route_xml_file"
	clean_route_xml_file_A="$clean_route_xml_file"

	#
	# site B

	pan_vpn_ipsec_tun_aux "$pre" "$path_B" "B"

	xml_file_B="$xml_file"
	clean_xml_file_B="$clean_xml_file"
	route_xml_file_B="$route_xml_file"
	clean_route_xml_file_B="$clean_route_xml_file"

	# ------------------------------------------------------------

	ipsec=1

	routes_A=""
	routes_B=""

	for ((i = 1; i <= $N_NET_IPSEC; i++)); do
		if [ $ipsec -gt $N_NET_IPSEC ]; then
			break 1
		fi

		ipsec_name=`printf "$IPSEC_NAME" $i`
		ipsec_ike_gateway=`printf "$IPSEC_IKE_GATEWAY" $i`

		proxy_id_A=""
		proxy_id_B=""

		if [ "$IPSEC_PROXY_ID_ADD" = "yes" ]; then
			for ((j = 1; j <= $IPSEC_PROXY_ID_LIMIT; j++)); do
				if [ $ipsec -gt $N_NET_IPSEC ]; then
					break 1
				fi

				proxy_id_name=`printf "$IPSEC_PROXY_ID_NAME" $i $j`

				local=`printf "$IPSEC_IP_LOCAL" $i $j`
				remote=`printf "$IPSEC_IP_REMOTE" $i $j`
				protocol="$IPSEC_PROXY_ID_PROTOCOL"

				proxy_id_A+="
                  <entry name='$proxy_id_name'>
                    <protocol>
                      <$protocol/>
                    </protocol>
                    <local>$local</local>
                    <remote>$remote</remote>
                  </entry>"

				proxy_id_B+="
                  <entry name='$proxy_id_name'>
                    <protocol>
                      <$protocol/>
                    </protocol>
                    <local>$remote</local>
                    <remote>$local</remote>
                  </entry>"

				if ! ((ipsec % 100)); then
					echo -n '.'
				fi

				((ipsec+=1))
			done

			proxy_id_A="<proxy-id>$proxy_id_A</proxy-id>"
			proxy_id_B="<proxy-id>$proxy_id_B</proxy-id>"
		fi

		element_A="
            <entry name='$ipsec_name'>
              <auto-key>
                <ike-gateway>
                  <entry name='$ipsec_ike_gateway'/>
                </ike-gateway>
                $proxy_id_A
              </auto-key>
              <tunnel-monitor>
                <enable>no</enable>
              </tunnel-monitor>
              <tunnel-interface>tunnel.$i</tunnel-interface>
              <anti-replay>$IPSEC_REPLAY_PROTECTION</anti-replay>
            </entry>"

		element_B="
            <entry name='$ipsec_name'>
              <auto-key>
                <ike-gateway>
                  <entry name='$ipsec_ike_gateway'/>
                </ike-gateway>
                $proxy_id_B
              </auto-key>
              <tunnel-monitor>
                <enable>no</enable>
              </tunnel-monitor>
              <tunnel-interface>tunnel.$i</tunnel-interface>
              <anti-replay>$IPSEC_REPLAY_PROTECTION</anti-replay>
            </entry>"

		clean_element="@name='ipsec_name' or "

		echo -n "$element_A" >> $xml_file_A
		echo -n "$clean_element" >> $clean_xml_file_A
		echo -n "$element_B" >> $xml_file_B
		echo -n "$clean_element" >> $clean_xml_file_B

		echo "$element_A" >> $CONFIG_DUMP

		#
		# install routes
		#

		route_name="Tunnel_Route-$i"

		destination_A=`printf "$IPSEC_IP_REMOTE$IPSEC_IP_REMOTE_PREFIX" $i 0`
		destination_B=`printf "$IPSEC_IP_LOCAL$IPSEC_IP_LOCAL_PREFIX" $i 0`

		routes_A+="
		          <entry name='$route_name'>
                    <interface>tunnel.$i</interface>
                    <metric>10</metric>
                    <destination>$destination_A</destination>
                    <route-table>
                      <unicast/>
                    </route-table>
                  </entry>"

		routes_B+="
		          <entry name='$route_name'>
                    <interface>tunnel.$i</interface>
                    <metric>10</metric>
                    <destination>$destination_B</destination>
                    <route-table>
                      <unicast/>
                    </route-table>
                  </entry>"

		clean_routes="@name='$route_name' or "

		echo -n "$clean_routes" >> $clean_route_xml_file_A
		echo -n "$clean_routes" >> $clean_route_xml_file_B
	done

	echo -n "$routes_A" >> $route_xml_file_A
	echo -n "$routes_B" >> $route_xml_file_B

	echo -n "@name='_$route_name']" >> $clean_route_xml_file_A
	echo -n "@name='_$route_name']" >> $clean_route_xml_file_B

	echo -n "@name='_$ipsec_name']" >> $clean_xml_file_A
	echo -n "@name='_$ipsec_name']" >> $clean_xml_file_B

	cat >> $CONFIG_DUMP <<-EOF
    </ipsec>
  </tunnel>
</network>
EOF

}  # pan_vpn_ipsec_tun()

# --------------------------------------------------------------------------------

if [ -n "$N_NET_IPSEC" ] && [ $N_NET_IPSEC -gt 0 ]; then

	unset script_file

	pan_vpn_ipsec_tun

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
