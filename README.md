# Phage
A very simple Safari app extension that injects userscripts into websites.

This app is currently not made for release; expect _**lots of issues**_.

![Screenshot of Phage.app](https://i.imgur.com/Lb8urit.png)

### What it does (in detail)
Phage.app reads and writes to `~/Library/GroupContainers/[group ID]/phage_data.json`.

PhageExtension (“Phage Injector”) injects a script, waits for the script to send `scriptsForURL` and then reads from `phage_data.json`, looks for matches, and sends back matching userscripts. The script then attempts to inject the script into the site. Since the injected script is in a sandbox—unless “Inject as &lt;script&gt;” is enabled—the userscript will also be sandboxed, but will work on sites with a Content-Security-Policy header that disallows running inline scripts.

### Building
Requirements:

- [Rust and Cargo](https://rust-lang.org)
    - should be located in `~/.cargo/bin` (if not, modify `glob/build_xcode.sh`)
- Xcode 10

Then either press Run in Xcode or run `xcodebuild`.

Note that trying to get Safari to recognize the extension can be a bit irritating. If the extension randomly disappears from the list of extensions, try deleting it and building again.
