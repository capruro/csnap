#!/bin/bash

############################################
#                                          #
#    CSNAP (Configuration Snapshot)        #
#         For Linux RHEL/SUSE              #
#                                          #
############################################

##########
# Config #
##########

DIR_LOG="/opt/csnap/results"       ##IMPORTANT: The script changes the permission to 775
DIR_ZIP="/opt/csnap/archive"     ##IMPORTANT: The script changes the permission to 775
BCK_FILE="chkpath.bck"
FMT_FILE=$(date +"%Y-%m-%d-%H-%M").$(hostname).txt
tempcsnapView="/tmp/tempcsnapView"
tempcsnapCompare="/tmp/tempcsnapCompare"
tempcsnapCompare1="/tmp/tempcsnapCompare1"
tempcsnapFailure="/tmp/tempcsnapFailure"


export PATH="/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin"

ROTATE="10"

TOTAL="40"


##############
# OS Version # 
##############

osversion() {
    #if [ -e /etc/os-release ]; then
    #    # Source the /etc/os-release file to set variables
    #    . /etc/os-release
    #    SO="$PRETTY_NAME"
    #    OSv=$(echo "$VERSION_ID" | cut -d'.' -f1)
    #elif [ -e /etc/redhat-release ]; then
    #... first part cut as not necessary, saved for later uses
    if [ -e /etc/redhat-release ]; then
        # Check for Red Hat-based distributions
        OS="REDHAT"
        OSv=$(cat /etc/redhat-release | awk '{print $7}' | cut -d'.' -f1)
    elif [ -e /etc/debian_version ]; then
        # Check for Debian-based distributions
        OS="UBUNTU"
    elif [ -e /etc/SuSE-release ]; then
        # Check for SUSE-based distributions
        OS="SUSE"
    else
        # If none of the above, print an error message
        echo "Error: Unable to determine the Linux distribution." >&2
    fi

}

###################
# Header Function #
###################
printhdr() {
   
   echo -e "######################" >> $DIR_LOG/$CMD.$FMT_FILE
   echo -e " $CMD "                 >> $DIR_LOG/$CMD.$FMT_FILE
   echo -e "######################" >> $DIR_LOG/$CMD.$FMT_FILE
}


###################
# Bottom Function #
###################
printbtm() {

   echo -e "######----END----######" >> $DIR_LOG/$CMD.$FMT_FILE
   echo -e ""                        >> $DIR_LOG/$CMD.$FMT_FILE
}

#####################
# Progress Function #
#####################
printtitle() {
   hashTrail=40
   missingTrail=$(($hashTrail-$COUNT))
   drawHash=0
   drawTrail=0
   drawString=
   
   echo -ne '\033[K'
   echo -e "\033[GColecting: $CHK_TITLE"
      
   while [ $drawHash -lt $COUNT ]
   do
        drawString="$drawString#"
        drawHash=$(($drawHash+1))
   done
   
   while [ $drawTrail -lt $missingTrail ]
   do
        drawString="$drawString."
        drawTrail=$(($drawTrail+1))
   done
   
   echo -n "[$drawString]"
   
   echo -e "\033[G\033[41C$COUNT/$TOTAL"
   echo -ne '\033[2A\033[G'
}


printBoxLeft(){
    echo -en '\e[34;1m|\e[m'
}

printBoxRight(){
    echo -e '\e[34;1m|\e[m'
}

printBoxFooter(){
    echo -e '\e[34;1m+----------------------------------------------------------------------------+\e[m'
}

printBoxHeader(){
    tput clear
    echo -e '\e[34;1m.----------------------------------------------------------------------------.\e[m'
    echo -e '\e[34;1m|                          Hardware Summary                                  |\e[m'
    echo -e '\e[34;1m|                                                                            |\e[m'
    printBoxFooter
}


checkUID(){
    if [ $UID -ne 0 ]
    then
        echo 'Only execute with root'
        echo "Try again using sudo: "
        echo "sudo $0"
        exit 1
    fi
}

#########################################

testDirs(){
    if [ ! -d $DIR_LOG ]
    then
        echo "[INFO] Log dir not found"
        echo "[INFO] Creating log directory"
        mkdir -p $DIR_LOG
        if [ $? != 0 ]
        then
            echo "[ERROR] Failure to create the directory"
            exit 1
        fi
        chmod 755 $DIR_LOG
        if [ $? != 0 ]
        then
            echo "[ERROR] Failure to change permissions for $DIR_LOG"
            exit 1
        fi
    fi
    
    if [ ! -d $DIR_ZIP ]
    then
        echo "[INFO] Rotate dir not found"
        echo "[INFO] Creating rotate directory"
        mkdir -p $DIR_ZIP
        if [ $? != 0 ]
        then
            echo "[ERROR] Failure to create the directory"
            exit 1
        fi
        chmod 755 $DIR_ZIP
        if [ $? != 0 ]
        then
            echo "[ERROR] Failure to change permissions for $DIR_ZIP"
            exit 1
        fi
    fi
}

createcsnap(){
    checkUID
    testDirs

    ############
    # Hardware #
    ############

    CMD=hardware
    
    [ -f /proc/sysinfo ] && MAINFRAME=1
    
    if [ -n "$MAINFRAME" ]
    then
        MODEL_CPU=`cat /proc/cpuinfo | grep ^vendor_id | head -n1 | awk '{print $NF}'`
        NR_CPU_CORE=`cat /proc/cpuinfo | grep ^# | head -n1 | awk '{print $NF}'`
        NR_NIC=`ls -l /sys/devices/qeth | grep ^d | wc -l`
        NR_FC="0"
        VENDOR="IBM"
        TYPE=`cat /proc/sysinfo | grep ^Type: | awk '{print $NF}'`
        LPAR=`cat /proc/sysinfo | grep ^LPAR\ Name: | awk '{print $NF}'`
        VM=`cat /proc/sysinfo | grep ^VM00\ Name: | awk '{print $NF}'`
        CONTROL=`cat /proc/sysinfo | grep Control | awk '{print substr($0, index($0,$4)) }' | awk '{print $1,$2}'`
    else
        MODEL_CPU=`cat /proc/cpuinfo | grep -m 1 "model name" |  cut -d":" -f 2 | sed 's/^\ //' | tr -s ' ' ' '`
        NR_CPU_CORE=`cat /proc/cpuinfo | grep processor | wc -l`
        NR_NIC=`lspci | grep "Ethernet" | wc -l 2> /dev/null`
        NR_FC=`lspci | grep "Fibre" | wc -l 2> /dev/null`
        if [[ `dmidecode 2> /dev/null` ]]
        then
            VENDOR=`dmidecode | grep "System Information" -A1 | tail -n1 | cut -d: -f2 | sed 's/\ //' 2> /dev/null`
            [ -z "$VENDOR" ] && VENDOR="N/A"
            TYPE=`dmidecode | grep "System Information" -A2 | tail -n1 | cut -d: -f2 | sed 's/\ //' 2> /dev/null`
            [ -z "$TYPE" ] && TYPE="N/A"
            SERIAL=`dmidecode | grep "System Information" -A4 | tail -n1 | cut -d: -f2 | sed 's/\ //' 2> /dev/null`
            [ -z "$SERIAL" ] && SERIAL="N/A"
        else
            VENDOR="N/A"
            TYPE="N/A"
            SERIAL="N/A"
        fi
    fi
   
    MEM_TOTAL=`cat /proc/meminfo | grep MemTotal | cut -d":" -f 2 | awk '{print $1,$2}'`
    MEM_FREE=`cat /proc/meminfo | grep MemFree | cut -d":" -f 2 | awk '{print $1,$2}'`
    SWAP_TOTAL=`cat /proc/meminfo | grep SwapTotal | cut -d":" -f 2 | awk '{print $1,$2}'`
    SWAP_FREE=`cat /proc/meminfo | grep SwapFree | cut -d":" -f 2 | awk '{print $1,$2}'`
    MEM_ACTIVE=`cat /proc/meminfo | grep Active | cut -d":" -f 2 | head -n1 | awk '{print $1,$2}'`
    MEM_INACTIVE=`cat /proc/meminfo | grep Inactive | cut -d":" -f 2 | head -n1 | awk '{print $1,$2}'`
    RUNLEVEL=`runlevel | awk '{print $NF}'`
    DATE=`date`
    DATE_UTC=`date -u`
    UPTIME=`uptime | cut -d, -f1 | tr -s ' ' ' ' | sed 's/\ //'`
    UNAME=`uname -rsm`

    printBoxHeader
    
    variableArray=(MEM_TOTAL MEM_FREE SWAP_TOTAL SWAP_FREE MEM_ACTIVE MEM_INACTIVE RUNLEVEL NR_FC NR_NIC DATE DATE_UTC UPTIME UNAME VENDOR SERIAL MODEL_CPU NR_CPU_CORE TYPE)

    arrayCounter=0
    firstPositionAfterHeader=4

    while [ $arrayCounter -lt ${#variableArray[*]} ]
    do
        thisVariable=${variableArray[$arrayCounter]}
    
        eval localVar=\$$thisVariable
        
        printBoxLeft
        
        case $thisVariable in
            MEM_TOTAL)      thisLabel="Total Memory :\t";;
            MEM_FREE)       thisLabel="   '->  Free :\t";;
            SWAP_TOTAL)     thisLabel="  Swap Total :\t";;
            SWAP_FREE)      thisLabel="   '->  free :\t";;
            MEM_ACTIVE)     thisLabel="Active Memory:\t";;
            MEM_INACTIVE)   thisLabel=" '-> Inactive:\t";;
            RUNLEVEL)       thisLabel="    Runlevel :\t";;
            NR_FC)          thisLabel=" Qtd de HBAs :\t";;
            NR_NIC)         thisLabel=" Qtd de NICs :\t";;
            DATE)           thisLabel=" Actual Date :\t";;
            DATE_UTC)       thisLabel="    UTC Date :\t";;
            UPTIME)         thisLabel="System Uptime:\t";;
            UNAME)          thisLabel="       Uname :\t";;
            VENDOR)         thisLabel="      Vendor :\t";;
            SERIAL)         thisLabel="      Serial :\t";;
            MODEL_CPU)      thisLabel="   CPU Model :\t";;
            NR_CPU_CORE)    thisLabel="   Qtd Cores :\t";;
            TYPE)           thisLabel="  Type/Model :\t";;
        esac
        
        if [ -n "$MAINFRAME" -a "$thisVariable" = "SERIAL" ]
        then
            echo -en "zLinux info:\tLPAR $LPAR, VM $VM, Control Program $CONTROL."
        else
            echo -en "$thisLabel$localVar"
        fi
        
        tput cup $firstPositionAfterHeader 77
        
        printBoxRight
        
        firstPositionAfterHeader=$(($firstPositionAfterHeader+1))

        arrayCounter=$(($arrayCounter+1))
    done
    
    printBoxFooter
    
    echo ""

    #############
    # Chkconfig #
    #############

    CMD=chkconfig
    CHK_TITLE="Active/Inactive Services"
    export COUNT=1
    printtitle
    printhdr
    if [ -e /usr/bin/systemctl ]
    then
	    systemctl list-unit-files >> $DIR_LOG/$CMD.$FMT_FILE
    elif [ -e /sbin/chkconfig ]
    then
    	chkconfig --list 2>/dev/null >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    #########
    # Hosts #
    #########

    CMD=etc-hosts
    CHK_TITLE="Hosts Information"
    COUNT=2
    printtitle
    printhdr
    if [ -e "/etc/hosts" ]
    then
	    cat /etc/hosts >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ###############
    # Resolv.conf #
    ###############

    CMD=etc-resolv
    CHK_TITLE="DNS Config"
    COUNT=3
    printtitle
    printhdr
    if [ -e "/etc/resolv.conf" ]
    then
    	cat /etc/resolv.conf >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    #################
    # Linux Devices #
    #################

    CMD=lspci
    CHK_TITLE="Device Info"
    COUNT=4
    printtitle
    printhdr
    lspci -v  2> /dev/null >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    ############
    # Modprope #
    ############

    CMD=modprobe
    CHK_TITLE="modprobe Config"
    COUNT=5
    printtitle
    printhdr
    if [ -e "/etc/modprobe.conf" ]
    then
	    cat /etc/modprobe.conf >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm
    
    ###########
    # Inittab #
    ###########

    CMD=inittab
    CHK_TITLE="inittab Info"
    COUNT=5
    printtitle
    printhdr
    if [ -e "/etc/inittab" ]
    then	
    	cat /etc/inittab >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    #######
    # NTP #
    #######

    CMD=ntp
    CHK_TITLE="NTP Config"
    COUNT=6
    printtitle
    printhdr
    if [ -e "/etc/ntp.conf" ]
    then
    	cat /etc/ntp.conf |grep server |grep -v ^# >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ##########
    # Sysctl #
    ##########

    CMD=sysctl
    CHK_TITLE="Kernel Parameters"
    COUNT=7
    printtitle
    printhdr
    sysctl -a 2>/dev/null |sort >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    #########
    # FSTAB #
    #########

    CMD=fstab
    CHK_TITLE="filesystems table"
    COUNT=8
    printtitle
    printhdr
    if [ -e "/etc/fstab" ]
    then    
    	cat /etc/fstab >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm	
    
    #########
    # Uname #
    #########

    CMD=uname
    CHK_TITLE="Uname"
    COUNT=9
    printtitle
    printhdr
    uname -a >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    ###########
    # Network #
    ###########

    CMD=network
    CHK_TITLE="network information"
    COUNT=10
    printtitle
    printhdr     
    osversion
    if [ $OS == "REDHAT" ]
    then
        cat /etc/sysconfig/network >> $DIR_LOG/$CMD.$FMT_FILE
        echo -e ""                 >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    if [ $OS == "SUSE" ]
    then
       cat /etc/sysconfig/network/routes >> $DIR_LOG/$CMD.$FMT_FILE
       echo -e ""                        >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm
    
    ###############
    # Print Queue #
    ###############

    CMD=lpstat
    CHK_TITLE="Print Queue"
    COUNT=11
    printtitle
    printhdr   
    if [ `lpstat 2> /dev/null` ]
    then
        lpstat -v >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ########
    # tape #
    ########

    CMD=tape
    CHK_TITLE="tape Info"
    COUNT=12
    printtitle
    printhdr
    cat /proc/scsi/IBM*  2>/dev/null >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm	

    #######
    # RPM #
    #######

    CMD=rpm
    CHK_TITLE="RPM Packages"
    COUNT=13
    printtitle
    printhdr
    if [ -e "/bin/rpm" ]
    then
	    rpm -qa --queryformat='(%{installtime:date}) %{NAME}-%{VERSION}.%{RELEASE}.%{ARCH}.rpm \n'| sort -b -k8,8 >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm	

    ##############
    # OS Release #
    ##############

    CMD=lsb_release
    CHK_TITLE="OS Version"
    COUNT=14
    printtitle
    printhdr
    cat /etc/*release >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    ########################
    # Mounted FileSystems #
    ########################

    CMD=dfm
    CHK_TITLE="Mounted Filesystems + Size"
    printhdr   
    df -mTP | sort | grep -v "$(df -mTP|head -1)" >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm
    
    CMD=df
    CHK_TITLE="Mounted Filesystems + Size"
    COUNT=15
    printtitle
    printhdr   
    df -mTP | sort | grep -v "$(df -mTP|head -1)" |awk '{ print $1" "$7}' >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    ###############
    # Route Table #
    ###############

    CMD=route
    CHK_TITLE="Route Table"
    COUNT=16
    printtitle
    printhdr
    if [[ $OS == "REDHAT" ]] && [[ $OSv -ge 7 ]]
    then
	    ip route show >> $DIR_LOG/$CMD.$FMT_FILE
    else
	    route -n >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ###########
    # Netstat #
    ###########

    CMD=netstat
    CHK_TITLE="UDP and TCP active ports"
    COUNT=17
    printtitle
    printhdr
    if [[ $OS == "REDHAT" ]] && [[ $OSv -ge 7 ]]
    then
	    ss -taupen >> $DIR_LOG/$CMD.$FMT_FILE
    else
	    netstat -taupen >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ##################
    # Network Config #
    ##################

    CMD=ifconfig
    CHK_TITLE="Network Interfaces"
    COUNT=18
    printtitle
    printhdr
    if [[ $OS == "REDHAT" ]] && [[ $OSv -ge 7 ]]
    then
	    ip a >> $DIR_LOG/$CMD.$FMT_FILE
    else
		ifconfig -a|grep -v -E 'RX |TX '>> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ##############
    # Disk Table #
    ##############

    CMD=fdisk
    CHK_TITLE="Disk Table"
    COUNT=19
    printtitle
    printhdr
    fdisk -l 2>/dev/null >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    ################
    # Modules list #
    ################

    CMD=lsmod
    CHK_TITLE="Active modules list"
    COUNT=20
    printtitle
    printhdr   
    lsmod | sort >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    #######
    # PVS #
    #######

    CMD=pvs
    CHK_TITLE="PV List"
    COUNT=21
    printtitle
    printhdr
    pvs 2>/dev/null >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    ##########
    # LSSCSI #
    ##########

    CMD=lsscsi
    CHK_TITLE="lsscsi"
    COUNT=21
    printtitle
    printhdr
    if [[ `lsscsi 2> /dev/null` ]]
    then
	    lsscsi 2> /dev/null >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    #######
    # VGS #
    #######

    CMD=vgs
    CHK_TITLE="VG List"
    COUNT=22
    printtitle
    printhdr   
    vgs 2>/dev/null >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    #######
    # LVS #
    #######

    CMD=lvs
    CHK_TITLE="LV List"
    COUNT=23
    printtitle
    printhdr
    lvs 2>/dev/null                  >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    ########
    # GRUB #
    ########

    CMD=grub
    CHK_TITLE="GRUB Info"
    COUNT=24
    printtitle
    printhdr	
    if [ -f "/boot/grub/menu.lst" ]
    then
        cat /boot/grub/menu.lst          >> $DIR_LOG/$CMD.$FMT_FILE
    elif [ -f /boot/grub2/grub.cfg ]
    then
        cat /boot/grub2/grub.cfg >> $DIR_LOG/$CMD.$FMT_FILE
    elif [ -f /etc/default/grub ]
    then
        cat /etc/default/grub >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ###########
    # Network #
    ###########

    CMD=link
    CHK_TITLE="Ethernet Link Information"
    COUNT=25
    printtitle
    printhdr
    if [[ $OS == "REDHAT" ]] && [[ $OSv -ge 7 ]]
    then
	    for i in `ip a |grep mtu |cut -d ':' -f 2 |sed 's/ //'`
	    do
	    	ethtool $i >> $DIR_LOG/$CMD.$FMT_FILE
	    done
    else
		for i in `ifconfig -a |grep Link |grep -v inet |cut -d" " -f1`
		do  
			ethtool $i >> $DIR_LOG/$CMD.$FMT_FILE
		done 
    fi
    printbtm

    ########
    # Last #
    ########

    CMD=last
    CHK_TITLE="Last"
    COUNT=26
    printtitle
    printhdr 
    last >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    ###########
    # Crontab #
    ###########

    CMD=crontab
    CHK_TITLE="Crontab"
    COUNT=27
    printtitle
    printhdr   
    osversion
    if [ $OS = "REDHAT" ]
	then
        for i in `ls /var/spool/cron/`
        do
            echo -e "\n User Crontab $i \n\n"               >> $DIR_LOG/$CMD.$FMT_FILE
            cat /var/spool/cron/$i                          >> $DIR_LOG/$CMD.$FMT_FILE
        done
        echo -e ""                                           >> $DIR_LOG/$CMD.$FMT_FILE
    fi
	if [ $OS = "SUSE" ]
	then
        for i in `ls /var/spool/cron/tabs/`
        do
            echo -e "\n User Crontab $i \n\n"               >> $DIR_LOG/$CMD.$FMT_FILE
            cat /var/spool/cron/tabs/$i                     >> $DIR_LOG/$CMD.$FMT_FILE
        done
        echo -e ""                                           >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    #######
    # PAM #
    #######

    CMD=pam
    CHK_TITLE="Pam"
    COUNT=28
    printtitle
    printhdr
    for file in /etc/pam.d/* 
    do 
        echo -e "####################################"	        >> $DIR_LOG/$CMD.$FMT_FILE
        echo "$file"						                        >> $DIR_LOG/$CMD.$FMT_FILE
        echo -e "####################################"		    >> $DIR_LOG/$CMD.$FMT_FILE
        echo -e " "						                        >> $DIR_LOG/$CMD.$FMT_FILE
        cat $file 2>/dev/null					                    >> $DIR_LOG/$CMD.$FMT_FILE
        echo -e " "						                        >> $DIR_LOG/$CMD.$FMT_FILE
    done
    printbtm

    #######
    # NFS #
    #######

    CMD=exports
    CHK_TITLE="NFS - Server"
    COUNT=29
    printtitle
    printhdr
    if [ -f /etc/exports ]
    then
        cat /etc/exports                                            >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    #############
    # Multipath #
    #############

    CMD=multipath
    CHK_TITLE="Multipath"
    COUNT=30
    printtitle
    printhdr	
    if [[ `multipath -ll 2> /dev/null` ]]
    then
        multipath -ll                                       >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    #######
    # SDD #
    #######

    CMD=sdd
    CHK_TITLE="SDD"
    COUNT=31
    printtitle
    printhdr
    if [[ `datapath 2> /dev/null` ]]
    then
        datapath query essmap                                   >> $DIR_LOG/$CMD.$FMT_FILE
        echo -e "\n"                                            >> $DIR_LOG/$CMD.$FMT_FILE
        datapath query device                                   >> $DIR_LOG/$CMD.$FMT_FILE
        echo -e "\n"                                            >> $DIR_LOG/$CMD.$FMT_FILE
        datapath query adapter                                  >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ##############
    # rawdevices #
    ##############

    CMD=rawdevices
    CHK_TITLE="RAW Devices"
    COUNT=32
    printtitle
    printhdr
    cat /etc/sysconfig/rawdevices 2> /dev/null                   >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    ############
    # Messages #
    ############

    CMD=messages
    CHK_TITLE="Messages Info"
    COUNT=33
    printtitle
    printhdr
    tail -500 /var/log/messages                                  >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    #########
    # Dmesg #
    #########

    CMD=dmesg
    CHK_TITLE="Dmesg"
    COUNT=34
    printtitle
    printhdr   
    dmesg                                                        >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    #############
    # Processes #
    #############

    CMD=processes
    CHK_TITLE="Processes"
    COUNT=35
    printtitle
    printhdr
    ps aux                                                       >> $DIR_LOG/$CMD.$FMT_FILE
    printbtm

    #########
    # Fibre #
    #########

    CMD=fibre
    CHK_TITLE="HBA Link"
    COUNT=36
    printtitle
    printhdr
    if [[ `multipath -ll 2> /dev/null` ]]
    then
        systool -c scsi_host -A state >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm 
    
    #############
    # Smbstatus #
    #############

    CMD=smbstatus
    CHK_TITLE="samba status"
    COUNT=37
    printtitle
    printhdr
    if [[ `smbstatus 2> /dev/null` ]]
    then
        smbstatus -s >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ############
    # Testparm #
    ############

    CMD=testparm
    CHK_TITLL="Samba Configuration"
    COUNT=38
    printtitle
    printhdr
    if [[ `testparm -s 2> /dev/null` ]]
    then
        testparm -s >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm
    
    #############
    # Cluster #
    #############

    CMD=pcs
    CHK_TITLE="Cluster status"
    COUNT=39
    printtitle
    printhdr
    if command -v "$CMD" &> /dev/null
    then    
    	pcs status >> $DIR_LOG/$CMD.$FMT_FILE
    elif command -v clustat &> /dev/null
    then    
    	clustat >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    ############
    # SELinux #
    ############

    CMD=selinux
    CHK_TITLL="Security-Enhanced Linux status"
    COUNT=40
    printtitle
    printhdr
    if [[ `getenforce 2> /dev/null` ]]
    then
        getenforce >> $DIR_LOG/$CMD.$FMT_FILE
    fi
    printbtm

    rotatecsnap 
} # createcsnap end

comparecsnap(){
    checkUID
    testDirs
    echo "csnap Comparisson:"
    echo "======================================"
    echo ""
    echo "Choose the old csnap to be compared"
    select i in `ls -t $DIR_LOG | cut -d"." -f 2 | uniq `
    do
        if [ -z $i ]
        then
            echo "Invalid option."
            exit 1
        else
            echo "First csnap Chosen: $i"
            break
        fi
    done
    echo "Choose the newest csnap to be compared"
    select j in `ls -t $DIR_LOG | cut -d"." -f 2 | uniq `
    do
        if [ -z $i ]
        then
            echo "Invalid option."
            exit 1
        else
            echo "Second csnap Chosen: $i"
            break
        fi
    break
    done
    if [ $i = $j ]
    then
        echo "You selected the same csnap, nothing to be compared."
        exit 1
    fi

   	echo "Failed Comparison Details" > $tempcsnapFailure
	echo "------------------------------------------------------------------------------" >> $tempcsnapFailure	
	echo "------------------------------------------------------------------------------" > $tempcsnapCompare
	echo "Starting csnap comparison between "$i" & "$j >> $tempcsnapCompare
	echo "------------------------------------------------------------------------------" >> $tempcsnapCompare
    for CHK_FILE in ifconfig rpm lsb_release df route fstab fdisk lsmod lsscsi pvs vgs lvs grub link crontab last exports multipath rawdevices chkconfig fibra testparm pam
    do
		itemName=$CHK_FILE
        CHK_ITEM1=$CHK_FILE.$i.$(hostname).txt
        CHK_ITEM2=$CHK_FILE.$j.$(hostname).txt
        if [[ -f $DIR_LOG/$CHK_ITEM1 ]] && [[ -f $DIR_LOG/$CHK_ITEM2 ]]
        then
			diff $DIR_LOG/$CHK_ITEM1 $DIR_LOG/$CHK_ITEM2 | grep -E "^<|^>"  >> /dev/null 2>&1
			if [[ $? -eq 0 ]]
			then
	            echo -e "\e[31;5;1m FAILED - $itemName \e[m" >> $tempcsnapCompare1
	            echo -e "\e[31;5;1m FAILED - $itemName \e[m" >> $tempcsnapFailure
	            echo -e "------------------------------------------------------------------------------" >> $tempcsnapFailure
	            diff $DIR_LOG/$CHK_ITEM1 $DIR_LOG/$CHK_ITEM2 | grep -E "^<|^>" | sed 's/^</[BEFORE] /' | sed 's/^>/[AFTER]/' |grep '\[BEFORE\]'  >> $tempcsnapFailure
	            diff $DIR_LOG/$CHK_ITEM1 $DIR_LOG/$CHK_ITEM2 | grep -E "^<|^>" | sed 's/^</[BEFORE] /' | sed 's/^>/[AFTER]/' |grep '\[AFTER\]'  >> $tempcsnapFailure
	            echo -e ""  >> $tempcsnapFailure
	        else
	            echo -e "\e[32;5;1m PASSED - $itemName \e[m" >> $tempcsnapCompare1
	        fi
	    fi
	done
	echo -e "List of Failed tests:" >> $tempcsnapCompare
	grep FAILED $tempcsnapCompare1 >> $tempcsnapCompare 2>/dev/null
	echo -e "------------------------------------------------------------------------------"  >> $tempcsnapCompare
	echo -e "List of Successful tests:" >> $tempcsnapCompare
	grep PASSED $tempcsnapCompare1 >> $tempcsnapCompare 2>/dev/null
	echo -e "------------------------------------------------------------------------------"  >> $tempcsnapCompare
	rm $tempcsnapCompare1
	if [ `grep FAILED $tempcsnapCompare |wc -l` -ne 0 ]
	then
		cat $tempcsnapFailure >> $tempcsnapCompare
	fi
	clear
	more $tempcsnapCompare
	rm $tempcsnapCompare $tempcsnapFailure >> /dev/null 2>&1

}

backupcsnap(){
    checkUID
    testDirs
    CMD="backup"
    echo "csnap Backup:"
    echo "====================="
    echo ""
    tar -czvT $BCK_FILE -f $CMD.$FMT_FILE.tar.gz
}


viewcsnap(){
    checkUID
    testDirs
	localDir=$(pwd)
	cd "$DIR_LOG"
	echo "Choose the csnap to be viewed:"
	select i in `ls -t *.txt | cut -d"." -f 2 | uniq `
	do
		if [ ! -z "$i" ] 
		then
			echo "csnap date chosen: $i"
			select j in `ls -t *$i*.txt | cut -d"." -f 1`
			do
				if [ ! -z "$j" ]
				then
					more $j.$i*.txt
				else
					echo "Invalid Option Selected"
					echo ""
					exit 1
				fi
				break
			done
		else
			echo "Invalid Option Selected"
			echo ""
			exit 1
		fi
	break
	done
	cd $localDir
}

delete(){
    checkUID
    testDirs
    echo "csnap Removal:"
    echo "======================"
    echo ""
    select i in `ls -t $DIR_LOG | cut -d"." -f 2 | uniq `
    do
        if [ -z $i ]
        then
            echo "[ERROR] Invalid option"
            exit 1
        else
            echo "csnap Chosen: $i"
            rm -rf $DIR_LOG/*$i*.txt
            exit 0
        fi
    done
}

zipcsnap(){
    checkUID
    testDirs
	localDir=$(pwd)
	cd "$DIR_LOG"
    cmd="csnap"
    select i in `ls -t *.txt | cut -d"." -f 2 | uniq `
    do
        if [ -z "$i" ]
        then
            echo "Invalid Option Selected." 1>&2
            exit 1
        else
            echo "Compressing csnap : $i"
            tar -zcf $DIR_ZIP/$cmd.$i.$(hostname).tar *$i*
            echo "csnap compressed at `ls -ld $DIR_ZIP/$cmd.$i.$(hostname).tar |awk '{ print $9 }'`"
            echo ""
            break
        fi
    done
    cd "$localDir"
}

ziplastcsnap(){
    checkUID
    testDirs
	localDir=$(pwd)
	cd "$DIR_LOG"
    cmd="csnap"
    for i in `ls -t *.txt | cut -d"." -f 2 | uniq | head -1`
    do
            if [ -z "$i" ]
            then
                echo "Invalid Option Selected." 1>&2
                exit 1
            else
                echo "Compressing csnap : $i"
                tar -cf $DIR_ZIP/$cmd.$i.$(hostname).tar *$i*
                echo "csnap compressed at `ls -ld $DIR_ZIP/$cmd.$i.$(hostname).tar |awk '{ print $9 }'`"
                echo ""
                break
            fi
    done
    cd "$localDir"
}

rotatecsnap(){
    checkUID
    testDirs
    called="$1"
    if [ -n "$called" ]
    then
        echo "csnap rotate:"
        echo "========================="
        echo ""
    fi
    MAX_ROTATE=$(($ROTATE + 1))
    QTD_CHECK=`ls -t $DIR_LOG | cut -d "." -f 2 | uniq | wc -l` 
    
    if [ $QTD_CHECK -le $ROTATE ]
    then
        echo -e "\n\n"
        echo -e "[INFO] There are no csnaps to be rotated"
        echo -e " "
    else
        while [ $QTD_CHECK -gt $ROTATE ]
        do		
            csnap_ROTATE="csnap: `ls -t $DIR_LOG/*.txt | cut -d "." -f 2 | uniq | head -n $MAX_ROTATE | tail -1` Rotacionado para o diretorio $DIR_ZIP com sucesso"
            echo -e "$MAX_ROTATE" | `echo $0` -z &> /dev/null 
            echo -e "$MAX_ROTATE" | `echo $0` -d &> /dev/null  
            QTD_CHECK=`ls -t $DIR_LOG/*.txt | cut -d "." -f 2 | uniq | wc -l` > /dev/null
            echo -e "\n\n"
            echo $csnap_ROTATE
            echo "[INFO] csnap rotated"
            echo -e " "
        done
    fi
}

version(){
    echo "csnap v1.0"
}

#######################################################################################################################################

helpme(){
    echo -e "\e[32;2;1m"
    echo "################################"
    echo "# Select one of these options  #"
    echo "################################"
    echo -e "\e[m"
    echo "-------------------------------------------------------------------------------------"
    echo "-m = Make new csnap"
    echo "-v = View a csnap"
    echo "-c = Compare 2 csnaps"
    echo "-z = Compress a csnap"
    echo "-d = Delete a csnap"
    echo "-V = csnap Version"
    echo "-h = help option"
    echo "-------------------------------------------------------------------------------------"
    echo -e "\n"    
}

if [ -z "$1" ] 
then
    helpme
    exit 1
else
    while getopts ":CVbcdhmqrvzt" OPT; do
        case "$OPT" in
        "V") version ;;
        "b") backupcsnap ;;
        "c") comparecsnap ;;
        "d") delete ;;
        "h") helpme ;;
        "m") createcsnap ;;
        "q") createcsnap &> /dev/null ;;
        "r") rotatecsnap called ;;
        "v") viewcsnap ;;
        "z") zipcsnap ;;
        "t") ziplastcsnap ;;
        \?) echo "Invalid Option: -$OPTARG" >&2 && helpme >&2 && exit 1 ;;
        esac
    done
fi
#EOF
