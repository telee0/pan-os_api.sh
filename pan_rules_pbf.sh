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
# PBF rules
#

pan_rules_pbf() {

	if [ -z "$N_RULES_PBF" ] || [ $N_RULES_PBF -le 0 ]; then
		return 0
	fi

	echo -en "\nPolicies > PBF ($N_RULES_PBF) "

	cat >> $CONFIG_DUMP <<-EOF
<pbf>
  <rules>
EOF

	local i; local j

	pre="pbf"

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
			xpath="xpath=/config/devices/entry[@name='$LHOST']/device-group/entry[@name='$dg']/$PBF_RULEBASE/pbf/rules"
		else
			xpath="xpath=/config/shared/$PBF_RULEBASE/pbf/rules"
        fi
    else
		xpath="xpath=/config/devices/entry[@name='$LHOST']/vsys/entry[@name='$VSYS']/rulebase/pbf/rules"
	fi

	echo "echo \"Adding rules $pre$seq ($N_RULES_PBF)..\"" >> $script_file
	echo $WGET \"$URL\" >> $script_file
	echo -n "type=config&action=set&key=$API_KEY&$xpath&element=" >> $xml_file

	echo "echo \"Deleting rules $pre$seq ($N_RULES_PBF)..\"" >> $clean_script_file
	echo $WGET_CLEAN \"$URL\" >> $clean_script_file
	echo -n "type=config&action=delete&key=$API_KEY&$xpath/entry[" >> $clean_xml_file

	rules=1

	for ((i = 0; i < 256; i++)); do
		for ((j = 0; j < 256; j++)); do
			if [ $rules -gt $N_RULES_PBF ]; then
				break 1
			fi

			rule_name=`printf "$PBF_NAME" $rules`
			source=`printf "$PBF_SOURCE" $i $j`

			element="
                <entry name='$rule_name'>
                  <action>
                    <forward>
                      <nexthop>
                        <ip-address>$PBF_NEXTHOP</ip-address>
                      </nexthop>
                      <egress-interface>$PBF_INTERFACE</egress-interface>
                    </forward>
                  </action>
                  <from>
                    <zone>
                      <member>$PBF_SRC_ZONE</member>
                    </zone>
                  </from>
                  <enforce-symmetric-return>
                    <enabled>no</enabled>
                  </enforce-symmetric-return>
                  <source>
                    <member>$source</member>
                  </source>
                  <destination>
                    <member>any</member>
                  </destination>
                  <source-user>
                    <member>any</member>
                  </source-user>
                  <application>
                    <member>any</member>
                  </application>
                  <service>
                    <member>any</member>
                  </service>
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
</pbf>
EOF

}  # pan_rules_pbf()

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

if [ -n "$N_RULES_PBF" ] && [ $N_RULES_PBF -gt 0 ]; then

	unset script_file

	if [ "$TARGET" = "PANORAMA" ]; then
		if [ -n "$PANORAMA_DEVICE_GROUP" ]; then
			pan_rules_pbf "$PANORAMA_DEVICE_GROUP"
		elif [ "$PBF_SHARED" = "Shared" ]; then
			pan_rules_pbf
		else
			for ((i = 1; i <= $N_PAN_DG; i++)); do
				group_name=`printf "$DG_NAME" $i`
				pan_rules_pbf "$group_name" $i
			done
		fi
	else
		pan_rules_pbf
	fi

	if [ -f "$script_file" ]; then
		CONFIG_ITEMS="$CONFIG_ITEMS $pre"
	fi
fi

#
# End
#
