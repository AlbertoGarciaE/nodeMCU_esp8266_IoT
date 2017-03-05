---------------------
--- Set Variables ---
---------------------
--- WIFI CONFIGURATION ---
WIFI_SSID = "***REMOVED***"
WIFI_PASSWORD = "***REMOVED***"
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
	print("Connnecting to Wi-Fi AP...")
	print("Old IP: ")
	print(wifi.sta.getip())
	wifi.setmode(wifi.STATION) 
	wifi.setphymode(WIFI_SIGNAL_MODE)
	wifi.sta.config(WIFI_SSID, WIFI_PASSWORD) 
	wifi.sta.connect()
	if ESP8266_IP ~= "" then
	 wifi.sta.setip({ip=ESP8266_IP,netmask=ESP8266_NETMASK,gateway=ESP8266_GATEWAY})
	end
	print("New IP: ")
	print(wifi.sta.getip())
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
--  RTC TIME FUNCTIONALITY  --
------------------------------

-- returns the hour, minute, second, day, month and year from the ESP8266 RTC seconds count (corrected to local time by tz)
function getRTCtime(tz)
   function isleapyear(y) if ((y%4)==0) or (((y%100)==0) and ((y%400)==0)) == true then return 2 else return 1 end end
   function daysperyear(y) if isleapyear(y)==2 then return 366 else return 365 end end           
   local monthtable = {{31,28,31,30,31,30,31,31,30,31,30,31},{31,29,31,30,31,30,31,31,30,31,30,31}} -- days in each month
   local secs=rtctime.get()
   local d=secs/86400
   local y=1970   
   local m=1
   while (d>=daysperyear(y)) do d=d-daysperyear(y) y=y+1 end   -- subtract the number of seconds in a year
   while (d>=monthtable[isleapyear(y)][m]) do d=d-monthtable[isleapyear(y)][m] m=m+1 end -- subtract the number of days in a month
   secs=secs-1104494400-1104494400+(tz*3600) -- convert from NTP to Unix (01/01/1900 to 01/01/1970)   
   return (secs%86400)/3600,(secs%3600)/60,secs%60,m,d+1,y   --hour, minute, second, month, day, year
end  --END getRTCtime()

-- Show time and date formated in the console
function showTimeDate()
	timeZone = 1 -- time zone +1 for Spain
	hour, minute, second, day, month, year = 0
	-- get the hour, minute, second, day, month and year from the ESP8266 RTC
	hour,minute,second,month,day,year=getRTCtime(timeZone)
	if year ~= 0 then
		-- format and print the hour, minute second, month, day and year retrieved from the ESP8266 RTC
		print(string.format("%02d:%02d:%02d  %02d/%02d/%04d",hour,minute,second,month,day,year))
		--print(string.format("%02d:%02d:%02d  %02d/%02d/%04d",getRTCtime(timeZone)))    
	else
		print("Unable to get time and date from the NTP server.")
	end
end  --END showTimeDate()

--------------------------
--  MAIN CODE EXECUTION --
--------------------------

connectToWiFiAP()
-- sync the ESP8266 Real Time Clock (RTC) to an NTP server
-- retrieve and display the time and date from the ESP8266 RTC
print("Contacting NTP server...\n")
sntp.sync(nil, nil, nil, 0)
tmr.alarm(0,500,0,showTimeDate())
-- Init server
srv=net.createServer(net.TCP)
srv:listen(80, function(conn) conn:on("receive", receiver) end)
