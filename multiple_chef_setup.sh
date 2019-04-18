#!/bin/bash -li
#Author : Samuel Ross
#Dont ask questions to which you dont want the answers
#To understand recursion, see end of this script
while true ; do
    read -r -p "Current knife.rb and key.pem location (ex.: /home/sross1/.chef): " knifepath
    if [ -d "$knifepath" ] ; then
        [[ -f "$knifepath/knife.rb" ]] && break || echo "knife.rb wasnt found @ $knifepath"
    fi
    echo "$knifepath isn't valid"
done
read -r -p "Enter your YPG AD username (ex.: sross1): " userid
oldknife=$(which knife)
if [[ ! -f "$knifepath/$userid.pem" ]]; then
  echo "$knifepath/$userid.pem not found!! Is your private key in a different location?"
  select yn in "Yes" "No"; do
      case $yn in
          Yes )
          while true ; do
            read -r -p "Please specify full path for your private key (ex.: /home/sross1/.chef/sross1.pem) : " keypath
            [[ -f "$keypath" ]] && break || echo "$keypath doesnt exist!"
          done
          break;;
          No )
          echo "Sorry bud i can't do everything for you, get yourself a .pem file"
          exit 1;;
      esac
  done
else
  keypath="$knifepath/$userid.pem"
fi
echo
echo
echo "Warning! By continuing here, everytime you will use the knife command, you will either need to pass the 'old' or 'new' as first parameter"
echo "Example : knife old cookbook upload xyz"
echo "Example 2 : knife new data bag show x y"
echo "If you don't, knife will prompt you asking whether you want to use the old or the new chef server!"
echo "If you have better ideas as how to manage multiple chef servers, feel free to talk with sross1"
echo
echo "Do you want to continue?"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
        break;;
        No )
        echo "Ok then, good luck~!"
        exit 1;;
    esac
done
echo
echo "Creating file $HOME/knifeinfo.txt, DO NOT DELETE THIS FILE! If you do, you will have to run this script again!"

[[ -f "$HOME/knifeinfo.txt" ]] && rm $HOME/knifeinfo.txt
touch $HOME/knifeinfo.txt
echo "knifepath=$knifepath/knife.rb" >> $HOME/knifeinfo.txt
echo "keypath=$keypath" >> $HOME/knifeinfo.txt
echo "userid=$userid" >> $HOME/knifeinfo.txt
echo "oldknife=$oldknife" >> $HOME/knifeinfo.txt

echo "Making backup of your original knife.rb since this script will modify it often"
echo "Copying $knifepath/knife.rb to $knifepath/knifebackup.txt (unless it exists)"
backup_path="$knifepath/knifebackup.txt"
if [[ -e $backup_path ]]; then
  digit=1
  while true; do
    temp_name=$backup_path-$digit
    if [[ ! -f $temp_name ]]; then
      echo "backup found already found! appending number and writing to $temp_name instead"
      cp -p $knifepath/knife.rb $temp_name
      break
    else
      ((digit++))
    fi
  done
else
  cp -p $knifepath/knife.rb $knifepath/knifebackup.txt
fi
echo
echo "Creating a ssh key to grab your client key! ($HOME/.ssh/knife_key)"
echo "You can use this key later to ssh to the chef server at your convenience"

cat << EOF > $HOME/.ssh/knife_key
-----BEGIN RSA PRIVATE KEY-----
KEY HERE
-----END RSA PRIVATE KEY-----
EOF
chmod 600 "$HOME/.ssh/knife_key"
echo "Pulling your .pem key for the new PROD chef server to $knifepath/new_$userid.pem"
echo "Also Pulling .pem key for the DEV chef server @ $knifepath/dev_$userid.pem"
[[ ! -f "$knifepath/new_$userid.pem" ]] && rm "$knifepath/new_$userid.pem"
[[ ! -f "$knifepath/dev_$userid.pem" ]] && rm "$knifepath/dev_$userid.pem"
scp -i $HOME/.ssh/knife_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@PROD CHEF URL.:/etc/opscode/users/$userid.pem $knifepath/new_$userid.pem
scp -i $HOME/.ssh/knife_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@DEV CHEF URL:/etc/opscode/users/$userid.pem $knifepath/dev_$userid.pem
echo
echo "Creating new knife script! Creating @ $knifepath/knife.sh"

cat << 'EOF' > "$knifepath/berks.sh"
#!/bin/bash
param=$@
[[ ! -f "$HOME/knifeinfo.txt" ]] && echo "WARNING!! $HOME/knifeinfo.txt doesn't exist! Please re-run the knifesetup.sh script! Or remove the knife alias" && exit 1
knifepath=$(grep knifepath $HOME/knifeinfo.txt | awk -F "=" '{ print $2 }')
keypath=$(grep keypath $HOME/knifeinfo.txt | awk -F "=" '{ print $2 }')
userid=$(grep userid $HOME/knifeinfo.txt | awk -F "=" '{ print $2 }')
keydir=$(grep key $HOME/knifeinfo.txt | awk -F "=" '{ print $2 }' | awk -F "/" '{ print "/" $2 "/" $3 "/" $4 }')
berkslocation=$(which berks)
set_old() {
  [[ $1 == "1" ]] && param=${param:4}
  sed -i  '/chef_server_url/d' $knifepath
  echo "chef_server_url     'OLD CHEF URL'" >> $knifepath
  sed -i '/client_key/d' $knifepath
  echo "client_key    '$keypath'" >> $knifepath
  $berkslocation $param
  exit 0
}
set_new() {
  [[ $1 == "1" ]] && param=${param:4}
  sed -i  '/chef_server_url/d' $knifepath
  echo "chef_server_url     'NEW CHEF URL'" >> $knifepath
  sed -i '/client_key/d' $knifepath
  echo "client_key    '$keydir/new_$userid.pem'" >> $knifepath
  $berkslocation $param
  exit 0
}
set_dev() {
  [[ $1 == "1" ]] && param=${param:4}
  sed -i  '/chef_server_url/d' $knifepath
  echo "chef_server_url     'DEV CHEF URL'" >> $knifepath
  sed -i '/client_key/d' $knifepath
  echo "client_key    '$keydir/dev_$userid.pem'" >> $knifepath
  $berkslocation $param
  exit 0
}
set_none() {
  echo "Do you want to connect to the old (ldcpchef) or new (ldcpchefsrv) or dev (ldcdchefsrv) chef?"
  select ynp in "old" "new" "dev"; do
      case $ynp in
          old ) set_old 0;;
          new ) set_new 0;;
          dev ) set_dev 0;;
      esac
  done
}
case $1 in
  old)
    set_old 1
    ;;
  new)
    set_new 1
    ;;
  dev)
    set_dev 1
    ;;
  *)
    set_none
    ;;
esac
EOF
cat << 'EOF' > "$knifepath/knife.sh"
#!/bin/bash
param=$@
[[ ! -f "$HOME/knifeinfo.txt" ]] && echo "WARNING!! $HOME/knifeinfo.txt doesn't exist! Please re-run the knifesetup.sh script! Or remove the knife alias" && exit 1
knifepath=$(grep knifepath $HOME/knifeinfo.txt | awk -F "=" '{ print $2 }')
keypath=$(grep keypath $HOME/knifeinfo.txt | awk -F "=" '{ print $2 }')
userid=$(grep userid $HOME/knifeinfo.txt | awk -F "=" '{ print $2 }')
keydir=$(grep key $HOME/knifeinfo.txt | awk -F "=" '{ print $2 }' | awk -F "/" '{ print "/" $2 "/" $3 "/" $4 }')
knifeexec=$(grep oldknife $HOME/knifeinfo.txt | awk -F "=" '{ print $2 }')
set_old() {
  [[ $1 == "1" ]] && param=${param:4}
  sed -i  '/chef_server_url/d' $knifepath
  echo "chef_server_url     'OLD CHEF URL'" >> $knifepath
  sed -i '/client_key/d' $knifepath
  echo "client_key    '$keypath'" >> $knifepath
  $knifeexec $param -c $knifepath
  exit 0
}
set_new() {
  [[ $1 == "1" ]] && param=${param:4}
  sed -i  '/chef_server_url/d' $knifepath
  echo "chef_server_url     'NEW CHEF URL'" >> $knifepath
  sed -i '/client_key/d' $knifepath
  echo "client_key    '$keydir/new_$userid.pem'" >> $knifepath
  $knifeexec $param -c $knifepath
  exit 0
}
set_dev() {
  [[ $1 == "1" ]] && param=${param:4}
  sed -i  '/chef_server_url/d' $knifepath
  echo "chef_server_url     'DEV CHEF URL'" >> $knifepath
  sed -i '/client_key/d' $knifepath
  echo "client_key    '$keydir/dev_$userid.pem'" >> $knifepath
  $knifeexec $param -c $knifepath
  exit 0
}
set_none() {
  echo "Do you want to connect to the old or new or dev chef?"
  select ynp in "old" "new" "dev"; do
      case $ynp in
          old ) set_old 0;;
          new ) set_new 0;;
          dev ) set_dev 0;;
      esac
  done
}
case $1 in
  old)
    set_old 1
    ;;
  new)
    set_new 1
    ;;
  dev)
    set_dev 1
    ;;
  *)
    set_none
    ;;
esac
EOF
chmod 777 "$knifepath/knife.sh"
chmod 777 "$knifepath/berks.sh"
sed -i '/knife.sh/d' $HOME/.bash_aliases
sed -i '/berks.sh/d' $HOME/.bash_aliases
echo "alias knife='$knifepath/knife.sh'" >> $HOME/.bash_aliases
echo "alias berks='$knifepath/berks.sh'" >> $HOME/.bash_aliases
alias knife="$knifepath/knife.sh"
alias berks="$knifepath/berks.sh"

echo "Make sure you ran this script using 'source chefsetup.sh' or else you will need to set alias manually via :"
echo "alias knife='$knifepath/knife.sh'"
echo "alias berks='$knifepath/berks.sh'"
$knifepath/knife.sh new ssl fetch
$knifepath/knife.sh dev ssl fetch

#To understand recursion, see beginning of this script

