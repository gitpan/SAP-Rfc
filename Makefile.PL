use ExtUtils::MakeMaker;

# FIND POSSIBLE RFC INSTALLATIONS
my @POSSIBLE_RFC_DIRS = qw(/usr/sap/rfcsdk /usr/local /usr);
my $EMBED_MANIFEST= 0;
map {my($key,$val) = split(/=/,$_); $EMBED_MANIFEST = 1 if $key eq "EMBED_MANIFEST" && $val =~ /yes/ } @ARGV;

# the ADDITIONAL_LIBS needs to be modified for each OS flavour - the rfcsdk
# has the information regarding where libs and incs resides for each
# system type

#This example information comes from the readme in the rfcsdk
#HP-UX : 
#=======
#cc -Ae -I .../rfcsdk/include -L .../rfcsdk/lib
#   sapinfo.c -o sapinfo -lrfc -lcl -ldld -lM
#
#AIX (RS/6000):
#==============
#cc -I .../rfcsdk/include -L .../rfcsdk/lib
#   sapinfo.c -o sapinfo -lrfc
#
#SINIX (RM600): 
#==============
#/opt/C/bin/cc -I .../rfcsdk/include -L .../rfcsdk/lib
#   sapinfo.c -o sapinfo -lrfc -lsocket -lnsl -lusc -ldl -lm
#
#DEC AlphaOSF:
#=============
#cc -std1 -unsigned -I .../rfcsdk/include -L .../rfcsdk/lib
#  sapinfo.c -o sapinfo -lrfc -lots -lm
#
#SUN (SunPro) :
#==============
#/opt/SUNWspro/bin/cc -Xc -xcg92 -I .../rfcsdk/include -L .../rfcsdk/lib
#    sapinfo.c -o sapinfo -lrfc -lsocket -lnsl -ldl -lm -lw

# This SHOULD work for most cases (well at least Win32, and Linux)
my $ADDITIONAL_LIBS = '-lm -ldl -lpthread -lc ';

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
#  inorder for the linktype dynamic to work, perl must be built with
#  threads, and the rfc library included - see running Configure for perl

use File::Basename qw(dirname basename);
use Getopt::Long;
use vars qw($opt_source $opt_addlibs $opt_help);

&GetOptions("source=s", \$opt_source, "addlibs=s", \$opt_addlibs, "iconv=s", \$opt_iconv, "unicode", \$opt_unicode, "help", \$opt_help);

$ADD_FLAGS = "";
if ($opt_unicode){
  print "O-ohhh -unicode!!\n";
	$ADDITIONAL_LIBS .= '-lsapu16 -lstdc++';
	$ADD_FLAGS = " -DSAP_RFC_TIME -DSAPwithUNICODE -DSAPonLIN -DSAPonUNIX ";
}

my ($iconv_inc, $iconv_lib);
if ($opt_iconv){
	$iconv_inc = $opt_iconv."/include";
	$iconv_lib = $opt_iconv."/lib";
	die "iconv include dir does not exist ($iconv_inc)\n" unless -d $iconv_inc;
	die "iconv lib dir does not exist ($iconv_lib)\n" unless -d $iconv_lib;
	$iconv_inc = "-I".$iconv_inc;
	$iconv_lib = "-L".$iconv_lib." -liconv";
  print "Iconv directory specified: adding $iconv_inc and $iconv_lib\n";
}

# spew forth the help
if ($opt_help){
print <<HELP;

==================================================================
BUILDING HELP
==================================================================

Hello - you obviously need Help! :-)

The whole trouble with the build process is one 
of determining what your OS is, and which RFC
library needs to be linked in, and where that 
library lives.

To help with this there are two command line
options that you can use to point me in the 
right direction:

(1) --source /usr/sap/rfcsdk
  This tells me where to look for your installed
  RFCSDK.  This must be the directory that contains
  the ./lib and ./include directories of the RFCSDK
  In the include directory must be saprfc.h etc.
  By default, this looks in /usr/sap/rfcsdk.
  librfccm is taken in preference to librfc.

(2) --addlibs ' -lm -ldl -lpthread '
  This tells me what additional libraries need to
  be passed in at link time - this can be anything
  that you would put in LDFLAGS.
  By default this is ' -lm -ldl -lpthread '

(3) --unicode
  This tells me that you want to compile in unicode 
  support - to do this you must have the unicode version of the RFC
  library specifically librfcum.xx or librfcu.a and the libsapu16 
  library.
  (good luck!!).

(3) --iconv /some/path/to/iconv
  This says where the path is to iconv (minus the ./include|./lib)
  This path will be added to the build plus the explicit linking 
  of -liconv.

Example:

perl Makefile.PL --source /opt/rfcsdk --addlibs '-lsomethingwacky'

==================================================================

HELP
;
  exit;
}



$ADDITIONAL_LIBS = $opt_addlibs if $opt_addlibs;
unshift(@POSSIBLE_RFC_DIRS, $opt_source) if $opt_source;

my $currdir = dirname($0) || '.';
chdir($currdir) || die("can't change to $currdir: $!");
if($^O eq 'MSWin32') {
    unshift(@POSSIBLE_RFC_DIRS, 'C:/Program Files/SAP/FrontEnd/SAPgui/rfcsdk', 'C:\Program Files\SAP\FrontEnd\SAPgui\rfcsdku\lib', 'c:/rfcsdk');
}

my @CANDIDATE;
my $dir;
for $dir (@POSSIBLE_RFC_DIRS) {
    next unless -d $dir;
    my $candidate = Candidate($dir);
    next unless $candidate && $candidate->[2];
    push(@CANDIDATE, $candidate);
}

if (@CANDIDATE == 1) {
    my($dir, $inc_dir, $lib) = @{$CANDIDATE[0]};
    print "Found $lib installed in $dir\n";
} elsif (@CANDIDATE > 1) {
    if ($opt_unicode){
      print "Found the following librfcu (or librfcum) installations:\n";
		} else {
      print "Found the following librfc (or librfccm) installations:\n";
		}
    for (@CANDIDATE) {
    my($dir, $inc_dir, $lib) = @$_;
      print "\t$lib\t$dir\n";
    }
}

my $RFC_DIR;
if($opt_source && (@CANDIDATE == 1) && $CANDIDATE[0][0]) {
    $RFC_DIR = $CANDIDATE[0][0];
    print "Using --source librfc candidate found at $RFC_DIR\n";
} else {
    if($ARGV[0] =~ /^[a-z]\:|^\//i) {
    $RFC_DIR = shift;
    } else {
    unless($CANDIDATE[0][0]) {
          print "No librfc installation found, usually in $POSSIBLE_RFC_DIRS[0]\n";
    }
    $RFC_DIR = prompt "Which librfc build path do you want to link against?", $CANDIDATE[0][0];
    }
  }

my $candidate = &Candidate($RFC_DIR);
unless($candidate) {
    warn "Apparently no librfc installation at '$RFC_DIR'\nAre you sure you got it correct????\n"
      unless -f "$RFC_DIR/include/saprfc.h";
}
$candidate ||= ["$RFC_DIR", "$RFC_DIR/include", 'rfc'];
  
$RFC_INC = "$RFC_DIR/include";
  
if($^O =~ /Win32/) {
    unless($RFC_DIR =~ /^[a-zA-Z]\:/) {
    # default drive c
    $RFC_DIR = "c:".$RFC_DIR;
    }
    unless($RFC_INC =~ /^[a-zA-Z]\:/) {
      # default drive c
      $RFC_INC = "c:".$RFC_INC;
    }
    $RFC_INC = "\"$RFC_INC\"";
    $RFC_DIR =~ s|/|\\|g;
    $RFC_INC =~ s|/|\\|g;

    # patch from Ben Laurie
    if(-d "$RFC_DIR/lib") {
      $RFC_LIB = "-L\"$RFC_DIR/lib\"";
    } elsif(-d "$RFC_DIR/out32dll") {
      $RFC_LIB = "-L\"$RFC_DIR\\out32dll\"";
    }else {
    # Allow developers to point at librfc source...
      $RFC_LIB = "-L\"$RFC_DIR\"";
    }

    $SEP = "\\";
    $LIBS = ' -l'.$candidate->[2];
} else {
    $RFC_LIB = "-L".$RFC_DIR."/lib";
    $SEP = "/";
    $LIBS = ' -l'.$candidate->[2];
  
    # ccc on alpha support
    if ($^O eq 'linux' && `uname -m` =~ /alpha/ &&
        !(system("nm $RFC_DIR/lib/librfc.a|grep -q 'U _Ots'")>>8)) {
      $LIBS .= ' -lots'; 
    }
}

my $candidate_info = join('; ', @$candidate);

if($^O eq 'MSWin32' && $opt_unicode){
  $LIBS .= ' -lsapucum ';
}
  
print <<INFO;

================================================
BUILD INFORMATION
================================================

rfc dir:        $RFC_DIR
libraries:      $ADDITIONAL_LIBS $RFC_LIB $LIBS
include dir:    $RFC_INC
rfc header:     $RFC_INC/saprfc.h
rfc candidate:  $candidate_info

================================================

INFO
;


WriteMakefile(
    clean => { 'FILES'    => 'CPICTRC* ./.rfc_cache/* ./examples/.rfc_cache/* ./examples/*.trc ./examples/CPICTRC* *.inl *.trc testconn ./examples/testconn *~ core test*.txt *.tar.gz _Inline ./examples/_Inline' },
    dist => { 'TARFLAGS'    => 'cvf',
              'COMPRESS'        => 'gzip -9f',
            'SUFFIX'    => '.tgz'},
    'AUTHOR' => 'Piers Harding <piers@cpan.org>',
    'ABSTRACT' => 'Perl extension for performing RFC Function calls agains an SAP R/3 System',
    'LINKTYPE'    => 'dynamic',
    'VERSION_FROM'    => 'Rfc.pm',
    'NAME'    => 'SAP::Rfc',
#     DEFINE => ' -D'.(($^O =~ /aix/i)? 'DOIBMWKRND' : 'SUMITELSE')." $ADD_FLAGS ",
     DEFINE => '-g -Wall -D'.(($^O =~ /aix/i)? 'DOIBMWKRND' : 'SUMITELSE')." $ADD_FLAGS ",

    'LIBS'      => ["$ADDITIONAL_LIBS $RFC_LIB $LIBS $iconv_lib"],
    'INC'    => "-I".$RFC_INC ." ".$iconv_inc,

);

sub MY::makefile { '' }

sub MY::processPL { '' }


sub MY::c_o {
  my $self = shift; 
  my $section = $self->MM::c_o;
  if ($opt_unicode && $^O !~ /MSWin32/i){
    $section =~ s/(\$\*\.i)/$1i\n\t\$\(FULLPERL\) u16lit\.pl \-le \$\(BASEEXT\)\.ii/s;
		#.c$(OBJ_EXT):
		#        $(CCCMD) $(CCCDLFLAGS) "-I$(PERL_INC)" $(PASTHRU_DEFINE) $(DEFINE) $*.c
		#
    $section =~ s/(\.c\$\(OBJ_EXT\)\:.*? \$\*\.)c/$1i/s;
    #print STDERR "c_o: $section\n";
	}
  return $section;
}


# add the manifest for win32
sub MY::dynamic_lib { 
  my $self = shift; 
  my $section = $self->MM::dynamic_lib;
	if ($^O =~ /MSWin32/i && $EMBED_MANIFEST){
	  $section .= "\tcd blib\\arch\\auto\\SAP\\Rfc\n";
	  $section .= "\tmt.exe -outputresource:Rfc.dll;2 -manifest Rfc.dll.manifest\n";
	  $section .= "\tcd ..\\..\\..\\..\\..\n";
	}
  if ($opt_unicode && $^O !~ /MSWin32/i){
	  $section =~ s/(\$\(INST_DYNAMIC\)\: )/$1\$\(BASEEXT\)\.i /s;
	#  print STDERR "dynamic_lib: $section\n";
	}
	return $section;
}


# Get input values for testing
unless ($ENV{ASHOST}){
print "\n\n\n";
print "Welcome to The SAP::Rfc Object oriented Programming Interface for \n";
print "performing RFC calls to an SAP R\/3 System\.\n";
print "YOU MUST READ THE README FILE THAT COMES WITH THIS DISTRIBUTION\n";
print "AND UNDERSTAND THE TERMS AND CONDITIONS THEREIN.\n\n\n";
print "           ---------------- Please Press Enter --------------- \n";
$x=<>;
print 
    <<ENDOFTEXT;
    Copyright (c) 2002 - 2006 Piers Harding.
    All rights reserved.

    This program is free software; you can redistribute it and/or modify
    it under the terms of either:

    a) the GNU General Public License as published by the Free
    Software Foundation; either version 1, or (at your option) any
    later version, or

    b) the "Artistic License" which comes with this Kit.

    This software is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
    the GNU General Public License or the Artistic License for more details.

    You should have received a copy of the Artistic License with this
    Kit, in the file named "Artistic".  If not, I'll be glad to provide one.

    You should also have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software Foundation,
    Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

ENDOFTEXT

print "           ---------------- Please Press Enter --------------- \n";
$x=<>;
}

print "\nPlease Enter The Following:\n";
open(FIL,">testconn") or die "cant open parm file: $!";
open(FILCP,">examples/testconn") or die "cant open parm file: $!";
&get("ASHOST", "Test SAP System Hostname:",($ENV{ASHOST} ||"localhost"));
&get("SYSNR", "System Number:",($ENV{SYSNR} || "00"));
&get("CLIENT", "Client Number:",($ENV{CLIENT} || "000"));
&get("LANG", "Login Language:",($ENV{SAPLANG} || "en"));
&get("USER", "User Id:",($ENV{SAPUSER} || "DEVELOPER"));
&get("PASSWD", "Password:",($ENV{PASSWD} || "developer"));
&get("TRACE", "Trace Level:","1");
close FIL;
close FILCP;

print "Were on our way .............\n";

# routine for each parameter
sub get{
 my $parm = shift;
 my $parmdesc = shift;
 my $parmdefault = shift;
 print "Enter $parm - $parmdesc \[$parmdefault\] ";
 my $val = <> unless $ENV{ASHOST};
 chomp $val;
 $val =~ s/^\s*?(\S+)\s*?$/$1/;
 if ( $val !~ m/^$/ ){
   print FIL "$parm\t$val\n";
   print FILCP "$parm\t$val\n";
 } else {
   print FIL "$parm\t$parmdefault\n";
   print FILCP "$parm\t$parmdefault\n";
 };
 print "\n" if $ENV{ASHOST};

}


sub Candidate {
    my $dir = shift;
    my $inc_dir;
    my @libs = ();

    for (
     "$dir/include/saprfc.h"
    ) 
      {
      if(-e $_) {
          $version_file = $_;
      } 
      }
    return unless defined $version_file;

    #$open_rfc = ($version_file =~ /openrfc/) ? 1 : 0;
    my $dirname = $inc_dir = dirname($version_file);
    return unless (-e "$dirname/saprfc.h");

    # Silly test to look for the library files
    my $libd = (-d "$dir/out32dll") ? 'out32dll' : 'lib';
    if (opendir(LIBDIR, "$dir/$libd")) {
    while (defined($_ = readdir(LIBDIR))) {
		    if ($opt_unicode){
          if($^O eq 'MSWin32') {
            push(@libs, 'rfc32u') if /rfc32u/i;
            push(@libs, 'rfcum') if /^librfcum/;
            push(@libs, 'rfcu') if /^librfcu\./;
					} else {
            push(@libs, 'rfcum') if /^librfcum/;
            push(@libs, 'rfcu') if /^librfcu\./;
					}
				} else {
          push(@libs, 'rfc32') if /rfc32/i;
          push(@libs, 'rfccm') if /^librfccm/;
          push(@libs, 'rfc') if /^librfc/;
				}
    }
    closedir(LIBDIR);
    }
		if ($opt_unicode){
      warn "$dir/lib does not seem to contain the librfcu (or librfcum) library files\n"
        unless scalar @libs;
		} else {
      warn "$dir/lib does not seem to contain the librfc (or librfccm) library files\n"
        unless scalar @libs;
		}
    @libs = reverse sort @libs;

    [$dir, $inc_dir, shift @libs];
}

