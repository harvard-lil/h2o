// This signature comes from Zotero's injected extension, not H2O.
const zoteroBackgroundError = /^Zotero Connector: Failed to send message i18n\.getStrings to background page\. It may be dead\.$/;

export function beforeSend(event) {
  const exceptions = event.exception?.values || [];
  if (exceptions.length === 1 && zoteroBackgroundError.test(exceptions[0].value || '')) {
    return null;
  }
  return event;
}
