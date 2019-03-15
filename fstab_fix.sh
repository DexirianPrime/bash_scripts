#!/bin/bash

##########################################################################################
# Script Name : fstab_fix                                                                #
# Maintainer : Samuel Ross                                                               #
# Last Update : 2019-02-20 1                                                             #
# Description :                                                                          #
# This script scans the fstab file for duplicate entries                                 #
# or wrong nfs mounts and fixes the /etc/fstab                                           #
# It can also attempt at unmounting duplicate moint point if the parameter is passed     #
# Possible Parameters :                                                                  #
# --help or -h or -help : print possible parameters                                      #
# --skip-validation OR -s : Runs script without user input                               #
# --umount OR -u : Will attempt at unmounting duplicate mount points                     #
# --force-umount OR -f : Will use umount -f !!! for duplicate entries                    #
# --verbose OR -v : Output what is done and warnings                                     #
# --no-fix OR -n : Do not attempt to fix /etc/fstab                                      #
# Be careful when using both -s and -u!!!                                                #
##########################################################################################

printhelp() {
  echo "Possible parameters :"
  echo "--skip-validation OR -s : Runs script without user input"
  echo "--umount-duplicates OR -u : Will attempt at unmounting duplicate mount points"
  echo "--force-umount OR -f : Will use umount -f !!! for duplicate entries"
  echo "--verbose OR -v : Output what is done and warnings"
  echo "--no-fix OR -n : Do not attempt to fix /etc/fstab"
  echo "Be careful when using both -s and -u!!!"
}

if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

skip=0
umount=0
verbose=0
force=0
nofix=0

for param in $@; do
  case $param in
    --skip-validation|-s)
      let "skip += 1";;
    --umount-duplicates|-u)
      let "umount += 1";;
    --verbose|-v)
      let "verbose = 1";;
    --force-umount|-f)
      let "force = 1";;
    --no-fix|-n)
      let "nofix = 1";;
    *)
      printhelp
      exit;;
  esac
done

if [[ -f $PWD/fstab.new ]] || [[ -f $PWD/fstab.tmp ]] || [[ -f $PWD/mount.tmp ]] || [[ -f $PWD/mount.tmp2 ]]; then
  [[ $verbose = 1 ]] && echo "Temp file already exists! Deleting..."
  rm -f $PWD/fstab.new $PWD/fstab.tmp $PWD/mount.tmp $PWD/mount.tmp* > /dev/null 2>&1
else
  [[ $verbose = 1 ]] && echo "Starting script... "
fi

if [[ $nofix = 0 ]]; then
  while read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && echo $line >> $PWD/fstab.new && continue
    [[ ! "$line" =~ [^[:space:]] ]] && echo $line >> $PWD/fstab.new && continue
    if [[ "$(echo $line | awk '{ print NF }' | sort -nu | tail -n 1)" -ne 6 ]];
    then
      if [[ $verbose = 1 ]]; then
        echo "Warning!! This line doesnt contain exactly 6 columns :"
        echo $line
        echo "This could lead to potential mistakes, please fix your fstab file"
      fi
      echo ${line} >> $PWD/fstab.new
      continue
    else
      unset a
      a=$(echo $line | awk '{ print $2 }')
      grep $a $PWD/fstab.tmp > /dev/null 2>&1
      i=$?
      if [[ $i = 0 ]]; then
        [[ $verbose = 1 ]] && echo "Duplicate mount point found for ${a}! Skipping line"
        continue
      fi
      echo "$a" >> $PWD/fstab.tmp
    if [[ "$(echo $line | awk '{ print $3 }')" =~ "nfs" ]];
      then
        [[ $verbose = 1 ]] && echo "Checking $line ..."
        [[ $verbose = 1 ]] && echo "NFS Mount found, changing bkp and fsck to 0 and appending line"
        echo $line | awk '{$5=$6="0"; print $0 }' >> $PWD/fstab.new
      else
        [[ $verbose = 1 ]] && echo "Checking $line ..."
        [[ $verbose = 1 ]] && echo "Not NFS mount, appending line to new file"
        echo ${line} >> $PWD/fstab.new
    fi
  fi
  done < /etc/fstab
fi

if [[ $nofix = 0 ]]; then
  if [[ $skip = 0 ]]; then
    echo "Do you want to see the difference between the old and new fstab files?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) echo "Here are the differences in your newly generated fstab :"
            echo
            diff=`diff -w $PWD/fstab.new /etc/fstab`
            echo "$diff"
            break;;
            No ) break;;
        esac
    done
  else
    if [[ $verbose = 1 ]]; then
      echo "Here are the differences in your newly generated fstab :"
      echo
      diff=`diff -w $PWD/fstab.new /etc/fstab`
      echo "$diff"
      echo
    fi
  fi

  newfile=`cat $PWD/fstab.new`

  if [[ $skip = 0 ]]; then
    echo "Do you want to see the new fstab file content?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) echo "Printing content of $PWD/fstab.new"
            echo "$newfile"
            break;;
            No ) break;;
        esac
    done
  else
    [[ $verbose = 1 ]] && echo "Here is the new fstab file :" && echo "$newfile"
  fi
fi

write_to_fstab() {
  tmp_fstab="/etc/fstab.bak"

  if [[ -e /etc/fstab.bak ]]; then
    digit=1
    while true; do
      temp_name=$tmp_fstab-$digit
      if [[ ! -f  $temp_name ]]; then
        [[ $verbose = 1 ]] && echo "fstab backup file found! appending number and writing to $temp_name"
        cp -p /etc/fstab $temp_name
        break
      else
        ((digit++))
      fi
    done
  else
    [[ $verbose = 1 ]] && echo "Making backup of original fstab @ /etc/fstab.bak and overwriting file..."
    cp -p /etc/fstab /etc/fstab.bak
  fi
  rm -f /etc/fstab
  cp $PWD/fstab.new /etc/fstab
  error=$?
  chmod 644 /etc/fstab
  [[ $verbose = 1 && $error = 0 ]] && echo "Success!";
  [[ $verbose = 1 && $error = 1 ]] && echo "Operation failed, are you running as root?"
}

if [[ $nofix = 0 ]]; then
  if [[ $skip = 0 ]]; then
    echo "Do you want to overwrite /etc/fstab with the new $PWD/fstab.new file?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) write_to_fstab
            break;;
            No ) [[ $verbose = 1 ]] && echo "Discarding changes..."
            break;;
        esac
    done
    else
      write_to_fstab
  fi
fi

f_umount() {
   mount | grep -E --color=never '^(/|[[:alnum:]\.-]*:/)' >> $PWD/mount.tmp3
   touch $PWD/mount.tmp
   while read -r line; do
       mntpt=$(echo $line | awk '{ print $3 }')
       cnt=$(grep -c $mntpt $PWD/mount.tmp)
       [[ ! $cnt -ge 2 ]] && echo $line >> $PWD/mount.tmp
   done < $PWD/mount.tmp3
   while read -r line; do
     dup=0
     count=0
     exit=0
     answer=1
     unset a
     a=$(echo $line | awk '{ print $3 }')
     [[ $verbose = 1 ]] && echo "Scanning for duplicate mount point on $a"
     grep $a $PWD/mount.tmp2 > /dev/null 2>&1
     if [[ "$(echo $?)" = 0 ]]; then
       dup=1
       if [[ "$(grep -c ${a} /etc/fstab)" = 0 ]]; then
         [[ $verbose = 1 ]] && echo "No entry found in fstab for this mount point! ($a)" && echo "Skipping this mount point" && continue
         continue
       fi
       [[ $verbose = 1 ]] && echo "Duplicate mount point found for $a"
       if [[ $skip = 0 ]]; then
         echo "Do you want to try and fix $a ?"
         select yn in "Yes" "No"; do
           case $yn in
             Yes ) answer=1
             break;;
             No ) answer=0
             break;;
           esac
        done < /dev/tty
       fi
       [[ $answer = 0 ]] && echo $a >> $PWD/mount.tmp2 && continue
       for ((n=0;n<20;n++)); do
         [[ $force = 0 ]] && umount $a || umount -f $a
         sleep .5
         mount | grep -E --color=never '^(/|[[:alnum:]\.-]*:/)' | grep $a > /dev/null 2>&1
         b=$?
         if [[ $b = 1 ]]; then
           while true; do
             [[ $verbose = 1 ]] && echo "Mount point ${a} not found anymore, trying to remount..."
             ((count++))
             mount $a
             sleep 2
             mount | grep -E --color=never '^(/|[[:alnum:]\.-]*:/)' | grep $a > /dev/null 2>&1
             b=$?
             if [[ $verbose = 1 ]]; then
               [[ $b = 0 ]] && echo "Mount has succeeded for ${a}, continuing..." && break 2
               [[ $count = 5 ]] && echo "Tried to mount 5 times without success, continuing..." && break 2
             else
               [[ $b = 0 ]] && break 2
               [[ $count = 5 ]] && break 2
             fi
           done
         fi
         [[ $verbose = 1 && $n = 19 ]] && echo "Tried to unmount ${a} 20 times and failed, please check logs"
         [[ $n = 19 ]] && break
       done
     fi
     [[ $dup = 0 ]] && echo $a >> $PWD/mount.tmp2
   done < $PWD/mount.tmp
}

f_delete_temp() {
  rm -f $PWD/fstab.new
  rm -f $PWD/fstab.tmp
  rm -f $PWD/mount.tmp
  rm -f $PWD/mount.tmp*
}

[[ $umount = 1 ]] && f_umount

if [[ $skip = 0 ]]; then
  echo "Do you want to delete temp files? (This preserves the fstab backup)"
  select yn in "Yes" "No"; do
    case $yn in
      Yes )
        f_delete_temp
        break;;
      No )
        break;;
      esac
    done
else
  f_delete_temp
fi

echo "Script completed on $HOSTNAME, please validate results"
