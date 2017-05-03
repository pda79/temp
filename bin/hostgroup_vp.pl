#!/usr/bin/perl
#
# Auteur : Jean-Laurent MARTINEZ
# Creation : 23 Nov 2011 
# Derniere modification : 23 Nov 2011 
#

use vars qw($separateur);
use vars qw($separateur2);
$separateur2 = ";";
$separateur = "\n";
use strict;
use Pod::Usage;
use Getopt::Long;
use XML::LibXML;
use Data::Dumper;
my $cheminsrc;
#$chemin = "/travail/ppr1/cci/ptech/ptech_TC/log";
$cheminsrc = "/admin/Emc_mig/trait_baies"; 
chomp ($cheminsrc);
#------------------------------------Synopsis pour Option------------------------------------
=head1 SYNOPSIS

usage: hostgroup_vsp.pl [--verbose] [--BatI] [--BatG] [--help] [--debug]
	BatG : lancement sur la baie du batiment G
	BatI : lancement sur la baie du batiment I
	
=cut

my ($optVerbose,$optHelp,$optdebug,$optBase,$optBati,$optBatg);
GetOptions( "verbose!"=>\$optVerbose,
                "help|?",\$optHelp,
                "debug"=>\$optdebug,
		"BatI"=>\$optBati,
                "BatG"=>\$optBatg);

pod2usage(1) if ( $optHelp );
#---------------------------------------------------------------------------------------------
#----------------------------Interogation baie pour HG Device et Wwn--------------------------
my @baies = ('85183','53317');

open (fichier,">$cheminsrc/host_group_device_all.log") || die ("Erreur d'ouverture de fichier");
close (fichier);

foreach (@baies){
	my $parser = XML::LibXML->new();
	print "Traitement Baie : #$_# \n" if ( $optdebug );	
	my @device= ();
	my @tab_res = ();
#	@tab_res=`/produit/CCI/HiCommandCLI GetStorageArray subtarget=HostStorageDomain "serialnum=85183" "model=R700" hsdsubinfo=path,wwn -f xml` if ($optBati);
#	@tab_res=`/produit/CCI/HiCommandCLI GetStorageArray subtarget=HostStorageDomain "serialnum=53317" "model=R700" hsdsubinfo=path,wwn -f xml` if ($optBatg);
	@tab_res=`/produit/CCI/HiCommandCLI GetStorageArray subtarget=HostStorageDomain serialnum=$_ model=R700 hsdsubinfo=path,wwn -f xml`;	

	my $res = join('',@tab_res);
	print "sc : ".scalar(@tab_res)."\n" if ($optdebug);
	print $tab_res[1]."\n" if ($optdebug);

	my $tree = $parser->parse_string($res);
	my $root = $tree->getDocumentElement;
	my $debug = 2;
	my $line = "";
	my @hostgroups_vsp = ();
	my @storages = $root->getElementsByTagName('StorageArray'); 

	#------------------------------------traitement du resultat Xml------------------------- 
	foreach my $storage (@storages) {
		my @hostgroups = $storage->getElementsByTagName('HostStorageDomain');
		    foreach my $hostgroup (@hostgroups) {
			print $storage->getAttribute('serialNumber').${separateur}.$hostgroup->getAttribute('nickname').${separateur}.$hostgroup->getAttribute('portName').${separateur}.$hostgroup->getAttribute('hostMode') if ($optVerbose);
			my @wwnhostgroups = $hostgroup->getElementsByTagName('WWN');
			foreach my $wwnhostgroup (@wwnhostgroups) {
				my @devicehostgroups = 	$hostgroup->getElementsByTagName('Path');
				foreach my $devicehostgroup (@devicehostgroups) {
					print $devicehostgroup->getAttribute('displayDevNum').${separateur2}.$devicehostgroup->getAttribute('portName').${separateur2}.$devicehostgroup->getAttribute('LUN').${separateur} if ($optVerbose);
					push(@hostgroups_vsp,$_.${separateur2}.$devicehostgroup->getAttribute('displayDevNum').${separateur2}.$hostgroup->getAttribute('nickname').${separateur2}.$devicehostgroup->getAttribute('LUN').${separateur});
				}
			}
		
		   }
	}

	#----------------------------------Ouverture des fichiers-------------------------------
	open (fichier,">>$cheminsrc/host_group_device_all.log") || die ("Erreur d'ouverture de fichier");
	#open (fichier,">$cheminsrc/host_group_device_batI.log") || die ("Erreur d'ouverture de fichier") if ($optBati);
	#open (fichier,">$cheminsrc/host_group_device_batG.log") || die ("Erreur d'ouverture de fichier") if ($optBatg);
	
	foreach my $affich (@hostgroups_vsp) {
			print fichier $affich;
	}
	close (fichier);


}
