-- sync the ESP8266 Real Time Clock (RTC) to an NTP server
-- retrieve and display the time and date from the ESP8266 RTC
-- requires the sntp and rtctime firmware modules

timeZone=-4 -- time zone (Eastern Daylight Time); -5 for Eastern Standard Time
hour=0
minute=0
second=0
day=0
month=0
year=0

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
end

print("\ncontacting NTP server...")
sntp.sync("0.pool.ntp.org")             -- sync the ESP8266 RTC with the NTP server
tmr.alarm(0,500,0,
   function()
      -- get the hour, minute, second, day, month and year from the ESP8266 RTC
      hour,minute,second,month,day,year=getRTCtime(timeZone)
      if year ~= 0 then
         -- format and print the hour, minute second, month, day and year retrieved from the ESP8266 RTC
         print(string.format("%02d:%02d:%02d  %02d/%02d/%04d",hour,minute,second,month,day,year))
         --print(string.format("%02d:%02d:%02d  %02d/%02d/%04d",getRTCtime(timeZone)))    
      else
         print("Unable to get time and date from the NTP server.")
      end
   end
)  -- See more at: http://www.esp8266.com/viewtopic.php?f=19&t=8916#sthash.MPpa8qbC.dpuf