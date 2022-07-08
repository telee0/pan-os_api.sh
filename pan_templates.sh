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
# Panorama templates
#

pan_templates() {

	if [ -z "$N_PAN_TPL" ] || [ $N_PAN_TPL -le 0 ]; then
		return 0
	fi

	echo -en "\nPanorama > Templates ($N_PAN_TPL) "

	cat >> $CONFIG_DUMP <<-EOF
<template>
EOF

	local i; local j

	pre="pan_tpl"

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

	xpath="xpath=/config/devices/entry[@name='$LHOST']/template"

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	templates=1

	for ((i = 0; i < $N_PAN_TPL; i++)); do
		template_name=`printf "$TPL_NAME" $templates`

		element="
              <entry name='$template_name'></entry>"

		clean_element="@name='$template_name' or "

		echo -n "$element" >> $xml_file
		echo -n "$clean_element" >> $clean_xml_file
		echo "$element" >> $CONFIG_DUMP

		if ! ((templates % 100)); then
			echo -n '.'
		fi

		((templates+=1))
	done

	echo -n "@name='_$template_name']" >> $clean_xml_file

	cat >> $CONFIG_DUMP <<-EOF
</template>
EOF

}  # pan_templates()

# --------------------------------------------------------------------------------

if [ "$TARGET" = "PANORAMA" ] \
		&& [ -n "$N_PAN_TPL" ] && [ $N_PAN_TPL -gt 0 ]; then

	unset script_file

    pan_templates

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
