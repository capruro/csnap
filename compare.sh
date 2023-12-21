#/bin/bash

# Config
DIR_RESULTS="~/Documents/csnap"
TMP_LOG="/tmp/tempcsnapView"
tempcsnapCompare="/tmp/tempcsnapCompare"
tempcsnapCompare1="/tmp/tempcsnapCompare1"
tempcsnapFailure="/tmp/tempcsnapFailure"

testDirs(){
    if [ ! -d $DIR_RESULTS ]
    then
        echo "[ERROR] csnap dir not found"
        exit 1
    fi
} # testDirs end

selectServer(){
    echo "csnap Comparisson"
    echo "======================================"
    echo ""
    if [ -z $SRV ]
    then
        echo "No server specified, choose the server to check from the list"
        select SRV in `ls $DIR_RESULTS`
        do
                if [ -z $SRV ]
                then
                        echo "Invalid option."
                        exit 1
                else
                        echo "Server selected: $SRV"
                        break
                fi
        done
    else
        if [ ! -d $DIR_RESULTS/$SRV ]
        then
            echo "[ERROR] csnap dir not found $DIR_RESULTS/$SRV"
            exit 1
        else
            echo "Server selected: $SRV"
        fi
    fi
    DIR_LOG=$DIR_RESULTS/$SRV
} # selectServer end

viewcsnap(){
    testDirs
    selectServer
	localDir=$(pwd)
	cd "$DIR_LOG"
	echo "Choose the csnap to be viewed:"
	select i in `ls -t $DIR_LOG | cut -d"." -f 2 | uniq`
    do
        if [ -z $i ]
        then
            echo "Invalid option."
            exit 1
        else
            echo "Chosen csnap: $i"
            break
        fi
    done
    mkdir $TMP_LOG
    tar -xf $DIR_LOG/csnap.$i*.tar -C $TMP_LOG
    more $TMP_LOG/*.txt
    cd $localDir
    rm -rf $TMP_LOG >> /dev/null 2>&1

} # viewcsnap end

comparecsnap(){
    testDirs
    selectServer
    
    echo ""
    echo "Choose the old csnap to be compared"
    select i in `ls -t $DIR_LOG | cut -d"." -f 2 | uniq | sort -nr`
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
    select j in `ls -t $DIR_LOG | cut -d"." -f 2 | uniq | sort -nr`
    do
        if [ -z $j ]
        then
            echo "Invalid option."
            exit 1
        else
            echo "Second csnap Chosen: $j"
            break
        fi
        break
    done

    if [ $i = $j ]
    then
        echo "You selected the same csnap, nothing to be compared."
        exit 1
    else
        mkdir $TMP_LOG
        tar -xf $DIR_LOG/csnap.$i*.tar -C $TMP_LOG
        tar -xf $DIR_LOG/csnap.$j*.tar -C $TMP_LOG
    fi
    

    #creating comparison files
    echo "Failed Comparison Details" > $tempcsnapFailure
    echo "------------------------------------------------------------------------------" >> $tempcsnapFailure	
    echo "------------------------------------------------------------------------------" > $tempcsnapCompare
    echo "Starting csnap comparison between "$i" & "$j >> $tempcsnapCompare
    echo "------------------------------------------------------------------------------" >> $tempcsnapCompare
    
    for CHK_FILE in ifconfig rpm lsb_release route fstab pvs vgs lvs grub link crontab exports multipath rawdevices fiber testparm pam selinux
    do
	    itemName=$CHK_FILE
        CHK_ITEM1=$CHK_FILE.$i.*.txt
        CHK_ITEM2=$CHK_FILE.$j.*.txt
        if `find $TMP_LOG -maxdepth 1 -name "$CHK_FILE.$i.*.txt" -print -quit | grep -q '.' && find $TMP_LOG -maxdepth 1 -name "$CHK_FILE.$j.*.txt" -print -quit | grep -q '.'`
        then
		    diff $TMP_LOG/$CHK_ITEM1 $TMP_LOG/$CHK_ITEM2 | grep -E "^<|^>"  >> /dev/null 2>&1
		    if [[ $? -eq 0 ]]
		    then
	            echo -e "\e[31;5;1m FAILED - $itemName \e[m" >> $tempcsnapCompare1
	            echo -e "\e[31;5;1m FAILED - $itemName \e[m" >> $tempcsnapFailure
	            echo -e "------------------------------------------------------------------------------" >> $tempcsnapFailure
	            diff $TMP_LOG/$CHK_ITEM1 $TMP_LOG/$CHK_ITEM2 | grep -E "^<|^>" | sed 's/^</[BEFORE] /' | sed 's/^>/[AFTER]/' |grep '\[BEFORE\]'  >> $tempcsnapFailure
	            diff $TMP_LOG/$CHK_ITEM1 $TMP_LOG/$CHK_ITEM2 | grep -E "^<|^>" | sed 's/^</[BEFORE] /' | sed 's/^>/[AFTER]/' |grep '\[AFTER\]'  >> $tempcsnapFailure
	            echo -e ""  >> $tempcsnapFailure
	        else
	            echo -e "\e[32;5;1m PASSED - $itemName \e[m" >> $tempcsnapCompare1
	        fi
	    fi
    done
    for CHK_FILE in fdisk df lsmod chkconfig
    do
	    itemName=$CHK_FILE
        CHK_ITEM1=$CHK_FILE.$i.*.txt
        CHK_ITEM2=$CHK_FILE.$j.*.txt
        if `find $TMP_LOG -maxdepth 1 -name "$CHK_FILE.$i.*.txt" -print -quit | grep -q '.' && find $TMP_LOG -maxdepth 1 -name "$CHK_FILE.$j.*.txt" -print -quit | grep -q '.'`
        then
		    sort $TMP_LOG/$CHK_ITEM1 --output=$TMP_LOG/$CHK_ITEM1.sorted
            sort $TMP_LOG/$CHK_ITEM2 --output=$TMP_LOG/$CHK_ITEM2.sorted
            CHK_ITEM1=$CHK_ITEM1.sorted
            CHK_ITEM2=$CHK_ITEM2.sorted
            diff $TMP_LOG/$CHK_ITEM1 $TMP_LOG/$CHK_ITEM2 | grep -E "^<|^>"  >> /dev/null 2>&1
		    if [[ $? -eq 0 ]]
		    then
	            echo -e "\e[31;5;1m FAILED - $itemName \e[m" >> $tempcsnapCompare1
	            echo -e "\e[31;5;1m FAILED - $itemName \e[m" >> $tempcsnapFailure
	            echo -e "------------------------------------------------------------------------------" >> $tempcsnapFailure
	            diff $TMP_LOG/$CHK_ITEM1 $TMP_LOG/$CHK_ITEM2 | grep -E "^<|^>" | sed 's/^</[BEFORE] /' | sed 's/^>/[AFTER]/' |grep '\[BEFORE\]'  >> $tempcsnapFailure
	            diff $TMP_LOG/$CHK_ITEM1 $TMP_LOG/$CHK_ITEM2 | grep -E "^<|^>" | sed 's/^</[BEFORE] /' | sed 's/^>/[AFTER]/' |grep '\[AFTER\]'  >> $tempcsnapFailure
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
    #clear
    more $tempcsnapCompare
    rm -rf $tempcsnapCompare $tempcsnapFailure $TMP_LOG >> /dev/null 2>&1

} # comparecsnap end

helpme(){
    echo -e "\e[32;2;1m"
    echo "################################"
    echo "# Select one of these options  #"
    echo "################################"
    echo -e "\e[m"
    echo "-------------------------------------------------------------------------------------"
    echo "-v = View a csnap"
    echo "-c = Compare 2 csnaps"
    echo "-d = Delete a csnap"
    echo "-V = csnap Version"
    echo "-h = help option"
    echo "-------------------------------------------------------------------------------------"
    echo -e "\n"    
} # helpme end

version(){
    echo "$(basename $0) v1 - For bugs or suggestions send a mail to marcello.franco@skytv.it."
} # version end

if [ -z "$1" ] 
then
    helpme
    exit 1
else
    SRV=$2
    while getopts ":Vcdhv" OPT; do
        case "$OPT" in
        "V") version ;;
        "c") comparecsnap ;;
        "d") delete ;;
        "h") helpme ;;
        "v") viewcsnap ;;
        \?) echo "Invalid Option: -$OPTARG" >&2 && helpme >&2 && exit 1 ;;
        esac
    done
fi