# pan-os_api

Scripts to generate PAN XML config and apply it through REST API

Supported config as follows.

* Device > Local users
* Network > Interfaces > Ethernet   (with vsys, zone and vr assignment)
* Network > Interfaces > Loopback   (with vsys, zone and vr assignment)
* Network > Interfaces > Tunnel     (with vsys, zone and vr assignment)
* Network > Zones
* Network > IKE Gateways
* Network > IPSec Tunnels (with static routes through tunnels)
* Objects > Addresses
* Objects > Address Groups
* Objects > Services
* Objects > Service Groups
* Objects > Custom URL Category with url.txt
* Policies > Security
* Policies > NAT
* Policies > PBF
* Network > VR > Static Routes
* Network > VR > BGP peer groups x peers

* User-ID mapping

(Panorama only)
* Panorama > Device Groups
* Panorama > Templates

Features and Capacity, All PAN-OS Releases
https://loop.paloaltonetworks.com/docs/DOC-3950

<pre>
$ ./pan.sh -h

Usage: ./pan.sh [-h] [-c] [-f] param_file
 
 c: clean
 f: use config from param_file
 h: help

$ ./pan.sh -f conf/pan-245.conf 

param_file = conf/pan-245.conf

SCRIPT_HOME = /home/terence/pan-os_api

PA/PA1 = 192.168.1.245 (main device to be configured)
PA2 = 192.168.1.251 (second device as VPN peer)
192.168.1.251: API key not set. Please check conf/pan-245.conf for access details.

target = Panorama
conf/pan-245.conf: default template/stack Template-001.
conf/pan-245.conf: template has precedence over stack if both set.

Panorama > Device Groups (10) 
Panorama > Templates (1) 
Policies > Security (50) DG = DG-0001
Policies > Security (50) DG = DG-0002
Policies > Security (50) DG = DG-0003
Policies > Security (50) DG = DG-0004
Policies > Security (50) DG = DG-0005
Policies > Security (50) DG = DG-0006
Policies > Security (50) DG = DG-0007
Policies > Security (50) DG = DG-0008
Policies > Security (50) DG = DG-0009
Policies > Security (50) DG = DG-0010

Generating config.sh and xml/config.xml.. This takes a while.

Config scripts and data are saved under the job directory 8666

Please run 8666/config.sh or individual 8666/*.sh in proper order. (e.g. zones before interfaces)

$ cd 8666/
$ sh pan_dg.sh 
$ cd ..
$ ./clean.sh
</pre>
