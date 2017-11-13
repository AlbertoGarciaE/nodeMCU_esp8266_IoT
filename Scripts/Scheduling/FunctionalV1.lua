-- TaskSchedule.lua functions ---
local RF_DEFAULT = 0  --RF_CAL depends on init data from byte 108
local RF_CAL = 1  --RF_CAL enabled causes large current drain after wake 170mA
local RF_NO_CAL = 2  --RF_CAL disabled, small current drain after wake 75mA
local RF_DISABLED = 4  --RF disabled, smallest current drain after wake 15mA

local ONE_SECOND = 1000000;
-- ONE_SECOND = 1000;  -- for testing
local ONE_HOUR =  3595*ONE_SECOND;  --120 seconds per day faster to be sure we are not late
--ONE_HOUR =  2000000;
--= 60 * 60 * ONE_SECOND;  -- number of microseconds (for deep_sleep of one hour)

local _statusDef = {
        RESET=0,
        COUNTING=1,
        CHECK=2,
        WORK=3
}

local _rtcMem = {
        markerFlag=0,
        counter=24,
        status =_statusDef.RESET 
}

local _sleepTime;

local _wakeup = {hour=0, minute=0, second=0}
local _actualTime = { seconds=0, useconds=0}
local SCHD_TASK_MEM = 65
local MARKFLAG_RESETED=85


-- Constructor
function dailyTask(hours,minutes)
        _wakeup.hour = hours
        _wakeup.minute=minutes
        _wakeup.second = 0
end  -- END dailyTask()

local switch = {

        [_statusDef.RESET] = function ()
					_rtcMem.markerFlag = MARKFLAG_RESETED
					_rtcMem.counter = 0
					_sleepTime=1
					_rtcMem.status = _statusDef.CHECK
					rtcmem.write32(SCHD_TASK_MEM, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
					print_rtcMem("RESET  ")
					rtctime.dsleep(_sleepTime, RF_DISABLED)
                end,

        [_statusDef.COUNTING] = function()
					if (_rtcMem.counter==0) then
							_sleepTime=1
							_rtcMem.status=_statusDef.CHECK
							rtcmem.write32(SCHD_TASK_MEM, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
							print_rtcMem("COUNTING ZERO ")
							rtctime.dsleep(_sleepTime, RF_DISABLED)
					else 
							_rtcMem.counter=_rtcMem.counter - 1
							_sleepTime=ONE_HOUR
							rtcmem.write32(SCHD_TASK_MEM, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
							print_rtcMem("COUNTING DOWN  ")
							rtctime.dsleep(_sleepTime, RF_DISABLED)
					end
					
					local exitSec, exitUsec = rtctime.get()
					print("This call took ")
					print(exitSec - entrySec)
					print(" seconds ")
					print(exitUsec - entryUsec)
					print(" microseconds \n")
                end,

        [_statusDef.CHECK] = function ()
					_secondsToWait = adjustTime()
					if (_secondsToWait>120) then
							if (_secondsToWait>3600) then
									_rtcMem.counter = _secondsToWait/3600
									_rtcMem.status=_statusDef.COUNTING
									_sleepTime=ONE_HOUR
									rtcmem.write32(SCHD_TASK_MEM, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
									print_rtcMem("CHECK AND SLEEP YET ")
									rtctime.dsleep(_sleepTime, RF_DISABLED)
							else
									_rtcMem.status=_statusDef.WORK
									_sleepTime=_secondsToWait*ONE_SECOND
									rtcmem.write32(SCHD_TASK_MEM, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
									print_rtcMem("CHECK AND WAIT FOR WORK  ")
									rtctime.dsleep(_sleepTime, RF_CAL)
							end
					else 
							_rtcMem.status=_statusDef.WORK
							_sleepTime=1
							rtcmem.write32(SCHD_TASK_MEM, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
							print_rtcMem("CHECK LESS 120 SECONDS  ")
							rtctime.dsleep(_sleepTime, RF_CAL)
					end
                end,

        [_statusDef.WORK] = function() print("SWITCH WORK CASE\n") end
}

function sleepOneDay() 

        local _secondsToWait;
		
		local entrySec, entryUsec = rtctime.get()

        _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status=rtcmem.read32(SCHD_TASK_MEM, 3)
        if ( _rtcMem.markerFlag~=MARKFLAG_RESETED) then _rtcMem.status=_statusDef.RESET end;
        print_rtcMem("SleepOneDay   ") 
        switch [_rtcMem.status]()
		
end -- END sleepOneDay()

function adjustTime()
        local _currentSecs,_wakeUpSecs;
        local _seconds;

		_actualTime.seconds, _actualTime.useconds = rtctime.get();
		_currentSecs = _actualTime.seconds;
		_wakeUpSecs = ((_wakeup.hour * 60) + _wakeup.minute) * 60 + _wakeup.second;
		_seconds=(_wakeUpSecs-_currentSecs>0) and (_wakeUpSecs-_currentSecs) or (_wakeUpSecs-_currentSecs+(24*3600));
		print("Adjust time to wait for executing the task \n");
		print("_currentSecs: %3d \n",_currentSecs);
		print("_wakeUpSecs: %3d \n",_wakeUpSecs);
		print("_secondsToGo: %3d \n",_seconds);
		return _seconds;
end -- END adjustTime()

function print_rtcMem(place) 
        print(place);
        print(" ");
        print("rtc marker: ");
        print(_rtcMem.markerFlag);
        print("Status: ");
        print(_rtcMem.status);
        print(", markerFlag: ");
        print(_rtcMem.markerFlag);
        print(", counter: ");
        print(_rtcMem.counter);
        print(", sleepTime: ");
        print(_sleepTime);
        print("\n");
end -- END print_rtcMem()


function backToSleep() 
        _rtcMem.counter = 23;     --24 hours to sleep
        _sleepTime=ONE_HOUR;
        _rtcMem.status=COUNTING;
        rtcmem.write32(SCHD_TASK_MEM, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status);
        print_rtcMem("WORK  ");
        rtctime.dsleep(_sleepTime, RF_DISABLED);
end -- END backToSleep()


-- END TaskSchedule.lua functions ---

-- WebServer_LedsOnOff_Time_V2.lua functions ---

---------------------
--- Set Variables ---
---------------------
--- WIFI CONFIGURATION ---
WIFI_SSID = "MOVISTAR_S1L"
WIFI_PASSWORD = "M0V1ST4R_S1L"
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
            mainScript()
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
-- END WebServer_LedsOnOff_Time_V2.lua functions --

-- SendMailSMTP.lua functions --

-- END SendMailSMTP.lua functions --

function mainScript()
--Set time to do the task
dailyTask(12, 45);
-- start checking flow until task time is off
sleepOneDay();
------------------ put the code for your daily task here -------------------------------
print("............ W O R K ...put the code for your daily task here....................\n");
gpio.write(blue_led, gpio.LOW);

----------------------- end of code for your daily task-------------------------------
-- and back to sleep once daily code is done --
backToSleep();

end
--------------------------
--  MAIN CODE EXECUTION --
--------------------------
--Network connection
gpio.write(blue_led, gpio.HIGH);
connectToWiFiAP()
--Time sync
syncTime()
	

------------------------------
--  END MAIN CODE EXECUTION --
------------------------------



