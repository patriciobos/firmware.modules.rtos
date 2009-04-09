#!/usr/bin/perl

# Copyright 2008, 2009, Mariano Cerdeiro
#
# This file is part of FreeOSEK.
#
# FreeOSEK is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#             
# Linking FreeOSEK statically or dynamically with other modules is making a
# combined work based on FreeOSEK. Thus, the terms and conditions of the GNU
# General Public License cover the whole combination.
#
# In addition, as a special exception, the copyright holders of FreeOSEK give
# you permission to combine FreeOSEK program with free software programs or
# libraries that are released under the GNU LGPL and with independent modules
# that communicate with FreeOSEK solely through the FreeOSEK defined interface. 
# You may copy and distribute such a system following the terms of the GNU GPL
# for FreeOSEK and the licenses of the other code concerned, provided that you
# include the source code of that other code when and as the GNU GPL requires
# distribution of source code.
#
# Note that people who make modified versions of FreeOSEK are not obligated to
# grant this special exception for their modified versions; it is their choice
# whether to do so. The GNU General Public License gives permission to release
# a modified version without this exception; this exception also makes it
# possible to release a modified version which carries forward this exception.
# 
# FreeOSEK is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FreeOSEK. If not, see <http://www.gnu.org/licenses/>.
#
use Switch;
use File::Copy;

$errors = 0;
$warnings = 0;
$fatalerrors = 0;

sub htons
{
	$val = 0;
	$mul = 1;
	foreach (split(//,@_[0]))
	{
		$val += $mul * ord($_);
		$mul *= 256;
	}

	return $val;
}

sub GetTestCases
{
	open TC, "<@_[0]" or die "@_[0] can not be openned: $!";
	my $val;
	my @ret;
	read(TC, $val, 35, 0);
	close(TC);
	foreach (split(//,$val))
	{
		$tc = ( ( $_ >> 0 ) & 3 );
		push(@ret, ord($tc));
		$tc = ( ( $_ >> 2 ) & 3 );
		push(@ret, ord($tc));
		$tc = ( ( $_ >> 4 ) & 3 );
		push(@ret, ord($tc));
		$tc = ( ( $_ >> 6 ) & 3 );
		push(@ret, ord($tc));
	}

	return @ret;
}

sub GetTestSequences
{
	my $file = @_[0];
	my @tc = ();

	open TSF, "<" . $file;

	while (my $line = <TSF>)
	{
		chomp($line);
		if ($line ne "")
		{
			$tabcount = ($line =~ tr/\t//);
			if ($tabcount == 0)
			{
				push(@tc, $line);
			}
		}
	}

	close(TSF);

	return @tc;
}

sub GetTestSequencesConfigs
{
	my $file = @_[0];
	my $tc = @_[1];
	my @tcs = ();
	my $startcount = 0;

	open TSF, "<" . $file;

	while (my $line = <TSF>)
	{
		chomp($line);
		if ($line ne "")
		{
			$tabcount = ($line =~ tr/\t//);
			$line =~ s/\t+//;
			if ($tabcount == 0)
			{
				if ($tc eq $line)
				{
					#print "LINE: $line\n";
					$startcount = 1;
				}
				else
				{
					#print "LINE END: $line\n";
					$startcount = 0;
				}
			}
			if ( ($tabcount == 1) && ( $startcount == 1 ) )
			{
				#print "$line\n";
				push(@tcs, $line);
			}
		}
	}

	close(TSF);

	return @tcs;
}

sub GetTestSequencesCon
{
	my $file = @_[0];
	my $tc = @_[1];
	my $tcc = @_[2];
	my @ret = ();
	my $stc1 = 0;
	my $stc2 = 0;

	open TSF, "<" . $file;

	while (my $line = <TSF>)
	{
		chomp($line);
		if ($line ne "")
		{
			$tabcount = ($line =~ tr/\t//);
			$line =~ s/\t+//;
			if ($tabcount == 0)
			{
				if ($tc eq $line)
				{
					#print "LINE: $line\n";
					$stc1 = 1;
				}
				else
				{
					#print "LINE END: $line\n";
					$stc1 = 0;
				}
			}
			if ( ($tabcount == 1) && ( $stc1 == 1 ) )
			{
				if ($line eq $tcc)
				{
					$stc2 = 1;
				}
				else
				{
					$stc2 = 0;
				}
			}
			if ( ($tabcount == 2) && ( $stc1 == 1 ) && ( $stc2 == 1 ) )
			{
				#print "LINE YES: $line\n";
				push(@ret, $line);
			}
		}
	}

	close(TSF);

	return @ret;
}

sub searchandreplace
{
	$file = @_[0];
	$s = @_[1];
	$r = @_[2];

	`perl -pi -e 's/$s/$r/' $file`;

	close(OUT);
}

sub EvaluateResults
{
	my $failed = 0;
	my $failedtotal = 0;

	open SC, "<out/dbg/SequenceCounter.bin" or die "SequenceCounter.bin can not be openned: $!";
	read(SC, $sc, 4, 0);
	close(SC);
	open SC, "<out/dbg/SequenceCounterOk.bin" or die "SequenceCounterOk.bin can not be openned: $!";
	read(SC, $scok, 4, 0);
	close(SC);
	$scerror = htons($sc) >> 31;
	$sc= ( htons($sc) & 0x7fffffff );
	$scok=htons($scok);
	if ( ($sc == $scok) && ($scerror == 0) )
	{
		$sctc = "OK";
	}
	else
	{
		$failed = 1;
		$failedtotal = 1;
		$sctc = "FAILED";
	}
	results("Sequence: $scerror-$sc - SequenceOk: $scok - Sequence Result: $sctc");

	$failed = 0;
	$failedcounter = 0;
	@ts = GetTestCases("out/dbg/TestResults.bin");
	@tsok = GetTestCases("out/dbg/TestResultsOk.bin");

	for($loopi = 0; $loopi < @ts; $loopi++)
	{
		#info("Loop: " . $loopi);
		if(@ts[$loopi] != @tsok[$loopi])
		{
			$failed = 1;
			$failedtotal = 1;
			$failedcounter++;
			results("Test Case $loop doesn't mach - Result: " . @ts[$loopi] . " ResultOk: " . @tsok[$loopi]);
		}
	}

	if($failed == 1)
	{
		results("$failedcounter testcases failed");
	}
	else
	{
		results("Test cases executed in the right form");
	}

}

sub readparam
{
	open CFG, "<@_[0]" or die "Config file @_[0] can not be openned: $!";
	while (my $line = <CFG>)
	{
		chomp($line);
		($var,$val) = split(/:/,$line);
		switch ($var)
		{
			case "GDB" { $GDB = $val; }
			case "BINDIR" { $BINDIR = $val; }
			case "ARCH" { $ARCH = $val; }
			case "CPUTYPE" { $CPUTYPE = $val; }
			case "CPU" { $CPU = $val; }
			case "DIR" { $DIR = $val; }
			case "LOG" { $logfile = $val; }
			case "LOGFULL" { $logfilefull = $val; }
			case "TESTS" { $TESTS = $val; }
			case "RES" { $RES = $val; }
			else { }
		}
	}

	close CFG;
}

sub results
{
	print RESFILE "@_[0]\n";
	info(@_[0]);
}

sub info
{
	print "INFO: " . @_[0] . "\n";
	logf("INFO: " . @_[0]);
}

sub warning
{
	print "WARNING: " . @_[0] . "\n";
	logf("WARNING: " . @_[0]);
	$warnings++;
}

sub error
{
	print "ERROR " . @_[0] . "\n";
	logf("INFO: " . @_[0]);
	$errors++;
}

sub halt
{
	print "FATAL ERROR: " . @_[0] . "\n";
	logf("FATAL ERROR: " . @_[0]);
	$errors;
	$fatalerrors++;
	finish();
}

sub finish
{
	info("Warnings: $warnings - Errors: $errors");
	if ( ($errors > 0) || ($fatalerrors > 0) )
	{
		exit(1);
	}
	exit(0);
}

sub logf
{
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	printf LOGFILE "%4d-%02d-%02d %02d:%02d:%02d %s\n",$year+1900,$mon+1,$mday,$hour,$min,$sec,@_[0];
	printf LOGFILEFULL "%4d-%02d-%02d %02d:%02d:%02d %s\n",$year+1900,$mon+1,$mday,$hour,$min,$sec,@_[0];
}

sub logffull
{
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	printf LOGFILEFULL "%4d-%02d-%02d %02d:%02d:%02d %s\n",$year+1900,$mon+1,$mday,$hour,$min,$sec,@_[0];
}


print "FreeOSEK Conformance Test Runner - Copyright 2008-2009, Mariano Cerdeiro - http://opensek.sf.net\n\n";
info("------ LICENSE START ------");
info("FreeOSEK Conformance Test Result is part of FreeOSEK.");
info("");
info("FreeOSEK is free software: you can redistribute it and/or modify");
info("it under the terms of the GNU General Public License as published by");
info("the Free Software Foundation, either version 3 of the License, or");
info("(at your option) any later version.");
info("");
info("Linking FreeOSEK statically or dynamically with other modules is making a");
info("combined work based on FreeOSEK. Thus, the terms and conditions of the GNU");
info("General Public License cover the whole combination.");
info("");
info("In addition, as a special exception, the copyright holders of FreeOSEK give");
info("you permission to combine FreeOSEK program with free software programs or");
info("libraries that are released under the GNU LGPL and with independent modules");
info("that communicate with FreeOSEK solely through the FreeOSEK defined interface.");
info("You may copy and distribute such a system following the terms of the GNU GPL");
info("for FreeOSEK and the licenses of the other code concerned, provided that you");
info("include the source code of that other code when and as the GNU GPL requires");
info("distribution of source code.");
info("");
info("Note that people who make modified versions of FreeOSEK are not obligated to");
info("grant this special exception for their modified versions; it is their choice");
info("whether to do so. The GNU General Public License gives permission to release");
info("a modified version without this exception; this exception also makes it");
info("possible to release a modified version which carries forward this exception.");
info("");
info("FreeOSEK is distributed in the hope that it will be useful,");
info("but WITHOUT ANY WARRANTY; without even the implied warranty of");
info("MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the");
info("GNU General Public License for more details.");
info("You should have received a copy of the GNU General Public License");
info("along with FreeOSEK. If not, see <http://www.gnu.org/licenses/>.");
info("------- LICENSE END -------");

if ($#ARGV + 1 < 2)
{
	info("ctest.pl -f ctest.cfg");
}

$onlytc = $ARGV[3];

$cfgfile = $ARGV[1];

if ($ARGV[4] eq "--debug")
{
	$debug = 1;
}
else
{
	$debug = 0;
}

readparam($cfgfile);

open LOGFILE, "> $logfile" or die "can not open $logfile for append: $!";
open LOGFILEFULL, "> $logfilefull" or die "can not open $logfile for append: $!";
open RESFILE, "> $RES" or die "can not open $RES for append: $!";

info("Starting FreeOSEK Conformance Test Runner");

@tests = GetTestSequences($TESTS);

if($onlytc ne "")
{
	@tmptests = @tests;
	@tests = ();
	
	foreach (@tmptests)
	{
		if(index($_,$onlytc)>-1)
		{
			push(@tests, $_);
		}
	}
}

foreach $testfn (@tests)
{
	@test = split(/:/,$testfn);
	$test = @test[0];
	
	info("Testing $test");

	@configs = GetTestSequencesConfigs($TESTS, $testfn);

	foreach $config (@configs)
	{
		print "Config: $config\n";
	
		$error = "";

		info("make clean of $test");
		$outmakeclean = `make clean`;
		$outmakecleanstatus = $?;
		info("make clean status: $outmakecleanstatus");
		logffull("make clean output:\n$outmakeclean");

		mkdir("out/gen/etc/");

		$org = "FreeOSEK/tst/ctest/etc/" . $test . ".oil";
		$dst = "out/gen/etc/" . $test . ".oil";
		copy($org, $dst) or die "file can not be copied from $org to $dst: $!";

		@replace = GetTestSequencesCon($TESTS, $testfn, $config);
		foreach $rep (@replace)
		{
			info("Replacing: $rep");
			@rep = split (/:/,$rep);
			searchandreplace($dst,@rep[0],@rep[1]);
		}

		if ($outmakecleanstatus == 0)
		{
			info("make generate of $test");
			$outmakegenerate = `make generate PROJECT=$test`;
			$outmakegeneratestatus = $?;
			info("make generate status: $outmakegeneratestatus");
			logffull("make generate output:\n$outmakegenerate");
			#print "$outmakegenerate";
			if ($outmakegeneratestatus == 0)
			{
				info("make of $test");
				$outmake = `make PROJECT=$test`;
				$outmakestatus = $?;
				info("make status: $outmakestatus");
				logffull("make output:\n$outmake");
				if ($outmakestatus == 0)
				{
					$out = $BINDIR . "/" . $test;
					info("debug of $test");
					$dbgfile = "FreeOSEK/tst/ctest/dbg/" . $ARCH . "/gcc/debug.scr";
					info("$GDB $out -x $dbgfile");
					`rm /dev/mqueue/*`;
					if($debug == 0)
					{
						#$outdbg = `$GDB $out -x $dbgfile`;
						system("$GDB $out -x $dbgfile");
					}
					else
					{
						exec("$GDB $out");
					}
					`rm /dev/mqueue/*`;
					$outdbg = "";
					$outdbgstatus = $?;
					info("debug status: $outdbgstatus");
					logffull("debug output:\n$outdbg");
					if ($outdbgstatus == 0)
					{
						results("Test: $test - Config: $config");
						EvaluateResults();
					}
				}
			}
			else
			{
				exit();
			}
		}
	}
}

close(LOGFILE);
close(LOGFILEFULL);
close(RESFILE);


