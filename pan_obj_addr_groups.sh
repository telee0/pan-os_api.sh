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
# Address groups
#

pan_obj_addr_groups() {

	if [ -z "$N_OBJ_ADDRESS_GROUP" ] || [ $N_OBJ_ADDRESS_GROUP -le 0 ]; then
		return 0
	fi

	echo -en "\nObjects > Addresses Groups ($N_OBJ_ADDRESS_GROUP) "

	cat >> $CONFIG_DUMP <<-EOF
<address-group>
EOF

	local i; local j

	pre="addr_group"

	if [ $# -ge 2 ]; then
		seq="-$2"
	else
		seq=""
	fi

	script_file="$pre$SCRIPT_FILE"
	xml_file="$X/$pre$seq$XML_FILE"
	out_file="$L/$pre$seq$OUT_FILE"
	log_file="$L/$pre$seq$LOG_FILE"

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
			xpath="xpath=/config/devices/entry[@name='$LHOST']/device-group/entry[@name='$dg']/address-group"
		else
			echo -n "(Shared)"
			xpath="xpath=/config/shared/address-group"
		fi
	else
		xpath="xpath=/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/address-group"
	fi

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	addresses=1

	for ((groups = 1; groups <= $N_OBJ_ADDRESS_GROUP; groups++)); do
		if [ $addresses -gt $N_OBJ_ADDRESS ]; then
			addresses=1
		fi

		group_name=`printf "$ADDR_GROUP_NAME$seq" $groups`

		members=""

		for ((j = 0; j < $ADDR_GROUP_MEMBER_COUNT; j++)); do
			if [ $addresses -gt $N_OBJ_ADDRESS ]; then
				addresses=1
			fi

			address_name=`printf "$ADDR_NAME$seq" $addresses`

			members+="<member>$address_name</member>"

			((addresses+=1))
		done

		element="
          <entry name='$group_name'>
            <static>
              $members
            </static>
          </entry>"

		clean_element="@name='$group_name' or "

		echo -n "$element" >> $xml_file
		echo -n "$clean_element" >> $clean_xml_file
		echo "$element" >> $CONFIG_DUMP

		if ! ((groups % 100)); then
			echo -n '.'
		fi
	done

	echo -n "@name='_$group_name']" >> $clean_xml_file

	cat >> $CONFIG_DUMP <<-EOF
</address-group>
EOF

}  # pan_obj_addr_groups()

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

if [ -n "$N_OBJ_ADDRESS_GROUP" ] && [ $N_OBJ_ADDRESS_GROUP -gt 0 ]; then

	unset script_file

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$PANORAMA_DEVICE_GROUP" ]; then
			pan_obj_addr_groups "$PANORAMA_DEVICE_GROUP"
		elif [ "$ADDR_GROUP_SHARED" = "Shared" ]; then
			if [ "$ADDR_SHARED" = "Shared" ]; then
				pan_obj_addr_groups
			else
				echo "ERROR: shared address groups cannot contain DG specific objects."
				echo "$param_file: check settings ADDR_GROUP_SHARED and ADDR_SHARED."
			fi
		else
			for ((i = 1; i <= $N_PAN_DG; i++)); do
				group_name=`printf "$DG_NAME" $i`
				pan_obj_addr_groups "$group_name" $i
			done
		fi
	else
    	pan_obj_addr_groups
	fi

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
