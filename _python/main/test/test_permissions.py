import pytest
from _pytest.fixtures import FixtureLookupError

from django.template import Variable
from django.urls import reverse

from ..urls import urlpatterns
from test.test_helpers import check_response


"""
    This file applies the tests that are attached to each view via the @perms_test decorator.
    A particular test looks like this:
    
        @perms_test({'method': 'post', 'args': ['casebook'], 'results': {302: ['casebook.owner', 'admin_user'], 403: ['other_user'], 'login': [None]}})
        def some_view(request, casebook): ...
    
    This means the test should POST to `reverse(some_view, args=[casebook])`, and that casebook.owner and admin_user
    should receive a 302 response; other_user should receive a 403; and non-auth requests should redirect to the login
    form. 
"""


def get_permissions_tests():
    """
        This function runs during test collection time. It inspects each route in main.urls, and generates parameters
        for the test_permissions() test below.
    """
    for path in urlpatterns:
        # don't run tests on built-in includes
        if hasattr(path, 'urlconf_module') and path.urlconf_module.__name__.startswith('django.'):
            continue

        view_func = path.callback

        # don't run tests on built-in views:
        if view_func.__name__ in ['RedirectView', 'TemplateView']:
            continue

        # retrieve the test config for this view, which will have been attached as view_func.perms_test by the
        # @perms_test decorator
        if not hasattr(view_func, 'perms_test') and hasattr(view_func, 'view_class'):
            # for class-based views, inspect each request method separately:
            view_class = path.callback.view_class
            to_test = [(m.lower(), getattr(getattr(view_class, m.lower()), 'perms_test', None)) for m in view_class()._allowed_methods() if m != 'OPTIONS']
        else:
            # just one test config for regular function-based views:
            to_test = [('get', getattr(view_func, 'perms_test', None))]

        # yield test_permissions parameters for each test config detected:
        for default_request_method, test_config in to_test:
            if test_config is None:
                yield path, False, None, None, None, None, None
                continue
            for test in test_config:
                request_method = test.get('method', default_request_method)
                url_args = test.get('args', [])
                for status_code, users in test['results'].items():
                    for user_string in users:
                        yield path, True, view_func, url_args, request_method, status_code, user_string


@pytest.mark.parametrize("path, has_tests, view_func, url_args, request_method, status_code, user_string", get_permissions_tests())
def test_permissions(
        # regular test fixtures
        client, request,
        # parameters from get_permissions_tests()
        path, has_tests, view_func, url_args, request_method, status_code, user_string
):
    """
        This test function runs a single request on behalf of a single user. The example at the top of this file would
        run this function four separate times.
    """
    # all routes are required to have tests
    if not has_tests:
        raise Exception(
            "View function or method for path %s is missing a @perms_test decorator. "
            "Use @no_perms_test if you are sure your view doesn't need tests." % path)

    # Helper method to fetch and return a particular fixture, like 'casebook' or 'casebook.owner'.
    # Values are also stored in the `context` dictionary so they can be reused instead of recreated.
    # The part of `path` before the first period is treated as a pytest fixture, and the remainder is
    # resolved using the Django template language (so lookups like 'casebook.resources.1.some_func'
    # will work).
    def hydrate(context, path):
        if path not in context:
            fixture_name = path.split('.', 1)[0]
            if fixture_name not in context:
                try:
                    context[fixture_name] = request.getfixturevalue(fixture_name)
                except FixtureLookupError:
                    pass  # path may not be a fixture name, like '"some string"'
            context[path] = Variable(path).resolve(context)
        return context[path]

    # Special handling for status code 'login' -- expect a 302, but also check that we redirect to
    # the login page. This lets us differentiate from pages that redirect on success.
    should_redirect_to_login = False
    if status_code == 'login':
        status_code = 302
        should_redirect_to_login = True

    # run request
    context = {}
    url = reverse(view_func, args=[hydrate(context, arg) for arg in url_args])
    user = hydrate(context, user_string) if user_string else None
    response = getattr(client, request_method)(url, as_user=user)

    # check response
    check_response(response, status_code=status_code, content_type=None)
    if should_redirect_to_login:
        assert response.url.startswith(reverse('login')), "View failed to redirect to login page"
