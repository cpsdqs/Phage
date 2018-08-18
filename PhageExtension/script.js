{
    const wrapScript = function wrapScript (name, prelude, script) {
        name = name.replace(/\\/g, '\\\\').replace(/`/g, '\\`')
        return `/* Phage injected script */
try {
${prelude}
} catch (err) {
    console.error(\`[Phage] Script error for ${name} (in required code)\`, err)
}
(function injectedScript() {
try {
${script}
} catch (err) {
    console.error(\`[Phage] Script error for ${name}\`, err)
}
})();`
    }

    const inject = function inject () {
        if (!window.document) return

        // prevent crosstalk
        const injectorID = Math.random().toString(36)

        safari.extension.dispatchMessage('scriptsForURL', {
            url: window.location.href,
            id: injectorID,
            topLevel: window.top === window
        })

        let runningScriptNames = []

        safari.self.addEventListener('message', event => {
            if (event.name === 'scriptsForURL') {
                if (event.message.id !== injectorID) return
                if (event.message.error) return
                for (let script of event.message.scripts) {
                    runningScriptNames.push(script.name)
                    if (script.injectAsScriptTag) {
                        let tag = document.createElement('script')
                        tag.id = `phage-${script.uuid}`
                        tag.innerHTML = wrapScript(script.name, script.prelude, script.script)
                        document.head.appendChild(tag)
                    } else {
                        let fn = new Function(wrapScript(script.name, script.prelude, script.script))
                        fn.apply(window, [])
                    }
                }
            } else if (event.name === 'runningScripts') {
                // only send top-level scripts for now
                if (window.top === window) {
                    safari.extension.dispatchMessage('runningScripts', {
                        request: event.message.request,
                        scripts: runningScriptNames
                    })
                }
            }
        });
    };

    if (location.protocol === 'about:') {
        // probably an unloaded iframe
        document.addEventListener('load', inject)
    } else {
        inject()
    }
}
