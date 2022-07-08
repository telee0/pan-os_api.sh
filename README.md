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


$ ./pan.sh -h
$ ./pan.sh -f conf/pan-245.conf
$ ./clean.sh
