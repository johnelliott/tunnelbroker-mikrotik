# down script
# Check if we have the interface disabled
:local HEtunnelinterface "sit1";
if ([/interface 6to4 get $HEtunnelinterface disabled]) do={
  :log info ("Tunnel interface " . $HEtunnelinterface . " disabled won't update"); :return
}
/system scheduler add disabled=no interval=10s name=check-tunnelbroker-ip on-event=tunnelbroker-update start-time=startup
