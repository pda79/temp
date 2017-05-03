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

usage: verif_creation.pl serveur [--verbose] [--help] [--debug]
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
print "##########################################################################################\n";
print "########  Script de Verification de la création des disques sous vplex   ######################\n";
print "########                 ./verif_creation.pl serveur --R2              	######################\n";
print "########          ./verif_creation.pl serveur --all -refresh 		######################\n";
print "########         genere le fichier pour scan rapide			######################\n";
print "########         ./verif_creation.pl serveur --all	                ######################\n";
print "########         verif serveur rapidement sans interroger le vplex	#######################\n";	
print "##########################################################################################\n\n\n\n\n";
print "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";


my $HG = sprintf uc ($ARGV[0]);


if (($HG eq "")){
        print "\n###################Merci de saisir Un hostgroup###################\n\n";
        exit 1;
}
open(FIC,"<$cheminsrc/Ldev_bat_all.log");# if ($optBati);
my @tab_contenu_LDEV = <FIC>;
close(FIC);

open (FIC,"<$cheminsrc/Ldev_TC.log");
my @tabtc =<FIC>;
close(FIC);

open(FIC,"<$cheminsrc/host_group_device_all.log");
my @tabhg = <FIC>;
close(FIC);
my (@tabcluster1,@tabcluster2);

print "all\n" if($optall);
print "refresh\n" if ($optrefresh);

print "recherche sur Vplex .....\n";
if (($optall) && ($optrefresh)){
	print "Generation fichier \n";	
	@tabcluster1 = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-1/devices/*?name\" |awk -F\\\" '/value/ {print $4}'`;
	open (FICCLUST1, ">$cheminsrc/cluster1.txt");
	foreach (@tabcluster1){	print FICCLUST1 "$_\n";	}
	close (FICCLUST1);
	@tabcluster2 = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-2/devices/*?name\" |awk -F\\\" '/value/ {print $4}'`;
        open (FICCLUST2, ">$cheminsrc/cluster2.txt");
        foreach (@tabcluster2){ print FICCLUST2 "$_\n"; }
        close (FICCLUST2);
	
}
elsif(!$optall){

	@tabcluster1 = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-1/devices/$HG*?name\" |awk -F\\\" '/value/ {print $4}'`;
	@tabcluster2 = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-2/devices/$HG*?name\" |awk -F\\\" '/value/ {print $4}'`;
}


#----------------------------------------------------------------------------------------------------
#--------------------------------------recherche du Hostgroup----------------------------------------
my %doublon = ();
my @unique = grep { ! $doublon{ $_ }++ } @tabhg;
                #####################gestion du Cluster et majuscule###########################

my @tab_contenu_HG = ();
@tab_contenu_HG = grep {/$HG/} @unique;

if ($optdebug) {
        my $i = 0;
        foreach (@tab_contenu_HG){
                chomp;
                print "LINE $i:$HG=>$_\n";
                $i++;
        }
}

#------------------------ Traitement et memo du fichier Ldev-----------------------------------------
my %infos_ldev_tb;
my %infos_ldev_pid;
my %infos_ldev_tk;
my %infos_ldev_lab;
my $ligne;
my $new_ldev;
my $wwn2;



foreach $ligne (@tab_contenu_LDEV)
{
        $ligne =~ s/\r?\n//gi;

        my ( $baie, $ldev, $taille_ko, $taille_bloc, $pool_id, $taille_use, $label) = split /;/, $ligne;
        $infos_ldev_tb{"$ldev#$baie"} = $taille_bloc;
        $infos_ldev_tk{"$ldev#$baie"} = $taille_ko;
        $infos_ldev_pid{"$ldev#$baie"} = $pool_id;
        $infos_ldev_lab{"$ldev#$baie"} = $label;
        #print "Volume : $ldev -> ".$infos_ldev_tk{"$ldev"}." -> ".$infos_ldev_lab{"$ldev"}."\n";
}


foreach my $ligne (@tab_contenu_HG)
{
      #$ligne =~ s/\r?\n//gi;
        my ($baie, $ldev, $host_group, $lunid) = split /;/, $ligne;
        my $non_cluster = 0;
        chomp ($ldev);
        ##################################modification le 2 septembre ############################
        if ($optr2){
                my($digt01,$digt02,$digt03) = split /:/, $ldev;
                if (hex ($digt02) > hex(80)){
 #                       print "Disque R2 $ldev on continue....\n";
                        next;
                 }
        }
	my $monlabel = $infos_ldev_lab{"$ldev#$baie"};
	if (($monlabel =~ m/rootvg/) || ($monlabel =~ m/ROOTVG/))
	{ 
		next;
	}
	
        ##########################################################################################
        print "ldev: $baie;$ldev #".$infos_ldev_tk{"$ldev#$baie"}."#\n";
#        print "host_group -> $host_group ";
	my ($val1,$val2,$val3) = split /:/, $ldev;
	my $ldevfinal = "$val2$val3";
	if ($optall){
	   open (FIC_c1,"<$cheminsrc/cluster1.txt");
	   @tabcluster1 = <FIC_c1>;
	   close (FIC_c1); 		
	   open (FIC_c2,"<$cheminsrc/cluster2.txt");
           @tabcluster2 = <FIC_c2>;
           close (FIC_c2);	
	}	
	

	if (grep (/$ldevfinal/,@tabcluster1)){
		print "Cluster 1 -> $ldevfinal Present \n";
		
	}
	else { print "#######Cluster 1 -> $ldevfinal ABSENT !!!!###### \n";} 

	if (grep (/$ldevfinal/,@tabcluster2)){
                print "Cluster 2 -> $ldevfinal Present \n";

        }
        else {  print "#######Cluster 2 -> $ldevfinal ABSENT !!!!###### \n";}


	
}
