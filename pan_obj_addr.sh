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
# Address objects
#

pan_obj_addr() {

	if [ -z "$N_OBJ_ADDRESS" ] || [ $N_OBJ_ADDRESS -le 0 ]; then
		return 0
	fi

	echo -en "\nObjects > Addresses ($N_OBJ_ADDRESS) "

	cat >> $CONFIG_DUMP <<-EOF
<address>
EOF

	local i; local j

	pre="addr"

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
			xpath="xpath=/config/devices/entry[@name='$LHOST']/device-group/entry[@name='$dg']/address"
		else
			echo -n "(Shared)"
			xpath="xpath=/config/shared/address"
		fi
	else
		xpath="xpath=/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/address"
	fi

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	addresses=1

	for ((i = 0; i < 256; i++)); do
		for ((j = 0; j < 256; j++)); do
			if [ $addresses -gt $N_OBJ_ADDRESS ]; then
				break 1
			fi

			address_name=`printf "$ADDR_NAME$seq" $addresses`

			case "$ADDR_TYPE" in
				ip-netmask)
					address=`printf "$ADDR_ADDRESS" $i $j`
					;;
				ip-range)
					# we assume $j > 0 for host number
					if [ $j -lt 1 ]; then j=1; fi
					k=$((j + ADDR_RANGE - 1))
					if [ $k -gt 254 ]; then k=254; fi
					address=`printf "$ADDR_ADDRESS-$ADDR_ADDRESS" $i $j $i $k`
					((j = j + ADDR_RANGE - 1))
					;;
				fqdn)
					# $j comes here
					address=`printf "$ADDR_ADDRESS" $j $i`
					;;
				*)
					echo -e "\n\n\tADDR_TYPE: $ADDR_TYPE: unknown type"
					break 2
					;;
			esac

			element="
              <entry name='$address_name'><$ADDR_TYPE>$address</$ADDR_TYPE></entry>"

			clean_element="@name='$address_name' or "

			echo -n "$element" >> $xml_file
			echo -n "$clean_element" >> $clean_xml_file
			echo "$element" >> $CONFIG_DUMP

			if ! ((addresses % 100)); then
				echo -n '.'
			fi

			((addresses+=1))
		done
	done

	echo -n "@name='_$address_name']" >> $clean_xml_file

	cat >> $CONFIG_DUMP <<-EOF
</address>
EOF

}  # pan_obj_addr()

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

if [ -n "$N_OBJ_ADDRESS" ] && [ $N_OBJ_ADDRESS -gt 0 ]; then

	unset script_file

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$PANORAMA_DEVICE_GROUP" ]; then
			pan_obj_addr "$PANORAMA_DEVICE_GROUP"
		elif [ "$ADDR_SHARED" = "Shared" ]; then
    		pan_obj_addr
		else
			for ((i = 1; i <= $N_PAN_DG; i++)); do
				group_name=`printf "$DG_NAME" $i`
				pan_obj_addr "$group_name" $i
			done
		fi
	else
    	pan_obj_addr
	fi

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
