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
# Service groups
#

pan_obj_svc_groups() {

	if [ -z "$N_OBJ_SERVICE_GROUP" ] || [ $N_OBJ_SERVICE_GROUP -le 0 ]; then
		return 0
	fi

	echo -en "\nObjects > Service Groups ($N_OBJ_SERVICE_GROUP) "

	cat >> $CONFIG_DUMP <<-EOF
<service-group>
EOF

	local i; local j

	pre="svc_group"

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
			xpath="xpath=/config/devices/entry[@name='$LHOST']/device-group/entry[@name='$dg']/service-group"
		else
			echo -n "(Shared)"
			xpath="xpath=/config/shared/service-group"
		fi
	else
		xpath="xpath=/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/service-group"
	fi

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	services=1

	for ((groups = 1; groups <= $N_OBJ_SERVICE_GROUP; groups++)); do
		if [ $services -gt $N_OBJ_SERVICE ]; then
			services=1
		fi

		group_name=`printf "$SERVICE_GROUP_NAME$seq" $groups`

		members=""

		for ((j = 0; j < $SERVICE_GROUP_MEMBER_COUNT; j++)); do
			if [ $services -gt $N_OBJ_SERVICE ]; then
				services=1
			fi

			((service_port = SERVICE_PORT_DST + services - 1))

			if [ "$SERVICE_GROUP_PROTOCOL" = "both" ] || [ "$SERVICE_GROUP_PROTOCOL" = "tcp" ]; then
				service_name=`printf "$SERVICE_NAME$seq" "tcp" $service_port`
				members+="
                  <member>$service_name</member>"
			fi
			if [ "$SERVICE_GROUP_PROTOCOL" = "both" ] || [ "$SERVICE_GROUP_PROTOCOL" = "udp" ]; then
				service_name=`printf "$SERVICE_NAME$seq" "udp" $service_port`
				members+="
                  <member>$service_name</member>"
			fi

			((services+=1))
		done

		element="
          <entry name='$group_name'>
            <members>
              $members
            </members>
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
</service-group>
EOF

}  # pan_obj_svc_groups()

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

if [ -n "$N_OBJ_SERVICE_GROUP" ] && [ $N_OBJ_SERVICE_GROUP -gt 0 ]; then

	unset script_file

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$PANORAMA_DEVICE_GROUP" ]; then
			pan_obj_svc_groups "$PANORAMA_DEVICE_GROUP"
		elif [ "$SERVICE_GROUP_SHARED" = "Shared" ]; then
			if [ "$SERVICE_SHARED" = "Shared" ]; then
    			pan_obj_svc_groups
			else
				echo "ERROR: shared service groups cannot contain DG specific objects."
				echo "$param_file: check settings SERVICE_GROUP_SHARED and SERVICE_SHARED."
			fi
		else
			for ((i = 1; i <= $N_PAN_DG; i++)); do
				group_name=`printf "$DG_NAME" $i`
				pan_obj_svc_groups "$group_name" $i
			done
		fi
	else
    	pan_obj_svc_groups
	fi

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
