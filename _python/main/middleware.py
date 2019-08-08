import base64
import datetime
import hashlib
import hmac
import urllib
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
import rubymarshal.reader

from django.conf import settings
from django.contrib.auth.models import AnonymousUser
from django.utils import timezone
from django.utils.crypto import constant_time_compare
from django.utils.encoding import force_bytes
from django.utils.functional import SimpleLazyObject

from .models import User


### rails auth middleware ###

encrypted_cookie_salt = b'encrypted cookie'
encrypted_signed_cookie_salt = b'signed encrypted cookie'
iterations = 1000
sign_secret = hashlib.pbkdf2_hmac('sha1', force_bytes(settings.RAILS_SECRET_KEY_BASE), encrypted_signed_cookie_salt, iterations, 64)
secret_token = hashlib.pbkdf2_hmac('sha1', force_bytes(settings.RAILS_SECRET_KEY_BASE), encrypted_cookie_salt, iterations, 32)

def read_rails_cookie(request):
    """
        Implement what we need from these two files:
        https://github.com/rails/rails/blob/master/activesupport/lib/active_support/message_encryptor.rb
        https://github.com/rails/rails/blob/master/activesupport/lib/active_support/message_verifier.rb

        Some inspiration from:
        https://gist.github.com/mbyczkowski/34fb691b4d7a100c32148705f244d028
        https://github.com/rosenfeld/rails_compatible_cookies_utils/blob/master/lib/rails_compatible_cookies_utils.rb
        https://blog.cobalt.io/rails-decrypting-devises-warden-session-cookie-19a03c2eee34
    """
    # verify signature
    parts = request.COOKIES.get('_h2o_session', '').split("--")
    if len(parts) != 2 or not all(parts):
        return {}
    data, digest = parts
    data = urllib.parse.unquote(data)
    new_digest = str(base64.b16encode(hmac.new(sign_secret, bytes(data, 'utf8'), hashlib.sha1).digest()).lower(), 'utf8')
    if not constant_time_compare(digest, new_digest):
        return {}

    # decrypt message
    encrypted_data, iv = [base64.standard_b64decode(i) for i in base64.urlsafe_b64decode(data).split(b'--')]
    cipher = Cipher(algorithms.AES(secret_token), modes.CBC(iv), backend=default_backend())
    decryptor = cipher.decryptor()
    marshaled_message = decryptor.update(encrypted_data) + decryptor.finalize()
    message = rubymarshal.reader.loads(marshaled_message)
    return message

def get_rails_user(request):
    """
        Implement what we need from https://github.com/binarylogic/authlogic
    """
    # fetch user, if exists, from request.rails_session['user_credentials_id']
    if not 'user_credentials_id' in request.rails_session:
        return AnonymousUser()
    user = User.objects.filter(id=request.rails_session['user_credentials_id']).first()
    if not user:
        return AnonymousUser()

    # set user.last_request_at to current datetime if not set within last 10 minutes
    if not user.last_request_at or user.last_request_at < datetime.datetime.now() - datetime.timedelta(minutes=10):
        user.last_request_at = datetime.datetime.now()
        user.save()

    return user

def rails_session_middleware(get_response):
    def middleware(request):
        request.rails_session = SimpleLazyObject(lambda: read_rails_cookie(request))
        return get_response(request)
    return middleware

def rails_auth_middleware(get_response):
    def middleware(request):
        request.user = SimpleLazyObject(lambda: get_rails_user(request))
        return get_response(request)
    return middleware