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
# Virtual router static routes
#

pan_vr_static() {

	if [ -z "$N_VR_STATIC" ] || [ $N_VR_STATIC -le 0 ]; then
		return 0
	fi

	echo -en "\nNetwork > VR > $VR_STATIC_VR > Static Routes ($N_VR_STATIC) "

	cat >> $CONFIG_DUMP <<-EOF
<routing-table>
  <ip>
    <static-route>
EOF

	local i; local j

	pre="route"

	script_file="$pre$SCRIPT_FILE"
	xml_file="$X/$pre$XML_FILE"
	out_file="$L/$pre$OUT_FILE"
	log_file="$L/$pre$LOG_FILE"

	WGET="$wget \
		--post-file=$xml_file \
		--no-check-certificate --output-document=$out_file --append-output=$log_file"

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

	xpath="$XPATH/config/devices/entry[@name='$LHOST']/network/virtual-router/entry[@name='$VR_STATIC_VR']/routing-table/ip/static-route"

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file

	if [ -z "$VR_STATIC_INTERFACE" ]; then
		interface=""
	else
		interface="<interface>$VR_STATIC_INTERFACE</interface>"
	fi

	routes=1

	for ((i = 0; i < 256; i++)); do
		for ((j = 0; j < 256; j++)); do
			if [ $routes -gt $N_VR_STATIC ]; then
				break 1
			fi

			route_name=`printf "$VR_STATIC_NAME" $routes`
			destination=`printf "$VR_STATIC_DESTINATION" $i $j`

			element="
                  <entry name='$route_name'>
                    <path-monitor>
                      <enable>no</enable>
                      <failure-condition>any</failure-condition>
                      <hold-time>2</hold-time>
                    </path-monitor>
                    <nexthop>
                      <ip-address>$VR_STATIC_NEXTHOP</ip-address>
                    </nexthop>
                    <bfd>
                      <profile>None</profile>
                    </bfd>
                    $interface
                    <metric>10</metric>
                    <destination>$destination</destination>
                    <route-table>
                      <unicast/>
                    </route-table>
                  </entry>"

			echo -n "$element" >> $xml_file
			echo "$element" >> $CONFIG_DUMP

			if ! ((routes % 100)); then
				echo -n '.'
			fi

			((routes+=1))
		done
	done

	cat >> $CONFIG_DUMP <<-EOF
    </static-route>
  </ip>
</routing-table>
EOF

}  # pan_vr_static()

# --------------------------------------------------------------------------------

if [ -n "$N_VR_STATIC" ] && [ $N_VR_STATIC -gt 0 ]; then
	pan_vr_static
fi

#
# End
#
