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
$chemin = "/admin/Emc_mig/log";
$cheminsrc = "/admin/Emc_mig/trait_baies";
chomp ($chemin);

#------------------------------------Synopsis pour Option------------------------------------
=head1 SYNOPSIS

usage: 	migration_emc.pl HostGroup [--verbose] [--help] [--debug] 
	arg 1: le premier le HG
	Debug : Affhichage des tableaux
=cut


my ($optVerbose,$optHelp,$optdebug,$optcheck,$optclean,$opt_all,$optrename,$optvmware,$optauto);
GetOptions( "verbose!"=>\$optVerbose,
                "help|?",\$optHelp,
		"check",\$optcheck,
		"clean",\$optclean,
		"vmware",\$optvmware,
		"rename",\$optrename,
		"auto",\$optauto,
		"all",\$opt_all,
                "debug"=>\$optdebug);

pod2usage(1) if ( $optHelp );
#---------------------------------------------------------------------------------------------
if ( $optHelp ){
print "usage: $0 [-h | -?] [-l]
	-h|?	: Affichage de l'aide
	arg 1	: Hostgroup
	clean   : nettoyage des hostgroups de migration
	rename	: Renome les distributed devices	
	-help	: Affichage de l'aide\n";
exit -1;
}
print "\033[2J";
print "#########################################################################################\n";
print "########             Script de Migration VSP --> EMC 	 	 ########################\n";
print "########                                                         ########################\n";
print "########	 ./02_migration_instance_check_emc.pl HG	 ########################\n";
print "########                                                         ########################\n";				
print "########             Check commit et nettoyage des instances     ########################\n";
print "########                                                         ########################\n";
print "########  ./02_migration_instance_check_emc.pl HG --check	 ########################\n";		
print "########                                                         ########################\n";
print "########                                                         ########################\n";
print "########            Clean nettoyage des HG                       ########################\n";
print "########  ./02_migration_instance_check_emc.pl HG --clean	 ########################\n";
print "########                                                         ########################\n";
print "########            Aucune Validation ATTENTION                  ########################\n";
print "########                                                         ########################\n";
print "########  ./02_migration_instance_check_emc.pl HG --clean --all  ########################\n";		
print "########                                                         ########################\n";
print "########            Renommage des Distributed Devices            ########################\n";
print "########  ./02_migration_instance_check_emc.pl HG --rename       ########################\n";	
print "########            Mode auto renommage                          ########################\n";
print "########  ./02_migration_instance_check_emc.pl HG --rename --auto########################\n"; 	 	
print "########                                                         ########################\n";
print "########                                                         ########################\n";
print "########            Gestion des Raw Device		        ########################\n";
print "########  ./02_migration_instance_check_emc.pl VM --clean --vmware  ########################\n";
print "########                                                         ########################\n";
print "#########################################################################################\n\n\n\n\n";
print "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";

my $HG = sprintf uc ($ARGV[0]);
chomp($HG);
if (($HG eq "")){
        print "\n###################Merci de saisir Un hostgroup###################\n";
        exit 1;
}
if (!$optvmware){
	open (fichierlog,">$chemin/$HG/Migration"."_"."$datestring.log") || die ("Erreur d'ouverture de fichier");
	if(! (-e "$chemin/$HG/F1.log")){
		open (fichierF1,">$chemin/$HG/F1.log") || die ("Erreur d'ouverture de fichier");}
	if(! (-e "$chemin/$HG/F2.log")){
		open (fichierF2,">$chemin/$HG/F2.log") || die ("Erreur d'ouverture de fichier");}
	}
if ($opt_all){
	print "opt:$opt_all\n";
}


if ($optcheck){
	my @cmd_checkdd;
	my $tag;	
	my $command_check= " curl  -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/data-migrations/device-migrations/\" |awk -F\\\" '\/name\/ && \$4~/$HG/ {print \$4}'";
	my @cmd_check =`$command_check`;
	
	if (!@cmd_check){
		my $command_check= "curl  -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/data-migrations/extent-migrations/\" |awk -F\\\" '\/name\/ && \$4~/$HG/ {print \$4}'";
	#	print "$command_check\n";
	        @cmd_checkdd =`$command_check`;
		chomp (@cmd_checkdd);
		$tag = 1;
		@cmd_check = @cmd_checkdd;
	}		
	if (@cmd_check) {
		foreach (@cmd_check){
			chomp ($_);
 			my $ma_mig = $_;
			print "\n############################################################";	
			print "\n\n\nInstance en cours :$ma_mig\n";
			print fichierlog "\n\n\nInstance en cours :$ma_mig\n";
			print "Voulez vous voir l'avancement de l'instance $ma_mig?\n";
			print "Reponse y/n ou q pour quitter le programme :  "; 
			my $input =<STDIN>;
			if ($input =~ m/^[Q]$/i){
		                 print "Exit du programme\n";
                		 exit(0);
            		}
	                elsif($input =~ m/^[Y]$/i){
				my $commande_pourcent;	
				if ($tag == 0){
		                 $commande_pourcent = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/data-migrations/device-migrations/$ma_mig?percentage-done\" |awk -F\\\" '\/value\/ {print \$4}'";	
				}
				elsif ($tag == 1){
					$commande_pourcent = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/data-migrations/extent-migrations/$ma_mig?percentage-done\" |awk -F\\\" '\/value\/ {print \$4}'";
				}
				print fichierlog "$commande_pourcent\n";
				my $cmd_pourcent = `$commande_pourcent`;
				chomp ($cmd_pourcent);
				print fichierlog "$cmd_pourcent\n";
				
				print "la migration est à $cmd_pourcent%\n";
				if ($cmd_pourcent == "100"){
				      my  $cmd_complite;
				      if ($tag == 0){	
					     $cmd_complite = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/data-migrations/device-migrations/$ma_mig?status\" |awk -F\\\" '\/value\/ {print \$4}'`;	
					}
				      elsif ($tag == 1){
					    $cmd_complite = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/data-migrations/extent-migrations/$ma_mig?status\" |awk -F\\\" '\/value\/ {print \$4}'`;	
					}	
				     chomp($cmd_complite);
				     print fichierlog "$cmd_complite\n";	
				     print "ma commande $cmd_complite\n";		
				     if ($cmd_complite eq "complete"){		
					     print "\n\n\nLa migration $ma_mig est terminée voulez vous lancer un Commit ?\n";
					     print "Reponse y/n ou q pour quitter le programme :  ";
					     my $input1 =<STDIN>;
		        	                if ($input1 =~ m/^[Q]$/i){
		                	                 print "Exit du programme\n";
                		        	         exit(0);
		                        	}
	                		        elsif($input1 =~ m/^[Y]$/i){
							print "Lancement du commit\n";
							print fichierlog "Lancement du commit\n";
							#####lancement du commit################
							my $retour_commit = &commit($ma_mig);
						}	
					}
				    else { print "Merci de relancer le script dans quelques secondes car le status n'est pas complete\n";
					   print fichierlog "Merci de relancer le script dans quelques secondes car le status n'est pas complete\n";	}		
				}
			}
		}
	}
	else { print "Aucune migration pour le host $HG en cours ....\n";
	       print fichierlog "Aucune migration pour le host $HG en cours ....\n"; }
}
elsif ($optclean)
{
	&clean;
}
elsif ($optrename)
{
	&rename;
}
else {
	&migration("I");
	&migration("G");
	}


sub migration {
	
	my ($bat)= @_;
	my $command_virtualvolume;	
	print fichierlog "Migration batiment $bat\n";
	if ($bat eq "I"){		###########modification FBVPA002 au lieu de 001
		$command_virtualvolume = "curl  -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA002/vplex/clusters/cluster-1/devices \"|awk -F\\\" '\/name\/ {print \$4}'";
	#	print fichierlog "I:$command_virtualvolume\n";
	}
	elsif ($bat eq "G"){		###########modification FBVPA002 au lieu de 001
		$command_virtualvolume = "curl  -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA002/vplex/clusters/cluster-2/devices \"|awk -F\\\" '\/name\/ {print \$4}'";
	#	print fichierlog "G:$command_virtualvolume\n";
	}
		my @cmd_virtualvolume = `$command_virtualvolume`;
		#print "macommande : $command_virtualvolume\n";
		print fichierlog "@cmd_virtualvolume\n";
		my $recherche = "$HG"."_";
		#print "marecherche : $recherche \n";
                my @tab_HGdestination = grep {/$recherche/} @cmd_virtualvolume;
		my @tabsrc;
		my @tab_HGsource = grep {/_$HG/} @cmd_virtualvolume;
		if (!@tab_HGsource){
			if (@tab_HGdestination){				####bug a corriger sur lacement de l'extend
				foreach (@tab_HGdestination){
					chomp($_);
					print "Device extend: $_\n";
					my $device_dest = $_;
					my ($command_extend_dst,$cmd_extend_dst);
					if ($bat eq "I"){	###########modification FBVPA002 au lieu de 001
						$command_extend_dst = "curl  -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA002/vplex/clusters/cluster-1/devices/$device_dest/components \" |awk -F\\\" '\/name\/ {A=\$4} END {print A}'";
						print fichierlog "Edst I: $command_extend_dst\n";
						$cmd_extend_dst = `$command_extend_dst`;
						print fichierlog "$cmd_extend_dst\n";
					}
					elsif ($bat eq "G"){
						$command_extend_dst = "curl  -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA002/vplex/clusters/cluster-2/devices/$device_dest/components \" |awk -F\\\" '\/name\/ {A=\$4} END {print A}'";
                                                print fichierlog "Edst G: $command_extend_dst\n";
                                                $cmd_extend_dst = `$command_extend_dst`;
						print fichierlog "$cmd_extend_dst\n";
					}
				#	print "$cmd_extend_dst\n";
					chomp ($cmd_extend_dst);
					my ($l_host,$l_vck,$ldev) = split (/_/,$_);
					my $search_ldev = substr($ldev,3);
					chomp ($search_ldev);
					my ($command_extend_src,$cmd_extend_src);
					if ($bat eq "I"){		###########modification FBVPA002 au lieu de 001
						$command_extend_src = "curl  -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA002/vplex/clusters/cluster-1/storage-elements/extents \" |awk -F\\\" '\/name\/ && \$4~/$search_ldev/ {print \$4}'";
						print fichierlog " $command_extend_src\n";	
						$cmd_extend_src = `$command_extend_src`;
						print fichierlog "$cmd_extend_src\n";
					}
					elsif ($bat eq "G"){		###########modification FBVPA002 au lieu de 001
						$command_extend_src = "curl  -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA002/vplex/clusters/cluster-2/storage-elements/extents \" |awk -F\\\" '\/name\/ && \$4~/$search_ldev/ {print \$4}'";
						print fichierlog " $command_extend_src\n";
                                                $cmd_extend_src = `$command_extend_src`;
						print fichierlog "$cmd_extend_src\n";

					}
					if ($cmd_extend_src){
						chomp($cmd_extend_src);	###########modification FBVPA002 au lieu de 001
						my $command_mig ="curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA002/vplex/dm+migration+start\" -X POST -d \"{\\\"args\\\":\\\"--name MIG_$search_ldev"."_"."$HG --from $cmd_extend_src --to $cmd_extend_dst --transfer-size 50M --force\\\"}\""; 
						print fichierlog "$command_mig\n";
						print "\n\n####Voulez Vous Lancer la migration du device $search_ldev du Host $HG###\n";
	                        	        print "Reponse y/n ou q pour quitter le programme :  ";
	        	                        my $input = <STDIN>;
        	        	                chomp $input;
			                                if ($input =~ m/^[Q]$/i){
	        		                               print "Exit du programme\n";
        	                	        	       exit(0);
                        			           }
			                                elsif($input =~ m/^[Y]$/i)
        	        		                    {
								print"Suppression du device pour lancer migration extent\n";
								 my $command_supp_dev;
								if ($bat eq "I"){		###########modification FBVPA002 au lieu de 001
									$command_supp_dev = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA002/vplex/local-device+destroy\" -X POST -d \"{\\\"args\\\":\\\"-d /clusters/cluster-1/devices/$device_dest -f\\\"}\"";
									print fichierlog "$command_supp_dev\n";
								}
								elsif ($bat eq "G"){	###########modification FBVPA002 au lieu de 001
									$command_supp_dev = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA002/vplex/local-device+destroy\" -X POST -d \"{\\\"args\\\":\\\"-d /clusters/cluster-2/devices/$device_dest -f\\\"}\"";
									print fichierlog "$command_supp_dev\n";
	
								}
								print "$command_supp_dev\n";
								print fichierlog "$command_supp_dev\n";
								my $cmd_supp_dev =`$command_supp_dev`;
								print $cmd_supp_dev;
								print fichierlog "$cmd_supp_dev\n";
							        print "Execution migration $ldev....\n";
			                                        print fichierlog "Execution migration $ldev....\n";
								sleep (2);######attente entre suppression et migration######	
			                                        my $cmd = `$command_mig`;
								######supprimer le device!!!####
								print "$cmd\n";
                		        	                print fichierlog $cmd;
        		                         	}

					}			
	
					#exit(0);	
				}	
#				print "Migration Via extend\n"
			}
		}
	if (@tab_HGsource){
		print "migration disque local via Device\n";
			
		foreach (@tab_HGsource) {
			my (undef,$baie,$ldev,$host) = split (/_/,$_);
			my @target = grep {/$ldev/} @tab_HGdestination;
			print "Local Device: $ldev\n";
			print "#### @tab_HGdestination \n";
			if (@target) {
				chomp ($_);
				chomp (@target[0]);
			#	@target[0]= substr @target[0] , 1;
			#       @target[0] = substr(@target[0], 0, length(@target[0])-2);		###########modification FBVPA002 au lieu de 001
				my $command = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA002/vplex/dm+migration+start\" -X POST -d \"{\\\"args\\\":\\\"--name MIG_$ldev"."_"."$HG --from $_ --to @target[0] --transfer-size 50M --force\\\"}\"";
				print "$command \n";
				print "\n\n####Voulez Vous Lancer la migration du device $ldev du Host $HG###\n";
			        print "Reponse y/n ou q pour quitter le programme :  ";
        		        my $input = <STDIN>;
		                chomp $input;
        		        if ($input =~ m/^[Q]$/i){
                	               print "Exit du programme\n";
                        	       exit(0);
		                   }
        	                elsif($input =~ m/^[Y]$/i)
        		            {
					print "Execution migration $ldev....\n";
					print fichierlog "Execution migration $ldev....\n";
					#my $supp_vsp = &suppression_vsp($ldev,$baie);
					my $cmd = `$command`;
					print "$cmd\n";
					print fichierlog $cmd;
		   		 }
		}
		else {print "le Ldev $ldev est en cours de migration \n"; 
		     print fichierlog "le Ldev $ldev est en cours de migration \n";}
		}
	}

}

sub addLock() {
	my $baie = shift;
	#$baie = substr($baie, 3);	
	my $ret = 1;
	my $retcode=0;	
	my $lock_inst;
	$lock_inst = 1839 if ($baie == "85183");
        $lock_inst = 3179 if ($baie == "53317");
		

	my $cmd="raidcom get resource -s '$baie' -ITC$lock_inst -login maintenance raid-mainte | grep \"Locked\"";	
#	print "$cmd\n";
	$ret = system( $cmd );
	if ($ret == 0) {
                print("ECHEC : Baie $baie deja lockee, merci de re-essayer plus tard !!\n");
		print("Les informations necessaires sont dans le fichier de log \n");
		$retcode = 1;
        } else {
		print("Pose du lock sur la baie $baie\n") if $optVerbose;
		my $cmd="raidcom lock resource -resource_name meta_resource -s '$baie' -ITC$lock_inst -login maintenance raid-mainte";
		$ret = system( $cmd );
		if ($ret == 0) {
			print("Pose du lock OK.\n");
			$retcode = 0;
		} else {
			print("ECHEC : impossible de poser un verrou.\n");
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


sub suppression_vsp {
	my ($l_ldev,$l_baie) = @_;
	$l_ldev = substr($l_ldev, 0, 2) . ":" . substr($l_ldev, 2);
#	my $cmd_get_ldev = `raidcom get ldev -ldev_id 00:20:97 -s '85183' -ITC1839 | grep PORTs`;
	my $lock = &addLock($l_baie);
	if ($lock == 0){
		# suppression 
	}
	elsif ($lock == 1) { print "Attention erreur de lock de la baie VSP\n";	}	
	print "mon lock :$lock\n";
	print "Mon Ldev: #$l_ldev#\n";
	print "Ma baie: #$l_baie#\n";		
}	

sub zoning {
	my $l_hg = lc($HG);
	my @zones_f1;
	my @zones_f2;
	print fichierF1 "#!/usr/bin/expect\nspawn su - admstk -c \"ssh admin\@fsstk005\"\n";
	print fichierF1 "expect \"admin>\"\nsend \"setcontext 1\\r\"\n";
	print fichierF2 "#!/usr/bin/expect\nspawn su - admstk -c \"ssh admin\@fsstk006\"\n";
	print fichierF2 "expect \"admin>\"\nsend \"setcontext 1\\r\"\n";	
	my @cmd_switchf1 = `su - admstk -c \"ssh -o 'BatchMode yes' -o 'ConnectTimeout 5' admin\@fsstk005 configshow -fid 1\"`;	
	my @cmd_switchf2 = `su - admstk -c \"ssh -o 'BatchMode yes' -o 'ConnectTimeout 5' admin\@fsstk006 configshow -fid 1\"`;
	my @f1_all = grep {/$l_hg/} @cmd_switchf1;
	my @f2_all = grep {/$l_hg/} @cmd_switchf2;
	#################################fabric du bas #################################################
	if (@f1_all){
		foreach (@f1_all) {
			if ($_ =~ /zone/){
			    if ($_ =~ /HDS/){
				my ($myzone,undef,undef) = split /:/,$_;
				my $zone = substr ($myzone,5);
				print fichierF1 "expect \"admin> \"\nsend \"cfgremove ZS_COV2_BAS, $zone\\r\"\n";
		        	    }			
		    	}	
		}
		print fichierF1 "expect \"admin> \"\nsend \"cfgenable ZS_COV2_BAS\\r\"\nexpect \"admin> \"\nsend \"y\\r\"\nexpect \"admin> \"\nsend \"exit\\r\"\nexpect eof";
	}
	else {print "Pas de zoning trouvé dans la fabric du Bas pour $l_hg\n";
	     print fichierlog "Pas de zoning trouvé dans la fabric du Bas pour $l_hg\n";}			
	####################################fabric du haut #############################################
	if (@f2_all){
		foreach (@f2_all) {
        	        if ($_ =~ /zone/){
                	    if ($_ =~ /HDS/){
                        	my ($myzone,undef,undef) = split /:/,$_;
	                        my $zone = substr ($myzone,5);
	                        print fichierF2 "expect \"admin> \"\nsend \"cfgremove ZS_COV2_HAUT, $zone\\r\"\n";
        	             }
                    	}
                }
	        print fichierF2 "expect \"admin> \"\nsend \"cfgenable ZS_COV2_HAUT\\r\"\nexpect \"admin> \"\nsend \"y\\r\"\nexpect \"admin> \"\nsend \"exit\\r\"\nexpect eof";
	}
	else {print "Pas de zoning trouvé dans la fabric du haut pour $l_hg\n";
             print fichierlog "Pas de zoning trouvé dans la fabric du haut pour $l_hg\n";}
	######execution des deux fichiers avec les zones######	
	    print " \n#####Voulez vous Supprimer le zoning du serveur : $l_hg \n";
			print "Reponse y/n ou q pour quitter le programme :  "; 
            my $input = <STDIN>;
            chomp $input;
            if ($input =~ m/^[Q]$/i){
                 print "Exit du programme\n";
                 exit(0);
            }
             elsif($input =~ m/^[Y]$/i){
             	print "Lancer les deux fichiers F1 et F2.log pour désactiver le zoning\n";  
		######executer le fichier F1.log######
		######executer le fichier F2.log######    
            }
}

sub commit{
	my ($l_instance_mig) = @_;
	my (undef,$l_ldev,$hg) = split /_/, $l_instance_mig;
	my @cmd_commit =  `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/dm+migration+commit\" -X POST -d \"{\\\"args\\\":\\\"--migrations $l_instance_mig --force\\\"}\"`;
	print fichierlog "@cmd_commit\n";	
	if (grep { /Committed 1 data migration/} @cmd_commit) {
		print "Commit OK nettoyage des instance :\n";
		my @cmd_nettoyage = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/dm+migration+remove\" -X POST -d \"{\\\"args\\\":\\\"--migrations $l_instance_mig --force\\\"}\"`;
		if (grep { /Removed 1 data migration/} @cmd_nettoyage){
			print "Nettoyage des Instances de migration ok\n";
			print fichierlog "Nettoyage des Instances de migration ok\n";
			#####voir si suppression apres le commit du device coté vplex#####
		}
		else { print "Le nettoyage à echoué merci de contacter le N3 (rien de grave)\n";
		       print fichierlog "Le nettoyage à echoué merci de contacter le N3 (rien de grave)\n";}	
	}
	else { print "Le commit à eu un probleme merci de le relancer\n";
	       print fichierlog "Le commit à eu un probleme merci de le relancer\n";}
}


sub clean
{
	my $lhg = lc($HG);
	my @tab_os;
	if ($optvmware){
		print "/mnt/MIG_EMC/Vmware/$lhg/volumes.txt\n";
		open (FICOS,"</mnt/MIG_EMC/Vmware/$lhg/volumes.txt") || die ("Fichier VM absent\n");
		@tab_os = <FICOS>;
		close(FICOS);
	}
	else{
		open (FICOS,"</mnt/MIG_EMC/lpar/$lhg/result/table_disk.vsp.txt") || die ("Fichier OS absent\n");
	        @tab_os = <FICOS>;
	        close(FICOS);
		print fichierlog "Clean des Ldev du hostgroup de migration du serveur $HG \n";
	}	
	my $operation;
	foreach (@tab_os){
		my ($c_ldev,undef,$c_baie,undef,undef,undef,undef,$c_vg) = split /;/,$_;
		my $bb = substr $c_ldev, 0,2;
		my $cc = substr $c_ldev, 2,2;
		my $c_ldev_fi = "00:$bb:$cc";
		my $inst;
		my $command_verif;
		if ($c_baie eq "85183"){	
			$command_verif = "export HORCMINST=1839;raidcom get ldev -ldev_id $c_ldev_fi  -login maintenance raid-mainte | grep MIGEMC";
			print "I:$c_ldev_fi\n";
			}	
		elsif($c_baie eq "53317"){
			$command_verif = "export HORCMINST=3179;raidcom get ldev -ldev_id $c_ldev_fi  -login maintenance raid-mainte | grep MIGEMC";
			print "G:$c_ldev_fi\n";
		}
		if ($c_vg =~ m/[rR][oO][oO][tT]/ ){
			print "rootvg pas dans HG $c_ldev -> $c_baie -> $c_vg\n"; 
		}
		else {
			print "Veuillez patienter verification en cours .....\n";
			my $cmd_verif = `$command_verif`;
			if ($cmd_verif)
			{
				my $input;
				print "\n\n####Voulez Vous enlever le Ldev $c_ldev_fi $c_baie $c_vg du hostgroup de migration ?###\n";
				print "Reponse y/n ou q pour quitter le programme :  ";
				if($opt_all){	
				$input = "Y";
				print "\nMode Automatique veuillez patienter.....\n";		
				}else{
				$input = <STDIN>;
				chomp $input;}
				
				if ($input =~ m/^[Q]$/i){
					print "Exit du programme\n";
				  	exit(0);
				}
				elsif($input =~ m/^[Y]$/i){		
					my $retour_lock = &addLock($c_baie);		##################Lock baie HDS#######################
					print "Lock:$retour_lock \n";
					$inst = 1839 if ($c_baie == "85183");
					$inst = 3179 if ($c_baie == "53317");
					if ($retour_lock == 0 ){
						my $command_vsp0 = "export HORCMINST=$inst;raidcom delete lun -port CL1-B HG_MIGEMC_1B -ldev_id $c_ldev_fi -s $c_baie -login maintenance raid-mainte";				
						my $cmd_vsp0 = `$command_vsp0`;		#################### suppression lun vsp  #########
						print "$cmd_vsp0\n";
						print fichierlog "$c_ldev_fi ->  $c_baie\n";
						print fichierlog "$cmd_vsp0\n";
						my $command_vsp1 = "export HORCMINST=$inst;raidcom delete lun -port CL2-B HG_MIGEMC_2B -ldev_id $c_ldev_fi -s $c_baie -login maintenance raid-mainte";
                	                        my $cmd_vsp1 = `$command_vsp1`;         #################### suppression lun vsp  #########
	                                        print "$cmd_vsp1\n";
        	                                print fichierlog "$cmd_vsp1\n";
						my $command_vsp2 = "export HORCMINST=$inst;raidcom delete lun -port CL5-D HG_MIGEMC_5D -ldev_id $c_ldev_fi -s $c_baie -login maintenance raid-mainte";
                        	                my $cmd_vsp2 = `$command_vsp2`;         #################### suppression lun vsp  #########
	                                        print "$cmd_vsp2\n";
        	                                print fichierlog "$cmd_vsp2\n";
						my $command_vsp3 = "export HORCMINST=$inst;raidcom delete lun -port CL6-D HG_MIGEMC_6D -ldev_id $c_ldev_fi -s $c_baie -login maintenance raid-mainte";
	                                        my $cmd_vsp3 = `$command_vsp3`;         #################### suppression lun vsp  #########
        	                                print "$cmd_vsp3\n";
                	                        print fichierlog "$cmd_vsp3\n";
						$operation = 1;
					}	
					else { print "Baie $c_baie lockée !! Veuillez essayer plus tard\n";}
					&delLock($c_baie) if ($operation == 1);
				}
			



			}
			else { print "Disque $c_ldev_fi déja supprimé du hostgroup de migration\n";}
		}	
	}	
}


sub rename
{

	print "#########################################################################################\n";
	print "#############################Renommage volume distribué##################################\n";
	print "#########################################################################################\n";
	print "\n\n";	
        my $lhg = lc($HG);
	print fichierlog "Renommage des disques distribuer\n";
	my $command_list_distributed = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/distributed-storage/distributed-devices/*$HG/distributed-device-components/\"|awk -F\\\" '\$2~/parent/ {split(\$4,A,\"/\");print A[4]} \$2~/name/ && \$4!~/name/ {print \$4}'|awk '{printf \$0\";\";getline;printf \$0\";\";getline;print \$0}'";

#	print $command_list_distributed ;
	print fichierlog "$command_list_distributed\n";
	my @cmd_list_distributed = `$command_list_distributed`;
	print fichierlog "@cmd_list_distributed\n";
	chomp (@cmd_list_distributed);	
#	print "@cmd_list_distributed\n";
	foreach (@cmd_list_distributed){
		chomp ($_);
		my($disque_dist,$disque01,$disque02) = split /;/, $_;
                my($dev,$baie,$ldev,$SRV) = split /_/, $disque_dist;
		my ($disque1,$command_rename_c1,$c1_nvdisque,$dd_nvdisque,$command_rename_dd);
		if ($disque01 =~ m/device_/){
			$disque1 = $disque01;
		}
		elsif ($disque02 =~ m/device_/){
			$disque1 = $disque02;
		}	
		else {
			print "Les disques en aval sont OK\n";
			if ($baie eq "VSP53317"){
				$dd_nvdisque = "dd_VCKM00152300074_$ldev"."_VCKM00152300075";
			}	   
			elsif ($baie eq "VSP85183"){
				$dd_nvdisque = "dd_VCKM00152300075_$ldev"."_VCKM00152300074";
			}
			else { print "Incoherence de baie \n";exit(0);print fichierlog "Incoherence de baie \n";}	
			print "Voulez vous lancer le renommage du disque:\n";
			print "$disque_dist --> $dd_nvdisque\n";
			print "Reponse y/n ou q pour quitter le programme :" ;
			my $input =<STDIN>;
			if ($input =~ m/^[Q]$/i){
                        	print "Exit du programme\n";
                                exit(0);
			}
                        elsif ($input =~ m/^[Y]$/i){
                                print "$command_rename_dd\n";
				my $cmd_rename_dd = `$command_rename_dd`;
				#my $cmd_rename_dd = `$command_rename_dd`;
                                print "$cmd_rename_dd\n";
                        }
			else {next;}	
		}
		if ($disque1 =~ m/device_/){
			my $command_extent = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/distributed-storage/distributed-devices/*$HG/distributed-device-components/$disque1/components\"|awk -F\\\" '\$4~/^extent_/ {print \$4}'";
			print fichierlog "$command_extent\n";
			my $cmd_extent = `$command_extent`;
			print fichierlog "Extent:$cmd_extent\n";
			my (undef,$baieid,undef) = split /_/,$cmd_extent;
			my ($n_baie,$n_id) = split /-/,$baieid;
						
			if ($n_baie eq "VCKM00152300074"){
				$c1_nvdisque = "$HG"."_VCKM00152300074-"."$n_id"."_VSP$ldev" ;
								
			}		
			elsif ($n_baie eq "VCKM00152300075"){
				$c1_nvdisque = "$HG"."_VCKM00152300075-"."$n_id"."_VSP$ldev" ;
			}	
			else { print "Incoherence de baie \n";print fichierlog "Incoherence de baie \n";}		
							
			if ($baie eq "VSP53317"){
				$dd_nvdisque = "dd_VCKM00152300074_$ldev"."_VCKM00152300075";
			}	   
			elsif ($baie eq "VSP85183"){
				$dd_nvdisque = "dd_VCKM00152300075_$ldev"."_VCKM00152300074";
			}
			else { print "Incoherence de baie \n";print fichierlog "Incoherence de baie \n";}		
									
								
			$command_rename_c1 = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/set\" -X POST -d \"{\\\"args\\\":\\\"-a /distributed-storage/distributed-devices/$disque_dist/distributed-device-components/$disque1"."::name -v $c1_nvdisque -f\\\"}\"";
			chomp($command_rename_c1);
			#print "c1:$c1_nvdisque\n";
			print fichierlog "$command_rename_c1\n";
			$command_rename_dd ="curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/set\" -X POST -d \"{\\\"args\\\":\\\"-a /distributed-storage/distributed-devices/$disque_dist"."::name -v $dd_nvdisque -f\\\"}\"";
			chomp($command_rename_dd);
			#print "$command_rename_dd\n";
			print fichierlog "$command_rename_dd\n";
			print "Voulez vous lancer le renommage des disques:\n";
			print "$disque1 --> $c1_nvdisque\n";
                        print "$disque_dist --> $dd_nvdisque\n";
			print "Reponse y/n ou q pour quitter le programme :" ;
			my $input;
			if ($optauto){
				$input = "Y";chomp $input;
                		print "\nMode Automatique veuillez patienter.....\n";
                                }else{
			        $input = <STDIN>;
		        	chomp $input;
			}
			if ($input =~ m/^[Q]$/i){
				print "Exit du programme\n";
				exit(0);
			}
			elsif ($input =~ m/^[Y]$/i){
				my $cmd_rename_c1 = `$command_rename_c1`;
				my $cmd_rename_dd = `$command_rename_dd`;
				#my $cmd_rename_dd = `$command_rename_dd`;
				print "$cmd_rename_c1\n";
				print "$cmd_rename_dd\n";
			}
			else {next;}	
									
		}
                else { print "Incoherence \n";print fichierlog "Incoherence \n";}				
	                	
	}#foreach
	print "rename $lhg\n";
	


}
