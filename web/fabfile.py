from datetime import date
import os
import signal
import subprocess
from functools import wraps
import sys
from tqdm import tqdm
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
def migrate_cases(max_cases=400):
    from datetime import timedelta
    from itertools import groupby
    from pyquery import PyQuery
    from main.models import Case, LegalDocumentSource, LegalDocument, ContentNode, ContentAnnotation
    cap = LegalDocumentSource.objects.filter(name="CAP").get()
    legacy = LegalDocumentSource.objects.filter(name="Legacy").get()

    resource_map = {k:[x for x in v] for k,v in groupby(ContentNode.objects.filter(resource_type='Case').all(), lambda x:x.resource_id)}
    used_cases = set(resource_map.keys())
    resource_count = len([1 for x in resource_map.values() for y in x])
    pre_res_count = ContentNode.objects.filter(resource_type='Case').count()
    print(f"Migrating {len(used_cases)} cases and {resource_count}[{pre_res_count}] resources")
    cases = list(Case.objects.filter(id__in=used_cases).all())
    fully_imported = 0
    legacy_docs = 0
    odd_imported = 0
    prior_ld_count = LegalDocument.objects.count()
    res_count = 0
    failed_import = 0
    for case in tqdm(cases[:max_cases]):
        ld = None
        if not case.capapi_id:
            cites = [x['cite'] for x in case.citations if 'cite' in x] if case.citations else []
            ld = LegalDocument.objects.create(source=legacy,
                                              short_name=case.name_abbreviation,
                                              name=case.name,
                                              doc_class='Case',
                                              citations=cites,
                                              jurisdiction=case.jurisdiction_slug,
                                              effective_date=case.decision_date,
                                              publication_date=case.created_at,
                                              updated_date=case.updated_at,
                                              source_ref=f'Case-conversion-{case.id}',
                                              content=case.content,
                                              metadata={'oldCaseId': case.id})
            legacy_docs += 1
        else:
            try:
                ld = cap.api_model().pull(cap,case.capapi_id)
                ld.save()
            except Exception:
                print(f"ERROR with CAPID: {case.capapi_id}")
                failed_import += 1
                continue
            if not ld:
                cites = [x['cite'] for x in case.citations if 'cite' in x]
                ld = LegalDocument.objects.create(source=legacy,
                                                  short_name=case.name_abbreviation,
                                                  name=case.name,
                                                  doc_class='Case',
                                                  citations=cites,
                                                  jurisdiction=case.jurisdiction_slug,
                                                  effective_date=case.decision_date,
                                                  publication_date=case.created_at,
                                                  updated_date=case.updated_at,
                                                  source_ref=f'Case-conversion-{case.id}',
                                                  content=case.content,
                                                  metadata={'oldCaseId': case.id,
                                                            'failedCapId':case.capapi_id})
                failed_import += 1
            else:
                original_text = PyQuery(case.content).text()
                new_text = PyQuery(ld.content).text()
                if new_text != original_text:
                    ld.publication_date = min(case.created_at.replace(tzinfo=None), ld.publication_date.replace(tzinfo=None) - timedelta(days=1))
                    ld.updated_date     = min(case.updated_at.replace(tzinfo=None), ld.updated_date.replace(tzinfo=None)     - timedelta(days=1))
                    ld.content = case.content
                    ld.save()
                    odd_imported += 1
                else:
                    fully_imported += 1
        res_count += case.related_resources().update(resource_type='LegalDocument', resource_id=ld.id)
        ld.refresh_from_db()
        ContentAnnotation.update_annotations(ld.related_annotations(), case.content, ld.content)
    post_ld_count = LegalDocument.objects.count()
    print(f"Created {legacy_docs} legacy, {odd_imported} kept content, {failed_import} failures, {fully_imported} CAP up-to-date legal docs")
    print(f"Updated {res_count} resources")
    print(f"Created {post_ld_count - prior_ld_count} legal docs")
    post_res_count = ContentNode.objects.filter(resource_type='Case').count()
    print(f"Resources: {pre_res_count} - {res_count} = {post_res_count}")



@task
@setup_django
def prune_unused_cases():
    from tqdm import tqdm
    from main.models import Case
    total_deleted = 0
    total_cases = Case.objects.all().count()
    for case in tqdm(Case.objects.all(), desc="Checking Cases"):
        if not case.related_resources().exists():
            case.delete()
            total_deleted += 1
    print(f"Total deleted: {total_deleted}/{total_cases}")


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
