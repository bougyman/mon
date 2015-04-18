#!/usr/local/bin/python
'''
bulksms.alert - Alert script for mon to pass SMS messages to the www.bulksms.co.uk system.

 
'''


import BulkSMS
# API for Bulksms.co.uk - see 
import ConfigParser
import os
import getopt
import sys
import string
import time

# Keep the main settings in a config file so that we can share them
# Look in /usr/local/etc/mon/bulksms.conf and ./bulksms.conf

def get_config():

    # Set all of our default config options
    # NB: During testing, pretend is default
    settings = ConfigParser.ConfigParser()
    settings.read(['/usr/local/etc/mon/bulksms.conf','./bulksms.conf'])
    config = {
        'userid' : settings.get('BulkSMS','username'),
        'password' : settings.get('BulkSMS','password'),
        'cost' : settings.get('BulkSMS','default_cost_route'),
        'from' : settings.get('BulkSMS','source'),
        'recipients' : string.split(settings.get('BulkSMS','recipients'),','),
        'LAST_SUMMARY' : os.getenv('MON_LAST_SUMMARY'),
        'LAST_OUTPUT' : os.getenv('MON_LAST_OUTPUT'),
        'LAST_FAILURE' : os.getenv('MON_LAST_FAILURE'),
        'FIRST_FAILURE' : os.getenv('MON_FIRST_FAILURE'),
        'LAST_SUCCESS' : os.getenv('MON_LAST_SUCCESS'),
        'DESCRIPTION' : os.getenv('MON_DESCRIPTION'),
        'GROUP' : os.getenv('MON_GROUP'),
        'SERVICE' : os.getenv('MON_SERVICE'),
        'RETVAL' : os.getenv('MON_RETVAL'),
        'OPSTATUS' : os.getenv('MON_OPSTATUS'),
        'ALERTTYPE' : os.getenv('MON_ALERTTYPE'),
        'TRAP_INTENDED' : os.getenv('MON_TRAP_INTENDED'),
        'LOGDIR' : os.getenv('MON_LOGDIR'),
        'STATEDIR' : os.getenv('MON_STATEDIR'),
        'subject' : sys.stdin.readline(),
        'hosts' : '',
        'alertevery' : '',
        'trap_timeout' : 0,
        'time' : '',
        'trap_triggered': 0,
        'upalert': 0
        }
    short_opt = 's:g:h:l:Ot:Tu?'
    try:
        (opts, extras) = getopt.getopt(sys.argv[1:], short_opt)
    except getopt.GetoptError, ex:
        raise UsageError, ex
    debug(opts)
    debug(extras)
    debug(sys.argv)
    for item in opts:
        if item[0] == '-s':
            config['SERVICE'] = item[1]
        elif item[0] == '-g':
            config['GROUP'] = item[1]
        elif item[0] == '-h':
            config['hosts'] = item[1]
        elif item[0] == '-l':
            config['alertevery'] = item[1]
        elif item[0] == '-O':
            config['trap_timeout'] = 1
        elif item[0] == '-t':
            if item[1].isdigit():
                config['time'] = time.ctime(float(item[1]))
            else:
                raise RuntimeError, 'Type mismatch on time parameter: not float'
        elif item[0] == '-T':
            config['trap_triggered'] = 1
        elif item[0] == '-u':
            config['upalert'] = 1
        elif item[0] == '-?': 
            raise UsageError, 'Help requested'
        else:
            raise RuntimeError, 'Error in parameters'
    return config
    
def debug(message):
    debug=1
    errlog = open('/tmp/bulksms.log','a')
    if debug:
        errlog.write('%s\n' % message)
    errlog.close()
    
def usage(ex):
    if str(ex) == 'Help requested':
        print __doc__
    elif str(ex) == 'Version information requested':
        version_info()
    else:
        sys.stderr.write("\n%s\n" % __doc__)
        sys.stderr.write("Error: %s\n" % str(ex))

def version_info():
    version = "%s v%s" % (os.path.basename(sys.argv[0]), __version__)
    print version

class UsageError(Exception):
    pass

# Here endeth the standard lesson...er...section.
################################################

# Ok, up until this point it's all been stuff about making this pretty.
# Here's where the actual guts of the thing starts.

# The main bit.
def main():
    #Get the config sorted
    debug('started')
    config=get_config()
    debug('Got config.')
    debug(config)
    #Set up our BulkSMS interface
    sms = BulkSMS.BulkSMS(config['userid'],config['password'])
    sms.cost_route = config['cost']
    if config['upalert']:
        message = 'UPALERT %s/%s: %s is now showing OK' % ( config['GROUP'],
            config['SERVICE'],
            config['hosts']
          )            
    else:
        message = 'ALERT %s/%s: %s (Last tested OK %s)' % ( config['GROUP'],
          config['SERVICE'],
          config['hosts'],
          config['LAST_SUCCESS'])
    debug(message)
##    fd = open('/tmp/output.test','w')
##    debug(fd)
    msgid = sms.send_sms(config['recipients'], message, sender = config['from'])
    debug(msgid)
##    fd.write(message)
##    fd.write('%s' % msgid)
##    fd.close   
    
# EOG (End of Guts - the end of the guts of the application)

# This is the main application. It does nothing except pump us back up
# into where we should be and raise a usage exception if something screwed up.

if __name__ == '__main__':
    try:
        main()
    except UsageError, ex:
        usage(ex)
