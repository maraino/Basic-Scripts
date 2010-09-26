#!/usr/bin/perl -w
use strict;
use HTTP::Date;
use Getopt::Long;
use Fcntl qw(:flock);
use YAML;
use XML::RSS::Parser;

my $DEBUG = 1;

sub read_config($) {
    my $file = shift;

    return undef if (!-e $file);

    my $conf = YAML::LoadFile($file);
    if (!exists($conf->{rss})) {
        if ($DEBUG) {
            print "Nothing to do\n";
            return undef;
        }
    }

    return $conf;
}

sub rfc822_to_localtime($) {
    my $date = shift;
    return HTTP::Date::str2time($date);
}

sub parse_rss($$) {
    my ($url, $last) = @_;
    
    my $tlast = ($last ? rfc822_to_localtime($last) : undef);
    my $new_tlast = $tlast;
    my $new_last = $last;

    my $p = XML::RSS::Parser->new;
    my $feed = $p->parse_uri($url);
    
    if (!defined($feed)) {
        print STDERR "Error: cannot parse $url\n";
        return ();
    }
    
    my @links = ();
    my ($link, $pub_date, $tpub_date, $node);
    foreach my $item ($feed->query('//item') ) { 
        $node = $item->query('link');
        $link = $node->text_content;
        $node = $item->query('pubDate');
        $pub_date = $node->text_content;
        $tpub_date = rfc822_to_localtime($pub_date);
        
        if (!$tlast || $tlast < $tpub_date) {
            push @links, $link;
            
            if ($tpub_date > $new_tlast) {
                $new_tlast = $tpub_date;
                $new_last = $pub_date;
            }
        }
    }
    
    my %ret = (links => \@links,
               new_last => $new_last);
    return \%ret;
}

sub save_in_path($$) {
    my ($url, $path) = @_;
    print "save in path $url $path\n";
    # TODO
}

sub do_rss_work($) {
    my $conf = shift;
    
    my $command = undef;
    my $path = undef;
    if (exists($conf->{default}->{command}) && $conf->{default}->{command}) {
        $command = $conf->{default}->{command};
    }
    
    if (exists($conf->{default}->{path}) && $conf->{default}->{path}) {
        $path = $conf->{default}->{path};
    }
    
    my ($last, $link, $cmd);
    my $rss;
    while(my ($rss, $v) = each(%{$conf->{rss}})) {
        if (exists($v->{url})) {
            $last = (exists($v->{last}) ? $v->{last} : undef);
            $rss = parse_rss($v->{url}, $last);
            
            foreach $link (@{$rss->{links}}) {
                if (defined($path)) {
                    save_in_path($link, $path);
                } 

                if (defined($command)) {
                    $cmd = $command;
                    $cmd =~ s/<url>/"$link"/g;
                    system($cmd);
                }
            }
            
            $v->{last} = $rss->{new_last};
        }
    }
}

sub main {
    my $conf_file = $ENV{HOME} . '/.rssd.yml';
    
    GetOptions ('conf=s' => \$conf_file,
                'debug'  => \$DEBUG);
    
    my $lock_file = $conf_file . '.lck';
    
    open (my $fl, ">> $lock_file") or die ("Error: cannot open $lock_file");
    flock($fl, LOCK_EX) or die ("Error: cannot lock $lock_file");
    
    my $conf = read_config($conf_file);
    do_rss_work($conf);
    YAML::DumpFile($conf_file, $conf);

    unlink($lock_file);
    flock($fl, LOCK_UN) or die ("Error: cannot unlock $lock_file");
    close($fl);
}

main();
