---------------------
--- Set Variables ---
---------------------
--- WIFI CONFIGURATION ---
WIFI_SSID = "PUT_YOUR_SSID"
WIFI_PASSWORD = "PUT_YOUR_PASSWORD"
WIFI_SIGNAL_MODE = wifi.PHYMODE_N
--- IP CONFIGURATION (Leave blank to use DHCP) ---
ESP8266_IP=""
ESP8266_NETMASK=""
ESP8266_GATEWAY=""
-- LED PINOUT CONFIGURATION
blue_led = 4 --GPIO2 onboard blue led
gpio.mode(blue_led, gpio.OUTPUT) -- Initialise the pin
gpio.write(blue_led, gpio.HIGH)

-----------------------------
--  NETWORK FUNCTIONALITY  --
-----------------------------

--- Connect to the wifi network
function connectToWiFiAP()
    if wifi.sta.status()~=wifi.STA_GOTIP then
        print("Connnecting to Wi-Fi AP...")
        print("Old IP: ")
        print(wifi.sta.getip())
        wifi.setmode(wifi.STATION)
        wifi.setphymode(WIFI_SIGNAL_MODE)
        wifi.sta.config(WIFI_SSID, WIFI_PASSWORD)
        --register callback
        wifi.sta.eventMonReg(wifi.STA_IDLE, function() print("STATION_IDLE") end)
        wifi.sta.eventMonReg(wifi.STA_CONNECTING, function() print("STATION_CONNECTING") end)
        wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function() print("STATION_WRONG_PASSWORD") end)
        wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function() print("STATION_NO_AP_FOUND") end)
        wifi.sta.eventMonReg(wifi.STA_FAIL, function() print("STATION_CONNECT_FAIL") end)
        wifi.sta.eventMonReg(wifi.STA_GOTIP, function() print("STATION_GOT_IP") end)
        --start WiFi event monitor with default interval
        wifi.sta.eventMonStart()
        wifi.sta.connect()
        if ESP8266_IP ~= "" then
         wifi.sta.setip({ip=ESP8266_IP,netmask=ESP8266_NETMASK,gateway=ESP8266_GATEWAY})
        end
        print("New IP: ")
        print(wifi.sta.getip()) 
    else
        print("Connected to Wi-Fi AP. The IP is ",wifi.sta.getip())
    end
end  -- END connectToWiFiAP()

----------------------------
--  SERVER FUNCTIONALITY  --
----------------------------

-- Receiver function read the request, process the data, and send a response to client
function receiver(conn,request)
-- Read request
    print(request) 
    local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
    if(method == nil)then
        _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
    end
    local _GET = {}
    if (vars ~= nil)then
        for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
            _GET[k] = v
        end
    end
-- Change LED status
    local _on,_off = "",""
        if(_GET.pin == "ON")then
              gpio.write(blue_led, gpio.LOW);
        elseif(_GET.pin == "OFF")then
              gpio.write(blue_led, gpio.HIGH);
        end
-- if you're sending back HTML over HTTP you'll want something like this instead
    local response = {"HTTP/1.0 200 OK\r\nServer: NodeMCU on ESP8266\r\nContent-Type: text/html\r\n\r\n"}
    response[#response + 1] = "<h1> ESP8266 Web Server</h1>"
    response[#response + 1] = "<p>GPIO2 <a href=\"?pin=ON\"><button>ON</button></a>&nbsp;<a href=\"?pin=OFF\"><button>OFF</button></a></p>"
    response[#response + 1] = "<p> Time: " .. showTimeDate() .. "</p>"
-- sends and removes the first element from the 'response' table
    local function send(localSocket)
        if #response > 0 then
          localSocket:send(table.remove(response, 1))
        else
          localSocket:close()
          response = nil
        end
    end --END send(localSocket)
-- triggers the send() function again once the first chunk of data was sent
  conn:on("sent", send)
  send(conn)
end --END receiver(conn,request)

------------------------------
--  TIME FUNCTIONALITY  --
------------------------------
-- sync the ESP8266 Real Time Clock (RTC) to an NTP server and display the time and date from the ESP8266 RTC. Retry 3 times if error occurs
function syncTime()
    print("Contacting NTP server...\n")
    attemp = 1
    max_ret = 3
    function sntpSuccess(sec, usec, server, info)
            print("SUCCESS: sync in attemp ",attemp, sec, usec, server)
            showTimeDate()
    end
    function sntpFailure(err_type)
           print("ERROR: type->",err_type, " in attemp ", attemp, " .Retrying...")
           attemp=attemp+1
           if attemp<=3
           then
           sntp.sync(nil,sntpSuccess,sntpFailure,0)
           end
    end
    sntp.sync(nil,sntpSuccess,sntpFailure,0)
end --END syncTime()

-- Show time and date formated in the console
function showTimeDate()
    function timeAdjustTZ (secs, tz) secs=secs+(tz*3600) return secs end -- function to adjust the time to the correct time zone
    tm = rtctime.epoch2cal(timeAdjustTZ (rtctime.get(),1))
    print(string.format("%02d/%02d/%04d %02d:%02d:%02d", tm["day"], tm["mon"], tm["year"], tm["hour"], tm["min"], tm["sec"]))
    return string.format("%02d/%02d/%04d %02d:%02d:%02d", tm["day"], tm["mon"], tm["year"], tm["hour"], tm["min"], tm["sec"])
end  --END showTimeDate()

--------------------------
--  MAIN CODE EXECUTION --
--------------------------
--Network connection
connectToWiFiAP()
--Time sync
syncTime()
-- Init server
srv=net.createServer(net.TCP)
srv:listen(80, function(conn) conn:on("receive", receiver) end)
