:nothing
# NB: `:nothing` above allows pasting this script into a CLI

# -------------------------------------------------------------------
# Update Hurricane Electric IPv6 Tunnel Client endpoints
# -------------------------------------------------------------------

:local HEtunnelinterface "tun-he"
:local HEtunnelid "tunnel-id-num"
:local HEuserid "he-user"
:local HEUpdatekey "update-key"
:local HEupdatehost "ipv4.tunnelbroker.net"
:local HEtunnelinfohost "tunnelbroker.net"
:local HEupdatepath "/nic/update"
:local WANinterface "WAN"
:local outputfile ("HE-" . $HEtunnelid . ".txt")

# Get WAN interface IP address
:local WANipv4addr [/ip address get [/ip address find interface=$WANinterface] address];
:set WANipv4addr [:pick [:tostr $WANipv4addr] 0 [:find [:tostr $WANipv4addr] "/"]];

# Error out if we can't find WAN address
:if ([:len $WANipv4addr] = 0) do={
  :log warning ("Could not get IP for interface " . $WANinterface);
  :error ("Script error: Could not get IP for WAN interface " . $WANinterface);
}

# Get current tunnel interface ip address
:local tunLocalAddr [/interface 6to4 get $HEtunnelinterface local-address];

:if ([:len $tunLocalAddr] = 0) do={
   :log warning ("Could not get IP for interface " . $HEtunnelinterface);
   :error ("Script error: Could not get IP for interface " . $HEtunnelinterface);
}

# Update our interface local-address
/interface 6to4 {
  :if ([get ($HEtunnelinterface) local-address] != $WANipv4addr) do={
    :log debug ("Updating " . $HEtunnelinterface . " local-address with new IP " . $WANipv4addr . "...");
    set ($HEtunnelinterface) local-address=$WANipv4addr;
  }
} 

# Check if out interface is out of date
:set tunLocalAddr [/interface 6to4 get $HEtunnelinterface local-address];
:if ($WANipv4addr = $tunLocalAddr) do={
  # Check and update HE's side
  # Doc: https://forums.he.net/index.php?msg=18553
  # E.g. request URL https://he-user:update-key@tunnelbroker.net/tunnelInfo.php?tid=tunnel-id-num
  :local getTunInfoURL ("https://" . $HEuserid . ":" . $HEUpdatekey . "@" . \
      $HEtunnelinfohost . "/tunnelInfo.php?tid=" . $HEtunnelid);

  # Send update to HE
  # Response should be ~850 chars including headers; under the 4kb variable limit of RouterOS
  :local getTunInfoURLResult [/tool fetch mode=https url=$getTunInfoURL as-value output=user];
  :if ($getTunInfoURLResult->"status" = "finished") do={
     :local body ($getTunInfoURLResult->"data")
     # Check result body for our ip address
     # HE address just updated above
     :local clientv4XML ("<clientv4>" . $WANipv4addr . "</clientv4>");

     :put ("XML to match against: " . $getTunInfoURLResult->"data");
     :put ("String to match: " . $clientv4XML);
     :local XMLMatch [:find $body $clientv4XML -1];

     :if ($XMLMatch) do={
       :put ("Client IPv4 Address: " . $WANipv4addr);
       :return;
     } else= {
       # Use API to update HE side with our wan address
       :put ("Need to update HE about our address" . $HEtunnelinterface . ":" . $WANipv4addr);

       # Now tell HE about the update
       :local htmlcontent;
       :put ("Updating IPv6 Tunnel " . $HEtunnelid . " Client IPv4 address to new IP " . $WANipv4addr . "...");

       # Doc: https://forums.he.net/index.php?topic=1994.0
       # e.g.: https://he-user:update-key@ipv4.tunnelbroker.net/nic/update?hostname=tunnel-id-num
       :local fetchurl ("https://" . $HEuserid . ":" . $HEUpdatekey . "@" . \
           $HEupdatehost . $HEupdatepath . \
           "?ipv4b=" . $WANipv4addr . \
           "&hostname=" . $HEtunnelid);

       # Send update
       /tool fetch mode=https url=$fetchurl dst-path=($outputfile);

       # Handle response from HE API
       :set htmlcontent [/file get $outputfile contents];
       /file remove $outputfile;
       :log info ("Tunnelbroker update resp: " . $htmlcontent);
      # End HE update API
     }
  }
} else={
  :log info "WAN IP on tunnel still not up to date";
}
