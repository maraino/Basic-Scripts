#!/usr/bin/perl -w
#
# RSSd RSS downloader. Performs automatic commands with each update.
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
use strict;
package main;
use Getopt::Long;

sub main {
    my $conf_file = $ENV{HOME} . '/.rssd.yml';
    my $test = 0;
    my $debug = 0;
    my ($run, $new, $help, $del);
    my ($add, $url, $params);
    
    GetOptions (
                # Configuration file
                'c|conf=s' => \$conf_file,
                
                # Help
                'h|help' => \$help,
                
                # Run 
                'r|run'  => \$run,
                
                # New file
                'n|new' => \$new, 

                # Add or update feed
                'a|add=s'    => \$add, 
                'u|url=s'    => \$url,
                'p|param=s%' => \$params,
                
                # Delete feed
                'd|del|delete=s' => \$del, 
                
                # Extra flags
                't|test'    => \$test,
                'v|verbose' => \$debug);

    if ($help) {
        help();
        return;
    }
    
    my $rssd;
    if ($new) {
        $rssd = RSSd->new();
    } else {
        $rssd = RSSd->new($conf_file);
    }
    
    # Set attributes
    if ($test) {
        $rssd->test(1);
    }

    if ($debug) {
        $rssd->debug(1);
    }
    
    # Run operations
    if ($new) {
        $rssd->create($conf_file);
        $rssd->save();
    } elsif($del) {
        if ($rssd->remove($del)) {
            $rssd->save();
        }
    } elsif($add) {
        $params->{url} = $url if ($url);
        $rssd->add($add, $params);
        $rssd->save();
    } else {
        $rssd->run();
        $rssd->save();
    }

    # my $lock_file = $conf_file . '.lck';
    # open (my $fl, ">> $lock_file") or die ("Error: cannot open $lock_file");
    # Fcntl::flock($fl, LOCK_EX) or die ("Error: cannot lock $lock_file");
    
    # unlink($lock_file);
    # Fcntl::flock($fl, LOCK_UN) or die ("Error: cannot unlock $lock_file");
    # close($fl);
}

sub help {
    print <<USAGE;
RSSd v0.2 (http://github.com/maraino)
Usage: $0 [--run] [--conf config_file] [FLAGS]
       $0 --new [--conf config_file] [FLAGS]
       $0 --add Name --url http://example.com/rss.xml [--param last=DATE] [--param command=COMMAND] [--param path=PATH] [FLAGS]
       $0 --del Name
       $0 --help 
Flags: 
  -t | --test     Don't perform any action. Display the results.
  -v | --verbose  Show debug messages.

Commands/Options: 
  --run   | -r    Default action. Get latest RSS and performa actions.
  --new   | -n    Create a new configuration YAML file.
  --add   | -a    Add or update a RSS feed in the selected YAML file.
  --url   | -u    Add the url of the feed to the YAML file, requires --add.
  --param | -p    Add specific parameters to the YAML file, requires --add.
  --del   | -d    Delete a RSS feed from the selected YAML file.
  --help  | -h    Show this help summary page.

Default YAML file: ~/.rssd.yml

USAGE
}

main();

package RSSd;
use Carp;
use HTTP::Date;
use YAML;
use XML::RSS::Parser;

sub new {
    my $class      = shift;
    my $self       = {};
    bless ($self, $class);
    
    $self->{CONF}  = undef;
    $self->{DEBUG} = undef;
    $self->{TEST}  = undef;
    $self->{YAML}  = undef;

    if (scalar(@_) > 0) {
        $self->{CONF} = shift;
        $self->_read_config();
    }
    
    return $self;
}

sub test {
    my $self = shift;
    $self->{TEST} = shift if @_;
    return $self->{TEST};
}

sub debug {
    my $self = shift;
    $self->{DEBUG} = shift if @_;
    return $self->{DEBUG};
}

sub conf {
    my $self = shift;
    $self->{CONF} = shift if @_;
    return $self->{CONF};
}

sub create($$) {
    my ($self, $conf) = @_;
    
    $self->{CONF} = $conf;
    $self->{YAML} = {
                     default => {
                                 command => undef, 
                                 path => undef,
                                }, 
                     rss => undef
                    };
}

sub add($$$) {
    my ($self, $name, $params) = @_;
    
    $self->_read_config() if(!defined($self->{YAML}));
    
    if (!exists($self->{YAML}->{rss})) {
        $self->{YAML}->{rss} = {};
    }
    
    if (!exists($self->{YAML}->{rss}->{$name})) {
        $self->{YAML}->{rss}->{$name} = {};
    }

    # Add parameters like url,last,command or path
    while(my ($k, $v) = each(%$params)) {
        $self->{YAML}->{rss}->{$name}->{$k} = $v;
    }
}

sub remove($$) {
    my ($self, $name) = @_;
    
    $self->_read_config() if(!defined($self->{YAML}));
    
    my $ret;
    if (exists($self->{YAML}->{rss}->{$name})) {
        $ret = 1;
        delete $self->{YAML}->{rss}->{$name};
    } else {
        $ret = 0;
        print STDERR "Error: Feed '$name' does not exist\n";
    }
    
    return $ret;
}

sub save {
    my ($self) = @_;

    if (!defined($self->{CONF})) {
        croak("configuration file is not defined");
    }
    
    if (!defined($self->{YAML})) {
        croak("YAML has not been created");
    }
    
    if ($self->{TEST}) {
        print '-'x80 . "\n";
        print "Configuration file\n";
        print '-'x80 . "\n";
        print YAML::Dump($self->{YAML});
    } else {
        YAML::DumpFile($self->{CONF}, $self->{YAML});
    }
}

sub run {
    my ($self) = @_;
    
    $self->_read_config() if(!defined($self->{YAML}));
    
    if ($self->{TEST}) {
        print '-'x80 . "\n";
        print "Commands\n";
        print '-'x80 . "\n";
    }
    
    my $default_command = undef;
    my $path = undef;
    if (exists($self->{YAML}->{default}->{command}) && $self->{YAML}->{default}->{command}) {
        $default_command = $self->{YAML}->{default}->{command};
    }
    
    my $default_path = undef;
    if (exists($self->{YAML}->{default}->{path}) && $self->{YAML}->{default}->{path}) {
        $default_path = $self->{YAML}->{default}->{path};
    }
    
    my ($last, $item, $command);
    my $rss;
    while(my ($rss, $v) = each(%{$self->{YAML}->{rss}})) {
        if (exists($v->{url})) {
            $last = (exists($v->{last}) ? $v->{last} : undef);
            $command = (exists($v->{command}) ? $v->{command} : $default_command);
            $path = (exists($v->{path}) ? $v->{path} : $default_path);
            
            $rss = $self->_parse_rss($v->{url}, $last);
            foreach $item (@{$rss->{items}}) {
                if (defined($path)) {
                    $self->_save_in_path($item->{link}, $path);
                } 

                if (defined($command)) {
                    my $cmd = $self->_create_command($command, $item);
                    
                    if ($self->{TEST}) {
                        print "$cmd\n";
                    } else {
                        system($cmd);
                        if ($? != 0) {
                            carp(sprintf("Command '$cmd' exited with a value '%d'", $? >>8));
                        }
                    }
                }
            }
            
            $v->{last} = $rss->{pubDate};
        }
    }
}

sub _read_config {
    my ($self) = @_;
    
    if (!defined($self->{CONF})) {
        croak("configuration file is not defined");
    }
    
    if (!-r $self->{CONF}) {
        croak("file '$self->{CONF}' cannot be read")
    }
    
    my $conf = YAML::LoadFile($self->{CONF});
    if (!exists($conf->{rss})) {
        if ($self->{DEBUG}) {
            carp("Nothing to do");
            print "mariano\n";
            return undef;
        }
    }

    $self->{YAML} = $conf;
}

sub _rfc822_to_localtime {
    my ($self, $date) = @_;
    return HTTP::Date::str2time($date);
}

sub _create_command {
    my ($self, $cmd, $params) = @_;

    while (my ($k, $v) = each (%$params)) {
        $v =~ s/"/\"/g;
        $cmd =~ s/<$k>/"$v"/g;
    }

    return $cmd;
}

sub _parse_rss {
    my ($self, $url, $last) = @_;
    
    my $tlast = ($last ? $self->_rfc822_to_localtime($last) : undef);
    my $new_tlast = $tlast;
    my $new_last = $last;

    my $p = XML::RSS::Parser->new;
    my $feed = $p->parse_uri($url);
    
    if (!defined($feed)) {
        print STDERR "Error: cannot parse $url\n";
        return ();
    }
    
    my @items = ();
    my @children;
    my ($i, $link, $pub_date, $tpub_date, $node);
    foreach my $item ($feed->query('//item') ) { 
        $node = $item->query('link');
        $link = $node->text_content;
        $node = $item->query('pubDate');
        $pub_date = $node->text_content;
        $tpub_date = $self->_rfc822_to_localtime($pub_date);
        
        if (!$tlast || $tlast < $tpub_date) {
            @children = $item->contents();
            $i = {};
            
            foreach (@{$children[0]}) {
                if ($_->qname) {
                    $i->{$_->qname} = $_->text_content;
                }
            }
            
            push @items, $i;
            
            if (!$new_tlast || $tpub_date > $new_tlast) {
                $new_tlast = $tpub_date;
                $new_last = $pub_date;
            }
        }
    }
    my %ret = (items   => \@items,
               pubDate => $new_last);
    return \%ret;
}

sub _save_in_path {
    my ($self, $link, $path) = @_;
    # TODO
    carp("Not implemented (link: $link, path: $path)");
}
