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
# Custom URL categories
#

pan_obj_url() {

	if [ -z "$N_OBJ_URL_CATS" -o $N_OBJ_URL_CATS -le 0 ] \
			|| [ -z "$N_OBJ_URL_ENTRIES" -o $N_OBJ_URL_ENTRIES -le 0 ]; then
		return 0
	fi

	echo -en "\nObjects > Custom URL Category with url.txt ($N_OBJ_URL_CATS x $N_OBJ_URL_ENTRIES) "

	cat >> $CONFIG_DUMP <<-EOF
<profiles>
  <custom-url-category>
EOF

	local i; local j

	pre="url"

	if [ $# -ge 2 ]; then
		seq="-$2"
	else
		seq=""
	fi

	script_file="$pre$SCRIPT_FILE"
	xml_file="$X/$pre$seq$XML_FILE"
	out_file="$L/$pre$seq$OUT_FILE"
	log_file="$L/$pre$seq$LOG_FILE"
	url_file="url.txt"

	clean_script_file="$pre$CLEAN_SCRIPT_FILE"
	clean_xml_file="$X/$pre$seq$CLEAN_XML_FILE"
	clean_out_file="$L/$pre$seq$CLEAN_OUT_FILE"
	clean_log_file="$L/$pre$seq$CLEAN_LOG_FILE"

	WGET="$wget \
		--post-file=$xml_file \
		--no-check-certificate --output-document=$out_file --append-output=$log_file"
	WGET_CLEAN="$wget \
		--post-file=$clean_xml_file \
		--no-check-certificate --output-document=$clean_out_file --append-output=$clean_log_file"

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$1" ]; then
			dg="$1"
			echo -n DG = $dg
			xpath="xpath=/config/devices/entry[@name='$LHOST']/device-group/entry[@name='$dg']/profiles/custom-url-category"
		else
			xpath="xpath=/config/shared/profiles/custom-url-category"
		fi
	else
		# xpath="xpath=/config/shared/profiles/custom-url-category"
		xpath="xpath=/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/profiles/custom-url-category"
	fi

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file

	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	entries=1

	for ((i = 0; i < $N_OBJ_URL_CATS; i++)); do
		url_category=`printf "$URL_CAT_NAME$seq" $((URL_CAT_NAME_i + i))`

		members=""

		for ((j = 0; j < $N_OBJ_URL_ENTRIES; j++)); do
			site=`printf "$URL_ENTRY" $((URL_ENTRY_j + j)) $((URL_CAT_NAME_i + i))`

			members+="
              <member>$site</member>"

			echo "http://$site" >> $url_file

			if ! ((entries % 100)); then
				echo -n '.'
			fi

			((entries+=1))
		done

		element="
          <entry name='$url_category'>
            <list>
            $members
            </list>
          <type>$URL_TYPE</type>
        </entry>"

		clean_element="@name='$url_category' or "

		echo -n "$element" >> $xml_file
		echo -n "$clean_element" >> $clean_xml_file
		echo "$element" >> $CONFIG_DUMP
	done

	echo -n "@name='_$url_category']" >> $clean_xml_file

	cat >> $CONFIG_DUMP <<-EOF
  </custom-url-category>
</profiles>
EOF

}  # pan_obj_url()

# --------------------------------------------------------------------------------

#
# options
#
# 1. PA 1 vsys
# 2. PA all vsys
# 3. PAN 1 DG
# 4. PAN all DG
# 5. PAN shared
#

if [ -n "$N_OBJ_URL_CATS" -a $N_OBJ_URL_CATS -gt 0 ] \
		&& [ -n "$N_OBJ_URL_ENTRIES" -a $N_OBJ_URL_ENTRIES -gt 0 ]; then

	unset script_file

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$PANORAMA_DEVICE_GROUP" ]; then
			pan_obj_url "$PANORAMA_DEVICE_GROUP"
		elif [ "$URL_SHARED" = "Shared" ]; then
			pan_obj_url
		else
			for ((i = 1; i <= $N_PAN_DG; i++)); do
				group_name=`printf "$DG_NAME" $i`
				pan_obj_url "$group_name" $i
			done
		fi
	else
        pan_obj_url
	fi

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
