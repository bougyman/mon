rem
rem  Easy setup for Microsoft NT/Win2K PERFMIB SNMP extensions
rem
rem  Requires MS PERFMIB kit (from Server Resource Kit)
rem
rem  See KB Article Q195336 for required update version
rem  (ftp://ftp.microsoft.com/bussys/winnt/winnt-public/reskit/nt40/i386/)
rem
rem  See also http://snmpboy.msft.net/asp/perfmibhack.asp
rem
rem  
rem
perf2mib perfmib.mib perfmib.ini  System 1 ntsys  Memory 2 mem  Processor 3 CPU  Server 4 server  PhysicalDisk 5 pdisk  LogicalDisk 6 ldisk   "Paging File" 7 pagefile  Telephony 8 telephony
rem
rem  other potentially interesting chapters - include on line above if desired
rem    "RAS Port" 9 rasport 
rem    "RAS Total" 10 rastot
rem
net stop SNMP
regini perfmib.reg
copy perfmib.dll %systemroot%\system32\perfmib.dll
copy perfmib.ini %systemroot%\system32\perfmib.ini
net start SNMP
