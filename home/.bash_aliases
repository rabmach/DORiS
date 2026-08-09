##aliases, debian, machiner
# Action/launcher aliases were moved to standalone scripts in ~/bin
# so they can be bound to keys; see ~/bin/* and ~/.bash_functions.md.
#------------------------------------------////
# System:
#------------------------------------------////
alias ping='ping -c 4'
alias iotop='sudo iotop -o -a'
alias fstab='sudo cp /etc/fstab /etc/fstab.backup; sudo nano /etc/fstab'
alias mounted='df -hT'
alias cleancache='sudo /sbin/sysctl vm.drop_caches=3'
alias mount='mount |column -t'
alias rm='rm -I --preserve-root'
alias mv='mv -i'
alias cp='cp -i'
alias ln='ln -i'
alias less='less -r'
alias bd='cd "$OLDPWD"'
alias nuke='/bin/rm  --recursive --force --verbose'
alias checkcommand="type -t"
alias del='mv --force -t ~/.local/share/Trash/files'
alias edit='nano --smarthome --multibuffer --const --autoindent'
alias nano='nano --smarthome --multibuffer --const --autoindent'
alias cat='batcat'
alias su='sudo -i'
alias src='source ~/.bashrc'
alias path='echo -e ${PATH//:/\\n}'
alias h='history'
alias home='cl ~'
alias rslv='sudo nano /etc/resolv.conf'
alias map='telnet mapscii.me'
alias bp="sudo chattr +i ${HOME}/.bashrc"
alias bup="sudo chattr -i ${HOME}/.bashrc"
alias bcp='if [[ $(lsattr -R -l ~/.bashrc | grep " Immutable") ]]; then echo "Protected"; else echo "Not Protected"; fi;'
alias services='systemctl list-units --type=service --state=running,failed'
alias servicesall='systemctl list-units --type=service'
alias {failed,servicefailed}='systemctl --failed'
alias servicestatus='sudo systemctl status'
alias serviceenable='sudo systemctl enable --now'
alias servicedisable='sudo systemctl disable'
alias servicestart='sudo systemctl start'
alias servicestop='sudo systemctl stop'
alias servicekill='sudo systemctl kill'
alias servicerestart='sudo systemctl restart'
alias servicereload='sudo systemctl reload'
#------------------------------------------////
# Package Management:
#------------------------------------------////
alias sources='sudo x-text-editor /etc/apt/sources.list'
alias deb='sudo dpkg -i'
alias show='aptitude show'
alias list='dpkg -L'
alias cpf='sudo aptitude clean && sudo aptitude purge ~c && sudo aptitude -f install'
alias remove='sudo aptitude purge'
alias install='sudo aptitude -y install'
alias apps='sudo synaptic'
alias search='aptitude search'
alias update='sudo aptitude update'
alias upgrade='sudo aptitude full-upgrade'
alias updoogie='runwithfeedback upgrading upgrade'
alias devs="aptitude -F '%p' search '~i -dev$'"
alias devsizes="aptitude -F '%I %p' search '~i -dev$'"
alias otto='sudo apt autoremove'
#------------------------------------------////
# Desktop / fun:
#------------------------------------------////
alias excuses='echo `telnet bofh.jeffballard.us 666 2>/dev/null` |grep --color -o "Your excuse is:.*$"'
alias insults='wget http://www.randominsults.net -O - 2>/dev/null | grep \<strong\> | sed "s;^.*<i>\(.*\)</i>.*$;\1;";'
alias matrix='echo -e "\e[32m"; while :; do for i in {1..16}; do r="$(($RANDOM % 2))"; if [[ $(($RANDOM % 5)) == 1 ]]; then if [[ $(($RANDOM % 4)) == 1 ]]; then v+="\e[1m $r   "; else v+="\e[2m $r   "; fi; else v+="     "; fi; done; echo -e "$v"; v=""; done'
alias matrix2='echo -ne "\e[32m" ; while true ; do echo -ne "\e[$(($RANDOM % 2 + 1))m" ; tr -c "[:print:]" " " < /dev/urandom | dd count=1 bs=50 2> /dev/null ; done'
alias matrix3='tr -c "[:digit:]" " " < /dev/urandom | dd cbs=$COLUMNS conv=lcase,unblock | GREP_COLOR="1;32" grep --color "[^ ]"'
alias sing='x="bottles of beer";y="on the wall";for b in {99..1};do echo "$b $x $y, $b $x. Take one down pass it around, $(($b-1)) $x $y"; sleep 8;done'
alias jan='cal -m 01'
alias feb='cal -m 02'
alias mar='cal -m 03'
alias apr='cal -m 04'
alias may='cal -m 05'
alias jun='cal -m 06'
alias jul='cal -m 07'
alias aug='cal -m 08'
alias sep='cal -m 09'
alias oct='cal -m 10'
alias nov='cal -m 11'
alias dec='cal -m 12'
#------------------------------------------////
# Lookin' at Stuff:
#------------------------------------------////
alias dir='dir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias parts='sudo gparted'
alias df='df --human-readable --print-type --exclude-type=squashfs --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=efivarfs'
alias new='lsd -lAtr --almost-all --color=always| tail -10 | tac'
alias tree='tree -CAhF --dirsfirst'
alias ltree='command lsd --almost-all --blocks permission,user,size,date,name --group-dirs first --header --long --tree'
alias la='ls -Alh' # show hidden files
alias ls='ls -aFh --color=always' # add colors and file type extensions
alias lx='ls -lXBh' # sort by extension
alias lk='ls -lSrh' # sort by size
alias lc='ls -lcrh' # sort by change time
alias lu='ls -lurh' # sort by access time
alias lr='ls -lRh' # recursive ls
alias lt='ls -ltrh' # sort by date
alias lf="ls -l | egrep -v '^d'" # files only
alias lm='ls -alh |more' # pipe through 'more'
alias lw='ls -xAh' # wide listing format
alias ll='ls -Fls' # long listing format
alias labc='ls -lap' #alphabetical sort
alias ldir="ls -l | egrep '^d'"
alias dmesg='dmesg --color'
alias du='du -h --max-depth=1 . | sort -h'
alias cards='lspci -k | grep -A 2 -E "(VGA|3D)"'
