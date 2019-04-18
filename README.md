# bash_scripts


The multiple_chef_setup.sh allows you to work with multiple chef servers in your env easily
It sets an alias of the knife and berks command that change your knife.rb configuration to use the proper chef server depending on the parameters passed. It pulls your .pem keys using a defined SSH key to your local machine and does the ssl fetch for all the servers

The xauth.sh script allows you to automatically do the X11 setup 

The fstab.fix allows you to scan the fstab fix for NFS shares and append 0 0 for them automatically, it can also remove duplicates entries and active mount points

The route_fix.sh is a internal specific script that scans for which subnet the machines resides in, and adds the route to the active config as well as the os-specific configuration files to keep it persistent.
