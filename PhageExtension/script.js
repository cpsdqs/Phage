{
    const inject = function inject () {
        if (!window.document) return;

        // prevent crosstalk
        const injectorID = Math.random().toString(36)

        safari.extension.dispatchMessage('scriptsForURL', { url: window.location.href, id: injectorID });
        safari.self.addEventListener('message', event => {
            if (event.message.id !== injectorID) return
            if (event.name === 'scriptsForURL') {
                if (event.message.error) return
                for (let script of event.message.scripts) {
                    if (script.injectAsScriptTag) {
                        let tag = document.createElement('script')
                        tag.id = `phage-${script.uuid}`
                        tag.innerHTML = `(function injectedScript() {
try {
${script.script}
} catch(err) {
    console.error(\`[Phage] Script error for ${script.name}\`, err)
}
})();`
                        document.head.appendChild(tag)
                    } else {
                        let fn = new Function(`
try {
${script.script}
} catch(err) {
    console.error(\`[Phage] Script error for ${script.name}\`, err)
}`)
                        fn.apply(window, [])
                    }
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
