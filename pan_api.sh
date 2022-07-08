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
# API call for the key
#

get_api_key() {

	case "$1" in
		PA|PA1)
			pa="$PA"
			user="$USER"
			pass="$PASS"
			key="key"
			key_var="API_KEY"
			;;
		PA2)
			pa="$PA2"
			user="$USER2"
			pass="$PASS2"
			key="key2"
			key_var="API_KEY2"
			;;
	esac

	out_file="$L/$key$OUT_FILE"
	log_file="$L/$key$LOG_FILE"

	WGET="$wget --no-check-certificate --output-document=$out_file --append-output=$log_file"
	URL="https://$pa/api/?type=keygen&user=$user&password=$pass"

	$WGET "$URL"

	if [ -f $out_file ] && [ -s $out_file ]; then
		api_key="`xml_grep key $out_file --text_only | head -1`"
	else
		echo "$pa: API key not set. Please check $param_file for access details."
		return 1
	fi

	if [ "$api_key" = "" ]; then
		echo "$pa: API key not set. Please check $param_file for access details."
		return 1
	fi

	eval "${key_var}=\"\$api_key\""
}

# --------------------------------------------------------------------------------

echo

unset API_KEY
unset API_KEY1
unset API_KEY2
unset API_KEY3
unset API_KEY4

if [ -n "$PA" ]; then
	echo "PA/PA1 = $PA (main device to be configured)"
	get_api_key PA1
else
	echo 'Target device $PA not specified' 
	exit 1
fi

if [ -z "$API_KEY" ]; then
	exit 1
fi

if [ -n "$PA2" ]; then
	echo "PA2 = $PA2 (second device as VPN peer)"
	get_api_key PA2
fi

echo

#
# End
#
