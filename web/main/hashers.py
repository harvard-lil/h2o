import hashlib

from django.contrib.auth.hashers import PBKDF2PasswordHasher


class PBKDF2WrappedRailsPasswordHasher(PBKDF2PasswordHasher):
    """
        Legacy password hasher -- see https://docs.djangoproject.com/en/2.2/topics/auth/passwords/#password-upgrading-without-requiring-a-login

        Rails-era passwords are stored as a salted password hashed 20 times with sha512. This legacy hasher wraps those
        hashes in our standard PBKDF2 hasher.
    """
    algorithm = 'pbkdf2_wrapped_rails'

    def encode_rails_hash(self, digest, salt, iterations=None):
        """ Used by the database migration. """
        return super().encode(digest, salt, iterations)

    def encode(self, password, salt, iterations=None):
        """ Used for checking passwords on login. """
        digest = password + salt
        for _ in range(20):
            digest = hashlib.sha512(digest.encode('utf8')).hexdigest()
        return super().encode(digest, salt, iterations)