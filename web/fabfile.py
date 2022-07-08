from datetime import date
import os
import signal
import subprocess
from functools import wraps
import sys
from tqdm import tqdm
from fabric.context_managers import shell_env
from fabric.decorators import task
from fabric.operations import local
import uuid
from pyquery import PyQuery

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
def run_django(port=None, debug_toolbar=''):
    with shell_env(DEBUG_TOOLBAR=debug_toolbar):
        if port is None:
            port = "0.0.0.0:8000" if os.environ.get('DOCKERIZED') else "127.0.0.1:8000"
        local(f'python manage.py runserver {port}')


@task
def run_frontend(port=None, debug_toolbar=''):
    node_proc = subprocess.Popen("npm run serve", shell=True, stdout=sys.stdout, stderr=sys.stderr)
    try:
        run_django(port, debug_toolbar)
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
    """ Update an existing search_view materialized view; will create if create_search_index hasn't been run once """
    from main.models import SearchIndex
    SearchIndex.refresh_search_index()

@task
@setup_django
def create_fts_index():
    """ Create (or recreate) the search_view materialized view """
    from main.models import FullTextSearchIndex
    FullTextSearchIndex.create_search_index()

@task
@setup_django
def refresh_fts_index():
    """ Update an existing search_view materialized view; will create if create_search_index hasn't been run once """
    from main.models import FullTextSearchIndex
    FullTextSearchIndex.refresh_search_index()

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
        print(f"Getting tags from {model.__name__}.{field}")
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
        print(f"{tag}[{','.join(s for s in styles if s)}]")

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
        print("Getting tags from {model.__name__}.{field}")
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
            repealed = ind_dict['title'].startswith("Repealed")
            entries.append(USCodeIndex(citation=ind_dict['citation'], effective_date=effective_date, title=ind_dict['title'], gpo_id=ind_dict['gpo_id'], lii_url=ind_dict['lii_link'], repealed=repealed))
        USCodeIndex.objects.bulk_create(entries)
        for ind in USCodeIndex.objects.all():
            ind.save()

if __name__ == "__main__":
    # allow tasks to be run as "python fabfile.py task"
    # this is convenient for profiling, e.g. "kernprof -l fabfile.py refresh_search_index"
    from fabric.main import main
    main()

@task
@setup_django
def prune_old_casebooks(older_than=90):
    from tqdm import tqdm
    from main.models import Casebook
    from datetime import datetime, timedelta
    target_time = datetime.now() - timedelta(days=older_than)
    total = 0
    for cb in tqdm(Casebook.objects.filter(state='Previous').filter(updated_at__lt=target_time), desc="Checking Casebooks"):
        if not cb.descendant_nodes.exists():
            try:
                cb.delete()
                total += 1
            except Exception:
                print(f"Failed to delete {cb.id} - {cb.title}")
    print(f"Deleted {total} casebooks")



def image_uuids(res):
    if not res.content:
        return None
    pq = PyQuery(res.content)
    for img in pq("img").items():
        src = img.attr('src') or ''
        i = 0
        while i < len(src) and src[i] in {'.','/'}:
            i += 1
        src = src[i:]
        if src.startswith('image/'):
            src_uuid = uuid.UUID(src[6:])
            yield src_uuid

@task
@setup_django
def list_used_images(output="", in_db=False, in_html=True):
    if output == "":
        print("Must include output file (list_used_images:output=to_file.txt)")
    from tqdm import tqdm
    from main.models import SavedImage, LegalDocument, TextBlock

    used_images = set()
    if in_html != "False":
        used_images = {src_uuid for tb in tqdm(TextBlock.objects.all(), desc="TextBlocks")
                       for src_uuid in image_uuids(tb)}.union(
                               {src_uuid for ld in tqdm(LegalDocument.objects.all(), desc="LegalDocs")
                                for src_uuid in image_uuids(ld)})
    if in_db is not False:
        for si in SavedImage.objects.all():
            used_images.add(si.external_id)
    with open(output, 'w') as f:
        for image in used_images:
            f.write(str(image) + "\n")


@task
@setup_django
def cleanup_images(keep_file=None, dry_run=True):
    if dry_run == "False":
        dry_run = False
    import re
    from datetime import timedelta
    from main.storages import get_s3_storage
    from main.models import SavedImage, LegalDocument, TextBlock

    used_images = {src_uuid for tb in tqdm(TextBlock.objects.all(), desc="TextBlocks")
                       for src_uuid in image_uuids(tb)}.union(
                               {src_uuid for ld in tqdm(LegalDocument.objects.all(), desc="LegalDocs")
                                for src_uuid in image_uuids(ld)})

    s3_files_to_keep = {}
    if keep_file:
        with open(keep_file) as keeps:
            s3_files_to_keep = {uuid.UUID(line.strip()) for line in keeps.readlines()}

    s3 = get_s3_storage()
    one_day = timedelta(days=1)
    s3_files_to_check = {x['file_name'] for x in s3.augmented_listdir('/') if x['age'] > one_day}

    uuid_re = re.compile('[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
    to_cleanup = {}
    for fname in s3_files_to_check:
        matches = uuid_re.findall(fname)
        if matches and len(matches) == 1:
            to_cleanup[uuid.UUID(matches[0])] = fname

    saved_images = {si.external_id: si for si in SavedImage.objects.all()}
    has_saved_image = 0
    no_saved_image = 0
    kept_used = 0
    kept_listed = 0
    for external_id, file_name in to_cleanup.items():
        if external_id in used_images:
            kept_used += 1
            continue
        if external_id in s3_files_to_keep:
            kept_listed += 1
            continue
        if external_id in saved_images:
            has_saved_image += 1
            si = saved_images[external_id]
            if not dry_run:
                si.image.delete(save=False)
                si.delete()
            else:
                print(f"Delete Image: {external_id}")
        else:
            no_saved_image += 1
            if not dry_run:
                s3.delete(file_name)
            else:
                print(f"Delete: {file_name}")

    print(f"Deleted {has_saved_image} SavedImages and {no_saved_image} orphaned images")
    print(f"Kept {kept_listed} images from list and {kept_used} from html")
    print(f"Total images: {len(to_cleanup)}")


@task
@setup_django
def list_exports():
    from main.models import Casebook
    from django.urls import reverse
    public = {Casebook.LifeCycle.PUBLISHED.value, Casebook.LifeCycle.REVISING.value}
    for cb in Casebook.objects.filter(state__in=public).all():
        print(reverse('export_casebook', args=[cb, 'docx']))

@task
@setup_django
def casebook_garbage_collect(older_than_days=180, dry_run=False):
    from main.models import ContentNode, Casebook
    from datetime import datetime, timedelta
    from tqdm import tqdm
    older_than_days = int(older_than_days)
    dry_run = bool(dry_run)
    living_casebook_states = {Casebook.LifeCycle.PUBLISHED.value, Casebook.LifeCycle.REVISING.value, Casebook.LifeCycle.DRAFT.value, Casebook.LifeCycle.NEWLY_CLONED.value, Casebook.LifeCycle.PRIVATELY_EDITING.value}
    newest_save = datetime.now() - timedelta(days=older_than_days)
    print(f"Preparing to {'check' if dry_run else 'delete'} previously saves of casebooks older than {older_than_days} days old.")
    cbs = list(Casebook.objects.filter(state=Casebook.LifeCycle.PREVIOUS_SAVE.value, updated_at__lte=newest_save).prefetch_related('contents').all())
    cn_ids = {cn.id for cb in cbs for cn in cb.contents.all()}
    referenced_nodes = {prov for cn in ContentNode.objects.filter(provenance__overlap=list(cn_ids), casebook__state__in=list(living_casebook_states)).select_related('casebook').all() for prov in cn.provenance}
    count = 0
    for cb in tqdm(cbs, desc="Filtering ContentNodes"):
        if {x.id for x in cb.contents.all()}.intersection(referenced_nodes):
            continue
        if not dry_run:
            cb.delete()
        count += 1
    print(f"Deleted {count}/{len(cbs)} previous saves older than {older_than_days} days old")


@task
@setup_django
def export_node(node_id=None, casebook_id=None, ordinals=None, annotations=True, file_name="temporary_export.docx", memory=False):
    from time import time
    import tracemalloc
    from main.models import ContentNode, Casebook
    from django.template.defaultfilters import filesizeformat

    try:
        if node_id:
            content_node_id = int(node_id)
            content_node = ContentNode.objects.get(id=content_node_id)
        else:
            casebook_id = int(casebook_id)
            if ordinals:
                ords = list(map(int, ordinals.split(".")))
                content_node = ContentNode.objects.get(casebook_id=casebook_id, ordinals=ords)
            else:
                content_node = Casebook.objects.get(id=casebook_id)
    except ContentNode.DoesNotExist:
        print(f"Couldn't find content node with node_id={node_id} or casebook_id={casebook_id} and ordinals={ordinals}")
        return
    include_annotations = annotations != "False"
    if memory == "True":
        tracemalloc.start()
    before = time()

    # Replace
    file_contents = content_node.export(include_annotations)

    after = time()
    if memory == "True":
        current, peak = tracemalloc.get_traced_memory()
        print(f"Current memory usage is {current / 10**6}MB; Peak was {peak / 10**6}MB")
        tracemalloc.stop()

    with open(file_name, "wb") as f:
        f.write(file_contents)

    print(f"Generated export file ({filesizeformat(len(file_contents))}) in {round(after-before,2)} seconds.")
