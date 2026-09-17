// Cancellation leaves the request unsuccessful, so callers must retain edits.
export class VerificationCancelledError extends Error {
  constructor() {
    super('Browser verification cancelled.');
    this.name = 'VerificationCancelledError';
  }
}

export class VerificationFailedError extends Error {
  constructor() {
    super('Browser verification failed.');
    this.name = 'VerificationFailedError';
  }
}
