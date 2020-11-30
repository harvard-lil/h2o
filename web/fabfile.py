from datetime import date
import os
import signal
import subprocess
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


@task
def run_frontend(port=None):
    node_proc = subprocess.Popen("npm run serve", shell=True, stdout=sys.stdout, stderr=sys.stderr)
    try:
        run_django()
    finally:
        os.kill(node_proc.pid, signal.SIGKILL)

### tasks ###

@task
@setup_django
def create_search_index():
    """ Create (or recreate) the search_view materialized view """
    from main.models import SearchIndex
    SearchIndex.create_search_index()


@task
@setup_django
def refresh_search_index():
    """ Update an existing search_view materialized view; will fail if create_search_index hasn't been run once """
    from main.models import SearchIndex
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
    from main.models import TextBlock, ContentNode
    from main.sanitize import sanitize
    from main.utils import parse_html_fragment, elements_equal

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
                elements_equal(content_tree, sanitized_tree, tidy_style_attrs=True)


@task
@setup_django
def load_uscode_index(index='uscode_index.jsonl', effective_date=date(2018,1,1)):
    """
    Import a jsonl file into the search index for US Code support
    """
    import json
    from main.models import USCodeIndex
    with open(index) as index_file:
        entries = []
        for line in index_file:
            ind_dict = json.loads(line)
            entries.append(USCodeIndex(citation=ind_dict['citation'], effective_date=effective_date, title=ind_dict['title'], gpo_id=ind_dict['gpo_id'], lii_url=ind_dict['lii_link']))
        USCodeIndex.objects.bulk_create(entries)
        for ind in USCodeIndex.objects.all():
            ind.save()

if __name__ == "__main__":
    # allow tasks to be run as "python fabfile.py task"
    # this is convenient for profiling, e.g. "kernprof -l fabfile.py refresh_search_index"
    from fabric.main import main
    main()

