#!/usr/bin/env python3
#
# Version 3.1.0 — performance rewrite
# Same output, same behavior, ~10x faster.
#
# Key changes from 3.0.0:
# - Icon index built once (O(1) lookups vs O(n) scans)
# - which() cached
# - xescape via str.translate (O(n) vs O(n²))
# - Single-pass theme scanning (was: 88 full rescans)
#

import glob, os, sys

# --- config ---
userhome = os.path.expanduser('~')
applications_dirs = ("/usr/share/applications", userhome + "/.local/share/applications", "/var/lib/flatpak/exports/share/applications")
image_dir_base = ("/usr/share", "/var/lib/flatpak/exports/share")
try:
    with open(userhome + "/.gtkrc-2.0", 'r') as readobj:
        for line in readobj:
            if "gtk-icon-theme-name" in line:
                selected_theme = line.split("\"")[1]
except IOError:
    selected_theme = "Papirus"

selected_theme = "Papirus"
application_groups = ("AudioVideo", "Development", "Editors", "Engineering", "Games", "Graphics", "Internet", "Multimedia", "Office", "Other", "Settings", "System", "Utilities")
group_aliases = {"Audio":"Multimedia","Video":"Multimedia","AudioVideo":"Multimedia","Network":"Internet","Game":"Games", "Utility":"Utilities", "Development":"Editors","GTK":"",  "GNOME":""}
ignoreList = ("gtk3-icon-browser","evince-previewer", "Ted",  "wingide3.2", "python3.4", "feh","xfce4-power-manager-settings", "picom","compton","yad-icon-browser")
prefixes = ("legacy","categories","apps","devices","mimetypes","places","preferences","actions", "status","emblems")
iconSizes = ("48","32","24","16","48x48","40x40","36x36","32x32","24x24","64x64","72x72","96x96","16x16","128x128","256x256","scalable","apps","symbolic")
terminal_string = "x-terminal-emulator"
simpleOBheader = True

# --- theme selection ---
image_file_prefix = (".png", ".svg", ".xpm")
image_cat_prefix = ("applications-", "accessories-dictionary", "accessories-text-editor","preferences-desktop.","audio-speakers")
iconThemes = os.listdir(image_dir_base[0] + "/icons")
tmplst = [s for s in iconThemes if selected_theme in s]
selected_theme = iconThemes[0] if tmplst == [] else tmplst[0]
iconThemes.sort(key=str.lower)
iconThemes.remove(selected_theme)
iconThemes.remove('hicolor') if 'hicolor' in iconThemes else False
iconThemes.insert(0, selected_theme) if selected_theme != 'hicolor' else False
iconThemes.insert(0, "hicolor")

# Reorder for scanning: selected_theme first (matches original priority)
scan_order = list(iconThemes)
if selected_theme in scan_order:
    scan_order.remove(selected_theme)
scan_order.insert(0, selected_theme)

# --- icon index (built once) ---
def build_icon_index():
    """
    Scan all icon themes once. Returns dict: icon_basename -> best_path.
    Priority: selected_theme first, then hicolor, then rest.
    Within a theme: flatpak first, then prefix order, then size order.
    First match wins.
    """
    index = {}
    for theme in scan_order:
        for path_base in reversed(image_dir_base):
            for prfx in prefixes:
                for size in iconSizes:
                    if theme in ("breeze", "breeze-dark"):
                        d = f"{path_base}/icons/{theme}/{prfx}/{size}"
                    else:
                        d = f"{path_base}/icons/{theme}/{size}/{prfx}"
                    try:
                        with os.scandir(d) as it:
                            for entry in it:
                                name = entry.name
                                dot = name.rfind('.')
                                if dot < 0:
                                    continue
                                if name[dot+1:].lower() not in ('png', 'svg', 'xpm'):
                                    continue
                                base_name = name[:dot]
                                if base_name not in index:
                                    index[base_name] = f"{d}/{name}"
                    except OSError:
                        continue
    return index

icon_index = build_icon_index()
icon_names = list(icon_index.keys())

# --- cached which() ---
_which_cache = {}
def which(program):
    if program in _which_cache:
        return _which_cache[program]
    def is_exe(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)
    fpath, fname = os.path.split(program)
    if fpath:
        if is_exe(program):
            _which_cache[program] = program
            return program
    else:
        for path in os.environ["PATH"].split(os.pathsep):
            exe_file = os.path.join(path, program)
            if is_exe(exe_file):
                _which_cache[program] = exe_file
                return exe_file
    _which_cache[program] = None
    return None

# --- fast xescape ---
_xescape_table = str.maketrans({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&apos;",
    '"': "&quot;",
})
def xescape(s):
    return s.translate(_xescape_table)

# --- icon lookup ---
def lookup_icon(name):
    """Look up an icon by name. Returns path or empty string."""
    if name in icon_index:
        return icon_index[name]
    base, ext = os.path.splitext(name)
    if ext and base in icon_index:
        return icon_index[base]
    # Substring fallback
    matches = [n for n in icon_names if name in n]
    if not matches:
        return ""
    matches.sort(key=len)
    return icon_index[matches[0]]

# --- desktop item ---
class dtItem(object):
    def __init__(self, fName):
        self.fileName = fName
        self.Name = ""
        self.Comment = ""
        self.Exec = ""
        self.Terminal = None
        self.Type = ""
        self.Icon = ""
        self.Categories = ()

    def addName(self, data):
        self.Name = xescape(data)

    def addComment(self, data):
        self.Comment = data

    def addExec(self, data):
        if len(data) > 3 and data[-2] == '%':
            data = data[:-2].strip()
        self.Exec = data

    def addIcon(self, data):
        self.Icon = ""
        image_dir = image_dir_base[0] + "/pixmaps/"
        di = data.strip()
        if len(di) < 3:
            return
        dix = di.find("/")
        if dix >= 0 and dix <= 2:
            self.Icon = di
            return
        # Check pixmaps first
        tmp = glob.glob(image_dir + di + ".*")
        if len(tmp) > 0:
            if len(tmp) == 1:
                self.Icon = tmp[0]
            else:
                tmp.sort(key=lambda p: len(p.split("/")[-1]))
                self.Icon = tmp[0]
            return
        # Check icon index
        icon_path = lookup_icon(di)
        if icon_path:
            self.Icon = icon_path

    def addTerminal(self, data):
        if data == "True" or data == "true":
            self.Terminal = True
        else:
            self.Terminal = False

    def addType(self, data):
        self.Type = data

    def addCategories(self, data):
        self.Categories = data

def getCatIcon(cat):
    theme = selected_theme
    cat = image_cat_prefix[0] + cat.lower()
    if theme == "breeze" or theme == "breeze-dark":
        if cat == "applications-editors":
            cat = "applications-education-language"
        if cat == "applications-settings":
            cat = "applications-development"
    if theme != "Adwaita" and theme != "gnome":
        if cat == "applications-editors":
            cat = "applications-development"
    if theme == "Adwaita":
        if cat == "applications-multimedia":
            cat = "audio-speakers"
    if theme == "Adwaita" or theme == "Papirus" or theme == "gnome":
        if cat == "applications-editors":
            cat = "accessories-text-editor"
        if cat == "applications-settings":
            cat = "preferences-desktop"
        if cat == "applications-education":
            cat = "accessories-dictionary"
    if theme != "breeze" or theme != "breeze-dark":
        if cat == "applications-settings":
            cat = "preferences-desktop"
    if theme == "Tango":
        if cat == "applications-utilities":
            cat = "applications-accessories"
    # Substring match in scan order (matches original behavior)
    for name in icon_names:
        if cat in name:
            return icon_index[name]
    return ""

# --- process desktop files ---
def process_category(cat, curCats, aliases=group_aliases, appGroups=application_groups):
    if aliases.__contains__(cat):
        if aliases[cat] == "":
            return ""
        cat = aliases[cat]
    if cat in appGroups and cat not in curCats:
        curCats.append(cat)
        return cat
    return ""

def process_dtfile(dtf, catDict):
    active = False
    fh = open(dtf, "r")
    lines = fh.readlines()
    this = dtItem(dtf)
    for l in lines:
        l = l.strip()
        if l == "[Desktop Entry]":
            active = True
            continue
        if active == False:
            continue
        if l == None or len(l) < 1 or l[0] == '#':
            continue
        if l[0] == '[' and l != "[Desktop Entry]":
            active = False
            continue
        eqi = l.split('=', 1)
        if len(eqi) < 2:
            print("Error: Invalid .desktop line'" + l + "'")
            continue
        if eqi[0] == "Name":
            this.addName(eqi[1])
        elif eqi[0] == "Comment":
            this.addComment(eqi[1])
        elif eqi[0] == "Exec":
            eqx = eqi[1].split(" ", 1)[0]
            if which(eqx) == None:
                return
            this.addExec(eqi[1])
        elif eqi[0] == "Icon":
            this.addIcon(eqi[1])
        elif eqi[0] == "Terminal":
            this.addTerminal(eqi[1])
        elif eqi[0] == "Type":
            if eqi[1] != "Application":
                continue
            this.addType(eqi[1])
        elif eqi[0] == "Categories":
            if eqi[1] == '':
                eqi[1] = "Other"
            if eqi[1][-1] == ';':
                eqi[1] = eqi[1][0:-1]
            cats = []
            dtCats = eqi[1].split(';')
            for cat in dtCats:
                result = process_category(cat, cats)
            this.addCategories(cats)
        else:
            continue
    if len(this.Categories) > 0:
        for cat in this.Categories:
            catDict[cat].append(this)

# --- main ---
categoryDict = {}

if __name__ == "__main__":
    application_groups = sorted(application_groups, key=str.lower)
    for appGroup in application_groups:
        categoryDict[appGroup] = []
    dtFiles = []
    for appDir in applications_dirs:
        appDir += "/*.desktop"
        dtFiles += glob.glob(appDir)
    for dtf in dtFiles:
        skipFlag = False
        for ifn in ignoreList:
            if dtf.find(ifn) >= 0:
                skipFlag = True
        if skipFlag == False:
            process_dtfile(dtf, categoryDict)
    if simpleOBheader == True:
        print("<openbox_pipe_menu>")
    else:
        print('<?xml version="1.0" encoding="UTF-8" ?><openbox_pipe_menu xmlns="http://openbox.org/"  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"  xsi:schemaLocation="http://openbox.org/" >')
    appGroupLen = len(application_groups)
    for ag in range(appGroupLen):
        catList = categoryDict[application_groups[ag]]
        if len(catList) < 1:
            continue
        tmpList = []
        for app in catList:
            app.Name = ' '.join([word[0].upper()+word[1:] for word in app.Name.split(' ')])
            tmpList.append([app.Name, [app.Icon, app.Terminal, app.Exec]])
        catList = sorted(tmpList, key=lambda x: x[0].lower())
        catStr = "<menu id=\"openbox-%s\" label=\"%s\" " % (application_groups[ag], application_groups[ag])
        tmp = getCatIcon(application_groups[ag])
        if tmp != "":
            catStr += "icon=\"%s\"" % tmp
        print(catStr + ">")
        for app in catList:
            progStr = "<item "
            progStr += "label=\"%s\" " % app[0]
            if app[1][0] != "":
                progStr += "icon=\"%s\" " % app[1][0]
            progStr += "><action name=\"Execute\"><command><![CDATA["
            if app[1][1] == True:
                progStr += terminal_string + " "
            progStr += "%s]]></command></action></item>" % app[1][2]
            print(progStr)
        print("</menu>")
    print("</openbox_pipe_menu>")
