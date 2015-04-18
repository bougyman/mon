#!/bin/sh
exec perl -I../lib -wT ../bin/minotaur.pl --configFile=../etc/minotaur-cgi.conf 
