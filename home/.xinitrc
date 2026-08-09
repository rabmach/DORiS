#!/bin/sh
# Session-level, WM/DE-agnostic startup.  Run by startx -> xinit.
# Openbox-specific startup lives in ~/.config/openbox/autostart.

# --- Advertise the graphical environment to the systemd user manager so
#     desktop services (nm-applet, PolicyKit agent, hplip systray,
#     solaar, keepassxc, pulseaudio, ...) see $DISPLAY and start up.
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=openbox

systemctl --user import-environment DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE 2>/dev/null
dbus-update-activation-environment --all 2>/dev/null

# --- Reach 'graphical-session' and launch the XDG autostart services.
#     graphical-session.target refuses manual starts, so we pull it in
#     (together with xdg-desktop-autostart.target) through our own
#     openbox-session.target instead.  It is stopped again on X exit so
#     a later startx within the same login runs the services fresh.
systemctl --user start openbox-session.target 2>/dev/null

# --- WM/DE-agnostic daemons.
#     xfce4-clipman and redshift-gtk stay here: their autostart entries
#     are OnlyShowIn=XFCE / disabled, so the XDG generator skips them.
xscreensaver -no-splash &
unclutter &
numlockx &
lxpanel &
xfce4-clipman &
redshift-gtk &

# --- The window manager.  Run in the foreground so this script (the X
#     session leader) stays alive until Openbox exits.
openbox-session

# --- Tear down the graphical session targets (services stop, ready for
#     the next startx).
systemctl --user stop openbox-session.target 2>/dev/null
