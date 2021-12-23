// Phage Injector content script in page context

{
    const EVT_NAME_IN = '__PHAGE_INJECTOR__EXT'
    const EVT_NAME_OUT = '__PHAGE_INJECTOR__PAGE'

    globalThis.addEventListener(EVT_NAME_IN, event => {
        if (!event.detail || typeof event.detail !== 'object') return
        if (event.detail.type === 'evalPageScript') {
            const fn = new Function(event.detail.source);
            fn.apply(window, [])
        }
    })

    globalThis.dispatchEvent(new globalThis.CustomEvent(EVT_NAME_OUT, {
        detail: {
            type: 'initPageInjector'
        }
    }))
}
