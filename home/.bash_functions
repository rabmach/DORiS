  ##functions, debian, machiner - code from everyone
  # Per-function docs live in ~/.bash_functions.md
                    #------------------------------------------////
                    # Handy One-Liners:
                    #------------------------------------------////
function hg() { history | grep "$1"; }
function myps() { ps $@ -u $USER -o pid,%cpu,%mem,bsdtime,command ; }
function pp() { myps f | awk '!/awk/ && $0~var' var=${1:-".*"} ; }
function wordnet() { curl dict://dict.org/d:${1}:wn; }
function mktar() { tar cvzf "${1%%/}.tar.gz"  "${1%%/}/"; }
function mkzip() { zip -9 -r "${1%%/}.zip" "$1" ; }
function sanitize() { chmod -R u=rwX,g=rX,o= "$@" ;}
function box() { t="$1xxxx";c=${2:-#}; echo ${t//?/$c}; echo "$c $1 $c"; echo ${t//?/$c}; }

                  #------------------------------------------////
                  # Handy Utility:
                  #------------------------------------------////

function hascommand() {
  # If no arguments or just '--strict' is provided, show help message
  if [[ -z "${1}" || (${#} -eq 1 && "${1}" == "--strict") ]]; then
    echo -e "${BRIGHT_WHITE}hascommand:${RESET} Checks if a command or alias exists"
    echo -e "${BRIGHT_WHITE}Options:${RESET}"
    echo -e "  ${BRIGHT_YELLOW}--strict${RESET} or ${BRIGHT_YELLOW}-s${RESET} checks for executable commands only ${BRIGHT_RED}excluding aliases${RESET}"
    echo -e "${BRIGHT_WHITE}Usage examples:${RESET}"
    echo -e "  Check any command or alias:"
    echo -e "    ${BRIGHT_GREEN}hascommand ${BRIGHT_YELLOW}ls${RESET}"
    echo -e "  Check executable only ${BRIGHT_RED}(strict mode)${RESET}:"
    echo -e "    ${BRIGHT_GREEN}hascommand ${BRIGHT_YELLOW}--strict ${BRIGHT_YELLOW}grep${RESET}"
    echo -e "  Display this help message:"
    echo -e "    ${BRIGHT_GREEN}hascommand${RESET}"
    return 2  # Return code 2 to indicate incorrect usage
  fi

  # Check for the '--strict' option
  if [[ "${1}" == "--strict" ]] || [[ "${1}" == "-s" ]]; then
    # Look for executable command using type -P which returns the path
    # to the executable while ignoring functions and aliases
    if type -P "${2}" &>/dev/null; then
      return 0  # Command exists
    else
      return 1  # Command doesn't exist
    fi
  else
    # Look for command or alias
    if type "${1}" &>/dev/null; then
      return 0  # Command or alias exists
    else
      return 1  # Command or alias doesn't exist
    fi
  fi
}

# Searches for text in all files in the current folder
function findtext() {
	# Local constant for maximum line length cut-off
	# NOTE: This is necessary for certain files like binaries
	local -r LINE_LENGTH_CUTOFF=1000

	# The prefix to prepend to search commands for elevated permissions
	local SUDO_PREFIX=""

	# Check for --sudo flag and remove it from arguments if present
	if [[ "$1" == "--sudo" ]]; then
		SUDO_PREFIX="sudo "
		shift
	fi

	# If no search text is specified, show help text
	if [ -z "$1" ]; then
		echo -e "${BRIGHT_WHITE}findtext:${RESET} Searches for text in all files recursively"
		echo -e "You can use both ${BRIGHT_YELLOW}plain text${RESET} and ${BRIGHT_YELLOW}regular expressions${RESET} for searching"
		echo -e "To use elevated permissions include the ${BRIGHT_YELLOW}--sudo${RESET} option"
		echo -e "${BRIGHT_WHITE}Usage:${RESET}"
		echo -e "  ${BRIGHT_CYAN}findtext${RESET} ${BRIGHT_YELLOW}[search_text]${RESET}"
		echo -e "${BRIGHT_WHITE}Examples:${RESET}"
		echo -e "  ${BRIGHT_CYAN}findtext${RESET} ${BRIGHT_YELLOW}'example text'${RESET}"
		echo -e "  ${BRIGHT_CYAN}findtext${RESET} ${BRIGHT_YELLOW}'Hello\\s+world\\.'${RESET} ${BRIGHT_BLUE}(${BRIGHT_MAGENTA}using regex${BRIGHT_BLUE})${RESET}"
		echo -e "  ${BRIGHT_CYAN}findtext${RESET} ${BRIGHT_GREEN}--sudo${RESET} ${BRIGHT_YELLOW}'todo'${RESET}     ${BRIGHT_BLUE}(${BRIGHT_MAGENTA}using sudo${BRIGHT_BLUE})${RESET}"
		return 1
	fi

	# If ripgrep is installed, use that
	# Link: https://github.com/BurntSushi/ripgrep
	if hascommand --strict rg; then
		echo -e "${BRIGHT_CYAN}Search using ${BRIGHT_YELLOW}ripgrep${BRIGHT_CYAN}:${RESET}"
		echo "${SUDO_PREFIX}rg --smart-case --no-ignore --hidden --pretty '$@' ."
		${SUDO_PREFIX}rg --smart-case --no-ignore --hidden --pretty "$@" .  | \
			awk -v len=$LINE_LENGTH_CUTOFF '{ $0=substr($0, 1, len); print $0 }'

	# If The Silver Searcher is installed, use that
	# Link: https://github.com/ggreer/the_silver_searcher
	# Hint: You can use --ignore "dir/or/file"
	elif hascommand --strict ag; then
		echo -e "${BRIGHT_CYAN}Search using ${BRIGHT_YELLOW}The Silver Searcher${BRIGHT_CYAN}:${RESET}"
		echo "${SUDO_PREFIX}ag --color --smart-case --hidden --literal '$@'"
		${SUDO_PREFIX}ag --color --smart-case  --literal "$@" 2> /dev/null | \
			awk -v len=$LINE_LENGTH_CUTOFF '{ $0=substr($0, 1, len); print $0 }'

	else # Use grep
		# Link: https://www.howtogeek.com/496056/how-to-use-the-grep-command-on-linux/
		# Hint: You can use --exclude='/dir/or/file'
		# --ignore-case (-i)        : Makes the search case-insensitive
		# --binary-files=without-match (-I) : Ignores binary files
		# --with-filename (-H)      : Displays the filename along with the matching line
		# --recursive (-r)          : Searches through all subdirectories recursively
		# --line-number (-n)        : Adds the line number to the output
		# Optional:
		# --fixed-strings (-F)      : Treats the search term as a fixed string (not a regular expression)
		# --files-with-matches (-l) : Only outputs the filenames that contain a match (e.g., grep -irl "$@" *)
		echo -e "${BRIGHT_CYAN}Search using ${BRIGHT_YELLOW}grep${BRIGHT_CYAN}:${RESET}"
		echo "${SUDO_PREFIX}grep --color=always --recursive --ignore-case --binary-files=without-match --with-filename --line-number '$@'"
		${SUDO_PREFIX}grep \
			--color=always \
			--recursive \
			--ignore-case \
			--binary-files=without-match \
			--with-filename \
			--line-number \
			"${@}" \
		| awk -v len=${LINE_LENGTH_CUTOFF} '{ $0=substr($0, 1, len); print $0 }'
	fi
}

function genphrase() {
  # Requires bash4 or newer and shuf
  # There is an older, more portable version of this available in my git history (pre 01/23)
  (( BASH_VERSINFO < 4 )) && {
    printf -- '%s\n' "genphrase(): bash 4 or newer required"
    return 1
  }
  command -v shuf >/dev/null 2>&1 || {
    printf -- '%s\n' "genphrase(): 'shuf' required but not found in PATH"
    return 1
  }

  # First, double check that the dictionary file exists.
  if [[ ! -f ~/.pwords.dict ]] ; then
    # Test if we can download our wordlist, otherwise use the standard 'words' file to generate something usable
    if ! wget -T 2 https://raw.githubusercontent.com/rawiriblundell/dotfiles/master/.pwords.dict -O ~/.pwords.dict &>/dev/null; then
      # Alternatively, we could just use grep -v "[[:punct:]]", but we err on the side of portability
      LC_COLLATE=C grep -Eh '^[A-Za-z].{3,9}$' /usr/{,share/}dict/words 2>/dev/null | grep -v "'" > ~/.pwords.dict
    fi
  fi

  # localise our vars for safety
  local OPTIND delimiter phrase_words phrase_num phrase_seed seed_word total_words

  # Default the vars
  delimiter='\0'
  phrase_words=6
  phrase_num=1
  phrase_seed="False"
  seed_word=

  while getopts ":d:hn:s:w:" Flags; do
    case "${Flags}" in
      (d) delimiter="${OPTARG}" ;;
      (h)
        printf -- '%s\n' "" "genphrase - a basic passphrase generator" \
          "" "Optional Arguments:" \
          "    -d Delimiter.  Note: Quote special chars. (Default: none)" \
          "    -h Help" \
          "    -n Number of passphrases to generate (Default: ${phrase_num})" \
          "    -s Seed your own word" \
          "    -w Number of random words to use (Default: ${phrase_words})" ""
        return 0
      ;;
      (n)  phrase_num="${OPTARG}" ;;
      (s)  phrase_seed="True"; seed_word="[${OPTARG}]" ;;
      (w)  phrase_words="${OPTARG}";;
      (:)
        printf -- "Option '%s' requires an argument. e.g. '%s 10'\n" "-${OPTARG}" "-${OPTARG}" >&2
        return 1
      ;;
      (*)
        printf -- "Unrecognised argument: '%s'\n" "-${OPTARG}.  Try 'genphrase -h' for usage." >&2
        return 1
      ;;
    esac
  done
  

  [[ "${phrase_seed}" = "True" ]] && (( phrase_words = phrase_words - 1 ))


  total_words=$(( phrase_words * phrase_num ))
  
  while read -r; do

    lineArray=( ${seed_word} ${REPLY} )
    shuf -e "${lineArray[@]^}" | paste -sd "${delimiter}" -
  done < <(
    shuf -n "${total_words}" ~/.pwords.dict |
      awk -v w="${phrase_words}" 'ORS=NR%w?FS:RS'
    )
  return 0
}


# e.g.: remindme 10m "omg, the pizza"
function remindme() {
  if [[ "$#" -ne 2 ]]; then
    echo -e "Usage: remindme [time] '[message]'"
    echo -e "Example: remindme 50s 'check mail'"
    echo -e "Example: remindme 10m 'go to class'"
    return 1
  fi
  sleep "$1" && notify-send -t 15000 "$2" &
  echo 'Reminder set'
}

function findbig() {
    du -h -x -s -- * | sort -r -h | head -20;
	}

# findd: find directory names, 2 levels deep by default (findtext/findbig style)
# usage: findd <name> [depth]   e.g.  findd music      findd storage 5
# plain find(1) backend: no hidden-dir/gitignore defaults to fight (fd renamed
# -I/--hidden to -H/--hidden in 8.0 and silently skips dot-dirs otherwise),
# so .config & friends are found with zero flags.
function findd() {
    local pattern="${1:?usage: findd <name> [depth]}"
    local depth="${2:-2}"
    [[ "$depth" =~ ^[0-9]+$ ]] || { echo "findd: depth must be a number" >&2; return 1; }
    command find . -maxdepth "$depth" -type d -iname "*${pattern}*" -print 2>/dev/null
}

  function mostused() {
  local num_items="${1:-10}"  # Default to 10 if num_items is not specified
  history \
  | awk ' { a[$4]++ } END { for ( i in a ) print a[i], i | "sort -rn | head -n'"$num_items"'"}' \
  | awk '$1 > max{ max=$1} { bar=""; i=s=10*$1/max;while(i-->0)bar=bar"#"; printf "%25s %15d %s %s", $2, $1,bar, "\n"; }'
}

function mkcd() {
  if [ -n "$1" ]; then
    mkdir -p "$1" && cd "$1"
  else  
    mkdir newdir && cd newdir 
  fi
}

function up ()
{
  local d="" limit="${1:-1}"
  for ((i=1 ; i <= limit ; i++))
    do
      d=$d/..
    done
  d=${d#/}
  if [ -z "$d" ]; then
    d=..
  fi
  cd "$d" || return
}


function runwithfeedback() {
  # Check if both parameters are provided
  if [ -z "${1}" ] || [ -z "${2}" ]; then
    echo -e "${BRIGHT_WHITE}Usage: ${BRIGHT_CYAN}runwithfeedback${RESET} ${BRIGHT_GREEN}[description] [command]${RESET}"
    return 1
  fi

  # Local variables for special characters with color codes
  local hourglass="${BRIGHT_YELLOW}⌛${RESET}"   # Yellow Hourglass
  local checkmark="\r${BRIGHT_GREEN}✓${RESET}"  # Green Checkmark
  local cross="\r${BRIGHT_RED}X${RESET}"      # Red Error Cross

  # Display the hourglass and message
  echo -ne "${hourglass} ${1}"

  # Execute the command
  if eval "${2}"; then
    # If successful, display a green checkmark
    echo -e "${checkmark} ${1} "
  else
    # If failed, display a red cross
    echo -e "${cross} ${1} "
  fi
}


function ver() {
  if hascommand --strict uname; then
    # Get information about the system kernel, release, and machine hardware
    uname --kernel-name --kernel-release --machine
    echo
  fi
  if [[ -e /proc/version ]]; then
    # File that contains version information about the operating kernel
    cat /proc/version
    echo
  fi
  if hascommand --strict lsb_release; then
    # Provides LSB (Linux Standard Base) and distribution-specific information
    lsb_release -a
    echo
  fi
  if hascommand --strict hostnamectl; then
    # Control the Linux system hostname, also shows various system details
    hostnamectl
    echo
  else
    # Various files that contain text relating to the system identification
    cat /etc/*-release 2> /dev/null
  fi
}


function chmodcalc() {
  # Validate the number of arguments
  if [ "$#" -eq 1 ]; then
    # Validate the length of the argument
    if [ "${#1}" -ge 4 ]; then
      echo -e "${BRIGHT_RED}Error: ${BRIGHT_CYAN}Invalid octal.${RESET}"
      return 128
    fi

    local text="$1"
    local output=""
    local example=""
    local i=0

    while (( i++ < ${#text} )); do
      # Extract individual octal digit
      local char=$(expr substr "${text}" "${i}" 1)

      # Map octal digit to permissions
      case $char in
      0) part[${i}]="---" ;;
      1) part[${i}]="--x" ;;
      2) part[${i}]="-w-" ;;
      3) part[${i}]="-wx" ;;
      4) part[${i}]="r--" ;;
      5) part[${i}]="r-x" ;;
      6) part[${i}]="rw-" ;;
      7) part[${i}]="rwx" ;;
      *)
        echo -e "${BRIGHT_RED}Error: ${BRIGHT_CYAN}Invalid octal digit at position ${BRIGHT_YELLOW}${i}${RESET}"
        return 128
        ;;
      esac

      # Create example representation
      example[${i}]="${part[${i}]//-}"
    done

    # Display formatted output and examples
    echo -e "${BRIGHT_GREEN}${part[1]}${RESET} ${BRIGHT_YELLOW}${part[2]}${RESET} ${BRIGHT_RED}${part[3]}${RESET}"
    echo -e "Examples:"
    echo -e "${BRIGHT_CYAN}chmod${RESET} ${BRIGHT_CYAN}-R${RESET} ${BRIGHT_MAGENTA}${text}${RESET} ${BRIGHT_BLUE}./*${RESET}"
    echo -e "${BRIGHT_CYAN}chmod${RESET} ${BRIGHT_CYAN}-R${RESET} ${BRIGHT_CYAN}u=${BRIGHT_GREEN}${example[1]}${RESET}${BRIGHT_CYAN},g=${BRIGHT_YELLOW}${example[2]}${RESET}${BRIGHT_CYAN},o=${BRIGHT_RED}${example[3]}${RESET} ${BRIGHT_BLUE}./*${RESET}"

  elif [ "$#" -eq 3 ]; then
    local formatted=""
    for p in "$@"; do
      local n=0
      [[ $p =~ .*r.* ]] && (( n+=4 ))
      [[ $p =~ .*w.* ]] && (( n+=2 ))
      [[ $p =~ .*x.* ]] && (( n+=1 ))
      formatted="${formatted}${n}"
    done
    echo -e "${BRIGHT_CYAN}${formatted}${RESET}"
    chmodcalc "${formatted}"

  else
    echo -e "${BRIGHT_RED}Error: ${BRIGHT_CYAN}1 or 3 parameters required.${RESET}"
    echo -e "Syntax: ${BRIGHT_CYAN}chmodcalc${RESET} ${BRIGHT_GREEN}[owner]${RESET} ${BRIGHT_YELLOW}[group]${RESET} ${BRIGHT_RED}[other]${RESET}"
    echo -e "Example: ${BRIGHT_GREEN}chmodcalc${RESET} ${BRIGHT_GREEN}rwx${RESET} ${BRIGHT_YELLOW}rw${RESET} ${BRIGHT_RED}r${RESET}"
    echo -e "Syntax: ${BRIGHT_CYAN}chmodcalc [octal]${RESET}"
    echo -e "Example: ${BRIGHT_GREEN}chmodcalc 777${RESET}"
    echo -e "You can also use symbols instead of numeric values with chmod"
    echo -e "${BRIGHT_BLUE}chmod u=rwx,g=rw,o=r filename.ext${RESET}"
    echo -e "To calculate octals: ${BRIGHT_BLUE}read${RESET} is ${BRIGHT_CYAN}4${RESET}, ${BRIGHT_BLUE}write${RESET} is ${BRIGHT_CYAN}2${RESET}, and ${BRIGHT_BLUE}execute${RESET} is ${BRIGHT_CYAN}1${RESET}"
  fi
}


function fixw() {
   if [ -d $1 ]; then
  sudo find $1 -type d -exec chmod 755 {} \;
  sudo find $1 -type f -exec chmod 644 {} \;
   else
   echo "$1 is not a directory."
   fi
	}
function fixp () {
if [ -d $1 ]; then
sudo find $1 -type d -exec chmod 750 {} \;
sudo find $1 -type f -exec chmod 640 {} \;
else
echo "$1 is not a directory"
fi
}

function arabic2roman() {

  echo $1 | sed -e 's/1...$/M&/;s/2...$/MM&/;s/3...$/MMM&/;s/4...$/MMMM&/
	s/6..$/DC&/;s/7..$/DCC&/;s/8..$/DCCC&/;s/9..$/CM&/
	s/1..$/C&/;s/2..$/CC&/;s/3..$/CCC&/;s/4..$/CD&/;s/5..$/D&/
	s/6.$/LX&/;s/7.$/LXX&/;s/8.$/LXXX&/;s/9.$/XC&/
	s/1.$/X&/;s/2.$/XX&/;s/3.$/XXX&/;s/4.$/XL&/;s/5.$/L&/
	s/1$/I/;s/2$/II/;s/3$/III/;s/4$/IV/;s/5$/V/
	s/6$/VI/;s/7$/VII/;s/8$/VIII/;s/9$/IX/
	s/[0-9]//g'

	}
                  #------------------------------------------////
                  # Temperature action:
                  #------------------------------------------////

function cel2fah() {

  if [[ $1 ]]; then
  echo "scale=2; $1 * 1.8  + 32" | bc
  fi

}
function fah2cel() {

  if [[ $1 ]]; then
  echo "scale=2 ; ( $1 - 32  ) / 1.8" | bc
  fi

}

                  #------------------------------------------////
                  # Maths/Numbers:
                  #------------------------------------------////
                  # Maths/Numbers:
                  #------------------------------------------////

function sum() {
  local param sum=0
  case "${1}" in
    (-h|--help|--usage)
      {
        printf -- '%s\n' "Usage: sum x y [..z], or pipeline | sum"
        printf -- '\t%s\n' \
          "sum a sequence of integers, input by either positional parameters or STDIN"
      } >&2
      return 0
    ;;
  esac
  if [ $# -eq 0 ] && [ ! -t 0 ]; then
    while read -r -a fields; do
      for param in "${fields[@]}"; do
        case "${param}" in
          (*[!0-9]*) : ;;
          (*) sum=$(( sum + param )) ;;
        esac
      done
    done
    printf -- '%d\n' "${sum}"
    return 0
  fi
  for param in "${@}"; do
    case "${param}" in
      (*[!0-9]*) : ;;
      (*) sum=$(( sum + param )) ;;
    esac
  done
  printf -- '%d\n' "${sum}"
}

# baseconv — convert a number between positional bases 2-36.
#   Usage:  baseconv <number> [from] [to]
#   Defaults: from=10, to=16, so bare `baseconv 255` = decimal -> hex.
#   Drop-in for the old helpers:
#     dec2hex 255   -> baseconv 255
#     dec2bin 255   -> baseconv 255 10 2
#     dec2oct 255   -> baseconv 255 10 8
#     oct2dec 377   -> baseconv 377 8
#     oct2hex 377   -> baseconv 377 8 16
#     bin2hex 1010  -> baseconv 1010 2 16
#   Input accepts 0-9a-zA-Z, a leading '-' (negative), and a 0x/0X prefix
#   (which forces from=16). Output is uppercase digits.
#   Examples:
#     baseconv 255         -> FF
#     baseconv 255 10 2    -> 11111111
#     baseconv 377 8       -> 255
#     baseconv 0xA 16 2    -> 1010
#     baseconv -255 10 16  -> -FF
#     baseconv 2R 36 10    -> 99
#   ASCII / text encodings are NOT positional math: use printf for char codes
#     (printf '%b' "\\$(printf '%o' 65)"  -> A) and base64(1) for base64/32.
function baseconv() {
    local num from to sign dec result alphabet i v
    alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    num="${1:?usage: baseconv <number> [from] [to]}"
    from="${2:-10}"
    to="${3:-16}"
    [[ "$from" =~ ^([2-9]|[12][0-9]|3[0-6])$ ]] || { echo "baseconv: from must be 2-36" >&2; return 1; }
    [[ "$to"   =~ ^([2-9]|[12][0-9]|3[0-6])$ ]] || { echo "baseconv: to must be 2-36" >&2; return 1; }
    sign=""
    [[ "$num" == -* ]] && { sign=-; num="${num#-}"; }
    [[ "$num" =~ ^0[xX] ]] && { from=16; num="${num:2}"; }
    [[ -n "$num" ]] || { echo "baseconv: empty number" >&2; return 1; }
    [[ "$num" =~ ^[0-9A-Za-z]+$ ]] || { echo "baseconv: invalid character in '$num'" >&2; return 1; }
    for ((i=0; i<${#num}; i++)); do
        v=$((36#${num:$i:1}))
        (( v >= from )) && { echo "baseconv: digit '${num:$i:1}' invalid in base $from" >&2; return 1; }
    done
    dec=$(( $from#$num )) || return 1
    (( dec == 0 )) && result=0
    while (( dec > 0 )); do
        result="${alphabet:$((dec % to)):1}${result}"
        dec=$((dec / to))
    done
    printf '%s%s\n' "$sign" "${result:-0}"
}


###### powers of numerals
# copyright 2007 - 2010 Christopher Bratusek
function power() {
  if [[ $1 ]]; then
    if [[ $2 ]]; then
      echo "$1 ^ $2" | bc
    else  echo "$1 ^ 2" | bc
    fi
  fi
}

###### finding the square root of numbers
function sqrt()
{
echo "sqrt ("$1")" | bc -l
}


function sec2all()
{
    local millennia=$((0))
    local centuries=$((0))
    local years=$((0))
    local days=$((0))
    local hour=$((0))
    local mins=$((0))
    local secs=$1
    local text=""
    # convert seconds to days, hours, etc
    millennia=$((secs / 31536000000))
    secs=$((secs % 31536000000))
    centuries=$((secs / 3153600000))
    secs=$((secs % 3153600000))
    years=$((secs / 31536000))
    secs=$((secs % 31536000))
    days=$((secs / 86400))
    secs=$((secs % 86400))
    hour=$((secs / 3600))
    secs=$((secs % 3600))
    mins=$((secs / 60))
    secs=$((secs % 60))
    # build full string from unit strings
    text="$text$(seconds-convert-part $millennia "millennia")"
    text="$text$(seconds-convert-part $centuries "century")"
    text="$text$(seconds-convert-part $years "year")"
    text="$text$(seconds-convert-part $days "day")"
    text="$text$(seconds-convert-part $hour "hour")"
    text="$text$(seconds-convert-part $mins "minute")"
    text="$text$(seconds-convert-part $secs "second")"
    # trim leading and trailing whitespace
    text=${text## }
    text=${text%% }
    # special case for zero seconds
    if [ "$text" == "" ]; then
        text="0 seconds"
    fi
    # echo output for the caller
    echo ${text}
}
# formats a time unit into a string
# $1: integer count of units: 0, 6, etc
# $2: unit name: "hour", "minute", etc
function seconds-convert-part()
{
    local unit=$1
    local name=$2
    if [ $unit -ge 2 ]; then
        echo " ${unit} ${name}s"
    elif [ $unit -ge 1 ]; then
        echo " ${unit} ${name}"
    else
        echo ""
    fi
}


                  #------------------------------------------////
                  # More functional goodness:
                  #------------------------------------------////
	
  # lowercase all files in the current directory
function lcfiles() {
	read -p 'Really lowercase all files? (y/n) ' -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		for i in *; do
			[ -e "$i" ] && mv -- "$i" "${i,,}"
		done
	fi
	}
	
  # Capitalize the first character. With one arg, that char of the whole
  # string (spaces and shell metachars are safe — arg passes quoted); with
  # no arg, acts as a stdin filter uppercasing each line's first char.
  # UTF-8 aware: perl -CSDA decodes @ARGV and -CS decodes stdin.
function ucfirst() {
    if [[ $# -ge 1 ]]; then
        perl -CSDA -e 'print ucfirst($ARGV[0]), "\n"' "$1"
    else
        perl -CS -ne 'print ucfirst($_)'
    fi
}


function extract ()
  {
  if [ -f "$1" ] ; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"   ;;
      *.tar.gz)    tar xzf "$1"   ;;
      *.bz2)       bunzip2 "$1"   ;;
      *.rar)       unrar x "$1"   ;;
      *.gz)        gunzip "$1"    ;;
      *.tar)       tar xf "$1"    ;;
      *.tbz2)      tar xjf "$1"   ;;
      *.tgz)       tar xzf "$1"   ;;
      *.zip)       unzip "$1"     ;;
      *.Z)         uncompress "$1";;
      *.7z)        7z x "$1"      ;;
      *.deb)       ar x "$1"      ;;
      *.tar.xz)    tar xf "$1"    ;;
      *.tar.zst)   unzstd "$1"    ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
  }


whassup() {
  case "${1}" in
    (-h|--help)
      printf -- '%s\n' "whassup - list all users and their memory/cpu usage (think 'who' and 'what')" \
        "Usage: whassup [-c (sort by cpu usage) -m (sort by memory usage)]"
    ;;
    (-c)
      ps -eo pcpu,vsz,user | 
        tail -n +2 | 
        awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%%\n", user, vsz[user]/1024, cpu[user]); }' | 
        sort -k7 -rn
    ;;
    (-m)
      ps -eo pcpu,vsz,user | 
        tail -n +2 | 
        awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%%\n", user, vsz[user]/1024, cpu[user]); }' | 
        sort -k4 -rn
    ;;
    ('')
      ps -eo pcpu,vsz,user |
        tail -n +2 | 
        awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%%\n", user, vsz[user]/1024, cpu[user]); }'
    ;;
  esac
}


# List available aliases with optional filter parameter
function findalias() {
    # Assign the first argument to FILTER for filtering the output
    local FILTER="${1}"
    # Print the section heading for aliases
    echo -e "${BRIGHT_RED}Aliases:${RESET}"
    # List all aliases, format and color their output, then apply the filter
    alias | awk -F'[ =]' '{print "\033[33m"$2"\033[0m\t\033[34m"$0"\033[0m";}' | grep -E "${FILTER}"
}


function showfile() {
   width=80
   for input
   do
	lines="$(wc -l < $input | sed 's/ //g')"
	chars="$(wc -c < $input | sed 's/ //g')"
	owner="$(ls -ld $input | awk '{print $3}')"
	echo "-----------------------------------------------------------------"
	echo "File $input ($lines lines, $chars characters, owned by $owner):"
	echo "-----------------------------------------------------------------"
	while read line
		do
		if [ ${#line} -gt $width ] ; then
			echo "$line" | fmt | sed -e '1s/^/  /' -e '2,$s/^/+ /'
		else
			echo "  $line"
		fi
		done < $input
	echo "-----------------------------------------------------------------"
	done | more
	}

function facts () {
   wget randomfunfacts.com -O - 2>/dev/null | grep \<strong\> | sed -e "s;^.*<i>\(.*\)</i>.*$;\1;g"
	}


function cl() {
    DIR="$*";
	# if no DIR given, go home
	if [ $# -lt 1 ]; then 
		DIR=$HOME;
    fi;
    builtin cd "${DIR}" && \
    # use your preferred ls command
	ls -F --color=auto
}
