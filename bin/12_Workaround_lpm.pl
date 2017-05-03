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
my $chemin = "/admin/Emc_mig/trait_baies/";
chomp($chemin);

#------------------------------------Synopsis pour Option------------------------------------
=head1 SYNOPSIS

usage: Workaround_lpm.pl serveur [--verbose] [--help] [--debug]
	arg 1: le premier le Serveur
	Debug : Affhichage des tableaux
	BatI : Liste des Ldev Batiment I
	BatG : Liste des Ldev Batiment G	
=cut


my ($optVerbose,$optHelp,$optdebug,$optrefresh);
GetOptions( "verbose!"=>\$optVerbose,
                "help|?",\$optHelp,
		"refresh|?",\$optrefresh,	
                "debug"=>\$optdebug);

pod2usage(1) if ( $optHelp );
print "##########################################################################################\n";
print "########  Script de d'ajout d'un initiateur dans un export group Vipr   ######################\n";
print "######## 		./Workaround_lpm.pl serveur 	            ######################\n";
print "########			./Workaround_lpm.pl --refresh 			######################\n";
print "######## 	Pour Rafraichir les données Vipr                        ######################\n";
print "##########################################################################################\n\n\n\n\n";	
print "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";

my $serveur = $ARGV[0];
chomp $serveur;
if (($serveur eq "")&& !($optrefresh) ){
	print "\n###################Merci de saisir Un serveur###################\n\n";
	exit (1);	

}

 my ($l_id_volume,$l_id_cg);
 my $creationcookies =`curl -k \"https://viprcontroller:4443/login?using-cookies=true\" -u \"root:Changeme1\!\" -c /tmp/cookiefile -v 2>&1 1>/dev/null`;
# print "$creationcookies \n";	


&Host_urn if ($optrefresh);
&traitement if ($serveur) ;

exit(0);

	my $command_putcg = "curl -X PUT -H \"Content-Type: application/json;\" -d '{\"add_volumes\":{\"volume\":[\"$l_id_volume\"]}}' -k \"https://viprcontroller:4443/block/consistency-groups/$l_id_cg/\" -b /tmp/cookiefile -v";
        print "$command_putcg\n";



sub Host_urn (){
        open (fichierhost,">$chemin/Vipr_host.log") || die ("Erreur d'ouverture de fichier");
        my @result_host_urn;
        my @command_host_urn = `curl -k \"https://viprcontroller:4443/compute/hosts/\" -b /tmp/cookiefile -v`;
        my $carac_host_urn = join ('',@command_host_urn);
        my $parser_host_urn = XML::LibXML->new();
        my $tree_host_urn = $parser_host_urn->parse_string($carac_host_urn);
#	print $tree_host_urn->to_literal."\n";
        foreach my $l_carac_host_urn ($tree_host_urn->findnodes('/hosts/host')){
                        my ($host_id) = $l_carac_host_urn->findnodes ('./id');
			my $id_host = $host_id->to_literal;
                        my ($host_name) = $l_carac_host_urn->findnodes ('./name');
			my $ligne = $host_name->to_literal."#!#".$host_id->to_literal;
			foreach ($host_id){
				my @command_initiator = `curl -k \"https://viprcontroller:4443/compute/hosts/$id_host/initiators/\" -b /tmp/cookiefile `;
				my $caract_initiator = join ('',@command_initiator);
				my $parser_initiator = XML::LibXML->new();
				my $tree_initiator = $parser_initiator->parse_string($caract_initiator );
				foreach my $l_carac_initiator ($tree_initiator->findnodes('/initiators/initiator')){
					my $initiator_id = $l_carac_initiator->findnodes ('./id');
					my $initiator_name = $l_carac_initiator->findnodes ('./name');
					$ligne = $ligne."#!#".$initiator_name->to_literal."#!#".$initiator_id->to_literal;  
				}
			}
			print "#############################\n";
			print "$ligne\n";
			print "#############################\n";
			push (@result_host_urn,$ligne);
        }
        foreach (@result_host_urn){
                chomp($_);
                print fichierhost "$_\n";
        }
	print "Les données sont rafraichit merci de relancer le script en mode normal\n";
}


sub traitement (){
	my $caract_name;
	open (FIC,"<$chemin/Vipr_host.log");
        my @l_host =<FIC>;
        close (FIC);
	my @host_def = grep (/\Q$serveur#\E/, @l_host);

	print "Merci de saisir l'urn de l'export de destination\n";
	my $input3 = <STDIN>;
	chomp $input3;
	my @command_verif = `curl -k \"https://viprcontroller:4443/block/exports/$input3\" -b /tmp/cookiefile `;
	my $carac_verif = join ('',@command_verif);
	my $parser_verif = XML::LibXML->new();
	my $tree_verif  = $parser_verif->parse_string($carac_verif);
	foreach my $l_carac_verif ($tree_verif->findnodes('/block_export')){
		 $caract_name = $l_carac_verif->findnodes('./name');
	}
	if (!($caract_name)){
		print "\n\n\nSaisie Incorrecte l'urn n'est pas la bonne merci de relancer le script\n";
                print "Sinon tu fais de l'informatique ?\n";
		exit(0);
	}
#	print $caract_name->to_literal;
	
	
	foreach (@host_def ){
		my ($name_host,$id_host,$wwn1,$id_wwn1,$wwn2,$id_wwn2) = split /#!#/, $_;
		chomp ($id_wwn1);
		chomp ($id_wwn2);	
	   	print "\n\n####Voulez Vous mettre le wwn $wwn1 du Host $name_host dans l'export $caract_name\n";
		print "Reponse y/n ou q pour quitter le programme :  ";		
		my $input = <STDIN>;
		chomp $input;
		while (($input ne "Y")&&($input ne "y")&&($input ne "q")&&($input ne "Q")&&($input ne "n")&&($input ne "N")){
			print "Merci de saisir la bonne valeur y/n ou q:";
	                $input = <STDIN>;
        		chomp $input;
        	}
		if ($input =~ m/^[Q]$/i){
                       	print "Exit du programme\n";
	                exit(0);
		}
		elsif($input =~ m/^[Y]$/i){
			print "$wwn1 choisi \n";
			my $command_put = "curl -X PUT -H \"Content-Type: application/json;\" -d '{\"initiator_changes\":{\"add\":[\"$id_wwn1\"]}}' -k \"https://viprcontroller:4443/block/exports/$input3/\" -b /tmp/cookiefile";
			print "$command_put\n";
			my $cmd_put = `$command_put`;
			print "\n$cmd_put\n";
		}
		elsif ($input =~ m/^[N]$/i){
			print "\n\n####Voulez Vous mettre le wwn $wwn2 du Host $name_host dans l'export $caract_name\n";
			print "Reponse y/n ou q pour quitter le programme :  ";
			my $input2 = <STDIN>;
			chomp $input2;
			if ($input2 =~ m/^[Q]$/i){
        	                print "Exit du programme\n";
	                        exit(0);
			}
			elsif ($input2  =~ m/^[Y]$/i){
        	                print "$wwn2 choisi \n";
				my $command_put2 = "curl -X PUT -H \"Content-Type: application/json;\" -d '{\"initiator_changes\":{\"add\":[\"$id_wwn2\"]}}' -k \"https://viprcontroller:4443/block/exports/$input3/\" -b /tmp/cookiefile";
			print "$command_put2\n";
			my $cmd_put2 = `$command_put2`;
		
                        print "\n$cmd_put2\n";

	                }
			elsif ($input2 =~ m/^[N]$/i){
				print "merci de relancer le script \n";
				exit(0);
			}		
                }

			
		
		
	}		
	

}





