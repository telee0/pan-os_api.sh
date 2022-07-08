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
# Services
#

pan_obj_svc() {

	if [ -z "$N_OBJ_SERVICE" ] || [ $N_OBJ_SERVICE -le 0 ]; then
		return 0
	fi

	echo -en "\nObjects > Services ($N_OBJ_SERVICE) "

	cat >> $CONFIG_DUMP <<-EOF
<service>
EOF

	local i; local j

	pre="svc"

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
			xpath="xpath=/config/devices/entry[@name='$LHOST']/device-group/entry[@name='$dg']/service"
		else
			echo -n "(Shared)"
			xpath="xpath=/config/shared/service"
		fi
	else
    	# xpath="xpath=/config/shared/service"
    	xpath="xpath=/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/service"
	fi

	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file

	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	for ((i = 0; i < $N_OBJ_SERVICE; i++)); do
		((service_port = SERVICE_PORT_DST + i))

		if [ -n "$SERVICE_PORT_SRC" ]; then
			service_port_src=`printf "<source-port>%d</source-port>" $((SERVICE_PORT_SRC + i))`
		fi

		element1=""
		element2=""
		clean_element1=""
		clean_element2=""

		if [ "$SERVICE_PROTOCOL" = "both" ] || [ "$SERVICE_PROTOCOL" = "tcp" ]; then
			service_name=`printf "$SERVICE_NAME$seq" "tcp" $service_port`

			element1="
      <entry name='$service_name'>
        <protocol>
          <tcp>
            <port>$service_port</port>
            <override>
              <no/>
            </override>
            $service_port_src
          </tcp>
        </protocol>
      </entry>"

			clean_element1="@name='$service_name' or "
		fi

		if [ "$SERVICE_PROTOCOL" = "both" ] || [ "$SERVICE_PROTOCOL" = "udp" ]; then
			service_name=`printf "$SERVICE_NAME$seq" "udp" $service_port`

			element2="
      <entry name='$service_name'>
        <protocol>
          <udp>
            <port>$service_port</port>
            <override>
              <no/>
            </override>
            $service_port_src
          </udp>
        </protocol>
      </entry>"

			clean_element2="@name='$service_name' or "
		fi

		echo -n "$element1$element2" >> $xml_file
		echo -n "$clean_element1$clean_element2" >> $clean_xml_file
		echo "$element1$element2" >> $CONFIG_DUMP

		if ! (((i+1) % 100)); then
			echo -n '.'
		fi
	done

	echo -n "@name='_$service_name']" >> $clean_xml_file

	cat >> $CONFIG_DUMP <<-EOF
</service>
EOF

}  # pan_obj_svc()

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

if [ -n "$N_OBJ_SERVICE" ] && [ $N_OBJ_SERVICE -gt 0 ]; then

	unset script_file

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$PANORAMA_DEVICE_GROUP" ]; then
			pan_obj_svc "$PANORAMA_DEVICE_GROUP"
		elif [ "$SERVICE_SHARED" = "Shared" ]; then
    		pan_obj_svc
		else
			for ((i = 1; i <= $N_PAN_DG; i++)); do
				group_name=`printf "$DG_NAME" $i`
				pan_obj_svc "$group_name" $i
			done
		fi
	else
    	pan_obj_svc
	fi

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
