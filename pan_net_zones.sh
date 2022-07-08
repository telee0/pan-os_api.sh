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
# Network zones
#

pan_net_zones() {

	if [ -z "$N_NET_ZONES" ] || [ $N_NET_ZONES -le 0 ]; then
		return 0
	fi

	echo -en "\nNetwork > Zones ($N_NET_ZONES) "

	cat >> $CONFIG_DUMP <<-EOF
<vsys>
  <entry name="$VSYS">
    <zone>
EOF

	local i; local j

	pre="zone"

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

	xpath="$XPATH/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/zone"

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	zones=1

	for ((i = 0; i < 256; i++)); do
		for ((j = 0; j < 256; j++)); do
			if [ $zones -gt $N_NET_ZONES ]; then
				break 1
			fi

			zone_name=`printf "$ZONE_NAME" $zones`

			if [ "$ZONE_UID" = "yes" ]; then
				zone_uid="<enable-user-identification>yes</enable-user-identification>"
			else
				zone_uid=""
			fi

			element="<entry name='$zone_name'>$zone_uid</entry>"

			clean_element="@name='$zone_name' or "

			echo -n "$element" >> $xml_file
			echo -n "$clean_element" >> $clean_xml_file
			echo "$element" >> $CONFIG_DUMP

			if ! ((zones % 100)); then
				echo -n '.'
			fi

			((zones+=1))
		done
	done

	echo -n "@name='_$zone_name']" >> $clean_xml_file

	cat >> $CONFIG_DUMP <<-EOF
    </zone>
  </entry>
</vsys>
EOF

}  # pan_net_zones()

# --------------------------------------------------------------------------------

if [ -n "$N_NET_ZONES" ] && [ $N_NET_ZONES -gt 0 ]; then

	unset script_file

	pan_net_zones

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
