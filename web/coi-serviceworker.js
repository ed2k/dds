/*! coi-serviceworker v0.1.7 - Guido Zouros - MIT License */
(() => {
    const isWindow = typeof window !== "undefined";

    const coi = {
        shouldRegister: () => true,
        shouldDeregister: () => false,
        doCoep: () => true,
        coepCredentialless: () => false,
        doCoop: () => true,
        quiet: false,
        ...(isWindow && window.coi ? window.coi : {})
    };

    const n = typeof navigator !== "undefined" ? navigator : null;

    // Check if we are running inside the ServiceWorker
    if (!isWindow) {
        self.addEventListener("install", () => self.skipWaiting());
        self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

        self.addEventListener("message", (event) => {
            if (event.data && event.data.type === "deregister") {
                self.registration.unregister().then(() => {
                    return self.clients.matchAll();
                }).then(clients => {
                    clients.forEach(client => client.navigate(client.url));
                });
            }
        });

        self.addEventListener("fetch", (event) => {
            const r = event.request;
            if (r.cache === "only-if-cached" && r.mode !== "same-origin") return;

            const request = (coi.coepCredentialless() && r.mode === "no-cors")
                ? new Request(r, { credentials: "omit" })
                : r;

            event.respondWith(
                fetch(request).then((response) => {
                    if (response.status === 0) return response;

                    const newHeaders = new Headers(response.headers);
                    if (coi.doCoop()) {
                        newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");
                    }
                    if (coi.doCoep()) {
                        newHeaders.set("Cross-Origin-Embedder-Policy", "require-corp");
                    }

                    return new Response(response.body, {
                        status: response.status,
                        statusText: response.statusText,
                        headers: newHeaders,
                    });
                }).catch((e) => console.error(e))
            );
        });
    } else {
        // Page thread execution: Register the ServiceWorker
        if (n && n.serviceWorker && coi.shouldDeregister() && n.serviceWorker.controller) {
            n.serviceWorker.controller.postMessage({ type: "deregister" });
        }

        if (!window.crossOriginIsolated && coi.shouldRegister()) {
            if (n && n.serviceWorker) {
                n.serviceWorker.register(window.document.currentScript.src).then(
                    (registration) => {
                        !coi.quiet && console.log("COOP/COEP Service Worker registered:", registration.scope);
                        registration.addEventListener("updatefound", () => {
                            !coi.quiet && console.log("Reloading page to enable Cross-Origin Isolation...");
                            window.location.reload();
                        });
                        if (registration.active && !n.serviceWorker.controller) {
                            !coi.quiet && console.log("Reloading page under Service Worker control...");
                            window.location.reload();
                        }
                    },
                    (err) => {
                        !coi.quiet && console.error("COOP/COEP Service Worker registration failed:", err);
                    }
                );
            }
        }
    }
})();
