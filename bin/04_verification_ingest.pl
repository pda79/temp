#!/usr/bin/perl

# Auteur : Jean-Laurent MARTINEZ
# Creation : 23 Nov 2011 15:27:31
# Derniere modification : 10 fevrier 2016

use Pod::Usage;
use Getopt::Long;
use XML::LibXML;
use Data::Dumper;
use strict;
use POSIX qw(strftime);
my $datestring = strftime "%Y-%m-%d_%H-%M", localtime;
print("date and time :$datestring\n");
my $chemin;
my $cheminsrc;

#print "heure:$date_modif";
$chemin = "/admin/Emc_mig/log";
$cheminsrc = "/admin/Emc_mig/trait_baies";
chomp ($chemin);
#------------------------------------Synopsis pour Option------------------------------------
=head1 SYNOPSIS

usage: 	Verification ingest [--verbose] [--help] [--debug]
        Debug : Affhichage des tableaux
=cut


my ($optVerbose,$optHelp,$optdebug);
GetOptions( "verbose!"=>\$optVerbose,
                "help|?",\$optHelp,
                "debug"=>\$optdebug);

pod2usage(1) if ( $optHelp );
#---------------------------------------------------------------------------------------------
if ( $optHelp ){
print "usage: $0 [-h | -?] [-l]
        -h|?    : Affichage de l'aide
        -help   : Affichage de l'aide\n";
exit -1;
}
print "Veuillez patienter recuperation des informations sur VPlex .....\n";
#############################commande de listing des storageview et de disque associé##########################
my $command_vol = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-1/exports/storage-views/*\"|grep -e '\"V' -e '\"('|awk -F\\\" ' \$2~/^value\$/ {SV=\$4} \$2~/\\\(/ {print SV\";\"\$2}'";
my @cmd_vol1 = `$command_vol`;
my $command_vol2 = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-2/exports/storage-views/*\"|grep -e '\"V' -e '\"('|awk -F\\\" ' \$2~/^value\$/ {SV=\$4} \$2~/\\\(/ {print SV\";\"\$2}'";
my @cmd_vol2 = `$command_vol2`;
my @cmd_vol = (@cmd_vol1,@cmd_vol2);

	
&viper;
############################Comande vipr
####creation du cookies#############################
my (@resultat,@tab_erreur);

sub viper(){
print "Veuillez patienter recuperation des informations sur Vipr .....\n";
print "Ceci peux prendre plusieurs minutes .....\n";
my $creationcookies =`curl -k \"https://viprcontroller:4443/login?using-cookies=true\" -u \"root:Changeme1!\" -c /tmp/cookiefile 2> /dev/null`;

my @command_id_vol = `curl -k \"https://viprcontroller:4443/block/volumes/bulk\" -b /tmp/cookiefile 2> /dev/null`;
        my $id_vol = join('',@command_id_vol);
        my $parser_id_vol = XML::LibXML->new();
        my $tree_id_vol = $parser_id_vol->parse_string($id_vol);


        foreach my $l_id_vol ($tree_id_vol->findnodes('ids/id')){
#                print $l_id_vol->to_literal;
#               my($name_id_vol) = $l_id_vol->findnodes ('./id');
                my $recherche = $l_id_vol->to_literal;
 #               print "#########$recherche########\n";
                my @command_carac_vol = `curl -k \"https://viprcontroller:4443/block/volumes/$recherche\" -b /tmp/cookiefile 2> /dev/null`;
                my $carac_vol = join('',@command_carac_vol);
                my $parser_carac_vol = XML::LibXML->new();
                my $tree_carac_vol = $parser_carac_vol->parse_string($carac_vol);
                foreach my $l_carac_vol ($tree_carac_vol->findnodes('volume')){
                        my ($name_carac_vol) = $l_carac_vol->findnodes ('./name');
                        my ($device_label)  = $l_carac_vol->findnodes ('./device_label');
                     #   print "###################################\n";
                     #   print $name_carac_vol->to_literal."\n";
                     #   print $device_label->to_literal."\n";
                        #push (@resultat,$recherche."#!#".$name_carac_vol->to_literal."#!#".$device_label->to_literal."#!#");
			push (@resultat,$name_carac_vol->to_literal);
                }

        }
}

	

foreach (@cmd_vol){
	chomp ($_);
	my (undef,$vol_rech,undef,undef) = split /,/, $_;
	if (($vol_rech !~ m/^device_/) && ($vol_rech !~ m/^dd_/)) {
		if (!grep(/$vol_rech/,@resultat)){push (@tab_erreur,$vol_rech);	}
	}
}

@tab_erreur= &doublon(@tab_erreur);
foreach (@tab_erreur){print "Volume non rentré dans Vipr:$_\n";}
	


sub doublon(){
	 my @tab_ori = @_;
	 my $size_ori = @tab_ori;
	 my %doublon = ();
	 my @unique = grep { ! $doublon{ $_ }++ } @tab_ori;
	 my $sizefin = @unique;
	 return (@unique);
}
