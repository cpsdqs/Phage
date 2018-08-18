# Phage
A very simple Safari app extension that injects userscripts into websites.

Compared to e.g. Greasemonkey <s>there are lots of features missing</s> it’s very lightweight.

<img src="https://i.imgur.com/Lb8urit.png" width="592" alt="Screenshot of Phage.app" />

### Short Guide
- Phage.app stores all scripts in `~/Library/GroupContainers/[group ID]/phage_data.json`.
- The option “As &lt;script&gt;” will inject the script into &lt;head&gt; instead of running it in the sandboxed extension context (which would prevent access through the dev console)
    + This option will break scripts on sites that prevent inline script execution using the Content-Security-Policy header
- Use the Resources panel (in the Window menu) to load `@require`d scripts
- Supported Greasemonkey tags:
    + `@name`
    + `@match` (globs only)
    + `@require` (absolute URLs only)
- Currently, scripts will be run whenever the extension script is injected (probably equivalent to GM’s document-start)
    + Inside iframes, it may be delayed to whenever document fires the load event

### Building
Requirements:

- [Rust and Cargo](https://rust-lang.org)
    - should be located in `~/.cargo/bin` (if not, modify `glob/build_xcode.sh`)
- Xcode 10

Then either press Run in Xcode or run `xcodebuild`.

Note that trying to get Safari to recognize the extension can be a bit irritating. If the extension randomly disappears from the list of extensions, try deleting it and building again.
If you have multiple Phage.app bundles in your file system, press “Uninstall” in the list of extensions (which will take you to the application bundle) and ensure it’s the correct one (or remove the bundle if it isn’t).
