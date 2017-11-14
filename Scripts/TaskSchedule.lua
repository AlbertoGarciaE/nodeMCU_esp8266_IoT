local RF_DEFAULT = 0,  --RF_CAL depends on init data from byte 108
local RF_CAL = 1,  --RF_CAL enabled causes large current drain after wake 170mA
local RF_NO_CAL = 2,  --RF_CAL disabled, small current drain after wake 75mA
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
        markerFlag=0;
        counter=24;
        status =_statusDef.RESET ;
}

local _resetPin;
local _sleepTime;

local _wakeup = {hour=0, minute=0, second=0};
local _actualTime = { seconds=0, useconds=0};



-- Set time to execute the task
function dailyTask(hours,minutes, reset_pin)
        _wakeup.hour = hours;
        _wakeup.minute=minutes;
        _wakeup.second = 0;
        _resetPin=reset_pin;
        if (_resetPin!=99) then pinMode(_resetPin,INPUT_PULLUP)end;
end  -- END dailyTask()

switch = {

        [_statusDef.RESET] = function ()
					_rtcMem.markerFlag = 85
					_rtcMem.counter = 0
					_sleepTime=1
					_rtcMem.status = _statusDef.CHECK
					rtcmem.write32(65, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
					print_rtcMem("RESET  ")
					rtctime.dsleep(_sleepTime, RF_DISABLED)
                end,

        [_statusDef.COUNTING] = function()
					if (_rtcMem.counter==0) then
							_sleepTime=1
							_rtcMem.status=_statusDef.CHECK
							rtcmem.write32(65, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
							print_rtcMem("COUNTING ZERO ")
							rtctime.dsleep(_sleepTime, RF_DISABLED)
					else 
							_rtcMem.counter--
							_sleepTime=ONE_HOUR
							rtcmem.write32(65, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
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
									rtcmem.write32(65, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
									print_rtcMem("CHECK AND SLEEP YET ")
									rtctime.dsleep(_sleepTime, RF_DISABLED)
							else
									_rtcMem.status=_statusDef.WORK
									_sleepTime=_secondsToWait*ONE_SECOND
									rtcmem.write32(65, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
									print_rtcMem("CHECK AND WAIT FOR WORK  ")
									rtctime.dsleep(_sleepTime, RF_CAL)
							end
					else 
							_rtcMem.status=_statusDef.WORK
							_sleepTime=1
							rtcmem.write32(65, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status)
							print_rtcMem("CHECK LESS 120 SECONDS  ")
							rtctime.dsleep(_sleepTime, RF_CAL)
					end
                end,

        [_statusDef.WORK] = function() print("SWITCH WORK CASE\n") end
}

function sleepOneDay() 

        local _secondsToWait;
		
		local entrySec, entryUsec = rtctime.get()

        _rtcMem=rtcmem.read32(65, 3);
        if ((_resetPin!=99 && digitalRead(_resetPin)==0 )|| _rtcMem.markerFlag!=85) then _rtcMem.status=RESET end;

        switch [_rtcMem.status]()
		
end -- END sleepOneDay()

function adjustTime()
        local _currentSecs,_wakeUpSecs;
        local _seconds;

		_actualTime.seconds, _actualTime.useconds = rtctime.get();
		_currentSecs = _actualTime.seconds;
		_wakeUpSecs = ((_wakeup.hour * 60) + _wakeup.minute) * 60 + _wakeup.second;
		_seconds=(_wakeUpSecs-_currentSecs>0) ? (_wakeUpSecs-_currentSecs) : (_wakeUpSecs-_currentSecs+(24*3600));
		print("Adjust time to wait for executing the task \n");
		print("_currentSecs: %3d \n",_currentSecs);
		print("_wakeUpSecs: %3d \n",_wakeUpSecs);
		print("_secondsToGo: %3d \n",_seconds);
		return _seconds;
end -- END adjustTime()

function print_rtcMem(String place) 
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
        rtcmem.write32(65, _rtcMem.markerFlag, _rtcMem.counter, _rtcMem.status);
        print_rtcMem("WORK  ");
        rtctime.dsleep(_sleepTime, RF_DISABLED);
end -- END backToSleep()


-- USE EXAMPLE --
	-- print("Start main execution \n");
    -- dailyTask(12, 0, RESET_PIN); --Hour to do the task
	-- sleepOneDay();

	-- ------------------ put the code for your daily task here -------------------------------

	-- print("............ W O R K ...............................");
	
	-- ----------------------- end of code for your daily task-------------------------------

	-- -- and back to sleep once daily code is done --
	-- backToSleep();																						
-- END USE EXAMPLE --