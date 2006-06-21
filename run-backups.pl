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

use Win32::Registry;
use Tk;
use Tk::Pane;

my $reg;
my @backup_projects;
my $fr;
my %backups;
my $main = MainWindow->new(
	-title =>	'SyGroup cwBackup',
	-height =>	500,
	-width =>	600,
);

sub clear_widget
{
	my ($widget) = @_;

	foreach my $child ($widget->children)
	{
		$child->destroy();
	}
}

sub call_script
{
	my ($script) = @_;

	foreach my $key (keys(%backups))
	{
		if ($backups{$key})
		{
			system({'perl'} 'perl', $script . '.pl', $key) == 0 or
				$main->messageBox(
					-icon =>	'error',
					-title =>	'Fehler',
					-message =>	'Konnte Backup von ' .
						$key . ' nicht durchfuehren: ' .
						'Konnte ' . $script .
						' nicht ausfuehren: ' . $!,
					-type =>	'Ok'
				);
		}
	}
}

$main->Label(-text =>	'Bitte warten...')->pack();
$main->update();
$main->MapWindow();

$HKEY_CURRENT_USER->Open('Software\\SyGroup GmbH\\cwBackup', $reg) or
	die('Kann nicht zur Registrierung verbinden: ' . $^E);
$reg->GetKeys(\@backup_projects) or
	die('Kann die Liste der Backups nicht aus der Registrierung lesen: ' .
		$^E);
$reg->Close();

clear_widget($main);

$main->Label(
	-text => 'Bitte waehlen Sie die auszufuehrenden Backups!',
)->pack();

$fr = $main->Scrolled(Frame, -scrollbars => 'oe');
foreach my $backup (@backup_projects)
{
	my $frame = $fr->Frame();
	my $label;
	$backups{$backup} = 0;
	$frame->Checkbutton(
		-onvalue =>	1,
		-offvalue =>	0,
		-variable =>	\$backups{$backup}
	)->pack(-side => 'left');
	$label = $frame->Label(
		-text =>	$backup
	);
	$label->bind('<Button-1>' =>	sub {
			$backups{$backup} = !$backups{$backup};
		}
	);
	$label->pack(-side => 'left');
	$frame->pack();
}
$fr->pack();

$fr = $main->Frame();
$fr->Button(
	-text =>	'Sichern',
	-command =>	sub {
		call_script('cwbackup');
	}
)->pack(-side => 'left');
$fr->Button(
	-text =>	'Wiederherstellen',
	-command =>	sub {
		call_script('cwrestore');
	}
)->pack(-side => 'left');
$fr->Button(
	-text =>	'Beenden',
	-command =>	sub {
		Tk::exit(0);
	}
)->pack(-side => 'right');
$fr->pack();

MainLoop();

exit(0);
