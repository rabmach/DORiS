#!/usr/bin/perl -w

#
# procinfo.pl script from waimea ( http://www.waimea.org/ ) ported to output
#             pekwm syntax by Claes Nasten ( http://pekdon.net/ )
#
# REPORTED to openbox3 pipe menu syntax by Dave Foster (daf@minuslab.net)
# some functions with no path to execute were removed, otherwise, no 
# logic was changed in this script at all.

# install instructions:
# 1) Put script somewhere (~/.config/openbox/scripts/ works well)
# 2) Make script executable (chmod +x procinfo.pl)
# 3) Edit openbox menu file:
#	a) Add <menu id="proc-menu" label="Processes" execute="pathto/procinfo.pl" />
#	b) Add <menu id="proc-menu" somewhere on your root menu or wherever you want it.

use POSIX;

my $script_location = $0;
my $offset = 0;
my $proc_dir = "/proc";
my $pid = 0;
my $host = "";
my $user = "";
$user = $ENV{USER};
chomp(my $hostname = qx(hostname));
my $forcepid = 0;
my $file = 0;
my $list_length = 20;

get_opt();

print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
print "<openbox_pipe_menu>\n";

if ($forcepid) {
    if ($hostname eq $host && $pid) {
        pid_info();
    } else {
       print "Name = \"process info\"\n";
       print "Entry = \"process info for this window could not be retrived\" { }\n";
    }
} else {
   if ($pid) {
       pid_info();     
   } else {
       list_proc();
   }
}

print "</openbox_pipe_menu>\n";

sub list_proc {
#    my $cmdline = 0;
    my $proc_name = 0;
    my $i = $offset;
    my $owner = "";
    my $printed = 0;
    my @output;

    opendir(DIR, $proc_dir) || die "can't opendir $proc_dir: $!";
    @proc_list = grep { (/^[^\.].*/ || /^\.\..*/) && /^\d+$/} readdir(DIR);
    closedir DIR;

#    print "$_\n" foreach @proc_list;


    while (($pid = $proc_list[$i]) && $printed <= $list_length) {
	open(FILE, "$proc_dir\/$pid\/status") || die "can't opendir $proc_dir: $!";
	($proc_name = (split(':', <FILE>))[1]) =~ s/^\s*(.*)\n/$1/;
#	if ($user eq 
	while ($_ = <FILE>) {
	    if (/^Uid\:\s*(\d+)\s+/) {
		$owner = getpwuid $1;
	    }
	}
	close FILE;
	
	if (($user && ($user eq 'all' || $user eq 'ALL')) ||
	    ($owner && $user && ($owner eq $user))) {
	    if ($printed < $list_length) {
#		push @output, "Submenu = \"$pid - $proc_name\" { Entry {  Actions = \"Dynamic $script_location -pid $proc_list[$i]\" } }\n";
	    
		push @output, "<menu  icon=\"/usr/share/icons/gnome/256x256/places/network_local.png\" id=\"menu-proc-$pid\" label=\"$pid - $proc_name\" execute=\"$script_location -pid $proc_list[$i]\" />\n";
		}
	    else {
		$i--;
	    }
	    $printed++;
	}
	$i++;
    }

    if ($proc_list[$i]) {
	$_ = $i;
	print "Submenu = \"more...\" { Entry { Actions = \"Dynamic $script_location -offset $_ -user $user\" } }\n";
    }

    print @output;
}

sub pid_info {
    my $name = "";
    my @procinfo;
    my $cmdline = "";
    my $priority = "";
    my $msize = "";
    my $mlck = "";
    my $mrss = "";
    my $mdata = "";
    my $mstk = "";
    my $mexe = "";
    my $mlib = "";
    my $pid_err = 0;
    
    open(FILE, "$proc_dir\/$pid\/stat") || pid_err();
    $_ = <FILE>;
    @procinfo = split(/ /,$_);
    close FILE;
    $procinfo[1] =~ m/^\((.*)\)/;
    $name = $1;
    $priority = $procinfo[18];

    open(FILE, "$proc_dir\/$pid\/status") || die "can't opendir $proc_dir: $!";
    while ($_ = <FILE>) {
       if ($_ =~ m/^State.*\((\w*)\)$/) {
          $state = $1;
          $state =~ s/\(/\\\(/;
          $state =~ s/\)/\\\)/;
          $state =~ s/\t/ /;
          $state =~ s/\s+/ /;
       }
       if ($_ =~ m/^VmSize/) {          
          $_ =~ m/.*:\t*\s*(.*)$/;          
          $msize = $1;
       }
       if ($_ =~ m/^VmLck/) {
          $_ =~ m/.*:\t*\s*(.*)$/;
          $mlck = $1;
       }
       if ($_ =~ m/^VmRSS/) {
          $_ =~ m/.*:\t*\s*(.*)$/;
          $mrss = $1; 
       }
       if ($_ =~ m/^VmData/) {
          $_ =~ m/.*:\t*\s*(.*)$/;
          $mdata = $1;
       }
       if ($_ =~ m/^VmStk/) {
          $_ =~ m/.*:\t*\s*(.*)$/;
          $mstk = $1;
       }
       if ($_ =~ m/^VmExe/) {
          $_ =~ m/.*:\t*\s*(.*)$/;
          $mexe = $1;
       }
       if ($_ =~ m/^VmLib/) {
          $_ =~ m/.*:\t*\s*(.*)$/;
          $mlib = $1;
       }
    }        

    if (open(FILE, "$proc_dir\/$pid\/cmdline")) {
        $_ = <FILE>;        
        while ($_ =~ m/\0/) {
            $_ =~ s/\0/\\\" \\\"/;
        }
        $_ =~ m/(.*).{3}$/;
        $cmdline = "\\\"$1";
        close FILE;
    }

	print "\t<menu id=\"menu-proc-$pid-state\" label=\"state ($state)\">\n";
	print "\t\t<item label=\"stop\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>kill -SIGSTOP $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"continue\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>kill -SIGCONT $pid</execute></action>\n";
	print "\t\t</item>\n";	
	print "\t</menu\n>";

	print "\t<menu id=\"menu-proc-$pid-memory\" label=\"memory ($msize)\">\n";
	print "\t\t<item label=\"size: $msize\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>true</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"lck: $mlck\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>true</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"rss: $msize\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>true</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"data: $mdata\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>true</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"stk: $mstk\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>true</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"exe: $mexe\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>true</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"lib: $mlib\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>true</execute></action>\n";
	print "\t\t</item>\n";
	print "\t</menu>\n";
          
    print "\t<menu id=\"menu-proc-$pid-priority\" label=\"priority ($priority)\">\n";
	print "\t\t<item label=\"increase by 1\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>renice +1 $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"0 (base)\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>renice 0 $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"5\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>renice 5 $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"10\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>renice 10 $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"15\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>renice 15 $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"20 (idle)\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>renice 20 $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t</menu>\n";

    print "\t<menu id=\"menu-proc-$pid-signal\" label=\"send signal\">\n";
	print "\t\t<item label=\"sighup\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>kill -HUP $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"sigint\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>kill -INT $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t\t<item label=\"sigkill\">\n";
	print "\t\t\t<action name=\"Execute\"><execute>kill -KILL $pid</execute></action>\n";
	print "\t\t</item>\n";
	print "\t</menu>\n";

    if ($cmdline ne "") {
		print "\t<item label=\"restart\">\n";
		print "\t\t<action name=\"Execute\"><execute>kill $pid &amp;&amp; $cmdline</execute></action>\n";
		print "\t</item>\n";
		print "\t<item label=\"spawn new\">\n";
		print "\t\t<action name=\"Execute\"><execute>$cmdline</execute></action>\n";
		print "\t</item>\n";

    }
}

sub get_opt {
    my $i = 0;
    while ($ARGV[$i+1] && ($_ = $ARGV[$i])) {
	if (/\-offset/) {
	    $offset = $ARGV[$i+1];
	}
	if (/\-pid/) {
	    $pid = $ARGV[$i+1];
	}
	if (/\-proc_dir/) {
	    $proc_dir = $ARGV[$i+1];
	}
	if (/\-user/) {
	    $user = $ARGV[$i+1];
	}
   if (/\-host/) {
      $host = $ARGV[$i+1];
   }
	$i++;
    }
    $i = 0;
    while ($_ = $ARGV[$i]) {
        $i++;
        if (/\-host/) {
            $forcepid = 1;
        }
    }
}

sub pid_err {
    print "<item label=\"??? ($pid)\">\n";
	print "<action name=\"Execute\"><execute>true</execute></action>\n";
	print "</item>\n";
    exit;
}
                               