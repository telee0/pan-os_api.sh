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
# Security rules
#

pan_rules_sec() {

	if [ -z "$N_RULES_SEC" ] || [ $N_RULES_SEC -le 0 ]; then
		return 0
	fi

	echo -en "\nPolicies > Security ($N_RULES_SEC) "

	cat >> $CONFIG_DUMP <<-EOF
<security>
  <rules>
EOF

	local i; local j

	pre="sec"

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
			xpath="xpath=/config/devices/entry[@name='$LHOST']/device-group/entry[@name='$dg']/$SEC_RULEBASE/security/rules"
		else
			xpath="xpath=/config/shared/$SEC_RULEBASE/security/rules"
		fi
	else
		xpath="xpath=/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/rulebase/security/rules"
    fi

	echo "echo \"Adding rules $pre$seq ($N_RULES_SEC)..\"" >> $script_file
	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file

	echo "echo \"Deleting rules $pre$seq ($N_RULES_SEC)..\"" >> $clean_script_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	if [ -z "$SEC_SERVICE" ]; then
		service="any"
	else
		service="$SEC_SERVICE"
	fi

	rules=1

	for ((i = 0; i < 256; i++)); do
		# for ((j = 0; j < 256; j++)); do
		for ((j = 1; j < 255; j++)); do
			if [ $rules -gt $N_RULES_SEC ]; then
				break 1
			fi

			rule_name=`printf "$SEC_NAME$seq" $rules`
			source=`printf "$SEC_SOURCE" $i $j`
			destination=`printf "$SEC_DESTINATION" $i $j`

			element="
                <entry name='$rule_name'>
                  <to>
                    <member>$SEC_DST_ZONE</member>
                  </to>
                  <from>
                    <member>$SEC_SRC_ZONE</member>
                  </from>
                  <source>
                    <member>$source</member>
                  </source>
                  <destination>
                    <member>$destination</member>
                  </destination>
                  <source-user>
                    <member>any</member>
                  </source-user>
                  <category>
                    <member>any</member>
                  </category>
                  <application>
                    <member>any</member>
                  </application>
                  <service>
                    <member>$service</member>
                  </service>
                  <hip-profiles>
                    <member>any</member>
                  </hip-profiles>
                  <action>$SEC_ACTION</action>
                </entry>"

			clean_element="@name='$rule_name' or "

			echo -n "$element" >> $xml_file
			echo -n "$clean_element" >> $clean_xml_file
			echo "$element" >> $CONFIG_DUMP

			if ! ((rules % 100)); then
				echo -n '.'
			fi

			((rules+=1))
		done
	done

	echo -n "@name='_$rule_name']" >> $clean_xml_file

	cat >> $CONFIG_DUMP <<-EOF
  </rules>
</security>
EOF

}  # pan_rules_sec()

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

if [ -n "$N_RULES_SEC" ] && [ $N_RULES_SEC -gt 0 ]; then

	unset script_file

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$PANORAMA_DEVICE_GROUP" ]; then
			pan_rules_sec "$PANORAMA_DEVICE_GROUP"
		elif [ "$SEC_SHARED" = "Shared" ]; then
			pan_rules_sec
		else
			for ((i = 1; i <= $N_PAN_DG; i++)); do
				group_name=`printf "$DG_NAME" $i`
				pan_rules_sec "$group_name" $i
			done
		fi
	else
		pan_rules_sec
	fi

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
