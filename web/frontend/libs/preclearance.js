import '../styles/preclearance.scss';
import { VerificationCancelledError, VerificationFailedError } from './requestErrors';

// Turnstile verifies the visitor inline; pre-clearance lets Cloudflare admit the retry.
let scriptPromise;
let verificationPromise;

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve(window.turnstile);
  if (!scriptPromise) {
    scriptPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      const timeout = setTimeout(() => finish(new Error('Verification could not load.')), 15000);
      function finish(error) {
        clearTimeout(timeout);
        script.onload = script.onerror = null;
        if (error) {
          script.remove();
          scriptPromise = null;
          reject(error);
        } else {
          resolve(window.turnstile);
        }
      }
      script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
      script.async = true;
      script.onload = () => finish();
      script.onerror = () => finish(new Error('Verification could not load.'));
      document.head.appendChild(script);
    });
  }
  return scriptPromise;
}

export function verifyBrowser() {
  // A page can load several resources at once; one check releases all waiting requests.
  if (verificationPromise) return verificationPromise;
  verificationPromise = new Promise((resolve, reject) => {
    const previousFocus = document.activeElement;
    const dialog = document.createElement('dialog');
    dialog.id = 'browser-verification';
    dialog.setAttribute('aria-labelledby', 'browser-verification-title');
    dialog.innerHTML = '<h2 id="browser-verification-title">Verify to continue</h2>' +
      '<p role="status">Complete the browser check to retry your request. Your page will stay open.</p>' +
      '<div class="verification-widget"></div><button type="button">Cancel</button>';
    const message = dialog.querySelector('p');
    let widget;
    let closed = false;
    let hasFailed = false;
    function finish(error) {
      if (closed) return;
      closed = true;
      if (widget !== undefined) window.turnstile.remove(widget);
      dialog.close();
      dialog.remove();
      previousFocus?.focus();
      if (error) reject(error);
      else resolve();
    }
    function failed() {
      if (closed) return;
      hasFailed = true;
      message.textContent = 'Verification failed. The request was not retried. Close this message to keep your page open and copy any unsaved text before reloading.';
      dialog.querySelector('button').textContent = 'Close';
    }
    const closeVerification = () => finish(hasFailed ? new VerificationFailedError() : new VerificationCancelledError());
    dialog.querySelector('button').onclick = closeVerification;
    dialog.addEventListener('cancel', event => {
      event.preventDefault();
      closeVerification();
    });
    // Do not treat clicks in verification as clicks outside an annotation editor.
    dialog.addEventListener('click', event => event.stopPropagation());
    document.body.appendChild(dialog);
    dialog.showModal();
    loadTurnstile().then(turnstile => {
      if (closed) return;
      widget = turnstile.render(dialog.querySelector('.verification-widget'), {
        sitekey: window.H2O_TURNSTILE_SITE_KEY,
        action: 'api_preclearance',
        retry: 'never',
        'refresh-expired': 'manual',
        'error-callback': () => { failed(); return true; },
        'expired-callback': failed,
        'timeout-callback': failed,
        callback: () => {
          if (closed || hasFailed) return;
          // Cloudflare issues and checks clearance. This callback only permits a retry;
          // it grants no Django permissions and does not validate a token for the app.
          finish();
        },
      });
    }, failed);
  }).finally(() => { verificationPromise = null; });
  return verificationPromise;
}

export function installPreclearance(client, verify = verifyBrowser) {
  client.interceptors.response.use(response => response, async error => {
    const config = error.config;
    if (!window.H2O_TURNSTILE_SITE_KEY || !config || error.response?.status !== 403 ||
        error.response.headers?.['cf-mitigated'] !== 'challenge' ||
        new URL(client.getUri(config), window.location.href).origin !== window.location.origin) {
      throw error;
    }
    if (config.preclearanceRetried) {
      window.alert('Your request is still blocked and was not completed. Copy any unsaved text before reloading.');
      throw error;
    }
    await verify();
    // Only an explicit edge challenge is safe to replay: Django did not receive it.
    return client.request({...config, preclearanceRetried: true});
  });
}
