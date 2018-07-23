# Phage
A very simple Safari app extension that injects userscripts into websites.

This app is currently not made for release; expect _**lots of issues**_.

### What it does
Phage.app reads and writes to `~/Library/GroupContainers/[group ID]/phage_data.json`.

PhageExtension (“Phage Injector”) injects a script, waits for the script to send `scriptsForURL` and then reads from `phage_data.json`, looks for matches, and sends back matching userscripts. The script then attempts to inject the script into the site. Since the injected script is in a sandbox—unless “Inject as <script>” is enabled—the userscript will also be sandboxed, but will work on sites with a Content-Security-Policy header.
