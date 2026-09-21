export function safeURL(value) {
  try {
    const url = new URL(value, window.location.href);
    return ['http:', 'https:', 'ftp:', 'ftps:', 'mailto:'].includes(url.protocol) ? value : undefined;
  } catch (error) {
    if (!(error instanceof TypeError)) throw error;
    return undefined;
  }
}
