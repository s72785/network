#!/usr/bin/env bash

{% macro uci_network_mgmt(ifname) -%}
set network.mgmt=interface
set network.mgmt.ifname={{ ifname }}
set network.mgmt.proto=static
set network.mgmt.ipaddr={{ pillar['hosts-inet']['mgmt'][hostname] }}
set network.mgmt.netmask=255.255.255.0
set network.mgmt.gateway={{ pillar['hosts-inet']['mgmt']['mgmt-gw'] }}
set network.mgmt.ip6addr={{ pillar['hosts-inet6']['mgmt'][hostname] }}/64
set network.mgmt.ip6gw={{ pillar['hosts-inet6']['mgmt']['mgmt-gw'] }}
delete network.mgmt.dns
add_list network.mgmt.dns={{ pillar['hosts-inet']['core']['upstream1'] }}
add_list network.mgmt.dns={{ pillar['hosts-inet6']['core']['upstream1'] }}
add_list network.mgmt.dns={{ pillar['hosts-inet']['core']['upstream2'] }}
add_list network.mgmt.dns={{ pillar['hosts-inet6']['core']['upstream2'] }}
{%- endmacro %}

{%- if conf.get('firstboot') %}
ssh-keygen -R 192.168.1.1

ssh root@192.168.1.1 \
    "ash -e -x" <<__SSH__
{%- else %}
ssh root@{{ pillar['hosts-inet']['mgmt'][hostname] }} \
    "ash -e -x" <<__SSH__
{%- endif %}

# Set root password
echo -e '{{ conf['password'] }}\n{{ conf['password'] }}' | passwd

# add ssh pubkey
echo "{{ pillar['ssh']['pubkey'] }}" > /etc/dropbear/authorized_keys

# System configuration
uci batch <<__UCI__
set system.@system[0].hostname={{ hostname }}
set dhcp.@dnsmasq[0].enabled=0

delete network.globals.ula_prefix
delete network.lan
delete network.wan
delete network.wan6
delete wireless.default_radio0
delete wireless.default_radio1

{%- set bridges = {} %}
{%- if conf.get('lan-access') %}
{%-   do bridges.__setitem__(conf['lan-access'], True) %}
{%- endif %}
{%- for path, radio in conf['radios'].items() %}
{%-   for ssid, ssidconf in radio['ssids'].items() %}
{%-     do bridges.__setitem__(ssidconf['net'], True) %}
{%-   endfor %}
{%- endfor %}

{%- if conf['model'] == 'TL-WDR4300' %}
{# These models have a shared Ethernet chip for LAN/WAN and therefore need switching #}
set network.@switch[0]=switch
set network.@switch[0].reset=1
set network.@switch[0].enable=1
set network.@switch[0].enable_vlan=1
set network.@switch[0].name=switch0
set network.@switch_vlan[0]=switch_vlan
set network.@switch_vlan[0].device='switch0'
set network.@switch_vlan[0].vlan='1'
set network.@switch_vlan[0].ports='0t 1t'
set network.@switch_vlan[0].comment='mgmt'
{%    set switchnum = 1 %}
{%-   for net in bridges.keys() %}
set network.@switch_vlan[{{ switchnum }}]=switch_vlan
set network.@switch_vlan[{{ switchnum }}].device='switch0'
set network.@switch_vlan[{{ switchnum }}].vlan='{{ pillar['vlans'][net] }}'
{%-     if conf.get('lan-access') == net %}
set network.@switch_vlan[{{ switchnum }}].ports='0t 1t 2 3 4 5'
{%-     else %}
set network.@switch_vlan[{{ switchnum }}].ports='0t 1t'
{%-     endif %}
set network.@switch_vlan[{{ switchnum }}].comment='{{ net }}'
{%    set switchnum = switchnum + 1 %}
{%- endfor %}

{{ uci_network_mgmt('eth0.1') }}

{%- for net in bridges.keys() %}
set network.{{ net }}=interface
set network.{{ net }}.type=bridge
set network.{{ net }}.proto=static
set network.{{ net }}.ifname='eth0.{{ pillar['vlans'][net] }}'
{%- endfor %}

{%- elif conf['model'] == 'TL-WR1043ND' %}
{# These models have a shared Ethernet chip with separate CPU ports for LAN/WAN and therefore need switching #}
set network.@switch[0]=switch
set network.@switch[0].reset=1
set network.@switch[0].enable=1
set network.@switch[0].enable_vlan=1
set network.@switch[0].name=switch0
set network.@switch_vlan[0]=switch_vlan
set network.@switch_vlan[0].device='switch0'
set network.@switch_vlan[0].vlan='1'
set network.@switch_vlan[0].ports='5t 6t'
set network.@switch_vlan[0].comment='mgmt'
{%    set switchnum = 1 %}
{%-   for net in bridges.keys() %}
set network.@switch_vlan[{{ switchnum }}]=switch_vlan
set network.@switch_vlan[{{ switchnum }}].device='switch0'
set network.@switch_vlan[{{ switchnum }}].vlan='{{ pillar['vlans'][net] }}'
# 0: eth1; 1-4: LAN ports; 5: WAN port; 6: eth0
{%-     if conf.get('lan-access') == net %}
set network.@switch_vlan[{{ switchnum }}].ports='0 1 2 3 4 5t'
{%-     else %}
set network.@switch_vlan[{{ switchnum }}].ports='5t 6t'
{%-     endif %}
set network.@switch_vlan[{{ switchnum }}].comment='{{ net }}'
{%    set switchnum = switchnum + 1 %}
{%- endfor %}

{{ uci_network_mgmt('eth0.1') }}

{%- for net in bridges.keys() %}
set network.{{ net }}=interface
set network.{{ net }}.type=bridge
set network.{{ net }}.proto=static
{%-   if conf.get('lan-access') == net %}
set network.{{ net }}.ifname='eth1'
{%-     else %}
set network.{{ net }}.ifname='eth0.{{ pillar['vlans'][net] }}'
{%-   endif %}
{%- endfor %}

{%- elif conf['model'] == 'TL-Archer-C7v2' %}
{# These models have a shared Ethernet chip with separate CPU ports for LAN/WAN and therefore need switching #}
set network.@switch[0]=switch
set network.@switch[0].reset=1
set network.@switch[0].enable=1
set network.@switch[0].enable_vlan=1
set network.@switch[0].name=switch0
set network.@switch_vlan[0]=switch_vlan
set network.@switch_vlan[0].device='switch0'
set network.@switch_vlan[0].vlan='1'
set network.@switch_vlan[0].ports='1t 6t'
set network.@switch_vlan[0].comment='mgmt'
{%    set switchnum = 1 %}
{%-   for net in bridges.keys() %}
set network.@switch_vlan[{{ switchnum }}]=switch_vlan
set network.@switch_vlan[{{ switchnum }}].device='switch0'
set network.@switch_vlan[{{ switchnum }}].vlan='{{ pillar['vlans'][net] }}'
# 0: eth1; 1: WAN port; 2-5: LAN ports; 6: eth0
{%-     if conf.get('lan-access') == net %}
set network.@switch_vlan[{{ switchnum }}].ports='0 1t 2 3 4 5'
{%-     else %}
set network.@switch_vlan[{{ switchnum }}].ports='1t 6t'
{%-     endif %}
set network.@switch_vlan[{{ switchnum }}].comment='{{ net }}'
{%    set switchnum = switchnum + 1 %}
{%- endfor %}

{{ uci_network_mgmt('eth0.1') }}

{%- for net in bridges.keys() %}
set network.{{ net }}=interface
set network.{{ net }}.type=bridge
set network.{{ net }}.proto=static
{%-   if conf.get('lan-access') == net %}
set network.{{ net }}.ifname='eth1'
{%-     else %}
set network.{{ net }}.ifname='eth0.{{ pillar['vlans'][net] }}'
{%-   endif %}
{%- endfor %}

{%- elif conf['model'] == 'TL-WR841Nv8' %}
{# Like v9 but with eth0/1 switched #}
set network.@switch[0].reset=1
set network.@switch[0].enable=1
set network.@switch[0].enable_vlan=0

{{ uci_network_mgmt('eth0.1') }}

{%-   for net in bridges.keys() %}

set network.{{ net }}=interface
set network.{{ net }}.type=bridge
set network.{{ net }}.proto=static
{# Add WAN VLAN to bridge #}
{%-     set ports = ['eth0.' ~ pillar['vlans'][net]] %}
{# Add LAN ports to bridge #}
{%-     if conf.get('lan-access') == net %}
{%-       do ports.append('eth1') %}
{%-     endif %}

set network.{{ net }}.ifname='{{ ' '.join(ports) }}'
{%-   endfor %}

{%- elif conf['model'] == 'TL-WA901NDv3' %}
{# Only eth0 exists, no switch #}

{{ uci_network_mgmt('eth0.1') }}

{%-   for net in bridges.keys() %}

set network.{{ net }}=interface
set network.{{ net }}.type=bridge
set network.{{ net }}.proto=static
{# Add WAN VLAN to bridge #}
set network.{{ net }}.ifname='{{ 'eth0.' ~ pillar['vlans'][net] }}'
{%-   endfor %}

{%- elif conf['model'] == 'DIR-615H1' %}
delete network.lan_dev
delete network.wan_dev
{# switch is cpu port 6, wan:cpu port 4, lan port 1 is cpu port 3, lan port 2 is 2 etc #}
set network.@switch[0]=switch
set network.@switch[0].reset=1
set network.@switch[0].enable=1
set network.@switch[0].enable_vlan=1
set network.@switch[0].name=switch0
set network.@switch_vlan[0]=switch_vlan
set network.@switch_vlan[0].device='switch0'
set network.@switch_vlan[0].vlan='1'
set network.@switch_vlan[0].ports='4t 6t'
set network.@switch_vlan[0].comment='mgmt'
{%    set switchnum = 1 %}
{%-   for net in bridges.keys() %}
set network.@switch_vlan[{{ switchnum }}]=switch_vlan
set network.@switch_vlan[{{ switchnum }}].device='switch0'
set network.@switch_vlan[{{ switchnum }}].vlan='{{ pillar['vlans'][net] }}'
{%-     if conf.get('lan-access') == net %}
set network.@switch_vlan[{{ switchnum }}].ports='0 1 2 3 4t 6t'
{%-     else %}
set network.@switch_vlan[{{ switchnum }}].ports='4t 6t'
{%-     endif %}
set network.@switch_vlan[{{ switchnum }}].comment='{{ net }}'
{%    set switchnum = switchnum + 1 %}
{%- endfor %}

{{ uci_network_mgmt('eth0.1') }}

{%- for net in bridges.keys() %}
set network.{{ net }}=interface
set network.{{ net }}.type=bridge
set network.{{ net }}.proto=static
#TODO: this should consider lan-access
set network.{{ net }}.ifname='eth0.{{ pillar['vlans'][net] }}'
{%- endfor %}

{%- else %}
{# All other models may have separate Ethernet chips for LAN/WAN #}
set network.@switch[0].reset=1
set network.@switch[0].enable=1
set network.@switch[0].enable_vlan=0

{{ uci_network_mgmt('eth1.1') }}

{%-   for net in bridges.keys() %}

set network.{{ net }}=interface
set network.{{ net }}.type=bridge
set network.{{ net }}.proto=static
{# Add WAN VLAN to bridge #}
{%-     set ports = ['eth1.' ~ pillar['vlans'][net]] %}
{# Add LAN ports to bridge #}
{%-     if conf.get('lan-access') == net %}
{%-       do ports.append('eth0') %}
{%-     endif %}

set network.{{ net }}.ifname='{{ ' '.join(ports) }}'
{%-   endfor %}

{%- endif %}

{%- set radionum = 0 %}
{%- set ifnum = 0 %}
{%- for path, radio in conf['radios'].items() %}
set wireless.radio{{ radionum }}=wifi-device
set wireless.radio{{ radionum }}.type=mac80211
set wireless.radio{{ radionum }}.country=DE
set wireless.radio{{ radionum }}.channel={{ radio['channel'] }}
set wireless.radio{{ radionum }}.path={{ path }}
set wireless.radio{{ radionum }}.hwmode={{ radio.get('hwmode') or '11n' }}
set wireless.radio{{ radionum }}.htmode={{ radio.get('htmode') or 'HT20' }}
set wireless.radio{{ radionum }}.noscan=1
delete wireless.radio{{ radionum }}.disabled

{%-   for ssid, ssidconf in radio['ssids'].items() %}
{%-     set ifnum = ifnum + loop.index0 %}
set wireless.wifi{{ ifnum }}=wifi-iface
set wireless.wifi{{ ifnum }}.device=radio{{ radionum }}
set wireless.wifi{{ ifnum }}.ssid='{{ ssid }}'
set wireless.wifi{{ ifnum }}.mode=ap
set wireless.wifi{{ ifnum }}.network={{ ssidconf['net'] }}
{%-     if ssidconf.get('psk') %}
set wireless.wifi{{ ifnum }}.encryption=psk2
set wireless.wifi{{ ifnum }}.key='{{ ssidconf['psk'] }}'
{%-     else %}
set wireless.wifi{{ ifnum }}.encryption=none
{%-     endif %}
set wireless.wifi{{ ifnum }}.mcast_rate=18000

{%-   endfor %}

{%-   set ifnum = ifnum + radio['ssids'].items()|length %}
{%-   set radionum = radionum + 1 %}
{%- endfor %}

commit
__UCI__

# Cronjob that makes sure WiFi is only visible when server with all
# the gateways is reachable
cat >/etc/crontabs/root <<__CRON__
* * * * *	/usr/sbin/wifi-on-link.sh
__CRON__
cat >/usr/sbin/wifi-on-link.sh <<__SH__
#!/bin/sh

if (ping -c 1 -W 3 {{ pillar['hosts-inet']['mgmt']['server1'] }}) ; then
        REACHABLE=y
else
        REACHABLE=n
fi

if [ "\\\$(cat /sys/class/net/wlan0/operstate)" == "up" ] ; then
        UP=y
else
        UP=n
fi

[ \\\$REACHABLE = y ] && [ \\\$UP = n ] && wifi up
[ \\\$REACHABLE = n ] && [ \\\$UP = y ] && wifi down

exit 0
__SH__
chmod a+rx /usr/sbin/wifi-on-link.sh
/etc/init.d/cron restart

{%- if conf.get('firstboot') %}
reboot
{%- endif %}

__SSH__

echo "Base configuration done \\o/"
echo "Later run: `dirname $0`/ap_install_collectd.sh {{ pillar['hosts-inet']['mgmt'][hostname] }}"
