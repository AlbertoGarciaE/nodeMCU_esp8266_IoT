-- Config AP
wifi.setmode(wifi.SOFTAP)
cfg={}
cfg.ssid="myssid"
cfg.pwd="mypassword"
wifi.ap.config(cfg)
print(wifi.ap.getip())

cfgip =
{
    ip="192.168.200.1",
    netmask="255.255.255.0",
    gateway="192.168.200.1"
}
wifi.ap.setip(cfgip)

print(wifi.ap.getip())

dhcp_config ={}
dhcp_config.start = "192.168.200.100"
wifi.ap.dhcp.config(dhcp_config)
wifi.ap.dhcp.start()

-- Config led pinout
blue_led = 4 --GPIO2 onboard blue led
gpio.mode(blue_led, gpio.OUTPUT) -- Initialise the pin
gpio.write(blue_led, gpio.HIGH)

srv=net.createServer(net.TCP)
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

srv:listen(80, function(conn)
  conn:on("receive", receiver)
end)
