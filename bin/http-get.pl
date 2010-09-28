#!/usr/bin/perl -w
#
# Perform HTTP request with custom 
# Copyright (C) 2010    Mariano Cano
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
use IO::Socket;
use strict;

sub show_help {
    print "Usage: $0 [--verbose] [--host host] [--port port] server document ...\n";
}

my $http_host = undef;
my @documents = ();
my $server    = undef;
my $verbose   = 0;
my $port      = 80;

my $size = scalar(@ARGV);
for (my $i = 0; $i < $size; $i++) {
    if ($ARGV[$i] eq '--host') {
        if ($i+1 < $size) {
            $i++;
            $http_host = $ARGV[$i];
        }
        else {
            print $i+1;print ' '. $size . "\n";
            show_help();
            exit 1;
        }
    }
    elsif ($ARGV[$i] eq '--verbose') {
        $verbose = 1;
    }
    elsif ($ARGV[$i] eq '--port') {
	if ($i+1 < $size) {
            $i++;
            $port = $ARGV[$i];
        }
        else {
            print $i+1;print ' '. $size . "\n";
            show_help();
            exit 1;
        }
    }
    else {
        if (! defined $server) {
            $server = $ARGV[$i];
        } else {
            push @documents, $ARGV[$i];
        }
    }
}

if (!defined $server || scalar(@documents) == 0) {
    show_help();
    exit 1;
}

if (!defined $http_host) {
    $http_host = $server;
}

my $EOL = "\015\012";
my $BLANK = $EOL x 2;
foreach my $document ( @documents ) {
    my $remote = IO::Socket::INET->new( Proto     => "tcp",
                                        PeerAddr  => $server,
                                        PeerPort  => $port,
                                      );
    unless ($remote) { die "cannot connect to http daemon on $server" }
    $remote->autoflush(1);
    print $remote "GET $document HTTP/1.1";
    print $remote $EOL;
    print $remote "Host: $http_host" . $BLANK;
    while ( <$remote> ) { print if $verbose }
    close $remote;
}
