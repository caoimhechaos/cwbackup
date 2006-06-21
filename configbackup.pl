#!/usr/bin/perl -w
#
# (c) 2006, Caoimhe Chaos <caoimhechaos@protonmail.com>,
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

#
# This doesn't seem to work under Windows. :-(
#
# BEGIN {
#	fork and exit;
# }

use strict;
use Tk qw(exit MainLoop Exists);
use Tk::Widget;
use Tk::Font;
use Tk::Frame;
use Tk::FileSelect;
use Data::Dumper;
use Win32::Registry;

my $main;
my $editwin;
my $rsyncwin;

sub end_edit_target
{
	my ($name, $dst, $src, $del) = @_;
	my $regkey;
	if (!defined($name) || !length($name) || $name eq 'Neues Backup')
	{
		$main->messageBox(
			-icon => 'error',
			-title => 'Kein Name angegeben',
			-message => 'Um ein neues Backup speichern zu ' .
				'koennen, muessen Sie einen Namen angeben!',
			-type => 'Ok'
		);
		return;
	}

	if (!$HKEY_CURRENT_USER->Create('SOFTWARE\\SyGroup GmbH\\cwBackup\\' .
	       $name, $regkey))
       	{
		$main->messageBox(
			-icon => 'error',
			-title => 'Fehler',
			-message => 'Konnte Backup nicht in die Registry ' .
				'speichern.',
			-type => 'Ok'
		);
		return;
	}

	$regkey->SetValueEx('source', 0, REG_SZ, $src);
	$regkey->SetValueEx('target', 0, REG_SZ, $dst);
	$regkey->SetValueEx('delete', 0, REG_DWORD, $del);
	$regkey->Close();

	if (Exists($editwin))
	{
		$editwin->destroy();
		$editwin = undef;
	}
}

sub edit_target
{
	my ($name) = @_;

	my $nameframe;
	my $namebutton;
	my $targetframe;
	my $target;
	my $sourceframe;
	my $source;
	my $deleteframe;
	my $delete = 0;
	my $label;

	if (defined($name) && length($name))
	{
		my $regkey;
		if ($HKEY_CURRENT_USER->Open('SOFTWARE\\SyGroup GmbH\\cwBackup\\' .
		       $name, $regkey))
       		{
			$regkey->QueryValueEx('target', REG_SZ, $target);
			$regkey->QueryValueEx('source', REG_SZ, $source);
			$regkey->QueryValueEx('delete', REG_SZ, $delete);
			$regkey->Close();
		}
	}

	if (Exists($editwin))
	{
		$editwin->raise();
		return;
	}

	$name = 'Neues Backup' unless defined($name);

	$editwin = $main->Toplevel(
		-title =>	$name . ' - SyGroup cwBackup',
	);

	$editwin->OnDestroy(sub {
		foreach my $child ($main->children)
		{
			$child->destroy();
		}
		list_targets();
	});

	$targetframe = $editwin->Frame(-relief => 'ridge', -borderwidth => 2);
	$sourceframe = $editwin->Frame(-relief => 'ridge', -borderwidth => 2);

	if ($name eq 'Neues Backup')
	{
		$nameframe = $editwin->Frame(
			-relief => 'ridge',
			-borderwidth => 1
		);

		$nameframe->Label(-text => 'Name des Backups')
			->pack(-side => 'left', -fill => 'x');
		$nameframe->Entry(-width => 15, -textvariable => \$name)
			->pack(-side => 'right', -fill => 'y');
		$nameframe->pack(-side => 'top', -fill => 'x');
	}

	$editwin->Label(-text => 'Quellverzeichnis des Backups')
		->pack(-side => 'top', -fill => 'x');
	$sourceframe->Entry(-width => 25, -textvariable => \$source)
		->pack(-side => 'left', -fill => 'y');
	$sourceframe->Button(-text => 'Suchen',
		-command => sub {
			my $defdir = (defined($source) && -d $source) ?
				$source : $ENV{HOMEDRIVE} . $ENV{HOMEPATH};
			my $sourcesel = $editwin->FileSelect(
				-title => 'Quellverzeichnis',
				-directory => $defdir
			);
			my $_source;
			$sourcesel->configure(-verify => [ '-d' ]);
			$_source = $sourcesel->Show();

			if (defined($_source) && length($_source))
			{
				$_source =~ s/\//\\/g;
				$source = $_source;
			}
		})->pack(-side => 'right', -fill => 'x');
	$sourceframe->pack();

	$editwin->Label(-text => 'Zielverzeichnis fuer das Backup')
		->pack(-side => 'top', -fill => 'x');
	$targetframe->Entry(-width => 25, -textvariable => \$target)
		->pack(-side => 'left', -fill => 'x');
	$targetframe->Button(-text => 'Suchen',
		-command => sub {
			my $defdir = (defined($target) && -d $target) ?
				$target : $ENV{HOMEDRIVE} . $ENV{HOMEPATH};
			my $targetsel = $editwin->FileSelect(
				-title => 'Zielverzeichnis',
				-directory => $defdir
			);
			my $_target;
			$targetsel->configure(-verify => [ '-d' ]);
			$_target = $targetsel->Show();

			if (defined($_target) && length($_target))
			{
				$_target =~ s/\//\\/g;
				$target = $_target;
			}
		})->pack(-side => 'right', -fill => 'x');
	$targetframe->pack();

	$deleteframe = $editwin->Frame(-relief => 'ridge', -borderwidth => 2);
	$deleteframe->Checkbutton(
		-variable =>	\$delete
	)->pack(-side => 'left', -fill => 'y');
	$label = $deleteframe->Label(
		-text => 'Lokal nicht mehr vorhandene Dateien auf dem Server' .
			'loeschen?'
	);
	$label->bind('<Button-1>' =>	sub {
		$delete = !$delete;
	});
	$label->pack(-side => 'right', -fill => 'y');
	$deleteframe->pack();

	$editwin->Button(
		-text    => 'Ok',
		-command => sub {
			end_edit_target($name, $target, $source, $delete);
		},
	)->pack;
}

sub end_set_rsync_path
{
	my ($rsync_path) = @_;
	my $regkey;

	if (!defined($rsync_path) || !length($rsync_path) || ! -f $rsync_path)
	{
		$main->messageBox(
			-icon => 'error',
			-title => 'Kein rsync-Programm angegeben',
			-message => 'Bitte waehlen Sie den Pfad eines ' .
				'rsync-Programms aus!',
			-type => 'Ok'
		);
		return;
	}

	if (!$HKEY_LOCAL_MACHINE->Create('SOFTWARE\\SyGroup GmbH\\cwBackup',
			$regkey))
       	{
		$main->messageBox(
			-icon => 'error',
			-title => 'Fehler',
			-message => 'Konnte rsync-Pfad nicht in die Registry ' .
				'speichern.',
			-type => 'Ok'
		);
		return;
	}

	$regkey->SetValueEx('rsync', 0, REG_SZ, $rsync_path);
	$regkey->Close();

	if (Exists($rsyncwin))
	{
		$rsyncwin->destroy();
		$rsyncwin = undef;
	}
}

sub isarsyncbin
{
	my ($win, $cd, $leaf) = @_;

	if (! -f ($cd . '/' . $leaf))
	{
		$main->messageBox(
			-icon => 'error',
			-title => 'Fehler',
			-message => 'Das ausgewaehlte Objekt (' . $leaf .
				') ist keine Datei.',
			-type => 'Ok'
		);
		return 0;
	}

	if ($leaf =~ /^rsync.*\.exe$/i)
	{
		return 1;
	}
	else
	{
		$main->messageBox(
			-icon => 'error',
			-title => 'Fehler',
			-message => 'Die gewaehlte Datei (' . $leaf .
				') ist kein gueltiges rsync-Programm!',
			-type => 'Ok'
		);
		return 0;
	}
}

sub set_rsync_path
{
	my $regkey;
	my $seachbut;
	my $rsync_path;
	my $settingsframe;

	if ($HKEY_LOCAL_MACHINE->Open('SOFTWARE\\SyGroup GmbH\\cwBackup',
					$regkey))
       	{
		$regkey->QueryValueEx('rsync', REG_SZ, $rsync_path);
		$regkey->Close();
	}
	
	if (!defined($rsync_path) || !length($rsync_path))
	{
		if (-f 'c:/Program Files/cwRsync/bin/rsync.exe')
		{
			$rsync_path = 'c:/Program Files/cwRsync/bin/rsync.exe';
		}
		elsif (-f 'c:/Programme/cwRsync/bin/rsync.exe')
		{
			$rsync_path = 'c:/Programme/cwRsync/bin/rsync.exe';
		}
		else
		{
			$rsync_path = 'c:/';
		}
	}

	if (Exists($rsyncwin))
	{
		$rsyncwin->raise();
		return;
	}

	$rsyncwin = $main->Toplevel(
		-title =>	'rsync-Pfad setzen - SyGroup cwBackup'
	);

	$settingsframe = $rsyncwin->Frame();
	$settingsframe->Label(-text => 'Pfad fuer rsync:')
		->pack(-side => 'left', -fill => 'x');
	$settingsframe->Entry(-width => 25, -textvariable => \$rsync_path)
		->pack(-side => 'left', -fill => 'x');
	$settingsframe->Button(
		-text => 'Suchen...',
		-command => sub {
			my $defpath;
			my $targetsel;

			if (-d $rsync_path)
			{
				$defpath = $rsync_path;
			}
			else
			{
				my @parts = split('/', $rsync_path);
				pop(@parts);
				$defpath = join('/', @parts);

				if (!length($defpath))
				{
					$defpath = $ENV{HOMEDRIVE} .
						$ENV{HOMEPATH};
				}
			}

			$targetsel = $rsyncwin->FileSelect(
				-title => 'Pfad fuer das rsync-Programm',
				-directory => $defpath
			);
			my $_target;
			$targetsel->configure(-verify => [ '-f', [ \&isarsyncbin ] ]);
			$_target = $targetsel->Show();

			if (defined($_target) && length($_target))
			{
				$_target =~ s/\//\\/g;
				$rsync_path = $_target;
			}
	})->pack(-side => 'right', -fill => 'x');
	$settingsframe->pack();

	$rsyncwin->Button(
		-text    => 'Ok',
		-command => sub {
			end_set_rsync_path($rsync_path);
		},
	)->pack(-side => 'left');

	$rsyncwin->Button(
		-text    => 'Abbrechen',
		-command => sub {
			$rsyncwin->destroy();
			$rsyncwin = undef;
		},
	)->pack(-side => 'right');
}

sub list_targets
{
	my $cwbackup;
	my @backup_targets;
	my $font;
	my $labels;
	my $buttonframe;

	$font = $main->Font(-underline => 1);
	$labels = $main->Frame(-relief => 'ridge', -borderwidth => 2);

	$HKEY_CURRENT_USER->Create('SOFTWARE\\SyGroup GmbH\\cwBackup',
		$cwbackup) or
		die('Konnte Registrierungsschluessel nicht erzeugen: ' . $^E);

	$cwbackup->GetKeys(\@backup_targets);
	$main->Label(
		-text => 'Bitte waehlen Sie das zu bearbeitende Backup!'
	)->pack();

	foreach my $target (@backup_targets)
	{
		my $label = $labels->Label(
			-text =>	$target,
			-foreground =>	'blue',
			-font =>	$font
		);

		$label->bind('<Button-1>' =>	sub { edit_target($target); });
		$label->pack();
	}
	$labels->pack();

	$buttonframe = $main->Frame();
	$buttonframe->Button(
		-text    => 'Beenden',
		-command => sub { Tk::exit(0); },
	)->pack(-side => 'left', -fill => 'x');
	$buttonframe->Button(
		-text    => 'Neues Backup',
		-command => sub { edit_target(); },
	)->pack(-side => 'left', -fill => 'x');
	$buttonframe->Button(
		-text	=> 'rsync-Pfad',
		-command => sub { set_rsync_path(); },
	)->pack(-side => 'right', -fill => 'x');
	$buttonframe->pack();
	return;
}

$main = MainWindow->new(
	-title =>	'SyGroup cwBackup',
	-height =>	500,
	-width =>	600,
);

list_targets();
MainLoop;

exit(0);
