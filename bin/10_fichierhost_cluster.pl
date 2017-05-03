#!/usr/bin/perl

# Auteur : Jean-Laurent MARTINEZ
# Creation : 23 Nov 2011 15:27:31
# Derniere modification : 10 fevrier 2016

use strict;

use Pod::Usage;
use Getopt::Long;
use XML::LibXML;
use Data::Dumper;
use POSIX qw(strftime);
my $cheminsrc;
$cheminsrc = "/admin/Emc_mig/trait_baies";
chomp ($cheminsrc);
#------------------------------------Synopsis pour Option------------------------------------
=head1 SYNOPSIS

usage: fichierhost_cluster serveur serveur [--verbose] [--help] [--debug]
        arg 1: le premier le Serveur
        Debug : Affhichage des tableaux
        BatI : Liste des Ldev Batiment I
        BatG : Liste des Ldev Batiment G
=cut


my ($optVerbose,$optHelp,$optdebug,$optrefresh,$optr2,$optall,$optrefresh);
GetOptions( "verbose!"=>\$optVerbose,
                "help|?",\$optHelp,
		"all"=>\$optall,
		"refresh"=>\$optrefresh,
		"R2"=>\$optr2,
                "refresh|?",\$optrefresh,
                "debug"=>\$optdebug);

pod2usage(1) if ( $optHelp );
print "###############################################################################################################\n";
print "########  Script de creation du fichier table_disk.emc des autres membres du clusters	######################\n";
print "########                 fichierhost_cluster serveur_source serveur_destination		######################\n";
print "########         									#######################\n";	
print "################################################################################################################\n\n\n\n\n";
print "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";


my $HG_SRC = sprintf uc ($ARGV[0]);
my $HG_DST = sprintf uc ($ARGV[1]);
my $l_hgsrc = lc($HG_SRC);
my $l_hgdst = lc($HG_DST);

if (($HG_SRC eq "")){
        print "\n###################Merci de saisir le hostgroup source ###################\n\n";
        exit 1;
}

if (($HG_DST eq "")){
        print "\n###################Merci de saisir le hostgroup destination ###################\n\n";
        exit 1;
}



open (fichiersrc,"</mnt/MIG_EMC/lpar/$l_hgsrc/result/table_disk.emc.txt");
my @tab_fichiersrc = <fichiersrc>;
close (fichiersrc);
open (fichierdst,"</mnt/MIG_EMC/lpar/$l_hgdst/result/table_disk.vsp.txt");
my @tab_fichierdst = <fichierdst>;
close (fichierdst);


foreach (@tab_fichiersrc){

	my ($ldev,undef,undef,undef,undef,undef,undef,undef,$wwn) = split /;/, $_;
	chomp ($ldev);
	chomp ($wwn);
	print "mon ldev: #$ldev# -> $wwn\n";
	my @ligne = grep (/\Q$ldev/,@tab_fichierdst);
	if (@ligne){
		open (fichierdst,">>/mnt/MIG_EMC/lpar/$l_hgdst/result/table_disk.emc.txt");
		chomp (@ligne[0]);
		print "@ligne[0]--> $wwn;\n";
		print fichierdst "@ligne[0]$wwn;\n";
		close(fichierdst);
	}
	else { print "absent\n";}
}
