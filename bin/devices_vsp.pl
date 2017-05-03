#!/usr/bin/perl
#
# Auteur : Jean-Laurent MARTINEZ
# Creation : 23 Nov 2011 15:27:31
# Derniere modification : 11 fevrier 2016 
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
my $chemin;
$chemin = "/admin/Emc_mig/trait_baies";
chomp ($chemin);
#------------------------------------Synopsis pour Option------------------------------------
=head1 SYNOPSIS

usage: devices_vsp.pl [--verbose] [--help] [--debug] [--BatI] [--BatG]
	Verbose : Mode Verbeux
	Debug : Affhichage des tableaux
	BatI : Liste des Ldev Batiment I
	BatG : Liste des Ldev Batiment G	
=cut

#my $OPTS = $ARGV[0];
my ($optVerbose,$optHelp,$optBati,$optBatg,$optdebug);
GetOptions( "verbose!"=>\$optVerbose,
                "help|?",\$optHelp,
                "BatI"=>\$optBati,
		"BatG"=>\$optBatg),
                "debug"=>\$optdebug;
                
pod2usage(1) if ( $optHelp );

open (fichier,">$chemin/Ldev_bat_all.log") || die ("Erreur d'ouverture de fichier");
close (fichier);

my @baies = ('85183','53317');
#my @baies = '53317';

foreach (@baies){

	my @device= ();
	my @tab_res = ();

#	@tab_res=`/produit/CCI/HiCommandCLI GetStorageArray "serialnum=85183" model=R700 subtarget=LDEV ldevsubinfo=VolumeConnection, -f xml`if ($optBati);
#	@tab_res=`/produit/CCI/HiCommandCLI GetStorageArray "serialnum=53317" model=R700 subtarget=LDEV ldevsubinfo=VolumeConnection, -f xml`;
	@tab_res=`/produit/CCI/HiCommandCLI GetStorageArray "serialnum=$_" model=R700 subtarget=LDEV ldevsubinfo=VolumeConnection, -f xml`;
	
	my $res = join('',@tab_res);
	print "sc : ".scalar(@tab_res)."\n" if ($optdebug);
	print $tab_res[1]."\n" if ($optdebug);


	my $parser = XML::LibXML->new();
	my $tree = $parser->parse_string($res);
	my $root = $tree->getDocumentElement;
	my $debug = 2;
	my $line = "";
	my @devices_vsp = ();

	my @storages = $root->getElementsByTagName('StorageArray'); 
 
	foreach my $storage (@storages) {
		my @devices = $storage->getElementsByTagName('LDEV');
	        foreach my $dev (@devices) {
			my @label = $dev->getElementsByTagName('ObjectLabel');
			if (@label){
		                foreach my $monlabel (@label) {
#	 if ($dev->getAttribute('displayName') !~ /00:FE|00:FC|00:FB|7F/){
	   		        print $storage->getAttribute('serialNumber').${separateur}.$dev->getAttribute('displayName').${separateur}.$dev->getAttribute('sizeInKB').${separateur}.$dev->getAttribute('lba').${separateur}.$dev->getAttribute('dpPoolID').${separateur}.$dev->getAttribute('consumedSizeInKB').${separateur}.$monlabel->getAttribute('label') if ($optVerbose);
			     push(@devices_vsp,$_.${separateur2}.$dev->getAttribute('displayName').${separateur2}.$dev->getAttribute('sizeInKB').${separateur2}.$dev->getAttribute('lba').${separateur2}.$dev->getAttribute('dpPoolID').${separateur2}.$dev->getAttribute('consumedSizeInKB').${separateur2}.$monlabel->getAttribute('label').${separateur});
	     			}
			}
			else {

			print $storage->getAttribute('serialNumber').${separateur}.$dev->getAttribute('displayName').${separateur}.$dev->getAttribute('sizeInKB').${separateur}.$dev->getAttribute('lba').${separateur}.$dev->getAttribute('dpPoolID').${separateur}.$dev->getAttribute('consumedSizeInKB').${separateur} if ($optVerbose);

                             push(@devices_vsp,$_.${separateur2}.$dev->getAttribute('displayName').${separateur2}.$dev->getAttribute('sizeInKB').${separateur2}.$dev->getAttribute('lba').${separateur2}.$dev->getAttribute('dpPoolID').${separateur2}.$dev->getAttribute('consumedSizeInKB').${separateur2}.${separateur});
			}
	 	}
	}
	
#	open (fichier,">$chemin/Ldev_batI.log") || die ("Erreur d'ouverture de fichier") if ($optBati);
#	open (fichier,">$chemin/Ldev_batG.log") || die ("Erreur d'ouverture de fichier") if ($optBatg);
	open (fichier,">>$chemin/Ldev_bat_all.log") || die ("Erreur d'ouverture de fichier");


	foreach my $affich (@devices_vsp) {
#		print "$affich\n";			
        #print fichier $affich->getAttribute('displayDevNum');
		print fichier $affich;
	}


}



