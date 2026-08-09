#!/usr/bin/env python3
"""browsah - put the search bar at the right of the toolbar, after a flexible space.

Patches browser.uiCustomization.state in <profile>/prefs.js so the nav-bar
placements end with a flexible space ("customizableui-special-spring<N>")
followed by the search bar ("search-container"). Also refreshes
browser.search.widget.lastUsed so Firefox does not auto-remove the search bar
for being "unused".

  - state present: reposition the search bar to the right end (idempotent,
    never duplicates, preserves version/counters).
  - no state yet: inject a fresh state with the current default nav-bar layout
    plus the trailing flexible space + search bar. All other toolbars fall
    back to Firefox's defaults (CustomizableUI.restoreStateForArea).

usage: ui.py <profile-directory>
"""

import json
import os
import re
import sys
from datetime import datetime, timezone

STATE_PREF = "browser.uiCustomization.state"
LASTUSED_PREF = "browser.search.widget.lastUsed"
SPRING_PREFIX = "customizableui-special-spring"
K_CURRENT_VERSION = 24  # kVersion of the Firefox whose defaults we mirror

# Default nav-bar for a Firefox 153 profile with the sidebar revamp on
# (matches the in-tree defaultPlacements, plus our trailing spring+search bar).
DEFAULT_NAVBAR = [
    "sidebar-button",
    "back-button",
    "forward-button",
    "stop-reload-button",
    "home-button",
    "customizableui-special-spring1",
    "vertical-spacer",
    "urlbar-container",
    "customizableui-special-spring2",
    "downloads-button",
    "fxa-toolbar-menu-button",
    "customizableui-special-spring3",
    "search-container",
]

PREF_LINE = re.compile(r'^user_pref\("([^"]+)", (.*)\);', re.MULTILINE)


def read_prefs(profile_dir):
    path = os.path.join(profile_dir, "prefs.js")
    if not os.path.isfile(path):
        print(f"!! no prefs.js in {profile_dir} - run Firefox once first")
        sys.exit(1)
    return path


def find_value(text, name):
    for m in PREF_LINE.finditer(text):
        if m.group(1) == name:
            return m.group(0), m.group(2)
    return None, None


def strip_lines(text, name):
    return (
        "\n".join(
            ln for ln in text.splitlines() if not PREF_LINE.match(ln) or PREF_LINE.match(ln).group(1) != name
        )
        + "\n"
    )


def js_string_to_python(literal):
    return json.loads(literal)


def python_to_js_string(value):
    return json.dumps(value)


def max_spring_number(nav, placements):
    biggest = 0
    for widgets in [nav] + list(placements.values()):
        for widget in widgets:
            if widget.startswith(SPRING_PREFIX):
                try:
                    biggest = max(biggest, int(widget[len(SPRING_PREFIX):]))
                except ValueError:
                    pass
    return biggest


def patch_navbar(state):
    placements = state.setdefault("placements", {})
    if not isinstance(placements, dict):
        placements = {}
        state["placements"] = placements
    nav = placements.get("nav-bar")
    if not isinstance(nav, list):
        nav = list(DEFAULT_NAVBAR)[:-2]  # stock layout, no search bar yet
    else:
        nav = list(nav)

    # Already correct: <flexible space> search-container at the right end.
    if (
        len(nav) >= 2
        and nav[-1] == "search-container"
        and nav[-2].startswith(SPRING_PREFIX)
    ):
        placements["nav-bar"] = nav
        return nav

    # Drop any existing search bar (and the flexible space directly before it)
    # so we can reposition it cleanly at the right end.
    cleaned = []
    for widget in nav:
        if widget == "search-container":
            if cleaned and cleaned[-1].startswith(SPRING_PREFIX):
                cleaned.pop()
            continue
        cleaned.append(widget)
    nav = cleaned

    if nav and nav[-1].startswith(SPRING_PREFIX):
        nav.append("search-container")
    else:
        new_n = max_spring_number(nav, placements) + 1
        nav.append(f"{SPRING_PREFIX}{new_n}")
        nav.append("search-container")

    placements["nav-bar"] = nav
    state["newElementCount"] = max_spring_number(nav, placements) + 1
    return nav


def main():
    if len(sys.argv) != 2:
        print("usage: ui.py <profile-directory>")
        sys.exit(2)
    prefs_path = read_prefs(sys.argv[1])

    with open(prefs_path, encoding="utf-8") as fh:
        text = fh.read()

    line, literal = find_value(text, STATE_PREF)
    if line is not None:
        state = json.loads(js_string_to_python(literal))
        mode = "existing state"
    else:
        state = {
            "placements": {},
            "seen": [],
            "dirtyAreaCache": [],
            "currentVersion": K_CURRENT_VERSION,
            "newElementCount": 3,
        }
        mode = "fresh state"
    nav = patch_navbar(state)
    text = strip_lines(text, STATE_PREF)
    text = text.rstrip("\n") + "\n"
    text += f'user_pref("{STATE_PREF}", {python_to_js_string(json.dumps(state, separators=(",", ":")))});\n'

    # Mark the search bar as used so SearchWidgetTracker won't remove it.
    text = strip_lines(text, LASTUSED_PREF)
    now = datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    text += f'user_pref("{LASTUSED_PREF}", {python_to_js_string(now)});\n'

    with open(prefs_path, "w", encoding="utf-8") as fh:
        fh.write(text)

    tail = " + ".join(nav[-2:])
    print(f"  ✓ search bar on the right, after a flexible space ({mode})")
    print(f"    nav-bar ends with: {tail}")


if __name__ == "__main__":
    main()
