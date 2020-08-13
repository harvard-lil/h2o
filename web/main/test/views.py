from django.core.exceptions import PermissionDenied, SuspiciousOperation
from django.http import Http404
from django.views.decorators.csrf import requires_csrf_token

def raise_400(request):
    raise SuspiciousOperation('Fishy')

def raise_403(request):
    raise PermissionDenied

@requires_csrf_token
def raise_403_csrf(request):
    pass   # pragma: no cover

def raise_404(request):
    raise Http404('Does not exist')

def raise_500(request):
    raise Exception('Oops')
