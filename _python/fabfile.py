import os
from functools import wraps
import sys
from tqdm import tqdm
from fabric.decorators import task
from fabric.operations import local

import django


### helpers ###

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
_django_setup = False
def setup_django(func):
    """
        For speed, avoid setting up django until we need it. Attach @setup_django to any tasks that rely on importing django packages.
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        global _django_setup
        if not _django_setup:
            sys.path.insert(0, '')
            django.setup()
            _django_setup = True
        return func(*args, **kwargs)
    return wrapper


@task(alias='run')
def run_django(port=None):
    if port is None:
        port = "0.0.0.0:8000" if os.environ.get('DOCKERIZED') else "127.0.0.1:8000"
    local('python manage.py runserver %s' % port)


### tasks ###

@task
@setup_django
def create_search_index():
    """ Create (or recreate) the search_view materialized view """
    from search.models import SearchIndex
    SearchIndex.create_search_index()


@task
@setup_django
def refresh_search_index():
    """ Update an existing search_view materialized view; will fail if create_search_index hasn't been run once """
    from search.models import SearchIndex
    SearchIndex.refresh_search_index()


@task
@setup_django
def report_tags():
    """ Report all HTML tags, attributes, and styles used in ContentNode.headnote and TextBlock.content. """
    from main.models import TextBlock, ContentNode
    from main.utils import parse_html_fragment
    from pprint import pprint
    import re

    tags = {}
    tag_styles = {}

    sanitized_fields = ((TextBlock, 'content'), (ContentNode, 'headnote'))

    for model, field in sanitized_fields:
        print("Getting tags from %s.%s" % (model.__name__, field))
        for obj in tqdm(model.objects.exclude(**{field: ''}).exclude(**{field: None}), total=float("inf")):
            tree = parse_html_fragment(getattr(obj, field))
            for el in tree.iter():
                tag = tags.setdefault(el.tag, set())
                for k, v in el.items():
                    tag.add(k)
                    if k == 'style':
                        tag_style = tag_styles.setdefault(el.tag, set())
                        v = re.compile(r'url\s*\(\s*[^\s)]+?\s*\)\s*').sub(' ', v)  # remove url()
                        for pair in v.split(';'):
                            tag_style.add(pair.split(':', 1)[0].strip().lower())

    print("Tags and attributes in use:")
    pprint(tags)

    print("Styles in use:")
    for tag in sorted(tag_styles.keys()):
        styles = tag_styles[tag]
        print("%s[%s]" % (tag, ",".join(s for s in styles if s)))

    print("Unique styles in use:")
    styles = set()
    for s in tag_styles.values():
        styles |= s
        print(" ".join(sorted(styles)))


@task
@setup_django
def compare_sanitized_html():
    """
        Report all changes that result from applying sanitize() to ContentNode.headnote and TextBlock.content.
    """
    import difflib
    from main.models import TextBlock, ContentNode
    from main.sanitize import sanitize
    from main.utils import parse_html_fragment

    def elements_equal(e1, e2, ignore={}):
        """
            Recursively compare two lxml Elements. Raise ValueError if not identical.
        """
        if e1.tag != e2.tag:
            raise ValueError("e1.tag != e2.tag (%s != %s)" % (e1.tag, e2.tag))
        if e1.text != e2.text:
            diff = '\n'.join(difflib.ndiff([e1.text or ''], [e2.text or '']))
            raise ValueError("e1.text != e2.text:\n%s" % diff)
        if e1.tail != e2.tail:
            raise ValueError("e1.tail != e2.tail (%s != %s)" % (e1.tail, e2.tail))
        ignore_attrs = ignore.get('attrs', set()) | ignore.get('tag_attrs', {}).get(e1.tag.rsplit('}', 1)[-1], set())
        e1_attrib = {k:v for k,v in e1.attrib.items() if k not in ignore_attrs}
        e2_attrib = {k:v for k,v in e2.attrib.items() if k not in ignore_attrs}
        if e1_attrib.get('style'):
            # allow easy comparison of sanitized style tags by removing all spaces and final semicolon
            e1_attrib['style'] = e1_attrib['style'].replace(' ', '').rstrip(';')
            e2_attrib['style'] = e2_attrib['style'].replace(' ', '').rstrip(';')
        if e1_attrib != e2_attrib:
            diff = "\n".join(difflib.Differ().compare(["%s: %s" % i for i in sorted(e1_attrib.items())], ["%s: %s" % i for i in sorted(e2_attrib.items())]))
            raise ValueError("e1.attrib != e2.attrib:\n%s" % diff)
        s1 = [i for i in e1 if i.tag.rsplit('}', 1)[-1] not in ignore.get('tags', ())]
        s2 = [i for i in e2 if i.tag.rsplit('}', 1)[-1] not in ignore.get('tags', ())]
        if len(s1) != len(s2):
            diff = "\n".join(difflib.Differ().compare([s.tag for s in s1], [s.tag for s in s2]))
            raise ValueError("e1 children != e2 children:\n%s" % diff)
        for c1, c2 in zip(s1, s2):
            elements_equal(c1, c2, ignore)

    sanitized_fields = (
        (TextBlock, 'content'),
        (ContentNode, 'headnote'),
    )
    for model, field in sanitized_fields:
        print("Getting tags from %s.%s" % (model.__name__, field))
        for obj in tqdm(model.objects.exclude(**{field: ''}).exclude(**{field: None}).iterator(), total=float("inf")):
            content = getattr(obj, field)
            sanitized = sanitize(content)
            if content != sanitized:
                content_tree = parse_html_fragment(content)
                sanitized_tree = parse_html_fragment(sanitized)
                try:
                    elements_equal(content_tree, sanitized_tree)
                except ValueError as e:
                    print("Error comparing %s:\n%s" % (obj.id, e))


if __name__ == "__main__":
    # allow tasks to be run as "python fabfile.py task"
    # this is convenient for profiling, e.g. "kernprof -l fabfile.py refresh_search_index"
    from fabric.main import main
    main()

