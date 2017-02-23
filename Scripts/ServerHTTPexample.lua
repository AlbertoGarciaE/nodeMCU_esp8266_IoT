print(wifi.sta.getip())
-----------------------------------------------
--- Set Variables ---
-----------------------------------------------
--- WIFI CONFIGURATION ---
WIFI_SSID = "***REMOVED***"
WIFI_PASSWORD = "***REMOVED***"
WIFI_SIGNAL_MODE = wifi.PHYMODE_N

--- IP CONFIG (Leave blank to use DHCP) ---
ESP8266_IP=""
ESP8266_NETMASK=""
ESP8266_GATEWAY=""
-----------------------------------------------

--- Connect to the wifi network ---
wifi.setmode(wifi.STATION) 
wifi.setphymode(WIFI_SIGNAL_MODE)
wifi.sta.config(WIFI_SSID, WIFI_PASSWORD) 
wifi.sta.connect()

if ESP8266_IP ~= "" then
 wifi.sta.setip({ip=ESP8266_IP,netmask=ESP8266_NETMASK,gateway=ESP8266_GATEWAY})
end
-----------------------------------------------

--- Check the IP Address ---
print(wifi.sta.getip())

-- a simple http server
srv=net.createServer(net.TCP) 
srv:listen(80,function(conn) 
    conn:on("receive",function(conn,payload) 
    print(payload) 
    conn:send("<h1> Hello, NodeMcu. This is a IoT server done by Alberto García</h1>")
    end) 
end)