#!/usr/bin/perl
#
# Auteur : Jean-Laurent MARTINEZ
# Creation : 08 juillet 2015 
# Derniere modification : 
#
# Description : Script de migration Hds vers EMC   
#		Ce dernier permet de creer des instances de migration
#		
#		


use Getopt::Long;
use strict;
use POSIX qw(strftime);
my $datestring = strftime "%Y-%m-%d_%H-%M", localtime;
print("date and time :$datestring\n");
my $chemin;
my $cheminsrc;
$cheminsrc = "/admin/Emc_mig/trait_baies";
chomp ($chemin);

open(FIC,"<$cheminsrc/host_group_device_all.log");
my @tabhg = <FIC>;
close(FIC);

my %doublon = ();
my @unique = grep { ! $doublon{ $_ }++ } @tabhg;

open (fichierlog,">/mnt/MIG_EMC/Traitement_baies/host_group_device_all.log") || die ("Erreur d'ouverture de fichier");

foreach (@unique){

	print fichierlog $_;


}

