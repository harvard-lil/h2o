# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey has `on_delete` set to the desired behavior.
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.contrib.postgres.fields import JSONField, ArrayField
from django.db import models
from django.utils import timezone

from main.utils import sanitize


class RailsModel(models.Model):
    """
        Tweaks to Django models to match behavior of Rails.
    """
    def save(self, *args, **kwargs):
        # set updated_at for each save
        self.updated_at = timezone.now()
        super().save(*args, **kwargs)

    class Meta:
        abstract = True


class Annotation(RailsModel):
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


class ArInternalMetadata(RailsModel):
    key = models.CharField(primary_key=True, max_length=255)
    value = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'ar_internal_metadata'


class CaseCourt(RailsModel):
    name_abbreviation = models.CharField(max_length=150, blank=True, null=True)
    name = models.CharField(max_length=500, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    capapi_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'case_courts'


class Case(RailsModel):
    name_abbreviation = models.CharField(max_length=150)
    name = models.CharField(max_length=10000, blank=True, null=True)
    decision_date = models.DateField(blank=True, null=True)
    case_court_id = models.IntegerField(blank=True, null=True)
    header_html = models.CharField(max_length=15360, blank=True, null=True)
    content = models.CharField(max_length=5242880)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    public = models.BooleanField(blank=True, null=True)
    created_via_import = models.BooleanField()
    capapi_id = models.IntegerField(blank=True, null=True)
    attorneys = JSONField(blank=True, null=True)
    parties = JSONField(blank=True, null=True)
    opinions = JSONField(blank=True, null=True)
    citations = JSONField(blank=True, null=True)
    docket_number = models.CharField(max_length=20000, blank=True, null=True)
    #annotations_count = models.IntegerField()  # in Greg PR

    class Meta:
        managed = False
        db_table = 'cases'


class CkeditorAsset(RailsModel):
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


class Collage(RailsModel):
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


class ContentAnnotation(RailsModel):
    id = models.BigAutoField(primary_key=True)
    resource = models.ForeignKey('ContentNode', models.DO_NOTHING, related_name='annotations')
    start_paragraph = models.IntegerField()
    end_paragraph = models.IntegerField(blank=True, null=True)
    start_offset = models.IntegerField()
    end_offset = models.IntegerField()
    kind = models.CharField(max_length=2255)
    content = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    # global_start_offset = models.IntegerField(blank=True, null=True)  # in Greg PR
    # global_end_offset = models.IntegerField(blank=True, null=True)  # in Greg PR

    class Meta:
        managed = False
        db_table = 'content_annotations'


class ContentCollaborator(RailsModel):
    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey('User', models.DO_NOTHING, blank=True, null=True)
    content = models.ForeignKey('ContentNode', models.DO_NOTHING, blank=True, null=True)
    role = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    has_attribution = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'content_collaborators'
        unique_together = (('user', 'content'),)


class ContentImage(RailsModel):
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


class ContentNode(RailsModel):
    id = models.BigAutoField(primary_key=True)
    title = models.CharField(max_length=10000, blank=True, null=True)
    slug = models.CharField(max_length=10000, blank=True, null=True)
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    headnote = models.TextField(blank=True, null=True)
    # raw_headnote = models.TextField(blank=True, null=True)  # in Greg PR
    public = models.BooleanField()
    casebook = models.ForeignKey('Casebook', models.DO_NOTHING, blank=True, null=True, related_name='contents')
    ordinals = ArrayField(models.IntegerField())
    copy_of = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True, related_name='clones')
    is_alias = models.BooleanField(blank=True, null=True)
    resource_type = models.CharField(max_length=255, blank=True, null=True)
    resource_id = models.BigIntegerField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    ancestry = models.CharField(max_length=255, blank=True, null=True)
    playlist_id = models.BigIntegerField(blank=True, null=True)
    root_user_id = models.BigIntegerField(blank=True, null=True)
    draft_mode_of_published_casebook = models.BooleanField(blank=True, null=True)
    cloneable = models.BooleanField()

    collaborators = models.ManyToManyField('User', through='ContentCollaborator')

    class Meta:
        managed = False
        db_table = 'content_nodes'

    def type(self):
        if not self.casebook:
            return 'casebook'
        elif not self.resource_id:
            return 'section'
        else:
            return 'resource'

    def resource(self):
        if not self.resource_id:
            # or maybe return None?
            raise Exception("This node has no associated resource")
        if self.resource_type in ['Case', 'TextBlock', 'Default']:
            # so fancy...
            return globals()[self.resource_type].objects.get(id=self.resource_id)
        else:
            raise NotImplemented

    def ordinal_string(self):
       return '.'.join(str(o) for o in self.ordinals)

    def formatted_headnote(self):
        return sanitize(self.headnote)

    @property
    def attributors(self):
        """ Users whose authorship should be attributed (as opposed to all having edit permission). """
        return self.collaborators.filter(has_attribution=True).order_by('-role')

    def has_collaborator(self, user):
        return self.collaborators.filter(pk=user.pk).exists()


#
# Start ContentNode Proxies
#

class CasebookManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(casebook__isnull=True)

class Casebook(ContentNode):
    class Meta:
        proxy = True

    objects = CasebookManager()

    def root_owner(self):
        if self.root_user_id:
          return User.objects.get(id=self.root_user_id)
        elif self.ancestry:
          pass
          # User.joins(:content_collaborators).where(content_collaborators: { content_id: self.root.id, role: 'owner' }).first ## make sure this returns root

    def viewable_by(self, user):
        return self.public or (user.is_authenticated and (self.has_collaborator(user) or user.is_superadmin))

class SectionManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(resource_id__isnull=True)

class Section(ContentNode):
    class Meta:
        proxy = True

    objects = SectionManager()


class ResourceManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(casebook__isnull=False, resource_id__isnull=False)

class Resource(ContentNode):
    class Meta:
        proxy = True

    objects = ResourceManager()


#
# End ContentNode Proxies
#

class Default(RailsModel):
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


class DelayedJob(RailsModel):
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


class FrozenItem(RailsModel):
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


class MediaType(RailsModel):
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


class Media(RailsModel):
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


class Metadata(RailsModel):
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


class Page(RailsModel):
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


class PermissionAssignment(RailsModel):
    user_collection_id = models.IntegerField(blank=True, null=True)
    user_id = models.IntegerField(blank=True, null=True)
    permission_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'permission_assignments'


class Permission(RailsModel):
    key = models.CharField(max_length=255, blank=True, null=True)
    label = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    permission_type = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'permissions'


class PlaylistItem(RailsModel):
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


class Playlist(RailsModel):
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


class PlaylistsUserCollection(RailsModel):
    """
    Legacy table
    """
    playlist_id = models.IntegerField(blank=True, null=True)
    user_collection_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'playlists_user_collections'


# in Greg PR
# class RawContent(RailsModel):
#     id = models.BigAutoField(primary_key=True)
#     content = models.TextField(blank=True, null=True)
#     source_type = models.CharField(max_length=-1, blank=True, null=True)
#     source_id = models.BigIntegerField(blank=True, null=True)
#     created_at = models.DateTimeField()
#     updated_at = models.DateTimeField()
#
#     class Meta:
#         managed = False
#         db_table = 'raw_contents'
#         unique_together = (('source_type', 'source_id'),)


class Role(RailsModel):
    """
        User roles.
    """
    name = models.CharField(max_length=40, blank=True, null=True)
    authorizable_type = models.CharField(max_length=40, blank=True, null=True)
    authorizable_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'roles'


class RolesUser(RailsModel):
    """
        Join table for User and Role.
    """
    user = models.ForeignKey('User', blank=True, null=True, on_delete=models.CASCADE)
    role = models.ForeignKey(Role, blank=True, null=True, on_delete=models.CASCADE)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'roles_users'


class SchemaMigration(RailsModel):
    version = models.CharField(primary_key=True, max_length=255)

    class Meta:
        managed = False
        db_table = 'schema_migrations'


class Session(RailsModel):
    session_id = models.CharField(max_length=255)
    data = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'sessions'


class Tagging(RailsModel):
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


class Tag(RailsModel):
    """
    Legacy table
    """
    name = models.CharField(max_length=255, blank=True, null=True)
    taggings_count = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'tags'


class TextBlock(RailsModel):
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
    # annotations_count = models.IntegerField()  # in Greg PR

    class Meta:
        managed = False
        db_table = 'text_blocks'


class UnpublishedRevision(RailsModel):
    id = models.BigAutoField(primary_key=True)
    node_id = models.IntegerField(blank=True, null=True)
    field = models.CharField(max_length=255)
    value = models.CharField(max_length=50000, blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    casebook_id = models.IntegerField(blank=True, null=True)
    node_parent_id = models.IntegerField(blank=True, null=True)
    annotation_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'unpublished_revisions'


class UserCollection(RailsModel):
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


class UserCollectionsUser(RailsModel):
    """
    Legacy table
    """
    user_id = models.IntegerField(blank=True, null=True)
    user_collection_id = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'user_collections_users'


class User(RailsModel):
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
    image_file_name = models.CharField(max_length=255, blank=True, null=True)
    image_content_type = models.CharField(max_length=255, blank=True, null=True)
    image_file_size = models.IntegerField(blank=True, null=True)
    image_updated_at = models.DateTimeField(blank=True, null=True)
    verified_professor = models.BooleanField(blank=True, null=True)
    professor_verification_requested = models.BooleanField(blank=True, null=True)
    verified_email = models.BooleanField()

    roles = models.ManyToManyField(Role, through=RolesUser)

    class Meta:
        managed = False
        db_table = 'users'

    def email_domain(self):
        return self.email_address

    def anonymous_name(self):
        return "{}#{}".format(self.email_domain, self.id)

    def display_name(self):
        if self.attribution:
          return self.attribution
        elif self.title:
          return self.title
        return self.anonymous_name

    # TODO: are all users active?
    is_active = True

    def has_role(self, role):
        return self.roles.filter(name=role).exists()

    @property
    def is_superadmin(self):
        return self.has_role('superadmin')

    # differentiate between real User model and AnonymousUser model:
    is_authenticated = True
    is_anonymous = False