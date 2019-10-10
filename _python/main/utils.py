import re
from copy import deepcopy
from datetime import datetime, date
import bleach

from django.conf import settings


def sanitize(html):
    """
    TODO: read up on this sanitization library
    """
    return bleach.clean(html, tags=['p', 'br', *bleach.sanitizer.ALLOWED_TAGS])


def show_debug_toolbar(request):
    """
        Whether to show the Django debug toolbar.
    """
    return bool(settings.DEBUG)


def parse_cap_decision_date(decision_date_text):
    """
        Parse a CAP decision date string into a datetime object.

        >>> assert parse_cap_decision_date('2019-10-27') == date(2019, 10, 27)
        >>> assert parse_cap_decision_date('2019-10') == date(2019, 10, 1)
        >>> assert parse_cap_decision_date('2019') == date(2019, 1, 1)
        >>> assert parse_cap_decision_date('2019-02-29') == date(2019, 2, 1)  # non-existent day of month
        >>> assert parse_cap_decision_date('not a date') is None
    """
    try:
        try:
            return datetime.strptime(decision_date_text, '%Y-%m-%d').date()
        except ValueError as e:

            # if court used an invalid day of month (typically Feb. 29), strip day from date
            if e.args[0] == 'day is out of range for month':
                decision_date_text = decision_date_text.rsplit('-', 1)[0]

            try:
                return datetime.strptime(decision_date_text, '%Y-%m').date()
            except ValueError:
                return datetime.strptime(decision_date_text, '%Y').date()
    except Exception:
        # if for some reason we can't parse the date, just store None
        return None


def looks_like_citation(s):
    """
        Return True if string s looks like a case citation (starts and stops with digits).

        >>> all(looks_like_citation(s) for s in [
        ...     "123 Mass. 456",
        ...     "123-mass-456",
        ...     "123 anything else here 456",
        ... ])
        True
        >>> not any(looks_like_citation(s) for s in [
        ...     "123Mass.456",
        ...     "123 Mass.",
        ... ])
        True
    """
    return bool(re.match(r'\d+(\s+|-).*(\s+|-)\d+$', s))


def clone_model_instance(instance):
    clone = deepcopy(instance)
    clone.id = clone.pk = clone.created_at = None
    return clone


def fix_before_deploy(message):
    """ Use this to document questions that should be answered before a given line of code is allowed to run on production. """
    if not settings.NOT_ON_PRODUCTION:
        raise ValueError(message)


def fix_after_rails(message):
    """ Use this to document actions that should be taken after the migration to Python is complete. """
    pass