import re
from functools import lru_cache
from pathlib import Path

from django import template
from django.conf import settings

register = template.Library()


@lru_cache(None)
def path_lookup():
    """
        This function caches every path in the Rails public/ directory (settings.WHITENOISE_ROOT) and returns a
        dictionary mapping the relative paths to the URLs that should be included in templates, stripping out
        hexadecimal hashes from the paths if necessary. This allows the rails_static tag to use
        {% rails_static "packs/css/main.css" %} in the template to include "/packs/css/main-a4a68e68.css" in the HTML.

        Given this set of files in public/ :

        >>> monkeypatch = getfixture('monkeypatch')
        >>> monkeypatch.setattr(Path, 'glob', lambda *args, **kwargs: [
        ...     settings.WHITENOISE_ROOT+'/css/main-a4a68e68.css',
        ...     settings.WHITENOISE_ROOT+'/main.css',
        ...     settings.WHITENOISE_ROOT+'/main-cafe0001.css',
        ... ])

        Return this lookup table:

        >>> assert path_lookup() == {
        ...     'css/main-a4a68e68.css': '/css/main-a4a68e68.css',
        ...     'css/main.css': '/css/main-a4a68e68.css',
        ...     'main.css': '/main.css',
        ...     'main-cafe0001.css': '/main-cafe0001.css',
        ... }

        Note that in the usual case css/main.css can be looked up with or without a hash, but we also make sure that
        main-cafe0001.css does not shadow main.css in the edge case where one file looks like a hashed version of another.
    """
    # get all paths
    paths = Path(settings.WHITENOISE_ROOT).glob('**/*')
    out = {}
    exact_paths = []

    # sort oldest to newest, so we overwrite older answers with new ones and return the newest version of each file
    paths = sorted(paths, key=lambda p: p.stat().st_mtime)

    # add all paths with hashes stripped
    for path in paths:
        path = str(path).split(settings.WHITENOISE_ROOT, 1)[1].lstrip('/')
        path_without_hash = re.sub(r'-[a-f0-9]+(\.\w+)$', r'\1', path)
        out[path_without_hash] = '/' + path
        exact_paths.append(path)

    # add paths without hashes stripped
    for path in exact_paths:
        out[path] = '/' + path

    return out


@register.simple_tag
def rails_static(path):
    return path_lookup().get(path, '')