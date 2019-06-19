const injectorSessionID = Math.random().toString(36)
// contents of this string must not contain single quotes or backslashes (see wrapScript):
const phageConsoleStyle = 'color:white;background:black;padding:2px;border-radius:4px'

// TODO: handle push/popstate?

let injectionTries = 0

;(function inject () {
    injectionTries++
    if (!window.document) {
        // try again later
        setTimeout(inject, 100 * 2 ** injectionTries)
        return
    }

    if (document.readyState !== 'complete' && location.protocol === 'about:') {
        // iframes that haven’t loaded yet will *navigate* from about:blank
        // to the target page so injection needs to be deferred to load time
        document.addEventListener('load', inject)
        return
    }

    safari.extension.dispatchMessage('initInjector', {
        url: window.location.href,
        sessionID: injectorSessionID,
        isTopLevel: window.top === window
    })

    let forceUpdateInterval = null

    function requestUpdate () {
        safari.extension.dispatchMessage('updateRequest', {
            url: window.location.href,
            sessionID: injectorSessionID,
        })
    }

    safari.self.addEventListener('message', event => {
        if (event.name === 'initInjector') {
            if (event.message.sessionID !== injectorSessionID) return

            for (const bundle of event.message.bundles) {
                injectScripts(bundle.id, bundle.scripts)
                injectStyles(bundle.id, bundle.styles)
            }
        } else if (event.name === 'forceUpdate') {
            if (event.message.action === 'single') {
                requestUpdate()
            } else if (event.message.action === 'begin' && forceUpdateInterval === null) {
                forceUpdateInterval = setInterval(requestUpdate, 1000)
            } else if (event.message.action === 'end' && forceUpdateInterval !== null) {
                clearInterval(forceUpdateInterval)
            }
        } else if (event.name === 'updateStyles') {
            if (event.message.sessionID !== injectorSessionID) return

            if (event.message.replace) {
                removeAllStyles()
            } else for (const bundleID of event.message.removed) {
                removeStyles(bundleID);
            }
            for (const bundle of event.message.updated) {
                injectStyles(bundle.id, bundle.styles);
            }
        }
    })
})()

function injectScripts (bundle, scripts) {
    let i = 0
    for (const script of scripts) {
        if (script.asScriptTag) {
            const node = document.createElement('script')
            node.textContent = wrapScript(script.name, script.prelude, script.contents)
            node.id = `phagejs-${bundle}-${i}`

            if (document.head) document.head.appendChild(node)
            else document.addEventListener('load', () => document.head.appendChild(node))
        } else {
            const fn = new Function(wrapScript(script.name, script.prelude, script.contents))
            fn.apply(window, [])
        }
        i++
    }
}

function wrapScript (name, prelude, contents) {
    name = name.replace(/\\/g, '\\\\').replace(/`/g, '\\`')
    return `/* Phage injected script */
try {
${prelude}
} catch (err) {
    console.error(
        \`%cPhage%c Script error for %c${name}%c in required code\`,
        '${phageConsoleStyle}',
        '',
        'font-weight:bold',
        '',
        err
    )
}
try {
${contents}
} catch (err) {
    console.error(
        \`%cPhage%c Script error for %c${name}%c\`,
        '${phageConsoleStyle}',
        '',
        'font-weight:bold',
        '',
        err
    )
}
    `
}

const injectedStyles = {}

function injectStyles (bundle, styles) {
    // remove existing styles first
    removeStyles(bundle)

    const nodes = []
    let i = 0
    for (const style of styles) {
        const node = document.createElement('style')
        node.textContent = style.contents
        node.id = `phagecss-${bundle}-${i++}`
        nodes.push(node)
    }

    injectedStyles[bundle] = nodes

    if (document.head) {
        // just append to document head
        for (const node of nodes) document.head.appendChild(node)
    } else {
        document.addEventListener('load', () => {
            // inject if still valid
            if (injectedStyles[bundle] === nodes) {
                for (const node of nodes) document.head.appendChild(node)
            }
        })
    }
}

function removeStyles (bundle) {
    if (injectedStyles[bundle]) {
        for (const node of injectedStyles[bundle]) {
            if (node.parentNode) node.parentNode.removeChild(node)
        }
    }
    delete injectedStyles[bundle]
}

function removeAllStyles () {
    for (const bundle in injectedStyles) removeStyles(bundle)
}
