#!/usr/bin/perl -w
#
# (c) 2006, Tonnerre Lombard <tonnerre@thebsh.sygroup.ch>,
#	    SyGroup GmbH Reinach. All rights reserved.
#
# Redistribution and use  in source and binary forms,  with or without
# modification, are  permitted provided that  the following conditions
# are met:
#
# * Redistributions  of source  code must  retain the  above copyright
#   notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form  must reproduce the above copyright
#   notice, this  list of conditions  and the following  disclaimer in
#   the  documentation  and/or   other  materials  provided  with  the
#   distribution.
# * Neither  the  name  of  the  SyGroup  GmbH nor  the  name  of  its
#   contributors may  be used to  endorse or promote  products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A  PARTICULAR PURPOSE ARE DISCLAIMED. IN  NO EVENT SHALL
# THE  COPYRIGHT  OWNER OR  CONTRIBUTORS  BE  LIABLE  FOR ANY  DIRECT,
# INDIRECT, INCIDENTAL,  SPECIAL, EXEMPLARY, OR  CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT  NOT LIMITED TO, PROCUREMENT OF  SUBSTITUTE GOODS OR
# SERVICES; LOSS  OF USE, DATA, OR PROFITS;  OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY  THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT  LIABILITY,  OR  TORT  (INCLUDING  NEGLIGENCE  OR  OTHERWISE)
# ARISING IN ANY WAY OUT OF  THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
#

use Win32::Registry;
use Tk;
use Tk::Pane;

my $reg;
my $rsync_path;
my @backup_projects;
my @backupme;

my $main = MainWindow->new(
	-title =>	'SyGroup cwBackup',
	-height =>	500,
	-width =>	600,
);
$main->Label(-text =>	'Bitte warten...')->pack();
$main->update();
$main->MapWindow();

sub humanreadable
{
	my ($bytes) = @_;
	my $ret;

	if (!defined($bytes))
	{
		$bytes = 0;
	}

	if ($bytes > 1610612736)
	{
		$ret = sprintf("%.02f GByte", $bytes / 1073741824);
	}
	elsif ($bytes > 1572864)
	{
		$ret = sprintf("%.02f MByte", $bytes / 1048576);
	}
	elsif ($bytes > 1572864)
	{
		$ret = sprintf("%.02f KByte", $bytes / 1536);
	}
	else
	{
		$ret = sprintf("%d byte", $bytes);
	}

	return $ret;
}

sub pretend
{
	my ($rsync, $src, $dst, $del) = @_;
	my $arg = $del ? '--delete' : '';
	my $line;
	my $parse = 1;
	my @delete;
	my @change;
	my @exclude;
	my %filelist;
	my $buttonframe;
	my $changesframe;
	my $realsrc;
	my $realdst;
	my @parts;
	my $elem = "";

	foreach my $child ($main->children)
	{
		$child->destroy();
	}

	$dst =~ s/\\/\//g;
	$src =~ s/\\/\//g;
	$realdst = $dst;
	$realsrc = $src;
	$dst =~ s/^(\w)\:/\/cygdrive\/$1/g;
	$src =~ s/^(\w)\:/\/cygdrive\/$1/g;

	@parts = split('/', $realsrc);
	while (defined($elem) && !length($elem))
	{
		$elem = pop(@parts);
	}
	$realsrc = join('/', @parts);

	open(RsyncProcess, sprintf("%s -aunv %s \"%s\" \"%s\" |", $rsync,
				$arg, $src, $dst)) or
		die('Unable to start rsync process: ' . $!);
	
	while ($parse && defined($line = <RsyncProcess>))
	{
		$line =~ s/[\r\n]//g;

		if ($line eq "")
		{
			$parse = 0;
		}
		elsif ($line =~ /^building file list/)
		{
		}
		elsif ($line =~ /^created directory /)
		{
		}
		elsif ($line =~ /^deleting /)
		{
			if (!($line =~ /\/$/))
			{
				$line =~ s/^deleting //;
				push(@delete, $line);
			}
		}
		else
		{
			if (!($line =~ /\/$/))
			{
				push(@change, $line);
			}
		}
	}

	close(RsyncProcess);

	if (!@delete && !@change)
	{
		$main->Label(
			-text =>	'Keine Dateien zu sichern.'
		)->pack();
		$main->Button(
			-text =>	'Schliessen',
			-command =>	sub { Tk::exit(0); }
		)->pack();
		MainLoop();
		exit(0);
	}

	$main->Label(
		-text =>	'Bitte entfernen Sie den Haken vor ungewuenschten Aenderungen!'
	)->pack();

	$buttonframe = $main->Frame();
	$buttonframe->Button(
		-text =>	'Alles ankreuzen',
		-command =>	sub {
			foreach my $file (keys %filelist)
			{
				$filelist{$file} = 1;
			}
		},
		-relief =>	'flat',
		-overrelief =>	'raised'
	)->pack(-side => 'left');
	$buttonframe->Button(
		-text =>	'Nichts ankreuzen',
		-command =>	sub {
			foreach my $file (keys %filelist)
			{
				$filelist{$file} = 0;
			}
		},
		-relief =>	'flat',
		-overrelief =>	'raised'
	)->pack(-side => 'right');
	$buttonframe->pack();

	$changesframe = $main->Scrolled(Frame, -scrollbars => 'oe');
	foreach my $deleted (@delete)
	{
		my @st = stat($realdst . '/' . $deleted);
		my $frame = $changesframe->Frame();
		my $label = $frame->Label(
			-text =>	sprintf('Loeschen von %s ' .
						'(Geaendert %s, %s)',
						$realsrc . '/' . $deleted,
						scalar localtime($st[9]),
						humanreadable($st[7]))
		);
		$filelist{$deleted} = 1;
		$frame->Checkbutton(
			-offvalue =>	0,
			-onvalue =>	1,
			-variable =>	\$filelist{$deleted},
		)->pack(-side => 'left');
		$label->bind('<Button-1>' =>	sub {
				$filelist{$deleted} = !$filelist{$deleted};
		});
		$label->pack(-side => 'right');
		$frame->pack();
	}

	foreach my $changed (@change)
	{
		my @st = stat($realsrc . '/' . $changed);
		my $frame = $changesframe->Frame();
		my $label = $frame->Label(
			-text =>	sprintf('Aktualisieren von %s ' .
						'(Geaendert %s, %s)',
						$realsrc . '/' . $changed,
						scalar localtime($st[9]),
						humanreadable($st[7]))
		);
		$filelist{$changed} = 1;
		$frame->Checkbutton(
			-offvalue =>	0,
			-onvalue =>	1,
			-variable =>	\$filelist{$changed}
		)->pack(-side => 'left');
		$label->bind('<Button-1>' =>	sub {
				$filelist{$changed} = !$filelist{$changed};
		});
		$label->pack(-side => 'right');
		$frame->pack();

		if (-f $realdst . '/' . $changed)
		{
			my @st2 = stat($realdst . '/' . $changed);
			$changesframe->Label(
				-text =>	sprintf('Alte Datei %s vom ' .
							'%s, %s', $realdst .
							'/' . $changed, scalar
							localtime($st2[9]),
							humanreadable($st2[7]))
			)->pack();
		}
	}
	$changesframe->pack();

	$buttonframe = $main->Frame();
	$buttonframe->Button(
		-text =>	'Ok',
		-command =>	sub {
			foreach my $file (keys %filelist)
			{
				if (!$filelist{$file})
				{
					push(@exclude,
					     sprintf('--exclude="%s"',$file));
				}
			}

			run_rsync($rsync, $src, $dst, $del, @exclude);
		}
	)->pack(-side => 'left');
	$buttonframe->Button(
		-text =>	'Abbrechen',
		-command =>	sub { Tk::exit(0); },
	)->pack(-side => 'right');
	$buttonframe->pack();

	MainLoop;
	return;
}

sub run_rsync
{
	my ($rsync, $src, $dest, $delete, @exclude) = @_;
	my $cmd;
	my @ret;

	$cmd = $delete ? sprintf('%s --delete -au %s "%s" "%s" 2>&1 |', $rsync,
				join(" ", @exclude), $src, $dest) :
			sprintf('%s -au %s "%s" "%s" 2>&1 |', $rsync,
				join(" ", @exclude), $src, $dest);

	foreach my $child ($main->children)
	{
		$child->destroy();
	}

	close(STDERR);
	open(STDERR, ">&STDOUT");

	$main->Label(-text => 'Backup laeuft...')->pack();
	$main->update();

	open(RsyncProc, $cmd) or die('Unable to start rsync: ' . $!);
	@ret = <RsyncProc>;
	close(RsyncProc);

	foreach my $child ($main->children)
	{
		$child->destroy();
	}

	if (@ret)
	{
		foreach my $line (@ret)
		{
			$line =~ s/[\r\n]//g;
			$main->Label(
				-text =>	$line
			)->pack();
		}
	}
	else
	{
		$main->Label(
			-text => 'Backup erfolgreich.'
		)->pack();
	}

	$main->Button(
		-text =>	'Schliessen',
		-command =>	sub { Tk::exit(0); }
	)->pack();
}

$HKEY_LOCAL_MACHINE->Open('SOFTWARE\\SyGroup GmbH\\cwBackup', $reg) or
	die('Kann nicht zur Registrierung verbinden: ' . $^E);
$reg->QueryValueEx('rsync', REG_SZ, $rsync_path) or
	die('Kann den Pfad von rsync nicht aus der Registrierung lesen: '. $^E);
$reg->Close();

$HKEY_CURRENT_USER->Open('Software\\SyGroup GmbH\\cwBackup', $reg) or
	die('Kann nicht zur Registrierung verbinden: ' . $^E);
$reg->GetKeys(\@backup_projects) or
	die('Kann die Liste der Backups nicht aus der Registrierung lesen: ' .
		$^E);
$reg->Close();

@backupme = @ARGV && $ARGV[0] eq '-a' ? @backup_projects : @ARGV;

foreach my $backup (@backupme)
{
	my $source;
	my $target;
	my $delete;
	my @ignorelist;

	$HKEY_CURRENT_USER->Open('Software\\SyGroup GmbH\\cwBackup\\' . $backup,
		$reg) or die('Kann nicht zur Registrierung verbinden: ' . $^E);
	$reg->QueryValueEx('source', REG_DWORD, $source);
	$reg->QueryValueEx('target', REG_DWORD, $target);
	$reg->QueryValueEx('delete', REG_DWORD, $delete);
	$reg->Close();

	pretend($rsync_path, $source, $target, $delete);
}

exit(0);
