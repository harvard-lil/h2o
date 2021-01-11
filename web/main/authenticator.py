from django.contrib.auth.backends import ModelBackend

class NormalizingAuthenticator(ModelBackend):
    def authenticate(self, request, username=None, password=None):
        try:
            [user, domain] = username.split('@')
            email = '@'.join([user, domain.lower()])
            sup = super().authenticate(request, username=email, password=password)
            return sup
        except Exception:
            return None
