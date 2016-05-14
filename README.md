# nwws-perl-client

A simple client for the NWWS-2 OI ([NOAA Weather Wire Service](http://www.nws.noaa.gov/nwws/) version 2 Open Interface) written in Perl. The NOAA Weather Wire Service is a satellite data collection and dissemination system operated by the [National Weather Service](http://weather.gov), which was established in October 2000. Its purpose is to provide state and federal government, commercial users, media and private citizens with timely delivery of meteorological, hydrological, climatological and geophysical information. 

This client was largely based on the example script found in the [Net::Jabber Perl module](http://search.cpan.org/~reatmon/Net-Jabber-2.0/lib/Net/Jabber.pm) documentation directory `/usr/share/doc/libnet-jabber-perl/examples/client.pl`.

####How do I run it?
This script was developed and tested on [Ubuntu 14.04](http://ubuntu.com). After downloading the latest [release](https://github.com/jbuitt/nwws-perl-client), run the following command to install the dependencies:

```
$ sudo apt-get -y install libnet-jabber-perl libconfig-inifiles-perl libxml-simple-perl
```

Now create a config file: (e.g. config.ini)

```
[Main]
server=nwws-oi.weather.gov
port=5222
username=[username]
password=[paswword]
resource=some_resource
logfile=/path/to/log/file
archivedir=/path/to/archive/dir
debugfile=/path/to/debug/file	(optional)
```

Where [username] and [password] are your NWWS-2 credentials obtained by signing up [on the NOAA Weather Wire Service website](http://www.nws.noaa.gov/nwws/#NWWS_OI_Request).

NOTE: Despite the NWWS-2 website's instructions to use port 5223, this client uses TLS on port 5222. Support for SSL on port 5223 was buggy within the client, so I removed it.

Now run the script:

```
$ ./nwws2.pl /path/to/config.ini
```

Provided that you're able to connect to the NWWS and your credentials are accepted, you will start to see products appear in the supplied archive directory. You can then type `Ctrl+Z` and then `bg` to send it to the background to continue downloading products. The script will automatically reconnect to NWWS if the connection is dropped.

####Author

+	[jim.buitt at gmail.com](mailto:jim.buitt@gmail.com)

## License

See [LICENSE](https://github.com/jbuitt/nwws-perl-client/blob/master/LICENSE) file.

