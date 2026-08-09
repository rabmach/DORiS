#!/bin/sh

echo "$(HOUR=$(date +%H); echo "$( [ "$HOUR" -lt 12 ] && echo "Good morning" || { [ "$HOUR" -lt 17 ] && echo "Good afternoon" || { [ "$HOUR" -lt 21 ] && echo "Good evening" || echo "Good night"; }; }) $(getent passwd "${USER}" | cut -d ":" -f 5 | cut -d "," -f 1 || echo "${USER}")! It is $(date +"%-I. %M. %p" | sed "s/AM/A. M./; s/PM/P. M./"). $(grep -q "^To " /var/mail/${USER} 2>/dev/null && echo "You have new messages." || echo "")")" | espeak -v mb-en1 -s170
