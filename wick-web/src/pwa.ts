// SPDX-License-Identifier: MPL-2.0
//
//  pwa.ts: install the web game as an app on Android (3.5).
//
//  Chrome on Android offers "Install app" for a site with a manifest and a
//  service worker. It announces that with a `beforeinstallprompt` event; we
//  keep the event and show our own Install button in the home footer, in place
//  of the App Store link, which is no use on Android. iPhone players get the
//  real app from the App Store, so nothing changes there.
//
//  The button's visibility is a class on <html> ("can-install"), so this file
//  never has to know which screen is showing.
//

/** Chrome's install event. Not in the standard DOM types yet. */
interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
}

let deferred: BeforeInstallPromptEvent | null = null;

function setInstallable(on: boolean): void {
  document.documentElement.classList.toggle("can-install", on);
}

/** Registers the service worker and listens for Chrome's install offer.
 *  Call once at startup. Safe in every browser: missing features are skipped. */
export function initPwa(): void {
  if ("serviceWorker" in navigator && import.meta.env.PROD) {
    // updateViaCache "none": always fetch a fresh sw.js, so a fixed worker
    // reaches players on their next visit.
    navigator.serviceWorker
      .register("./sw.js", { updateViaCache: "none" })
      .catch((err: unknown) => console.warn("[wick] service worker failed:", err));
  }
  window.addEventListener("beforeinstallprompt", (e) => {
    e.preventDefault(); // we show our own button instead of Chrome's mini bar
    deferred = e as BeforeInstallPromptEvent;
    setInstallable(true);
  });
  window.addEventListener("appinstalled", () => {
    deferred = null;
    setInstallable(false);
  });
}

/** Opens Chrome's install dialog. The event can be used only once. */
export async function promptInstall(): Promise<void> {
  const e = deferred;
  if (!e) return;
  deferred = null;
  setInstallable(false);
  await e.prompt();
  const { outcome } = await e.userChoice;
  if (outcome === "dismissed") {
    // Chrome may offer again later; it fires a fresh event when it does.
  }
}
