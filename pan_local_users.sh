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
# Local users on PA or template/stack
#

get_phash () {
	user_pass="$1"

	xml_file="$X/phash$XML_FILE"
	out_file="$L/phash$OUT_FILE"
	log_file="$L/phash$LOG_FILE"

	WGET="$wget \
		--post-file=$xml_file \
		--no-check-certificate --output-document=$out_file --append-output=$log_file"

	echo -n "type=op&key=$API_KEY&cmd=" >> $xml_file
	echo -n "<request><password-hash><password>$user_pass</password></password-hash></request>" >> $xml_file

	$WGET "$URL"

	phash="`xml_grep phash $out_file --text_only | head -1`"
	# phash="`xml_grep key $out_file --text_only | head -1`"

	if [ "$phash" = "" ]; then
		echo "$phash: Invalid password hash"
		exit
	fi

	echo "$phash"
}


pan_local_users() {

	if [ -z "$N_USERS" ] || [ $N_USERS -le 0 ]; then
		return 0
	fi

	echo -en "\nDevice > Users ($N_USERS) "

	cat >> $CONFIG_DUMP <<-EOF
<shared>
  <local-user-database>
    <user>
EOF

	local i; local j

	pre="user"

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
		fi
		echo -n Template = $template
	else
		XPATH="xpath="
	fi

	xpath="$XPATH/config/shared/local-user-database/user"

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	phash=$(get_phash "$USER_PASS")

	for ((i = 1; i <= $N_USERS; i++)); do
		user_name=`printf "$USER_NAME" $i`

		element="
          <entry name='$user_name'>
            <phash>$phash</phash>
          </entry>"

		clean_element="@name='$user_name' or "

		echo -n "$element" >> $xml_file
		echo -n "$clean_element" >> $clean_xml_file
		echo "$element" >> $CONFIG_DUMP
	done

	echo -n "@name='_$user_name']" >> $clean_xml_file

	cat >> $CONFIG_DUMP <<-EOF
    </user>
  </local-user-database>
</shared>
EOF

}  # pan_local_users()

# --------------------------------------------------------------------------------

if [ -n "$N_USERS" ] && [ $N_USERS -gt 0 ]; then
    pan_local_users
fi

#
# End
#
