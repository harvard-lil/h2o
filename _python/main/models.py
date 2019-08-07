# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey has `on_delete` set to the desired behavior.
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.db import models


class Annotation(models.Model):
    """
    Legacy table; does not hold currently-used annotations.
    """
    collage_id = models.IntegerField(blank=True, null=True)
    annotation = models.CharField(max_length=10240, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    cloned = models.BooleanField()
    xpath_start = models.CharField(max_length=255, blank=True, null=True)
    xpath_end = models.CharField(max_length=255, blank=True, null=True)
    start_offset = models.IntegerField()
    end_offset = models.IntegerField()
    link = models.CharField(max_length=255, blank=True, null=True)
    hidden = models.BooleanField()
    highlight_only = models.CharField(max_length=255, blank=True, null=True)
    annotated_item_id = models.IntegerField()
    annotated_item_type = models.CharField(max_length=255)
    error = models.BooleanField()
    feedback = models.BooleanField()
    discussion = models.BooleanField()
    user_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'annotations'


class ArInternalMetadata(models.Model):
    key = models.CharField(primary_key=True, max_length=-1)
    value = models.CharField(max_length=-1, blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'ar_internal_metadata'


class CaseCourt(models.Model):
    name_abbreviation = models.CharField(max_length=150, blank=True, null=True)
    name = models.CharField(max_length=500, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    capapi_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'case_courts'


class Case(models.Model):
    name_abbreviation = models.CharField(max_length=150)
    name = models.CharField(max_length=-1, blank=True, null=True)
    decision_date = models.DateField(blank=True, null=True)
    case_court_id = models.IntegerField(blank=True, null=True)
    header_html = models.CharField(max_length=15360, blank=True, null=True)
    content = models.CharField(max_length=5242880)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    public = models.BooleanField(blank=True, null=True)
    created_via_import = models.BooleanField()
    capapi_id = models.IntegerField(blank=True, null=True)
    attorneys = models.TextField(blank=True, null=True)  # This field type is a guess.
    parties = models.TextField(blank=True, null=True)  # This field type is a guess.
    opinions = models.TextField(blank=True, null=True)  # This field type is a guess.
    citations = models.TextField(blank=True, null=True)  # This field type is a guess.
    docket_number = models.CharField(max_length=20000, blank=True, null=True)
    annotations_count = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'cases'


class CkeditorAsset(models.Model):
    """
    Legacy table, from when people could embed assets in books.
    """
    data_file_name = models.CharField(max_length=255)
    data_content_type = models.CharField(max_length=255, blank=True, null=True)
    data_file_size = models.IntegerField(blank=True, null=True)
    assetable_id = models.IntegerField(blank=True, null=True)
    assetable_type = models.CharField(max_length=30, blank=True, null=True)
    type = models.CharField(max_length=30, blank=True, null=True)
    width = models.IntegerField(blank=True, null=True)
    height = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'ckeditor_assets'


class Collage(models.Model):
    """
    Legacy table
    """
    annotatable_type = models.CharField(max_length=255, blank=True, null=True)
    annotatable_id = models.IntegerField(blank=True, null=True)
    name = models.CharField(max_length=250)
    description = models.CharField(max_length=5120, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    word_count = models.IntegerField(blank=True, null=True)
    ancestry = models.CharField(max_length=255, blank=True, null=True)
    public = models.BooleanField(blank=True, null=True)
    readable_state = models.CharField(max_length=5242880, blank=True, null=True)
    words_shown = models.IntegerField(blank=True, null=True)
    user_id = models.IntegerField()
    annotator_version = models.IntegerField()
    featured = models.BooleanField()
    created_via_import = models.BooleanField()
    version = models.IntegerField()
    enable_feedback = models.BooleanField()
    enable_discussions = models.BooleanField()
    enable_responses = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'collages'


class ContentAnnotation(models.Model):
    id = models.BigAutoField(primary_key=True)
    resource = models.ForeignKey('ContentNodes', models.DO_NOTHING)
    start_paragraph = models.IntegerField()
    end_paragraph = models.IntegerField(blank=True, null=True)
    start_offset = models.IntegerField()
    end_offset = models.IntegerField()
    kind = models.CharField(max_length=-1)
    content = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    global_start_offset = models.IntegerField(blank=True, null=True)
    global_end_offset = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'content_annotations'


class ContentCollaborator(models.Model):
    id = models.BigAutoField(primary_key=True)
    user_id = models.BigIntegerField(blank=True, null=True)
    content = models.ForeignKey('ContentNodes', models.DO_NOTHING, blank=True, null=True)
    role = models.CharField(max_length=-1, blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    has_attribution = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'content_collaborators'
        unique_together = (('user_id', 'content'),)


class ContentImage(models.Model):
    """
    Legacy table
    """
    name = models.CharField(max_length=255, blank=True, null=True)
    page_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    image_file_name = models.CharField(max_length=255, blank=True, null=True)
    image_content_type = models.CharField(max_length=255, blank=True, null=True)
    image_file_size = models.IntegerField(blank=True, null=True)
    image_updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'content_images'


class ContentNode(models.Model):
    id = models.BigAutoField(primary_key=True)
    title = models.CharField(max_length=-1, blank=True, null=True)
    slug = models.CharField(max_length=-1, blank=True, null=True)
    subtitle = models.CharField(max_length=-1, blank=True, null=True)
    raw_headnote = models.TextField(blank=True, null=True)
    public = models.BooleanField()
    casebook = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True)
    ordinals = models.TextField()  # This field type is a guess.
    copy_of = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True)
    is_alias = models.BooleanField(blank=True, null=True)
    resource_type = models.CharField(max_length=-1, blank=True, null=True)
    resource_id = models.BigIntegerField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    ancestry = models.CharField(max_length=-1, blank=True, null=True)
    playlist_id = models.BigIntegerField(blank=True, null=True)
    root_user_id = models.BigIntegerField(blank=True, null=True)
    draft_mode_of_published_casebook = models.BooleanField(blank=True, null=True)
    cloneable = models.BooleanField()
    headnote = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'content_nodes'


class Default(models.Model):
    """
    These are actually Link Resource
    """
    name = models.CharField(max_length=1024, blank=True, null=True)
    url = models.CharField(max_length=1024)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    public = models.BooleanField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    content_type = models.CharField(max_length=255, blank=True, null=True)
    user_id = models.IntegerField(blank=True, null=True)
    ancestry = models.CharField(max_length=255, blank=True, null=True)
    created_via_import = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'defaults'


class DelayedJob(models.Model):
    """
    Legacy table
    """
    priority = models.IntegerField(blank=True, null=True)
    attempts = models.IntegerField(blank=True, null=True)
    handler = models.TextField(blank=True, null=True)
    last_error = models.TextField(blank=True, null=True)
    run_at = models.DateTimeField(blank=True, null=True)
    locked_at = models.DateTimeField(blank=True, null=True)
    failed_at = models.DateTimeField(blank=True, null=True)
    locked_by = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    queue = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'delayed_jobs'


class FrozenItem(models.Model):
    """
    Legacy table
    """
    content = models.TextField(blank=True, null=True)
    version = models.IntegerField()
    item_id = models.IntegerField()
    item_type = models.CharField(max_length=255)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'frozen_items'


class MediaType(models.Model):
    """
    Legacy table
    """
    label = models.CharField(max_length=255, blank=True, null=True)
    slug = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'media_types'


class Media(models.Model):
    """
    Legacy table
    """
    name = models.CharField(max_length=255, blank=True, null=True)
    content = models.TextField(blank=True, null=True)
    media_type_id = models.IntegerField(blank=True, null=True)
    public = models.BooleanField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    user_id = models.IntegerField()
    created_via_import = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'medias'


class Metadata(models.Model):
    """
    Legacy table
    """
    contributor = models.CharField(max_length=255, blank=True, null=True)
    coverage = models.CharField(max_length=255, blank=True, null=True)
    creator = models.CharField(max_length=255, blank=True, null=True)
    date = models.DateField(blank=True, null=True)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    format = models.CharField(max_length=255, blank=True, null=True)
    identifier = models.CharField(max_length=255, blank=True, null=True)
    language = models.CharField(max_length=255, blank=True, null=True)
    publisher = models.CharField(max_length=255, blank=True, null=True)
    relation = models.CharField(max_length=255, blank=True, null=True)
    rights = models.CharField(max_length=255, blank=True, null=True)
    source = models.CharField(max_length=255, blank=True, null=True)
    subject = models.CharField(max_length=255, blank=True, null=True)
    title = models.CharField(max_length=255, blank=True, null=True)
    dc_type = models.CharField(max_length=255, blank=True, null=True)
    classifiable_type = models.CharField(max_length=255, blank=True, null=True)
    classifiable_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'metadata'


class Page(models.Model):
    page_title = models.CharField(max_length=255)
    slug = models.CharField(max_length=255)
    content = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    footer_link = models.BooleanField()
    footer_link_text = models.CharField(max_length=255, blank=True, null=True)
    footer_sort = models.IntegerField()
    is_user_guide = models.BooleanField()
    user_guide_sort = models.IntegerField()
    user_guide_link_text = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'pages'


class PermissionAssignment(models.Model):
    user_collection_id = models.IntegerField(blank=True, null=True)
    user_id = models.IntegerField(blank=True, null=True)
    permission_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'permission_assignments'


class Permission(models.Model):
    key = models.CharField(max_length=255, blank=True, null=True)
    label = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    permission_type = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'permissions'


class PlaylistItem(models.Model):
    """
    Legacy table
    """
    playlist_id = models.IntegerField(blank=True, null=True)
    position = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    public_notes = models.BooleanField()
    actual_object_type = models.CharField(max_length=255, blank=True, null=True)
    actual_object_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'playlist_items'


class Playlist(models.Model):
    """
    Legacy table
    """
    name = models.CharField(max_length=1024, blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    public = models.BooleanField(blank=True, null=True)
    ancestry = models.CharField(max_length=255, blank=True, null=True)
    position = models.IntegerField(blank=True, null=True)
    counter_start = models.IntegerField()
    location_id = models.IntegerField(blank=True, null=True)
    when_taught = models.CharField(max_length=255, blank=True, null=True)
    user_id = models.IntegerField()
    primary = models.BooleanField()
    featured = models.BooleanField()
    created_via_import = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'playlists'


class PlaylistsUserCollection(models.Model):
    """
    Legacy table
    """
    playlist_id = models.IntegerField(blank=True, null=True)
    user_collection_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'playlists_user_collections'


class RawContent(models.Model):
    """
    Oh... this table is created in PR 812
    """
    id = models.BigAutoField(primary_key=True)
    content = models.TextField(blank=True, null=True)
    source_type = models.CharField(max_length=-1, blank=True, null=True)
    source_id = models.BigIntegerField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'raw_contents'
        unique_together = (('source_type', 'source_id'),)


class Role(models.Model):
    name = models.CharField(max_length=40, blank=True, null=True)
    authorizable_type = models.CharField(max_length=40, blank=True, null=True)
    authorizable_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'roles'


class RolesUser(models.Model):
    user_id = models.IntegerField(blank=True, null=True)
    role_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'roles_users'


class SchemaMigration(models.Model):
    version = models.CharField(primary_key=True, max_length=-1)

    class Meta:
        managed = False
        db_table = 'schema_migrations'


class Session(models.Model):
    session_id = models.CharField(max_length=255)
    data = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'sessions'


class Tagging(models.Model):
    """
    Legacy table
    """
    tag_id = models.IntegerField(blank=True, null=True)
    taggable_id = models.IntegerField(blank=True, null=True)
    tagger_id = models.IntegerField(blank=True, null=True)
    tagger_type = models.CharField(max_length=255, blank=True, null=True)
    taggable_type = models.CharField(max_length=255, blank=True, null=True)
    context = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'taggings'
        unique_together = (('tag_id', 'taggable_id', 'taggable_type', 'context', 'tagger_id', 'tagger_type'),)


class Tag(models.Model):
    """
    Legacy table
    """
    name = models.CharField(max_length=255, blank=True, null=True)
    taggings_count = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'tags'


class TextBlock(models.Model):
    name = models.CharField(max_length=255)
    content = models.CharField(max_length=5242880)
    public = models.BooleanField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    user_id = models.IntegerField(blank=True, null=True)
    created_via_import = models.BooleanField()
    description = models.CharField(max_length=5242880, blank=True, null=True)
    version = models.IntegerField()
    enable_feedback = models.BooleanField()
    enable_discussions = models.BooleanField()
    enable_responses = models.BooleanField()
    annotations_count = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'text_blocks'


class UnpublishedRevision(models.Model):
    id = models.BigAutoField(primary_key=True)
    node_id = models.IntegerField(blank=True, null=True)
    field = models.CharField(max_length=-1)
    value = models.CharField(max_length=-1, blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    casebook_id = models.IntegerField(blank=True, null=True)
    node_parent_id = models.IntegerField(blank=True, null=True)
    annotation_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'unpublished_revisions'


class UserCollection(models.Model):
    """
    Legacy table
    """
    user_id = models.IntegerField(blank=True, null=True)
    name = models.CharField(max_length=255, blank=True, null=True)
    description = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'user_collections'


class UserCollectionsUser(models.Model):
    """
    Legacy table
    """
    user_id = models.IntegerField(blank=True, null=True)
    user_collection_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'user_collections_users'


class User(models.Model):
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    login = models.CharField(max_length=255, blank=True, null=True)
    crypted_password = models.CharField(max_length=255, blank=True, null=True)
    password_salt = models.CharField(max_length=255, blank=True, null=True)
    persistence_token = models.CharField(max_length=255)
    login_count = models.IntegerField()
    last_request_at = models.DateTimeField(blank=True, null=True)
    last_login_at = models.DateTimeField(blank=True, null=True)
    current_login_at = models.DateTimeField(blank=True, null=True)
    last_login_ip = models.CharField(max_length=255, blank=True, null=True)
    current_login_ip = models.CharField(max_length=255, blank=True, null=True)
    oauth_token = models.CharField(max_length=255, blank=True, null=True)
    oauth_secret = models.CharField(max_length=255, blank=True, null=True)
    email_address = models.CharField(max_length=255, blank=True, null=True)
    tz_name = models.CharField(max_length=255, blank=True, null=True)
    attribution = models.CharField(max_length=255)
    perishable_token = models.CharField(max_length=255, blank=True, null=True)
    default_font_size = models.CharField(max_length=255, blank=True, null=True)
    title = models.CharField(max_length=255, blank=True, null=True)
    affiliation = models.CharField(max_length=255, blank=True, null=True)
    url = models.CharField(max_length=255, blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    canvas_id = models.CharField(max_length=255, blank=True, null=True)
    default_font = models.CharField(max_length=255, blank=True, null=True)
    print_titles = models.BooleanField()
    print_dates_details = models.BooleanField()
    print_paragraph_numbers = models.BooleanField()
    print_annotations = models.BooleanField()
    print_highlights = models.CharField(max_length=255)
    print_font_face = models.CharField(max_length=255)
    print_font_size = models.CharField(max_length=255)
    default_show_comments = models.BooleanField()
    default_show_paragraph_numbers = models.BooleanField()
    hidden_text_display = models.BooleanField()
    print_links = models.BooleanField()
    toc_levels = models.CharField(max_length=255)
    print_export_format = models.CharField(max_length=255)
    image_file_name = models.CharField(max_length=-1, blank=True, null=True)
    image_content_type = models.CharField(max_length=-1, blank=True, null=True)
    image_file_size = models.IntegerField(blank=True, null=True)
    image_updated_at = models.DateTimeField(blank=True, null=True)
    verified_professor = models.BooleanField(blank=True, null=True)
    professor_verification_requested = models.BooleanField(blank=True, null=True)
    verified_email = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'users'
