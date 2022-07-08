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
# User-ID IP-user mappings
#

pan_uid() {

	if [ -z "$N_UID_NETS" -o $N_UID_NETS -le 0 ] \
			|| [ -z "$N_UID_ENTRIES" -o $N_UID_ENTRIES -le 0 ]; then
		return 0
	fi

	echo -en "\nUser-ID > IP-user mappings ($N_UID_NETS x $N_UID_ENTRIES) "

	local i; local j

	pre="uid"

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

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=user-id&key=$API_KEY&cmd=" >> $xml_file
	# echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	# echo -n "type=user-id&key=$API_KEY&cmd=" >> $clean_xml_file

	cat >> $xml_file <<-EOF
<uid-message>
<version>2.0</version>
<type>update</type>
<payload>
<login>
EOF

	for ((i = 0; i < $N_UID_NETS; i++)); do

		entries=1

		for ((i2 = 0; i2 < 256; i2++)); do
			for ((j2 = 1; j2 < 255; j2++)); do
				if [ $entries -gt $N_UID_ENTRIES ]; then
					break 2
				fi

				uid_user=`printf "$UID_USER" $((UID_DOMAIN_i + i)) $entries`
				uid_ip=`printf "${UID_IP[$i]}" $i2 $j2`

				element="<entry name=\"$uid_user\" ip=\"$uid_ip\" timeout=\"$UID_TIMEOUT\"/>"

				# clean_element="@name='$uid_ip' or "

				echo "$element" >> $xml_file
				# echo -n "$clean_element" >> $clean_xml_file

				if ! ((entries % 100)); then
					echo -n '.'
				fi

				((entries+=1))
			done
		done
	done

	cat >> $xml_file <<-EOF
</login>
</payload>
</uid-message>
EOF

	# echo -n "@name='_$user_name']" >> $clean_xml_file

}  # pan_uid()

# --------------------------------------------------------------------------------

if [ -n "$N_UID_NETS" -a $N_UID_NETS -gt 0 ] \
		&& [ -n "$N_UID_ENTRIES" -a $N_UID_ENTRIES -gt 0 ]; then
	pan_uid
fi

#
# End
#
