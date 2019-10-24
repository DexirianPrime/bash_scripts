#!/bin/bash
# Author : Samuel Ross
# Last Update : 24/10/2019
######################################################################
# NOTE : Copy the script to your $workingdir and run it from there ! #
######################################################################
# Description : Migrate items between chef servers
# Say you provided yp_sys, it will copy ad_groups, ad_users, etc... [for databags]
# You can pass a list of databags directly to the script or a text file
# Example : chef_migrate.sh dtbg linko_qa osp_se yp_sys
# Example 2 : chef_migrate.sh dtbg dtbglist.txt
# You can also copy roles / envs / cookbooks, pass 1st argument :
# ./chef_migrate.sh role rolename1 rolename2 etc...

###### INPUT ######
chef_source="old" # Chef server to copy from [dev / old / new]
chef_desto="dev" # Chef server to copy to [dev / old / new]
workingdir="$HOME/scripts" # Where temp files will be created / deleted
knifelocation="$HOME/.chef/knife.sh" # Set custom knife.sh location
berkslocation="$HOME/.chef/berks.sh" # Set custom berks.sh location
###################

# Copy function

f_copycookbook() {
  cd $workingdir
  $knifelocation $chef_source cookbook download $1
  path=$(ls | grep $1)
  cd $path
  if [[ -f "$workingdir/$path/Berksfile" ]]; then
    $berkslocation $chef_source install
    $berkslocation $chef_desto upload
  else
    $knifelocation $chef_desto cookbook upload $1 -o "$workingdir"
  fi
  cd ..
  rm -rf $path
}

f_copyrole() {
  content=$($knifelocation $chef_source role show $1 -F json)
  cat << EOF > $workingdir/$1.json
    $content
EOF
  $knifelocation $chef_desto role from file "$workingdir/$1.json"
  rm "$workingdir/$1.json"
}

f_copyenv() {
  content=$($knifelocation $chef_source environment show $1 -F json)
  cat << EOF > $workingdir/$1.json
    $content
EOF
  $knifelocation $chef_desto environment from file "$workingdir/$1.json"
  rm "$workingdir/$1.json"
}

f_copydtbg() {
  for dtbg in $($knifelocation $chef_source data bag show $1); do
    echo "Found data bag item : $1 $dtbg"
    content=$($knifelocation $chef_source data bag show $1 $dtbg --format json)
    cat << EOF > $workingdir/$1.$dtbg.json
      $content
EOF
    if [[ ! $desto_dtbg_list = *$1* ]]; then
      echo "Databag not found on desto! Creating..."
      $knifelocation $chef_desto data bag create $1
      desto_dtbg_list+=" $1"
    fi
    $knifelocation $chef_desto data bag from file $1 "$workingdir/$1.$dtbg.json"
    rm "$workingdir/$1.$dtbg.json"
  done
}

###### Scan parameters passed to script ######
###### Copy dtbgs if passed as argument ######
echo "source : $chef_source"
echo "desto : $chef_desto"
case $1 in
  "dtbg"|"databag")
    copy_what="dtbg"
    desto_dtbg_list="$($knifelocation $chef_desto data bag list)"
    shift
    ;;
  "env")
    copy_what="env"
    shift
    ;;
  "cookbook")
    copy_what="cookbook"
    shift
    ;;
  "role")
    copy_what="role"
    shift
    ;;
  *)
    echo "Please specify type you want to copy as first parameter!"
    echo "Examples :"
    echo "chef_migrate.sh dtbg dtbgname1 dtbgname2"
    echo "chef_migrate.sh role role1 role2"
    exit 0
esac

for param in $@; do
  if [[ -f "$workingdir/$param" ]]; then
    echo "Input from file :"
    echo "$(cat $workingdir/$param)"
    for item in $(cat $workingdir/$param); do
      case $copy_what in
        "dtbg")
          f_copydtbg $item
          ;;
        "env")
          f_copyenv $item
          ;;
        "cookbook")
          f_copycookbook $item
          ;;
        "role")
          f_copyrole $item
          ;;
      esac

    done
  else
    echo "Starting $param scan and copy"
    case $copy_what in
      "dtbg")
        f_copydtbg $param
        ;;
      "env")
        f_copyenv $param
        ;;
      "cookbook")
        f_copycookbook $param
        ;;
      "role")
        f_copyrole $param
        ;;
    esac
  fi
done

