// browsah - Firefox privacy hardening
// Drop this file into a Firefox profile directory (e.g. ~/.config/mozilla/firefox/<profile>/user.js)
// Firefox applies it on every startup, so changes made in about:config are reverted on restart.
// To change a preference permanently, edit THIS file instead.
//
// NOTE: Firefox will write these values into prefs.js on first run. That's expected.

/**********************************************************************
 * 1. TELEMETRY / MOZILLA CHECK-INS
 *  Kill the phone-home channels. Nothing leaves the machine.
 **********************************************************************/
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.usage.uploadEnabled", false);

// No remote experiments / pref-flipping (Shield + Normandy).
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");

// No "recommended extensions" discovery feed.
user_pref("browser.discovery.enabled", false);

/**********************************************************************
 * 2. DNS - encrypted, strict, no ISP peeking
 *  NextDNS over HTTPS, DoH-only (no fallback to plain DNS). If the primary
 *  resolver is unreachable, Firefox still resolves via the fallback URI
 *  (also DoH), so one outage doesn't take down your whole connection.
 *  Change network.trr.uri to your own resolver if you use one.
 **********************************************************************/
user_pref("network.trr.mode", 3);                       // 3 = DoH only
user_pref("network.trr.uri", "https://firefox.dns.nextdns.io/");
user_pref("network.trr.fallback-uri", "https://dns.quad9.net/dns-query");
user_pref("network.trr.excluded-domains", "");          // no bypasses
user_pref("network.dns.disablePrefetch", true);

/**********************************************************************
 * 3. UNASKED-FOR CONNECTIONS
 *  No speculative/prefetch/preconnect traffic.
 **********************************************************************/
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("browser.urlbar.suggest.searches", false);

/**********************************************************************
 * 4. TRACKING & COOKIES
 **********************************************************************/
// Global Privacy Control: tell sites "don't sell/share my data".
user_pref("privacy.globalprivacycontrol.enabled", true);

// Tracking protection level. "standard" is a good default; "strict" blocks
// more (including some fingerprinters). Pick what breaks nothing.
user_pref("browser.contentblocking.category", "standard");

// Fingerprinting protection (on top of the ETP level above).
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);

// No clipboard read events for sites (pasting still works; reading is blocked).
user_pref("dom.event.clipboardevents.enabled", false);

// GPC + tracking protection exceptions stay off (no silent "allowed" list).
// user_pref("privacy.trackingprotection.allow_list", "");

// Clear what little we can on shutdown (matches the manual setting).
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown_v2.formdata", true);

/**********************************************************************
 * 5. NEW TAB - no sponsored content, no discovery stream
 **********************************************************************/
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);

/**********************************************************************
 * 6. SEARCH - no suggestions, no query echo
 **********************************************************************/
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.history", false);
user_pref("browser.urlbar.suggest.openpage", false);
user_pref("browser.urlbar.suggest.quickactions", false);
user_pref("browser.urlbar.suggest.recentsearches", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.suggest.trending", false);
user_pref("browser.urlbar.showSearchSuggestionsFirst", false);

// Open search results in a new tab instead of the same tab.
user_pref("browser.search.openintab", true);

/**********************************************************************
 * 7. PASSWORDS & FORMS - don't let the browser remember you
 *  (use KeePassXC-Browser instead)
 **********************************************************************/
user_pref("signon.rememberSignons", false);
user_pref("signon.generation.enabled", false);
user_pref("signon.management.page.breach-alerts.enabled", false);
user_pref("signon.firefoxRelay.feature", "disabled");
user_pref("browser.formfill.enable", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

/**********************************************************************
 * 8. HTTPS - always upgrade where possible
 **********************************************************************/
user_pref("dom.security.https_only_mode", true);

/**********************************************************************
 * 9. DOWNLOADS - ask where, forget in private
 **********************************************************************/
user_pref("browser.download.useDownloadDir", false);
user_pref("browser.download.deletePrivate", true);

/**********************************************************************
 * 10. SAFE BROWSING - ON
 *  Lookups are hash-prefix based over HTTPS (no full URLs are sent) and
 *  catch brand-new phishing/malware URLs that static blocklists can't.
 *  DNS filtering + uBlock still sit on top as a second layer.
 **********************************************************************/
user_pref("browser.safebrowsing.malware.enabled", true);
user_pref("browser.safebrowsing.phishing.enabled", true);

/**********************************************************************
 * 11. RAM CACHE - disk cache lives on a tmpfs, dies with the reboot
 **********************************************************************/
// Requires a RAM disk mounted at /mnt/ramdisk (see install.sh; it warns
// if the mount isn't actually tmpfs). Leaves no cache trace on the SSD.
user_pref("browser.cache.disk.parent_directory", "/mnt/ramdisk/firefox_cache");

/**********************************************************************
 * 12. LOOK & FEEL
 **********************************************************************/
// Vertical tabs (new tabstrip in the sidebar).
// FF135+ moved this behind the sidebar revamp; browser.tabs.vertical_tabs.enabled
// is dead on current builds.
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs", true);
// Auto-hide: tab bar collapses to a slim icon rail and expands on hover
// (or when the toolbar's sidebar button is clicked to pin it open).
user_pref("sidebar.visibility", "expand-on-hover");

// Ctrl+Tab cycles through tabs in recently-used order.
user_pref("browser.ctrlTab.recentlyUsedOrder", true);

// New-tab page: no Firefox logo/wordmark.
user_pref("browser.newtabpage.activity-stream.logowordmark.alwaysVisible", false);

// Bookmarks open in tabs; middle-click opens links in a background tab.
user_pref("browser.tabs.loadBookmarksInTabs", true);
user_pref("browser.tabs.loadBookmarksInBackground", true);
user_pref("browser.tabs.opentabfor.middleclick", true);

user_pref("browser.theme.content-theme", "dark");
user_pref("browser.theme.toolbar-theme", "dark");
user_pref("ui.systemUsesDarkTheme", 1);

// Don't nag when closing the window via Ctrl+Q.
user_pref("browser.warnOnQuitShortcut", false);

// Minimum readable font size; pages still get to choose their own fonts.
user_pref("browser.display.min_font_size", 10);
user_pref("browser.display.use_system_font", false);

/**********************************************************************
 * 13. SEARCH ENGINE - DuckDuckGo
 * Since Firefox 128 the default engine lives in search.json.mozlz4, not
 * in a pref. configure-firefox.sh patches that file (and its verification
 * hash) so the default becomes DuckDuckGo for normal and private windows.
 **********************************************************************/

/**********************************************************************
 * 14. AI / ML - ALL OFF
 * Chatbot, link previews, smart tab groups, PDF alt-text, visual search,
 * model downloads. Nothing local, nothing remote.
 **********************************************************************/
user_pref("browser.ml.enable", false);
user_pref("browser.ai.control.default", "blocked");
user_pref("browser.ml.modelHubRootUrl", "");
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.provider", "");
user_pref("browser.ml.chat.sidebar", false);
user_pref("browser.ml.chat.menu", false);
user_pref("browser.ml.chat.page", false);
user_pref("browser.ml.chat.shortcuts", false);
user_pref("browser.ml.chat.page.footerBadge", false);
user_pref("browser.ml.chat.page.menuBadge", false);
user_pref("browser.ai.control.sidebarChatbot", "blocked");
user_pref("extensions.ml.enabled", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("browser.ai.control.linkPreviewKeyPoints", "blocked");
user_pref("browser.ml.pageAssist.enabled", false);
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("browser.tabs.groups.smart.userEnabled", false);
user_pref("browser.ai.control.smartTabGroups", "blocked");
user_pref("browser.ai.control.translations", "blocked");
user_pref("browser.ai.control.pdfjsAltText", "blocked");
user_pref("pdfjs.enableAltText", false);
user_pref("pdfjs.enableAltTextModelDownload", false);
user_pref("pdfjs.enableGuessAltText", false);
user_pref("browser.search.visualSearch.featureGate", false);
user_pref("browser.urlbar.quicksuggest.mlEnabled", false);
user_pref("places.semanticHistory.featureGate", false);

// "Remote improvements" - automatic fixes/feature changes pushed between
// updates. That's Norman(y)-adjacent; off. (Still get regular monthly
// updates - just no live re-engineering of the browser.)
user_pref("nimbus.rollouts.enabled", false);

// Privacy is a lifestyle, not a setting.
// Do NOT sign into a Firefox Account / Sync while using this config.
