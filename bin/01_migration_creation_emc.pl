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

usage: genfic_auto.pl HostGroup [--verbose] [--help] [--debug] [--BatI] [--BatG]
	arg 1: le premier le HG
	arg 2: Preference de batiment 
	arg 3: Environnement	
	Debug : Affhichage des tableaux
	BatI : Liste des Ldev Batiment I
	BatG : Liste des Ldev Batiment G	
=cut


my ($optVerbose,$optHelp,$optdebug,$optBase,$optBati,$optBatg,$optprincipal,$optforce,$optlinux,$optr2,$optvpa);
GetOptions( "verbose!"=>\$optVerbose,
                "help|?",\$optHelp,
                "debug"=>\$optdebug,
		"auto"=>\$optforce,
		"principal"=>\$optprincipal,
		"linux"=>\$optlinux, # modif du 25 juillet
		"BatI"=>\$optBati,
		"R2"=>\$optr2, 
                "BatG"=>\$optBatg);

pod2usage(1) if ( $optHelp );
#---------------------------------------------------------------------------------------------
if ( $optHelp ){
print "usage: $0 [-h | -?] [-l]
	-h|?	: Affichage de l'aide
	arg 1	: Hostgroup
	arg 2	: Environnement P ou HP
	R2	: Ne prends plus en création les R2 TC
	-help	: Affichage de l'aide\n";
exit -1;
}
#$optvpa = "FBVPA001";
$optvpa = "FBVPA002";
print "Cluster $optvpa\n";
print "\033[2J"; 
print "###########################################################################################\n";
print "########  Script de création des disques VNX et Encapsulation VSP    ######################\n";
print "########         --principal Membre principal du cluster             ######################\n";
print "########         --auto pour automatique sv	  	             ######################\n";
print "########         --R2 pour ne pas traiter les disque de plus 80hexa  ######################\n";
print "########         --Bati/g pour selectionner le batiment par defaut   ######################\n";
print "########         --linux pour prise en compte du rootvg boot on san  ######################\n";	
print "###########################################################################################\n\n\n\n\n";	
print "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";

my $HG = sprintf uc ($ARGV[0]);
#my $pref = $ARGV[];
my $env = $ARGV[1];

chomp($HG);
#chomp($pref);
chomp($env);

if (($HG eq "")){
        print "\n###################Merci de saisir Un hostgroup###################\n\n";
        exit 1;
}

if (( $env ne "P") && ( $env ne "HP")) {
        print "\n###################Merci de saisir l'environnement du serveur P ou HP###################\n\n";
        exit 1;

}
if ($optforce){
        print "Mode automatique storageview pour cluster activé\n";
}


#&distributed("SAMAQ023_APPSVG_DDI_PROD_S_003","85183","00:10:7F");

#&storage_view("00:10:7F","SAMAQ023_APPSVG_DDI_PROD_S_003","85183","yes");
#$l_dev,$l_lun,$l_baie,$l_tc
print "########Serveur Linux forcé #####################\n\n" if ($optlinux);


print "########Verification lock Baie VSP #####################\n\n";
my $cmd_lock="raidcom get resource -s '85183' -ITC1839 -login maintenance raid-mainte | grep \"Locked\"";
my $ret = system ($cmd_lock);
if ( $ret == 0 ){
		print "Baie 85183 lockée Virtualisation Impossible\n" ;
		print "voulez vous continuer y/n?\n";
		my $input = <STDIN>;
                chomp $input;
                if ($input =~ m/^[N]$/i){
                        exit(0);
                }
	}
else {
	my $cmd_lock="raidcom get resource -s '53317' -ITC3179 -login maintenance raid-mainte | grep \"Locked\"";
	my $ret = system ($cmd_lock);
	if ( $ret ==0 ){
                print "Baie 53317 lockée Virtualisation Impossible\n" ;
                print "voulez vous continuer y/n?\n";
                my $input = <STDIN>;
                chomp $input;
                if ($input =~ m/^[N]$/i){
                        exit(0);
                }
        }
}	

# -------------------------------------creation d'un repertoire pour les fichiers --------------------------
if( -d $chemin."/".$HG ) {
  # le sous-rére existe
  print "Serveur dèja généré\n";
}
else {
  # ou non
  mkdir $chemin."/".$HG;

}
	

#--------------------------------------------------------------------------------------------------------------

open (fichierlog,">$chemin/$HG/$HG"."_"."$datestring.log") || die ("Erreur d'ouverture de fichier");
print "#############Mode sans traitement des R2 #################\n" if($optr2);
print "Recherche du Serveur $HG \n";
#print "Preference : Bat $pref\n"; 
print "Environnement : $env\n";
print "Analyse ....\n";
print fichierlog "##################################### etape 1 #################################\n";	
print fichierlog "Serveur $HG -> $env\n";

my $baiesrc;
my $baiedst;


#--------------------------------ouverture des fichiers créé par les autres pl-----------
open(FIC,"<$cheminsrc/Ldev_bat_all.log");# if ($optBati);
my @tab_contenu_LDEV = <FIC>;
close(FIC);

open (FIC,"<$cheminsrc/Ldev_TC.log");
my @tabtc =<FIC>;
close(FIC);

open(FIC,"<$cheminsrc/host_group_device_all.log");
my @tabhg = <FIC>;
close(FIC);
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

###----------------------------------resultat dans fichiers --------------------------------------------
open (fichierI,">$chemin/$HG/commande_VNXI.txt") || die ("Erreur d'ouverture de fichier");
open (fichierG,">$chemin/$HG/commande_VNXG.txt") || die ("Erreur d'ouverture de fichier");
open (fichiervsp85183,">$chemin/$HG/commande_encapsulation_85183.txt") || die ("Erreur d'ouverture de fichier");
open (fichiervsp53317,">$chemin/$HG/commande_encapsulation_53317.txt") || die ("Erreur d'ouverture de fichier");
my $lhg = lc($HG);
if(! (-e "/mnt/MIG_EMC/lpar/$lhg/result/table_disk.emc.txt")){
        open (fichieros,">/mnt/MIG_EMC/lpar/$lhg/result/table_disk.emc.txt") || ("Erreur d'ouverture de fichier");}
my ($cpt, $stop) = 0;
my @tab_wwn;
my ($b2_orig, $b3_orig);
my $pool;
my $nomdevice;
my $tc = "no";
#my %doublon = ();
#my @unique = grep { ! $doublon{ $_ }++ } @tab_contenu_HG;
my @cluster_ori;

############################verification avec le fichier de Christian############################
&trait_fic_os;

#----------------------------------traitement des elements et calcul en Hexa -------------------------	
foreach my $ligne (@tab_contenu_HG)
{
      #$ligne =~ s/\r?\n//gi;
	my ($baie, $ldev, $host_group, $lunid) = split /;/, $ligne;
	my $non_cluster = 0;
	chomp ($ldev);
	print "######$ldev####\n";
	#########################modification 8 decembre exclusion des lun R1 des R2 suivant lol #########
	next if (($ldev eq  "00:21:C6")||($ldev eq  "00:21:C7")||($ldev eq  "00:20:16")||($ldev eq  "00:20:07")||($ldev eq  "00:10:A8"));
	##################################modification le 2 septembre ############################
	if ($optr2) {
		##########################modification 8 decembre exclusion des lun r2 ###########
		if (($ldev ne "00:A1:C6") || ($ldev ne "00:A1:C7") || ($ldev ne "00:A0:16") || ($ldev ne "00:A0:07")|| ($ldev ne "00:90:A8")){
		#########################modification 7 decembre exclusion des lun asmcli#########
		if (($lhg eq "saapp237")||($lhg eq "saapp239")){
			open(FIC,"<$cheminsrc/exclusion_saapp237_239.log");# if ($optBati);
			my @tab_contenu_srv = <FIC>;
			close(FIC);
			if (grep {/$ldev/} @tab_contenu_srv)
			{
			print "######Exclusion du volume $ldev #######\n";		
			next;
			}

			#exit(0);
		}
		my($digt01,$digt02,$digt03) = split /:/, $ldev;
		if (hex ($digt02) > hex(80)){
			print "Disque R2 $ldev on continue....\n";
			next;
		 }
		}
	}
	

	##########################################################################################
	$tc = "no";	
	print "ldev: $baie;$ldev #".$infos_ldev_tk{"$ldev#$baie"}."#\n" if ($optdebug);	
	print "host_group -> $host_group " if ($optdebug); 
	my @hg_storageview;
	if (grep (/$ldev;$baie/,@tabtc)){
		$tc = "yes";
		print "\n\n############################################################################################################\n";
	#	print "volume TC $ldev\n";		###############Verifier avec disque TC ########## 
		print fichierlog "volume TC $ldev\n";
	}
	
	@cluster_ori = grep {/$baie;$ldev/} @tabhg;
	my %dejavu = ();
	my @cluster_tmp = grep { ! $dejavu{ $_ }++ } @cluster_ori;	#####enleve les doublons ########
	my @cluster = sort (@cluster_tmp);				#####tri par ordre alphabetique####"
	my $clu;
	my $cluster_final ;
	my $l_hg_or = substr ($HG,0,5);
	$cluster_final = $HG;
	push (@hg_storageview,$lhg);
#	if (!@cluster[1]){
#		print "disque non cluster\n";
# 		$non_cluster = 1;
#	}
#	else {
#		if ($optprincipal){
#		  	print "disque cluster\n";	
#		}
#		else { next;}
			 

#	}	
	if ((@cluster[1])&& (!$optprincipal)){
		print "Disque $ldev en cluster mais non pricipal on continue\n";
		next;
	}	



	foreach (@cluster){
				########################### voir si recuperation lunid des autre membres du cluster pour ajout storage view#####
		print "Cluster:$_\n";
		
		if (!($_ =~ m/$HG/)){
			my ($l_1, $l_2) = split /#/, $_;
			my ($l_hostg,$l_typeSer,$l_mon_hg) = split /_/, $l_1;
		#	print "ici ->$_  -----> #$l_mon_hg#";
			push (@hg_storageview,$l_mon_hg);
			my $l_hg_mod_clu = substr ($l_mon_hg,0,5);
			if ($l_hg_mod_clu eq $l_hg_or){
				$clu = substr ($l_mon_hg,5,3);
				$cluster_final = $cluster_final."_".$clu;	
			}
		}
	}	
#	foreach (@hg_storageview){print "sv#$_#\n";}	
	print "mon cluster final $cluster_final \n" if ($optdebug);

#	my $taille = (($infos_ldev_tk{"$ldev#$baie"}/1024)/1024);
	my $taille = $infos_ldev_tb{"$ldev#$baie"};
        my $verif = "$baie;$HG;$ldev;".$infos_ldev_pid{"$ldev#$baie"}.";".$infos_ldev_tk{"$ldev#$baie"}.";".$infos_ldev_lab{"$ldev#$baie"}.";"."$cluster_final.\n";
	my $non_encap;
	print fichierlog "\n\n#######################etape n°2 verification ########################\n";
	print fichierlog $verif."\n";
		if ($infos_ldev_pid{"$ldev#$baie"} == 0) {$pool="0";}
	 	if ($infos_ldev_pid{"$ldev#$baie"} == 20) {$pool="1";}
		if ($infos_ldev_pid{"$ldev#$baie"} == 30) {$pool="2";} 		

	if (($baie == "85183" ) && ($tc ne "yes")){
			$nomdevice = &gen_nom("I",$tc,$pool,$infos_ldev_lab{"$ldev#$baie"},$lunid,$cluster_final);
		        chomp($nomdevice);
			$non_encap = 0;
			if ((!($nomdevice =~ m/ROOTVG/)) || ($optlinux)) {	#modif du 25 juillet
				print "\n\n\n\n\n##########################################################################\n\n";
				my $command_verifVNXI = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38  getlun | grep $nomdevice`;
				if (!$command_verifVNXI){
					print "Disque non créé sur VNX I....\n";
					my $action_I = &action_vnxI($taille,$pool,$nomdevice,"I",$ldev,$baie,$lunid);
					print "########$action_I######\n";
					if ($action_I eq "next"){
						$non_encap = 1;
					}
					
				}
				else {print "Volume $ldev Dèja créé sur la baie $baie on passe à la suite\n";}
			}
		
		} 
	if (($baie == "53317") && ($tc ne "yes")){
			$nomdevice = &gen_nom("G",$tc,$pool,$infos_ldev_lab{"$ldev#$baie"},$lunid,$cluster_final);
                        chomp($nomdevice);
			$non_encap = 0;
			if ((!($nomdevice =~ m/ROOTVG/)) || ($optlinux)) {	#modif du 25 juillet
				print "\n\n\n\n\n##########################################################################\n\n";
				my $command_verifVNXG = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40  getlun | grep $nomdevice`;
				if (!$command_verifVNXG){
                                        print "Disque non créé sur VNX G....\n";
					my $action_G = &action_vnxG($taille,$pool,$nomdevice,"G",$ldev,$baie,$lunid);
					print "########$action_G######\n";
					if ($action_G eq "next"){
                                                $non_encap = 1;
                                        }	
				}
				else {print "Volume $ldev Dèja créé sur la baie $baie on passe à la suite\n";}
			}	
	}
	if ($tc eq "yes"){
		print "Serveur True copier à la source n'oublier pas la Golden Copy\n";
		my $group_repli = horcm($ldev,$baie);
		print $group_repli;
		print "Disque $ldev TC a la source Baie: $baie \nCreation des fichiers VNX pour les deux Batiments I et G \n";
		print fichierlog "Disque $ldev TC a la source Baie: $baie \nCreation des fichiers VNX pour les deux Batiments I et G \n";
		print "\n\n#######Quelle preference de batiment######\n";
		my $input;
		if($optBati){
                	$input = "I";chomp $input;
                        print "\nMode Automatique Batiment I \nVeuillez patienter.....\n\n";
			
                }
		elsif ($optBatg){
                        $input = "G";chomp $input;
                        print "\nMode Automatique Batiment G \nVeuillez patienter.....\n\n";

                }
		else {
			print "Reponse I/G ou q pour quitter le programme :  ";
	                $input = <STDIN>;
        	        chomp $input;
		}
		while (($input ne "I")&&($input ne "i")&&($input ne "G")&&($input ne "g")&&($input ne "q")&&($input ne "Q")){
                        print "Merci de saisir la bonne valeur I/G ou q:";
                        $input = <STDIN>;
                        chomp $input;
                }
                	if ($input =~ m/^[Q]$/i){
	                        print "Exit du programme\n";
	                        exit(0);
	                }
        	        elsif (($input eq "I") || ($input eq "G") || ($input eq "i") || ($input eq "g")){		 
				      $nomdevice = &gen_nom($input,$tc,$pool,$infos_ldev_lab{"$ldev#$baie"},$lunid,$cluster_final);
		 	              chomp($nomdevice);
				       if ((!($nomdevice =~ m/ROOTVG/)) || ($optlinux)) {      #modif du 25 juillet			
		                      	    my $command_verifVNXI = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38  getlun | grep $nomdevice`;
					    my $command_verifVNXG = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40  getlun | grep $nomdevice`;	
	                                	if (!$command_verifVNXI){
							 print "Execution Creation VNX I....\n";
							 $non_encap = 0;
	                        		         my $action_I = &action_vnxI($taille,$pool,$nomdevice,"I",$ldev,$baie,$lunid);
							 if ($action_I eq "next"){
                                         		      $non_encap = 1;
                                        		 }	
	                                	}
						else {print "Volume $ldev Dèja créé sur la VNX I on passe à la suite\n";}
						if(!$command_verifVNXG){
							 $non_encap = 0;	
							 print "Execution Creation VNX G....\n";
	                        	                 my $action_G = &action_vnxG($taille,$pool,$nomdevice,"G",$ldev,$baie,$lunid);
							 if ($action_G eq "next"){
                                                              $non_encap = 1;
                                                         }

						}
						else { print "Volume $ldev Dèja créé sur la VNX G on passe à la suite\n";}
					}
		 	}	
			
	}
	if (((!($nomdevice =~ m/ROOTVG/)) || ($optlinux))  && ($non_encap == 0)) { # modif du 25 juillet
	    ######mettre ici retour d'action i et G dans variable	#######
	    my $instance;	
	    if($baie eq "85183"){$instance = "1839";}
	    if($baie eq "53317"){$instance = "3179";}	
	    my $command_verif = "export HORCMINST=$instance;raidcom get ldev -ldev_id $ldev -login maintenance raid-mainte | grep MIGEMC";
	    print "$command_verif\n";			
	    my $cmd_verif = `$command_verif`;			
	    if (!$cmd_verif){	
		    #######################################################virtualisation des disque VSP######################################
		    print " \n#####Voulez vous Encapsuler et virtualiser le disque : $ldev source HDS de la baie $baie\n";
		    print "Reponse y/n ou q pour quitter le programme :  "; 
	            my $input3 = <STDIN>;
	            chomp $input3;
	            if ($input3 =~ m/^[Q]$/i){
	                 print "Exit du programme\n";
        	         exit(0);
	            }
        	     elsif($input3 =~ m/^[Y]$/i){
			 print "ATTENTION Le Zoning doit etre désactivé!!!\n";
		#	 my $cmd_zoning = &zoning;
			 my $cmd_zoning = 1;	
			 if ($cmd_zoning == 1) {
	                 	my $commande_VSP = &addvolumevsptovplex($ldev,$baie,$lunid,$nomdevice);
				if ($tc eq "yes"){
					print "\n\n####Disque TC!! Creation du distributed device? ###\n";
	                                 print "Reponse y/n ou q pour quitter le programme :  ";
	                                 my $input = <STDIN>;
        	                         chomp $input;
                	                 if ($input =~ m/^[Q]$/i){
                        	                print "Exit du programme\n";
	                                        exit(0);
        	                         }
                	                 elsif($input =~ m/^[Y]$/i){
				 		my $distributed = &distributed($nomdevice,$baie,$ldev);	
						print fichierlog "$distributed\n";	
					}
				 }
				 print "\n\n####Le Volume $ldev Va etre positionnné dans la storage view du host $HG####\n";	
				 print fichierlog "#####Met le ldev $ldev dans la storage view du host $HG####\n";
				 my $size_sv = @hg_storageview;
				 if ($size_sv > 1){
					foreach (@hg_storageview){		
					   print "\n#### Mode cluster ####\n";	
					   my $input;
					   print "\n\n####Voulez Vous mettre le $ldev du Host $HG dans la storage view $_ ###\n";
					   print "Reponse y/n ou q pour quitter le programme :  ";
					   if($optforce){
		                                $input = "Y";chomp $input;
                		                print "\nMode Automatique veuillez patienter.....\n";
                                	   }else{
			                       	   $input = <STDIN>;
		        	               	   chomp $input;
						}
					   while (($input ne "Y")&&($input ne "y")&&($input ne "q")&&($input ne "Q")&&($input ne "n")&&($input ne "N")){
						print "Merci de saisir la bonne valeur Y/N ou q:";
			                        $input = <STDIN>;
                        			chomp $input;
                			   }
	
			
	                               	   if ($input =~ m/^[Q]$/i){
			                       	print "Exit du programme\n";
				                exit(0);
                        	       	   }
                                	   elsif($input =~ m/^[Y]$/i){
						print fichierlog "#####Mode cluster Met le ldev $ldev dans la storage view du host $_####\n";
					        &storage_view($ldev,$nomdevice,$baie,$tc,$_);
					   }
					   else { print "On continue\n";print fichierlog "click No ou autre chose \on continue\n";	
					   }		
					}
				}
				else {&storage_view($ldev,$nomdevice,$baie,$tc,$lhg);}
        	                # }

			 }
			 else {print "Le zoning n'est pas supprimé\n";
			       print "Le disque n'est pas Virtualisé\n";}
		     }
		     else { 
		     print "\nOn continue\n";
			}		
		}
		else {print "Ldev $ldev dèjà dans hostgroup de migration baie $baie\n";}
			###########################################################################################################################
	}	

} 

close (fichierI);
close (fichierG);
close (fichiervsp85183);
close (fichiervsp53317);	
close (fichierVplexI);
close (fichierVplexG);
close (fichierlog);	
&clean_fic;

sub action_vnxI {		######################## fonction de creation des ldev Vnx Bat I ##########################

		my ($taille,$pool,$mon_volume,$pref,$ldev,$baie,$lunid ) = @_;
		my $sp;
		my $cmd_recupid = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 storagegroup -list -gname FBVPA001 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1;n[\$1]=\$2 }END{print n[m]}'`;
		chomp($cmd_recupid);
		my $cmd_sp = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38  getlun $cmd_recupid | awk '/Current\ owner:/ {print \$4}'`;
		chomp ($cmd_sp);
		if ($cmd_sp eq "A"){$sp = "B";}
		elsif ($cmd_sp eq "B"){ $sp = "A";}
#		my $commande_creat_I = "/opt/Navisphere/bin/naviseccli -h 172.23.238.38 lun -create -type nonThin -capacity $taille -sq gb -poolId $pool -sp $sp -name $mon_volume-1 -tieringPolicy autoTier -initialTier highestAvailable";
		my $commande_creat_I = "/opt/Navisphere/bin/naviseccli -h 172.23.238.38 lun -create -type nonThin -capacity $taille -sq bc -poolId $pool -sp $sp -name $mon_volume-1 -tieringPolicy autoTier -initialTier highestAvailable";
		print "\n\nRecapitulatif: LEDV : $ldev Baie: $baie Lun de $taille Bloc pool $pool Nom du volume: $mon_volume \n\n";
		print fichierlog "Recapitulatif: Lun de $taille Bloc pool $pool Nom du volume: $mon_volume \n";
		print "Affichage de la commande:\n";
		print "$commande_creat_I\n";
		print "\n\n####Voulez Vous créer le Ldev $ldev sur la VNX du Batiment I###\n";
		print "Reponse y/n ou q pour quitter le programme :  ";
		my $input = <STDIN>;
		chomp $input;
		if ($input =~ m/^[Q]$/i){
			print "Exit du programme\n";
		  	exit(0);
		}
		elsif($input =~ m/^[Y]$/i){	
			  print "Execution Verification VNX I....\n";
			  print fichierlog "$commande_creat_I \n";	
			  print "\n\n######Creation des fichiers VNX BatI######\n";
        		  print fichierlog "###############etape n°3 Creation des fichiers VNX BatI #########################\n";
			  my $cmd = `$commande_creat_I`;	
			  print fichierI $commande_creat_I."\n";
			  print $cmd;
			  print fichierlog "$cmd\n";	
		#	  my $commande_storegroup = &commande_vnx($pref,$mon_volume); ### lancement des commandes		
			  my $num_hlu = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 storagegroup -list -gname FBVPA001 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1 }END{print m}'`;
			  print fichierlog "/opt/Navisphere/bin/naviseccli -h 172.23.238.38 storagegroup -list -gname FBVPA001 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1 }END{print m}'";
	          	  my $num_hlu_end = $num_hlu + 1;
			  my $num_lun = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 lun -list -name $mon_volume-1 -uid | awk \'\$1~/LOGICAL/ \{print \$4\}\'`;
			  print fichierlog "/opt/Navisphere/bin/naviseccli -h 172.23.238.38 lun -list -name $mon_volume-1 -uid | awk \'\$1~/LOGICAL/ \{print \$4\}\'\n";
			  chomp ($num_lun);
			  my $num_uid = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 getlun $num_lun | awk \'/^UID/ \{print \$2\}\' | sed -e s/\://g | tr A-Z a-z`;
			  print fichierlog "/opt/Navisphere/bin/naviseccli -h 172.23.238.38 getlun $num_lun | awk \'/^UID/ \{print \$2\}\' | sed -e s/\://g | tr A-Z a-z\n";
			  chomp ($num_uid);
			  print "Volume :$mon_volume\n Lun:$num_lun \n Hlu:$num_hlu_end \n UID:$num_uid \n";
			  print fichierlog "Volume :$mon_volume\n Lun:$num_lun \n Hlu:$num_hlu_end \n UID:$num_uid \n";
			  my $num_stroreage = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 storagegroup -addhlu -gname FBVPA001 -hlu $num_hlu_end -alu $num_lun`;
			  print fichierlog "/opt/Navisphere/bin/naviseccli -h 172.23.238.38 storagegroup -addhlu -gname FBVPA001 -hlu $num_hlu_end -alu $num_lun\n";
			  &commande_Vplex($num_uid,$num_lun,$pref,$mon_volume,$ldev);
		}
		else {
	             print "\nOn continue\n";
		     return "next";
                }
}	

sub action_vnxG {		######################## fonction de creation des ldev Vnx Bat G ##########################
		  my ($taille,$pool,$mon_volume,$pref,$ldev,$baie,$lunid) = @_;
		  my $sp;
	          my $cmd_recupid = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 storagegroup -list -gname FBVPA002 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1;n[\$1]=\$2 }END{print n[m]}'`; #MODIF 28
        	  chomp($cmd_recupid);
                  my $cmd_sp = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40  getlun $cmd_recupid | awk '/Current\ owner:/ {print \$4}'`; #MODIF 28
                  chomp ($cmd_sp);
                  if ($cmd_sp eq "A"){$sp = "B";}
                  elsif ($cmd_sp eq "B"){ $sp = "A";}
#		  my $commande_creat_G = "/opt/Navisphere/bin/naviseccli -h 172.23.238.40 lun -create -type nonThin -capacity $taille -sq gb -poolId $pool -sp $sp -aa 1 -name $mon_volume-0 -tieringPolicy autoTier -initialTier highestAvailable";
		  my $commande_creat_G = "/opt/Navisphere/bin/naviseccli -h 172.23.238.40 lun -create -type nonThin -capacity $taille -sq bc -poolId $pool -sp $sp -aa 1 -name $mon_volume-0 -tieringPolicy autoTier -initialTier highestAvailable";
		  print "\n\nRecapitulatif: LEDV : $ldev Baie: $baie Lun de $taille Block pool $pool Nom du volume: $mon_volume \n\n";
		  print fichierlog "\n\nRecapitulatif: LEDV : $ldev Baie: $baie Lun de $taille Block pool $pool Nom du volume: $mon_volume \n";
		  print "Affichage de la commande:\n";
		  print "$commande_creat_G\n";
		  print "\n\n####Voulez Vous créer le Ldev $ldev sur la VNX du Batiment G###\n";
		  print "Reponse y/n ou q pour quitter le programme :  ";	
		  	my $input = <STDIN>;
		  	chomp $input;
		  	if ($input =~ m/^[Q]$/i){
		  			print "Exit du programme\n";
		  			exit(0);
		  	}
		  	elsif($input =~ m/^[Y]$/i)
		  	{
  			  print "\n\n######Creation des fichiers VNX BatG######\n";
                          print fichierlog "###############etape n°3 Creation des fichiers VNX BatG #########################\n";
			  print "Execution Verification VNX G....\n";
			  print fichierlog "$commande_creat_G \n";
			  my $cmd = `$commande_creat_G`;
			  print $cmd;
			  print fichierlog "$cmd\n";
		#  	      my $commande_storegroup = &commande_vnx($pref,$mon_volume); ### lancement des commandesa
			  my $num_hlu = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 storagegroup -list -gname FBVPA002 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1 }END{print m}'`;
			  print fichierlog "/opt/Navisphere/bin/naviseccli -h 172.23.238.40 storagegroup -list -gname FBVPA002 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1 }END{print m}'";
			  my $num_hlu_end = $num_hlu + 1;
			  my $num_lun = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 lun -list -name $mon_volume-0 -uid | awk \'\$1~/LOGICAL/ \{print \$4\}\'`;
			  print fichierlog "/opt/Navisphere/bin/naviseccli -h 172.23.238.40 lun -list -name $mon_volume-0 -uid | awk \'\$1~/LOGICAL/ \{print \$4\}\'\n";
			  chomp ($num_lun);
			  my $num_uid = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 getlun $num_lun | awk \'/^UID/ \{print \$2\}\' | sed -e s/\://g | tr A-Z a-z`;
			  print fichierlog "/opt/Navisphere/bin/naviseccli -h 172.23.238.40 getlun $num_lun | awk \'/^UID/ \{print \$2\}\' | sed -e s/\://g | tr A-Z a-z\n";
			  chomp ($num_uid);
			  print "Volume :$mon_volume\n Lun:$num_lun \n Hlu:$num_hlu_end \n UID:$num_uid \n";
			  print fichierlog "Volume :$mon_volume\n Lun:$num_lun \n Hlu:$num_hlu_end \n UID:$num_uid \n";
			  my $num_stroreage = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 storagegroup -addhlu -gname FBVPA002 -hlu $num_hlu_end -alu $num_lun`;
			  print fichierlog "/opt/Navisphere/bin/naviseccli -h 172.23.238.40 storagegroup -addhlu -gname FBVPA002 -hlu $num_hlu_end -alu $num_lun \n";
			  &commande_Vplex($num_uid,$num_lun,$pref,$mon_volume,$ldev);
			}
			  else {
	                    print "\nOn continue\n";
			    return "next";
			}
}				

sub gen_nom {
	my ($pref,$l_tc,$l_pool,$l_label,$l_lunid,$l_cluster_final) = @_;
	my $nom_def;
	my $label_mod;
	my $type;
	my $lunid;
	if (($optprincipal) && ($l_cluster_final =~ m/_/)){
#		if (!(-e "$chemin/$HG/ingest.txt")){
		if (!(-e "/mnt/MIG_EMC/lpar/$lhg/result/ingest.txt")){
	#		open (fichierIngest,"$chemin/$HG/ingest.txt") || die ("Erreur d'ouverture du fichier Ingest Merci de le créer au prealable\n ");
			#print "/mnt/MIG_EMC/lpar/$lhg/result/ingest.txt";
			print "Préparation de l'ingest \n";
			open (fichierIngest,">/mnt/MIG_EMC/lpar/$lhg/result/ingest.txt") || die ("Erreur d'ouverture du fichier Ingest Merci de le créer au prealable\n ");
			print fichierIngest "./viprcli -hostname viprcontroller.maif.local exportgroup add_vol -name $HG"."_NPIV  -pr MAIF  -v ";
			close (fichierIngest);
			}
	}
#	if($l_label =~ m/[aA][sS][mM]/ ){ $label_mod = "ASM";}
	if ($l_label =~ m/[aA][sS][mM][cC][lL][iI]/ ){$label_mod = "ASMCLI";}
	elsif ($l_label =~ m/[aA][sS][mM]_[cC][lL][iI]/ ){$label_mod = "ASMCLI";}
	elsif ($l_label =~ m/[aA][sS][mM][dD][aA][tT][aA]/ ){$label_mod = "ASMDATA";}
	elsif ($l_label =~ m/[aA][sS][mM]_[dD][aA][tT][aA]/ ){$label_mod = "ASMDATA";}
	elsif ($l_label =~ m/[aA][sS][mM][bB][aA][cC][kK][uU][pP]/ ){ $label_mod = "ASMBACKUP";}
	elsif ($l_label =~ m/[aA][sS][mM]_[bB][aA][cC][kK][uU][pP]/ ){ $label_mod = "ASMBACKUP";}
	elsif ($l_label =~ m/[rR][oO][oO][tT]/ ){$label_mod = "ROOTVG";}
	#elsif ($l_label =~ m/[aA][pP][pP][sS]/ ){$label_mod = "APPSVG";}
	elsif ($l_label =~ m/[gG][pP][fF]/ ){$label_mod = "GPFS";}
	else {
		my (undef,$label) = split /_/,$l_label;
		if ($label =~ m/#/){
			my ($label_mod0,undef) = split /#/,$label;
			$label = $label_mod0;
		}
        	$label_mod = uc($label);
	}

	$env = "PROD" if ($env eq "P");
	$env = "HPROD" if ($env eq "HP");
	$l_pool = "G" if ($l_pool == 0);
	$l_pool = "S" if ($l_pool == 1);
	$l_pool = "B" if ($l_pool == 2);
	#$dec_num = sprintf("%d", hex($l_lunid));
	if ($l_label =~ m/#/){			###modifier pour prendre que les deux digit aprés ou avant le & ####
		print "#####Mode cluster LunID forcé######\n";
		my (undef,$lunforce) = split /#/,$l_label;
		if ($lunforce =~ m/&/){
		   my ($lunforceet,undef) = split /&/, $lunforce;	
		   $lunid = sprintf ('%03.d',$lunforceet);	
		}
		else{
		   $lunid = sprintf ('%03.d',$lunforce);
		}
	}
	else {	
		$lunid = sprintf ('%03.d',$l_lunid);#####fonction 3 digit pour lunid#######	
	     }	
	if ($l_label =~ m/&/){
	 	print "#####Mode Batiment forcé#####\n";
		my (undef,$batforce) = split /&/,$l_label;
		$pref = $batforce;
	}	
		#############################################################################################
	if ($l_tc eq "yes"){
               	$type = "DD$pref";
	}
	else {
                $type = "DL$pref";
       	}
	
	
#	print "mon lunid mod:$lunid\n";	
	if ($HG =~ m/[vV][iI]4/){
		$nom_def = "$HG"."_"."$type"."_"."$env"."_"."$l_pool"."_"."$lunid";
	}
	elsif ($label_mod eq "")
		{
		 print "Attention Label non valide -->: \n";
		 print fichierlog "Attention Label non valide -->: \n";
		 $nom_def = "$l_cluster_final"."_"."$type"."_"."$env"."_"."$l_pool"."_"."$lunid";	
		}
	else{

		$nom_def = "$l_cluster_final"."_"."$label_mod"."_"."$type"."_"."$env"."_"."$l_pool"."_"."$lunid";
	}
	if (($optprincipal) && ($l_cluster_final =~ m/_/)){ ######################faire verification dan sfichier presence du ldev########
		
		open (fichierIngest, "</mnt/MIG_EMC/lpar/$lhg/result/ingest.txt");
		if (grep /\Q$nom_def/, <fichierIngest>){
			print "Volume present dans fichier Ingest on passe \n";	
		}
		else { 
			close (fichierIngest);
			print "volume non present dans fichier Ingest on rajoute\n";
			open (fichierIngest2, ">>/mnt/MIG_EMC/lpar/$lhg/result/ingest.txt");
			print fichierIngest2 "$nom_def:$lunid ";
			close (fichierIngest2);
		}	
	
	}	
	return ($nom_def);
}

sub commande_Vplex {
	my ($l_num_uid,$l_num_lun,$l_pref,$nom_vol,$l_ldev) = @_;
	my ($OX1,$OX2,$OX3) = split /:/, $l_ldev;
	if ($l_pref eq "I"){
		print fichierlog "\n\n\n################etape n°4 Creation des Lun Vplex Bat I ##################\n";
		open (fichierVplexI, ">$chemin/$HG/Vplex_I.txt") || die ("Erreur d'ouverture de fichier");
		print fichierVplexI "cd /clusters/cluster-1/storage-elements/storage-arrays/\n";
		#print fichierlog "cd /clusters/cluster-1/storage-elements/storage-arrays/\n";
		my $command_redisco = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/array+re-discover\" -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-1/storage-elements/storage-arrays/*0075 -c cluster-1 -f\\\"}\"";
		my $cmd_redisco = `$command_redisco`;
		print "$cmd_redisco\n";
		print fichierlog "$command_redisco\n";
		print fichierlog "$cmd_redisco\n";
		print fichierVplexI "array re-discover *0075 --force\n";
		print fichierVplexI "cd /clusters/cluster-1/storage-elements/storage-volumes/\n";
		#print fichierlog "cd /clusters/cluster-1/storage-elements/storage-volumes/\n";
		my $lun_claim = sprintf ('%05.d',$l_num_lun);
		print fichierVplexI "storage-volume claim -n VCKM00152300075-$lun_claim -d VPD83T3:$l_num_uid\n";
		my $command_claim = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/storage-volume+claim\"  -X POST -d \"{\\\"args\\\":\\\"-n VCKM00152300075-$lun_claim -d VPD83T3:$l_num_uid -f\\\"}\"";
#		print "$command_claim\n";
		sleep(3);
		my $cmd_claim = `$command_claim`;
		#print fichierlog "storage-volume claim -n VCKM00152300075-$lun_claim -d VPD83T3:$l_num_uid\n";
		print "$cmd_claim\n";
		print fichierlog "$command_claim\n";
		print finchierlog "$cmd_claim\n";
		print fichierVplexI "extent create -d VCKM00152300075-$lun_claim\n";
		my $command_extend = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/extent+create\" -X POST  -d \"{\\\"args\\\":\\\"-d VCKM00152300075-$lun_claim\\\"}\"";
		my $cmd_extend = `$command_extend`;
		print finchierlog "$command_extend\n";
		print finchierlog "$cmd_extend\n";
		print "$cmd_extend\n";
		#print fichierlog "extent create -d VCKM00152300075-$lun_claim\n";
		print fichierVplexI "local-device create -n device_VCKM00152300075-$lun_claim -g raid-0 -e extent_VCKM00152300075-$lun_claim"."_1\n";
		my $command_device = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/local-device+create\" -X POST  -d \"{\\\"args\\\":\\\"-n $HG"."_VCKM00152300075-"."$lun_claim"."_VSP$OX2$OX3"." -g raid-0 -e extent_VCKM00152300075-$lun_claim"."_1 -f\\\"}\"";
		my $cmd_device = `$command_device`;
		print "$cmd_device\n";
		print fichierlog "$command_device\n";
		print fichierlog "$cmd_device\n";
		print fichierlog "local-device create -n device_VCKM00152300075-$lun_claim -g raid-0 -e extent_VCKM00152300075-$lun_claim"."_1\n";
		print fichierlog "###################################################################################\n";

	}
	elsif($l_pref eq "G"){
		print fichierlog "\n\n\n################etape n°4 Creation des Lun Vplex Bat G ##################\n";
		open (fichierVplexG, ">$chemin/$HG/Vplex_G.txt") || die ("Erreur d'ouverture de fichier");
		print fichierVplexG "cd /clusters/cluster-2/storage-elements/storage-arrays/\n";
		my $command_redisco = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/array+re-discover\" -X POST -d \"{\\\"args\\\":\\\"-a /clusters/cluster-2/storage-elements/storage-arrays/*0074 -c cluster-2 -f\\\"}\"";
                my $cmd_redisco = `$command_redisco`;
                print "$cmd_redisco\n";
		print fichierlog "$command_redisco\n";
                print fichierlog "$cmd_redisco\n";
		#print fichierlog "cd /clusters/cluster-2/storage-elements/storage-arrays/\n";
                print fichierVplexG "array re-discover *0074 --force\n";
		#print fichierlog "array re-discover *0074 --force\n";
                print fichierVplexG "cd /clusters/cluster-1/storage-elements/storage-volumes/\n";
		#print fichierlog "cd /clusters/cluster-1/storage-elements/storage-volumes/\n";
                my $lun_claim = sprintf ('%05.d',$l_num_lun);
                my $command_claim = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/storage-volume+claim\" -X POST -d \"{\\\"args\\\":\\\"-n VCKM00152300074-$lun_claim -d VPD83T3:$l_num_uid -f\\\"}\"";
#               print "$command_claim\n";
		sleep(3);
                my $cmd_claim = `$command_claim`;
                #print fichierlog "storage-volume claim -n VCKM00152300075-$lun_claim -d VPD83T3:$l_num_uid\n";
                print "$cmd_claim\n";
		print fichierlog "command_claim:$command_claim\n";
                print finchierlog "cmd_claim:$cmd_claim\n";
		print fichierVplexG "storage-volume claim -n VCKM00152300074-$lun_claim -d VPD83T3:$l_num_uid\n";
	#	print fichierlog "storage-volume claim -n VCKM00152300074-$lun_claim -d VPD83T3:$l_num_uid\n";
                print fichierVplexG "extent create -d VCKM00152300074-$lun_claim\n";
	#	print fichierlog "extent create -d VCKM00152300074-$lun_claim\n";
                print fichierVplexG "local-device create -n device_VCKM00152300074-$lun_claim -g raid-0 -e extent_VCKM00152300074-$lun_claim"."_1\n";
		print fichierlog "local-device create -n device_VCKM00152300074-$lun_claim -g raid-0 -e extent_VCKM00152300074-$lun_claim"."_1\n";
		my $command_extend = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/extent+create\" -X POST  -d \"{\\\"args\\\":\\\"-d VCKM00152300074-$lun_claim\\\"}\"";
                my $cmd_extend = `$command_extend`;
		print finchierlog "$command_extend\n";
                print finchierlog "$cmd_extend\n";
                print "$cmd_extend\n";
                print fichierVplexG "virtual-volume create --device device_VCKM00152300074-$lun_claim --set-tier 1\n";
		my $command_device = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/local-device+create\" -X POST  -d \"{\\\"args\\\":\\\"-n $HG"."_VCKM00152300074-"."$lun_claim"."_VSP$OX2$OX3"." -g raid-0 -e extent_VCKM00152300074-$lun_claim"."_1 -f\\\"}\"";
                my $cmd_device = `$command_device`;
                print "$cmd_device\n";
		print fichierlog "$command_device\n";
                print fichierlog "$cmd_device\n";
		print fichierlog "###################################################################################\n";
 	}
	else {
		open (fichierVplexI, ">$chemin/$HG/Vplex_I.txt") || die ("Erreur d'ouverture de fichier");
		open (fichierVplexG, ">$chemin/$HG/Vplex_G.txt") || die ("Erreur d'ouverture de fichier");
	}		
}

	
sub addvolumevsptovplex {
	my ($l_dev,$l_baies,$l_lunid,$l_nomdevice) = @_;	
	my $vplex;
	my $monfic;
	my $operation;		
	my $inst;
	chomp ($l_lunid); 
	print "Volume to vplex\n";
	$inst = 1839 if ($l_baies == "85183");
	$inst = 3179 if ($l_baies == "53317");
		
	print fichierlog "###########################	Ajout du volume dans les 4 hostgroups sur les VSP        ################################################\n"; 
	print "Lock baie $l_baies\n";
	print fichierlog "Lock baie $l_baies\n";
	my $command_vsp0 = "export HORCMINST=$inst; raidcom add lun -port 'CL1-B' 'HG_MIGEMC_1B' -ldev_id '$l_dev' -s '$l_baies'"; 
	print fichierlog "$command_vsp0\n";
	my $command_vsp1 = "export HORCMINST=$inst; raidcom add lun -port 'CL2-B' 'HG_MIGEMC_2B' -ldev_id '$l_dev' -s '$l_baies'";
	print fichierlog "$command_vsp1\n";
	my $command_vsp2 = "export HORCMINST=$inst; raidcom add lun -port 'CL5-D' 'HG_MIGEMC_5D' -ldev_id '$l_dev' -s '$l_baies'";
	print fichierlog "$command_vsp2\n";
	my $command_vsp3 = "export HORCMINST=$inst; raidcom add lun -port 'CL6-D' 'HG_MIGEMC_6D' -ldev_id '$l_dev' -s '$l_baies'";
	print fichierlog "$command_vsp3\n";
	
	my $retour_lock = addLock($l_baies);		##################Lock baie HDS#######################
	while ($retour_lock == 2){
		$retour_lock = addLock($l_baies);            ##################Lock baie HDS#######################
	}
	
	if ($retour_lock == 0 ){
		my $cmd_vsp0 =`$command_vsp0`;		#################### Ajout Lun dans Hostgroup VSP  #########
		if (!(grep /will be used for adding/,$cmd_vsp0)) { print "Erreur Baie HDS on sort du script\n";&delLock($l_baies);exit(0);}
		print fichierlog "$cmd_vsp0\n";
		my $cmd_vsp1 =`$command_vsp1`;
		if (!(grep /will be used for adding/,$cmd_vsp1)) { print "Erreur Baie HDS on sort du script\n";&delLock($l_baies);exit(0);}
		print fichierlog "$cmd_vsp1\n";	
		my $cmd_vsp2 =`$command_vsp2`;
		if (!(grep /will be used for adding/,$cmd_vsp2)) { print "Erreur Baie HDS on sort du script\n";&delLock($l_baies);exit(0);}
		print fichierlog "$cmd_vsp2\n";
		my $cmd_vsp3 =`$command_vsp3`;
		if (!(grep /will be used for adding/,$cmd_vsp3)) { print "Erreur Baie HDS on sort du script\n";&delLock($l_baies);exit(0);}
		print fichierlog "$cmd_vsp3\n";
		$operation = 1;
	}	
#	else {exit(0);}
	else {next;}
	&delLock($l_baies) if ($operation == 1);	##################Unlock baie#########################
	
	##########################	refresh Vplex plus claim du volume		######################################################### 
	my ($OX1,$OX2,$OX3) = split /:/, $l_dev;
	########	recuperation du SID vplex du volume ########
	if ($l_baies == "85183"){
		 my $command_redisco = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/array+re-discover\" -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-1/storage-elements/storage-arrays/*85183 -c cluster-1 -f\\\"}\"";
        	 my $cmd_redisco = `$command_redisco`;
	         print fichierlog "$command_redisco\n";
	         print fichierlog "$cmd_redisco\n";
		 my $command_sid = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/clusters/cluster-1/storage-elements/storage-arrays/HITACHI-OPEN-V-$l_baies/logical-units\" | grep -i $OX2$OX3`;
 		 chomp $command_sid;
		 my (undef,undef,undef,$SID,undef) = split /"/,$command_sid;
	         print "mon SID = $SID\n";
		 my $command_claim = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/storage-volume+claim\"  -X POST -d \"{\\\"args\\\":\\\"-n VSP$l_baies"."_"."$OX2$OX3 -d $SID -f\\\"}\"";
		 print fichierlog "$command_claim\n";
		 my $cmd_claim = `$command_claim`;
		 print fichierlog "$cmd_claim\n";	
	         my $command_claim = "storage-volume claim  --thin-rebuild  -n VSP$l_baies"."_"."$OX2$OX3 -d $SID" ;
	         #print "#$command_claim#\n";
	         print fichiervsp85183 "$command_claim\n";
		 my $command_extend = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/extent+create\" -X POST  -d \"{\\\"args\\\":\\\"-d VSP$l_baies"."_"."$OX2$OX3\\\"}\"";	
		 print fichierlog "$command_extend\n";
		 my $cmd_extent = `$command_extend`;
		 print fichierlog "fichierlog\n";	
	         my $command_extent = "extent create -d VSP$l_baies"."_"."$OX2$OX3";
	         #print "#$command_extent#\n";
	         print fichiervsp85183 "$command_extent\n";
		 my $command_device = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/local-device+create\" -X POST  -d \"{\\\"args\\\":\\\"-n device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG -g raid-0 -e extent_VSP$l_baies"."_"."$OX2$OX3"."_1 -f\\\"}\"";
		 print fichierlog "$command_device\n";
		 my $cmd_device = `$command_device`;
		 print fichierlog "$cmd_device\n";
	         my $command_device = "local-device create -n device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG -g raid-0 -e extent_VSP$l_baies"."_"."$OX2$OX3"."_1";
#	         print "#$command_device#\n";
	         print fichiervsp85183 "$command_device\n";
		 my $command_volume = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/virtual-volume+create\"  -X POST  -d \"{\\\"args\\\":\\\"-r device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG -t 1 \\\"}\"";
		 print fichierlog "$command_volume\n";
		 my $cmd_volume = `$command_volume`;
		 print fichierlog "$cmd_volume\n";		
	         my $command_volume = "virtual-volume create --device device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG --set-tier 1";
	         #print "#$command_volume#";
	         print fichiervsp85183 "$command_volume\n";
		 my $command_rename = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/set\"  -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-1/virtual-volumes/device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG"."_vol::name -v $l_nomdevice -f\\\"}\"";
 		 print fichierlog "$command_rename\n";
                 my $cmd_rename = `$command_rename`;
		 print $cmd_rename;
		 print fichierlog "$cmd_rename\n";
		 print fichierlog "################encapsulation du ldev:$l_dev de la baie $l_baies ####################\n";
		 print "################encapsulation du ldev:$l_dev de la baie $l_baies -> $l_nomdevice OK ####################\n";
		 #print fichierlog "$command_claim\n$command_extent\n$command_device\n$command_volume\n";
	}
	if ($l_baies == "53317"){
		my $command_redisco = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/array+re-discover\" -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-2/storage-elements/storage-arrays/*53317 -c cluster-2 -f\\\"}\"";
                 my $cmd_redisco = `$command_redisco`;
		 print fichierlog "$command_redisco";
                 print fichierlog "$cmd_redisco\n";
		 my $command_sid = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/clusters/cluster-2/storage-elements/storage-arrays/HITACHI-OPEN-V-$l_baies/logical-units\" | grep -i $OX2$OX3`;
                 chomp $command_sid;
                 my (undef,undef,undef,$SID,undef) = split /"/,$command_sid;
                 print "mon SID = $SID\n";
                 my $command_claim = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/storage-volume+claim\"  -X POST -d \"{\\\"args\\\":\\\"-n VSP$l_baies"."_"."$OX2$OX3 -d $SID -f\\\"}\"";
                 print fichierlog "$command_claim\n";
                 my $cmd_claim = `$command_claim`;
                 print fichierlog "$cmd_claim\n";
                 my $command_claim = "storage-volume claim  --thin-rebuild  -n VSP$l_baies"."_"."$OX2$OX3 -d $SID" ;
                 #print "#$command_claim#\n";
                 print fichiervsp53317 "$command_claim\n";
                 my $command_extend = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/extent+create\" -X POST  -d \"{\\\"args\\\":\\\"-d VSP$l_baies"."_"."$OX2$OX3\\\"}\"";
                 print fichierlog "$command_extend\n";
                 my $cmd_extent = `$command_extend`;
                 print fichierlog "fichierlog\n";
                 my $command_extent = "extent create -d VSP$l_baies"."_"."$OX2$OX3";
                 #print "#$command_extent#\n";
                 print fichiervsp53317 "$command_extent\n";
                 my $command_device = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/local-device+create\" -X POST  -d \"{\\\"args\\\":\\\"-n device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG -g raid-0 -e extent_VSP$l_baies"."_"."$OX2$OX3"."_1 -f\\\"}\"";
                 print fichierlog "$command_device\n";
                 my $cmd_device = `$command_device`;
                 print fichierlog "$cmd_device\n";
                 my $command_device = "local-device create -n device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG -g raid-0 -e extent_VSP$l_baies"."_"."$OX2$OX3"."_1";
#                print "#$command_device#\n";
                 print fichiervsp53317 "$command_device\n";
                 my $command_volume = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/virtual-volume+create\"  -X POST -d \"{\\\"args\\\":\\\"-r device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG -t 1 \\\"}\"";
                 print fichierlog "$command_volume\n";
                 my $cmd_volume = `$command_volume`;
                 print fichierlog "$cmd_volume\n";
                 my $command_volume = "virtual-volume create --device device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG --set-tier 1";
	         print fichiervsp53317 "$command_volume\n";
		 my $command_rename = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/set\"  -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-2/virtual-volumes/device_VSP$l_baies"."_"."$OX2$OX3"."_"."$HG"."_vol::name -v $l_nomdevice -f\\\"}\"";
                 print fichierlog "$command_rename\n";
                 my $cmd_rename = `$command_rename`;
		 print $cmd_rename;
                 print fichierlog "$cmd_rename\n";
		 print fichierlog "################encapsulation du ldev:$l_dev de la baie $l_baies ####################\n";
		 print "################encapsulation du ldev:$l_dev de la baie $l_baies -> $l_nomdevice OK ####################\n";
                #print fichierlog "$command_claim\n$command_extent\n$command_device\n$command_volume\n";
	}
	
}	

sub addLock() {
	my $baie = shift;
	my $ret = 1;
	my $retcode=0;	
	my $lock_inst;
	$lock_inst = 1839 if ($baie == "85183");
        $lock_inst = 3179 if ($baie == "53317");
	
	my $cmd="raidcom get resource -s '$baie' -ITC$lock_inst -login maintenance raid-mainte | grep \"Locked\"";	
	$ret = system( $cmd );
	if ($ret == 0) {
		print("######################################################################\n");
		print("ECHEC : Baie $baie deja lockee, merci de re-essayer plus tard !!\n");
		print fichierlog ("ECHEC : Baie $baie deja lockee, merci de re-essayer plus tard !!\n");
		print("Les informations necessaires sont dans le fichier de log \n");
		print "Voulez vous essayer de nouveau?\n";
		print "Reponse Y/N : ";
		my $input_lock = <STDIN>;
                chomp $input_lock;
		while (($input_lock ne "Y")&&($input_lock ne "N")&&($input_lock ne "y")&&($input_lock ne "n")){
                        print "Merci de saisir la bonne valeur Y/N :";
                        $input_lock = <STDIN>;
                        chomp $input_lock;
                }		
			if (($input_lock eq "N")|| ($input_lock eq "n")){
				print("######################################################################\n");
        	                print "Attention encapsulation à refaire car baie lockée\n";
				print("######################################################################\n");
				print fichierlog ("Attention encapsulation à refaire car baie lockée\n");
				$retcode = 1;
        	        }
			elsif (($input_lock eq "Y")|| ($input_lock eq "y")){
				$retcode = 2;
					
			}
		


        } else {
		print("Pose du lock sur la baie $baie\n") if $optVerbose;
		my $cmd="raidcom lock resource -resource_name meta_resource -s '$baie' -ITC$lock_inst -login maintenance raid-mainte";
		my $ret_lock = system( $cmd );
		if ($ret_lock == 0) {
			print("Pose du lock OK.\n");
			$retcode = 0;
		} else {
			print("ECHEC : impossible de poser un verrou.\n");
			 print fichierlog ("ECHEC : impossible de poser un verrou !!\n");
			$retcode = 1;
		}
	}
	return $retcode;
}
sub delLock() {
        my $baie = shift;
	my $ret = 1;
	my $lock_inst;
        $lock_inst = 1839 if ($baie == "85183");
        $lock_inst = 3179 if ($baie == "53317");

        print("Suppression du lock sur la baie $baie\n") if $optVerbose;
        my $cmd="raidcom unlock resource -resource_name meta_resource -s '$baie' -ITC$lock_inst -login maintenance raid-mainte";
        $ret = system( $cmd );
        if ($ret == 0) {
                print("Suppression du lock OK.\n");
        } else {
                print("ECHEC : impossible de supprimer le verrou.\n");
                exit(1);
        }	
}

sub zoning {
	if(! (-e "$chemin/$HG/F1.log")){
	        open (fichierF1,">$chemin/$HG/F1.log") || die ("Erreur d'ouverture de fichier");}
	if(! (-e "$chemin/$HG/F2.log")){
		open (fichierF2,">$chemin/$HG/F2.log") || die ("Erreur d'ouverture de fichier");}

        my @zones_f1;
        my @zones_f2;
        print fichierF1 "#!/usr/bin/expect\nspawn su - admstk -c \"ssh admin\@fsstk005\"\n";
        print fichierF1 "expect \"admin>\"\nsend \"setcontext 1\\r\"\n";
        print fichierF2 "#!/usr/bin/expect\nspawn su - admstk -c \"ssh admin\@fsstk006\"\n";
        print fichierF2 "expect \"admin>\"\nsend \"setcontext 1\\r\"\n";
        my @cmd_switchf1 = `su - admstk -c \"ssh -o 'BatchMode yes' -o 'ConnectTimeout 5' admin\@fsstk005 configshow -fid 1\"`;
        my @cmd_switchf2 = `su - admstk -c \"ssh -o 'BatchMode yes' -o 'ConnectTimeout 5' admin\@fsstk006 configshow -fid 1\"`;
        my @f1_all = grep {/$lhg/} @cmd_switchf1;
        my @f2_all = grep {/$lhg/} @cmd_switchf2;
        #################################fabric du bas #################################################
        if (@f1_all){
		print "#########Zone à supprimer :\n";
                foreach (@f1_all) {
                        if ($_ =~ /zone/){
                            if ($_ =~ /HDS/){
                                my ($myzone,undef,undef) = split /:/,$_;
                                my $zone = substr ($myzone,5);
				print "#########Fabric du Bas :$zone \n";	
                                print fichierF1 "expect \"admin> \"\nsend \"cfgremove ZS_COV2_BAS, $zone\\r\"\n";
                                    }
                        }
                }
                print fichierF1 "expect \"admin> \"\nsend \"cfgenable ZS_COV2_BAS\\r\"\nexpect \"admin> \"\nsend \"y\\r\"\nexpect \"admin> \"\nsend \"exit\\r\"\nexpect eof";
        }
        else {print "Pas de zoning trouvé dans la fabric du Bas pour $lhg\n";
             print fichierlog "Pas de zoning trouvé dans la fabric du Bas pour $lhg\n";}
        ####################################fabric du haut #############################################
	if (@f2_all){	
		print "#########Zone à supprimer :\n";
		foreach (@f2_all) {
			if ($_ =~ /zone/){
			     if ($_ =~ /HDS/){
			 	my ($myzone,undef,undef) = split /:/,$_;
				my $zone = substr ($myzone,5);
                                print "#########Fabric du Haut :$zone \n";
				print fichierF2 "expect \"admin> \"\nsend \"cfgremove ZS_COV2_HAUT, $zone\\r\"\n";
			    }
			}
		}
		print fichierF2 "expect \"admin> \"\nsend \"cfgenable ZS_COV2_HAUT\\r\"\nexpect \"admin> \"\nsend \"y\\r\"\nexpect \"admin> \"\nsend \"exit\\r\"\nexpect eof";
	}
	else {print "Pas de zoning trouvé dans la fabric du haut pour $lhg\n";
	     print fichierlog "Pas de zoning trouvé dans la fabric du haut pour $lhg\n";}

	######execution des deux fichiers avec les zones######
	print " \n#####Merci de desactiver les zones avant de repondre Yes(fichier F1.log et F2.log dans repertoire du serveur) : $lhg \n";
	print "Reponse y/n ou q pour quitter le programme :  ";
	my $input = <STDIN>;
	chomp $input;
	if ($input =~ m/^[Q]$/i){
		 print "Exit du programme\n";
		 exit(0);
	}
	 elsif($input =~ m/^[Y]$/i){
		#######verifier si zoning actif ou pas pour continuer#######
		print "Zoning désactiver on contiue\n";
		return 1;
		######executer le fichier F1.log######
		######executer le fichier F2.log######
	}
}
sub storage_view{
        my ($l_dev,$l_lun,$l_baie,$l_tc,$l_hg) = @_;
	$l_hg = lc($l_hg);	
	my $lunid = substr($l_lun, -3);	
	print "storageview $l_baie->$l_tc->$l_dev->$l_lun->$lunid->$l_hg\n";
	print fichierlog "storageview $l_baie->$l_tc->$l_dev->$l_lun->$lunid->$l_hg\n";
	open (FICOS,"</mnt/MIG_EMC/lpar/$l_hg/result/table_disk.vsp.txt") || die ("Fichier OS absent storage_view\n");
	my @tab_os = <FICOS>;
        close(FICOS);
	my ($l_aa,$l_bb,$l_cc) = split /:/,$l_dev;
	my @ligne = grep (/$l_bb$l_cc/,@tab_os);
	open (fichieros,">>/mnt/MIG_EMC/lpar/$l_hg/result/table_disk.emc.txt") || die ("Probleme fichier OS Emc\n");
	
	if ($l_baie eq "85183" || $l_tc eq "yes"){
		print "Ajout dans la storage view V1_$l_hg du disque $l_dev\n";
	        my $command_virtual = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/export+storage-view+addvirtualvolume\" -X POST -d \"{\\\"args\\\":\\\" -v V1_$l_hg -o ($lunid,$l_lun) -f\\\"}\"";
		print fichierlog "Storage view V1_$l_hg du disque $l_dev\n";
		print fichierlog "$command_virtual\n";
		my $cmd_vitual = `$command_virtual`;
		print fichierlog "$cmd_vitual\n";
		print "$cmd_vitual\n";
		print "Ajout dans la storage view V1_$l_hg-lpm du disque $l_dev\n";
		my $command_id = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-1/virtual-volumes/$l_lun?vpd-id\" |awk -F\\\" '\/value\/ {print \$4}'";
		my $cmd_id =`$command_id`;
		my (undef,$id_fin) = split /:/,$cmd_id;
		chomp($id_fin);	
		print fichierlog "$command_id\n";
		print fichierlog "$cmd_id\n";
		print "$cmd_id\n";
		chomp (@ligne[0]);
		print fichieros "@ligne[0]$id_fin;\n";
		print fichierlog "$ligne;$cmd_id;\n";
		
		my $command_virtual_lpm = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/export+storage-view+addvirtualvolume\" -X POST -d \"{\\\"args\\\":\\\" -v V1_$l_hg-lpm -o ($lunid,$l_lun) -f\\\"}\"";
		print fichierlog "Storage view V1_$l_hg-lpm du disque $l_dev\n";
                print fichierlog "$command_virtual_lpm\n";
	#	print "ma commande:$command_virtual_lpm\n";##### A supprimer#####
		my $cmd_vitual_lpm = `$command_virtual_lpm`;
                print fichierlog "$cmd_vitual_lpm\n";
	}
	if ($l_baie eq "53317" || $l_tc eq "yes"){
		print "Ajout dans la storage view V2_$l_hg du disque $l_dev\n";
                my $command_virtual = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA002/vplex/export+storage-view+addvirtualvolume\" -X POST -d \"{\\\"args\\\":\\\" -v V2_$l_hg -o ($lunid,$l_lun) -f\\\"}\"";
		print fichierlog "Storage view V2_$l_hg du disque $l_dev\n";
                print fichierlog "$command_virtual\n";
         #       print "ma commande:$command_virtual\n";##### A supprimer#####
		my $cmd_vitual = `$command_virtual`;
                print fichierlog "$cmd_vitual\n";
                print "Ajout dans la storage view V2_$l_hg-lpm du disque $l_dev\n";
		 my $command_id = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-2/virtual-volumes/$l_lun?vpd-id\" |awk -F\\\" '\/value\/ {print \$4}'";
                my $cmd_id =`$command_id`;
		print "$cmd_id\n";
                my (undef,$id_fin) = split /:/,$cmd_id;
                chomp($id_fin);
                print fichierlog "$command_id\n";
                print fichierlog "$cmd_id\n";
		print "$cmd_id\n";
                chomp (@ligne[0]);
                print fichieros "@ligne[0]$id_fin;\n";
                print fichierlog "$ligne;$cmd_id;\n";

                my $command_virtual_lpm = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA002/vplex/export+storage-view+addvirtualvolume\" -X POST -d \"{\\\"args\\\":\\\" -v V2_$l_hg-lpm -o ($lunid,$l_lun) -f\\\"}\"";
		print fichierlog "Storage view V2_$l_hg du disque $l_dev\n";
                print fichierlog "$command_virtual_lpm\n";
         #       print "ma commande:$command_virtual_lpm\n";##### A supprimer#####
		my $cmd_vitual_lpm = `$command_virtual_lpm`;
                print fichierlog "$cmd_vitual_lpm\n";
         #      print "ma commande:$command_virtual_lpm\n";
	}
	print "################################################\n\n\n\n\n";	
}


sub trait_fic_os
{
	open (FICOS,"</mnt/MIG_EMC/lpar/$lhg/result/table_disk.vsp.txt") || die ("Fichier OS absent trait_fic_os\n");
	my @tab_os = <FICOS>;
	close(FICOS);
	my @tab_def_os;
	my @tabb_def_baie;
	print "############################################################################################################\n";
	print "Traitement fichier OS: \n";
	foreach (@tab_os){
		my ($ldevhds,undef,$baiehds,undef,undef,undef,undef,undef) = split (';',$_);
		push (@tab_def_os,"$ldevhds;$baiehds");
	}
	
	
	foreach my $ligne (@tab_contenu_HG)
	{
	        my ($baie, $ldev, $host_group, $lunid) = split /;/, $ligne;
		my ($AA,$BB,$CC) = split /:/, $ldev;
		push(@tabb_def_baie,"$BB$CC;$baie");
	}

	 my %temp;
 	 @temp{@tab_def_os} = 0..$#tabb_def_baie;
 
	  for my $val (@tabb_def_baie) {
	    if( exists $temp{$val} ) {
	      print "$val est présent dans l'inventaire OS.\n";
	    } else {
	      print "$val n'est pas dans l'inventaire OS.\n";
	    }
	 }
	print "############################################################################################################\n";
}


sub distributed {
	my ($l_nomdevice,$l_baie,$l_ldev) = @_;	
	my ($aa,$bb,$cc) = split (/:/,$l_ldev);
	my ($l_host,undef,undef) = split (/_/,$l_nomdevice);
	print "nomhost:$l_host\n";
	if ($l_baie == '85183'){
		my $command_virtu_dev = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-1/virtual-volumes/$l_nomdevice?supporting-device\" |awk -F\\\" '\/value\/ {print \$4}'";
		#print "$command_virtu_dev\n";
		my $cmd_virtu_dev = `$command_virtu_dev`;
		print fichierlog "$cmd_virtu_dev\n";
		chomp($cmd_virtu_dev);
		my $command_dev_ext = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-1/devices/$cmd_virtu_dev/components\"|awk -F\\\" '/name/ {A=\$4}END{print A}'";
		my $cmd_dev_ext =`$command_dev_ext`;
		#print "$command_dev_ext\n";
		print "$cmd_dev_ext";
		print fichierlog "Creation du destributed device \n";
		my $command_trouvldev = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA002/vplex/clusters/cluster-2/devices\" | awk -F\\\" '/name/ && /$bb$cc/ && /$l_host/ {print \$4}'"; 	
		print fichierlog "$command_trouvldev\n";
		my $cmd_trouvldev = `$command_trouvldev`;
		chomp ($cmd_trouvldev);
		print fichierlog "Creation du distributed device entre $l_nomdevice baie 85183 et le device de destination $cmd_trouvldev sur le vplex G \n";
		print "Creation du distributed device entre $l_nomdevice baie 85183 et le device de destination $cmd_trouvldev sur le vplex G \n";
		my $command_attach = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://$optvpa/vplex/device+attach-mirror\" -X POST -d \"{\\\"args\\\":\\\"-d $cmd_virtu_dev -m $cmd_trouvldev -f\\\"}\"";
		print fichierlog "$command_attach\n";
		my $cmd_attach = `$command_attach`;
		print "ATTACH dd:$cmd_attach\n";
		print fichierlog "$cmd_attach";
	}
	elsif ($l_baie == '53317'){
		my $command_virtu_dev = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-2/virtual-volumes/$l_nomdevice?supporting-device\" |awk -F\\\" '\/value\/ {print \$4}'";
                #print "$command_virtu_dev\n";
                my $cmd_virtu_dev = `$command_virtu_dev`;
		print fichierlog "$cmd_virtu_dev\n";
                chomp($cmd_virtu_dev);
		my $command_dev_ext = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/clusters/cluster-2/devices/$cmd_virtu_dev/components\"|awk -F\\\" '/name/ {A=\$4}END{print A}'";
		print fichierlog "$command_dev_ext\n";
		print "$command_dev_ext\n";
                my $cmd_dev_ext =`$command_dev_ext`;
                print "$cmd_dev_ext";
		print fichierlog $cmd_dev_ext;
		print fichierlog "Creation du destributed device \n";
                my $command_trouvldev = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/clusters/cluster-1/devices\" | awk -F\\\" '/name/ && /$bb$cc/ && /$l_host/ {print \$4}'";
                print fichierlog "$command_trouvldev\n";
                my $cmd_trouvldev = `$command_trouvldev`;
		chomp ($cmd_trouvldev);
                print fichierlog "Creation du distributed device entre $l_nomdevice baie 53317 et le device de destination $cmd_trouvldev sur le vplex I \n";
                print "Creation du distributed device entre $l_nomdevice baie 53317 et le device de destination $cmd_trouvldev sur le vplex I \n";
                my $command_attach = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://$optvpa/vplex/device+attach-mirror\" -X POST -d \"{\\\"args\\\":\\\"-d $cmd_virtu_dev -m $cmd_trouvldev -f\\\"}\"";
		print fichierlog "$command_attach\n";
                my $cmd_attach = `$command_attach`;
                print "ATTACH dd: $cmd_attach\n";
                print fichierlog "$cmd_attach";

	}
	print "##########################################################\n\n\n\n\n";
	
}


sub horcm  {
	my ($h_ldev,$h_baie) =@_;
	my @tab_horcm;
	my $recherche = substr $h_ldev, 3,5;
	
	#if ($h_baie == "85183"){
		open(FIC,"</etc/horcm183.conf");
		my @tab_horcmi = <FIC>;
		close (FIC);
	#	}
#	elsif($h_baie == "53317"){
		open (FIC,"</etc/horcm317.conf");
                my @tab_horcmg = <FIC>;
                close (FIC);

#	}
	my @tab_horcm = (@tab_horcmi,@tab_horcmg);
	my @contenu_horcm = grep {/$recherche/} @tab_horcm;

	if (@contenu_horcm){

		foreach (@contenu_horcm){
			my ($gr,undef,undef,undef) = split / /,$_;
			chomp $gr;
			return "Groupe de replication ->$gr<- pour instance horcm baie $h_baie \n#############################################################################################################\n";	
		}
				
	}
	else {return "Groupe de replication introuvable dans le fichier Horcm de Production\n##########################################################################################################\n";}

}

sub clean_fic {

	open (FIC,"</mnt/MIG_EMC/lpar/$lhg/result/table_disk.emc.txt") || ("Erreur d'ouverture de fichier");
	my @tab = <FIC>;
	close(FIC);
	my %doublon = ();
	my @unique = grep { ! $doublon{ $_ }++ } @tab;
	open (fichierfinal,">/mnt/MIG_EMC/lpar/$lhg/result/table_disk.emc.txt") || die ("Erreur d'ouverture de fichier");
	foreach (@unique){
	        print fichierfinal $_;
	}
	close (fichierfinal);

}


