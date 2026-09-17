import { VerificationCancelledError } from '../libs/requestErrors';

// This signature comes from Zotero's injected extension, not H2O.
const zoteroBackgroundError = /^Zotero Connector: Failed to send message i18n\.getStrings to background page\. It may be dead\.$/;

export function beforeSend(event, hint = {}) {
  if (hint.originalException instanceof VerificationCancelledError) return null;
  const exceptions = event.exception?.values || [];
  // Rendering crawlers routinely abort XHRs when they abandon a page. Keep
  // real-browser aborts and all other crawler errors visible.
  if (/\bYandex(?:Accessibility)?Bot\b/i.test(navigator.userAgent) &&
      exceptions.length === 1 && exceptions[0].type === 'AxiosError' &&
      exceptions[0].value === 'Request aborted') return null;
  if (exceptions.length === 1 && zoteroBackgroundError.test(exceptions[0].value || '')) {
    return null;
  }
  return event;
}
