# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey has `on_delete` set to the desired behavior.
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.conf import settings
from django.contrib.auth.models import AnonymousUser
from django.contrib.postgres.fields import JSONField, ArrayField
from django.db import models
from django.db.models import Q
from django.urls import reverse
from django.utils import timezone
from django.utils.text import slugify

from urllib.parse import urlparse

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
    case_court = models.ForeignKey('CaseCourt', models.DO_NOTHING, related_name='cases')
    header_html = models.CharField(max_length=15360, blank=True, null=True)
    content = models.CharField(max_length=5242880)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    public = models.BooleanField()
    created_via_import = models.BooleanField()
    capapi_id = models.IntegerField(blank=True, null=True)
    attorneys = JSONField(blank=True, null=True)
    parties = JSONField(blank=True, null=True)
    opinions = JSONField(blank=True, null=True)
    citations = JSONField(blank=True, null=True)
    docket_number = models.CharField(max_length=20000, blank=True, null=True)
    annotations_count = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'cases'

    def get_name(self):
        return self.name_abbreviation if self.name_abbreviation else self.name

    def __str__(self):
        return self.get_name()

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='Case')


class ContentAnnotation(RailsModel):
    resource = models.ForeignKey('ContentNode', models.DO_NOTHING, related_name='annotations')
    start_paragraph = models.IntegerField()
    end_paragraph = models.IntegerField(blank=True, null=True)
    start_offset = models.IntegerField()
    end_offset = models.IntegerField()
    kind = models.CharField(max_length=2255)
    content = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    global_start_offset = models.IntegerField(blank=True, null=True)
    global_end_offset = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'content_annotations'


class ContentCollaborator(RailsModel):
    user = models.ForeignKey('User', models.DO_NOTHING, blank=True, null=True)
    content = models.ForeignKey('ContentNode', models.DO_NOTHING, blank=True, null=True)
    role = models.CharField(
        max_length=255,
        choices = (('owner', 'owner'), ('editor', 'editor'))
    )
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    has_attribution = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'content_collaborators'
        unique_together = (('user', 'content'),)


class ContentNode(RailsModel):
    title = models.CharField(max_length=10000, blank=True, null=True)
    slug = models.CharField(max_length=10000, blank=True, null=True)
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    headnote = models.TextField(blank=True, null=True)
    raw_headnote = models.TextField(blank=True, null=True)
    public = models.BooleanField()
    casebook = models.ForeignKey('Casebook', models.DO_NOTHING, blank=True, null=True, related_name='contents')
    ordinals = ArrayField(models.IntegerField())
    copy_of = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True, related_name='clones')
    # In all instances, is_alias is null
    # is_alias = models.BooleanField(blank=True, null=True)
    resource_type = models.CharField(max_length=255)
    resource_id = models.BigIntegerField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    ancestry = models.CharField(max_length=255, blank=True, null=True, help_text="List of parent IDs in tree, separated by slashes.")
    playlist_id = models.BigIntegerField(blank=True, null=True)
    root_user = models.ForeignKey('User', blank=True, null=True, on_delete=models.SET_NULL, related_name='casebooks_and_clones')
    draft_mode_of_published_casebook = models.BooleanField(blank=True, null=True, help_text='Unknown (None) or True; never False')
    cloneable = models.BooleanField()

    # Can we make this relationship return casebook objects, not nodes?
    # I don't think so. Workaround: see "to_proxy"
    collaborators = models.ManyToManyField('User', through='ContentCollaborator', related_name='casebooks')

    class Meta:
        managed = False
        db_table = 'content_nodes'

    @property
    def type(self):
        if not self.casebook:
            return 'casebook'
        elif not self.resource_id:
            return 'section'
        else:
            return 'resource'

    def to_proxy(self):
        """
        A utility class for getting a Casebook, Section, or Resource object,
        if you have a ContentNode. Helpful for accessing methods specific
        to the proxy class, in a context where it is difficult to obtain
        the proxy objects directly.

        For instance, user.casebooks returns ContentNode objects, not Casebook objects
        """
        self.__class__ = globals()[self.type.capitalize()]
        return self

    @property
    def resource(self):
        if not self.resource_id:
            # or maybe return None?
            raise Exception("This node has no associated resource")
        if self.resource_type in ['Case', 'TextBlock', 'Default']:
            # so fancy...
            return globals()[self.resource_type].objects.get(id=self.resource_id)
        else:
            raise NotImplementedError

    def ordinal_string(self):
       return '.'.join(str(o) for o in self.ordinals)

    def ordinals_with_urls(self):
        return_value = []
        ordinals = []
        for o in self.ordinals:
            ordinals.append(o)
            return_value.append({
                'ordinal': o,
                'ordinals': [*ordinals],
                'url': globals()['ContentNode'].objects.get(
                    casebook_id=self.casebook_id,
                    ordinals=ordinals
                ).get_absolute_url()
            })
        return return_value

    def users_with_role(self, role):
        return self.collaborators.filter(contentcollaborator__role=role)

    @property
    def attributors(self):
        """ Users whose authorship should be attributed (as opposed to all having edit permission). """
        return self.collaborators.filter(contentcollaborator__has_attribution=True).order_by('-contentcollaborator__role')

    @property
    def editors(self):
        return self.users_with_role('editor')

    @property
    def owners(self):
        return self.users_with_role('owner')

    @property
    def owner(self):
        return self.owners.first()

    def has_collaborator(self, user):
        return self.collaborators.filter(pk=user.pk).exists()

    def get_absolute_url(self):
        t = self.type
        if t == 'casebook':
            return Casebook.get_absolute_url(self)
        elif t == 'section':
            return Section.get_absolute_url(self)
        elif t == 'resource':
            return Resource.get_absolute_url(self)
        else:
            raise NotImplementedError

    def get_title(self):
        t = self.type
        if t == 'casebook':
            return Casebook.get_title(self)
        elif t == 'section':
            return Section.get_title(self)
        elif t == 'resource':
            return Resource.get_title(self)
        else:
            raise NotImplementedError

    def __str__(self):
        return "{} ({})".format(self.get_title(), self.id)

    ###
    # compatibility for the rails Ancestry gem
    # see https://github.com/stefankroes/ancestry/blob/master/lib/ancestry/materialized_path.rb
    ###

    def child_ancestry(self):
        """ Return ancestry value for children of this node. """
        return "%s/%s" % (self.ancestry, self.pk) if self.ancestry else str(self.pk)

    def descendants(self):
        """ Return all descendants of this node. """
        return type(self).objects.filter(Q(ancestry=self.child_ancestry()) | Q(ancestry__startswith=self.child_ancestry()+"/"))

    def root(self):
        """ Return root node for this node, or None if no ancestors. """
        if not self.ancestry:
            return None
        return type(self).objects.get(pk=self.ancestry.split("/")[0])

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
            return self.root_user
        elif self.ancestry:
            return self.root().collaborators.filter(contentcollaborator__role='owner').first()

    def viewable_by(self, user):
        return self.public or self.editable_by(user)

    def editable_by(self, user):
        return user.is_authenticated and (self.has_collaborator(user) or user.is_superadmin)

    def get_absolute_url(self):
        return reverse('casebook', args=[{"id": self.id, "slug": slugify(self.get_title())}])

    def get_title(self):
        return self.title or "Untitled casebook"
        # Proposed: I dislike the ID number here
        # return self.title or "Untitled casebook #%s" % self.pk

    def drafts(self):
        """
            Return first existing draft.
            TODO: Should this be named "draft"? It only returns one, and logic should ensure that only one ever exists.
        """
        return self.clones.filter(draft_mode_of_published_casebook=True).first()


class SectionManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(casebook__isnull=False, resource_id__isnull=True)


class Section(ContentNode):
    class Meta:
        proxy = True

    objects = SectionManager()

    @property
    def contents(self):
        """
        See https://github.com/harvard-lil/h2o/blob/master/app/models/content/concerns/has_children.rb#L5
        """
        # Django syntax for inspecting a slice of an array field
        # https://docs.djangoproject.com/en/2.2/ref/contrib/postgres/fields/#slice-transforms
        # We want only nodes whose first ordinals match this section's.
        # That is, if this is section [2, 2], we want [2, 2, 1], [2, 2, 2, 7], etc.,
        # but not [2, 1, 1], [1,1], etc.
        first_ordinals = "ordinals__0_{}".format(len(self.ordinals))
        return ContentNode.objects.filter(**{
            "casebook": self.casebook,
            first_ordinals: self.ordinals,
            "ordinals__len__gte": len(self.ordinals) + 1
        }).order_by('ordinals')

    def get_absolute_url(self):
        return reverse('section', args=[
            {"id": self.casebook.id, "slug": slugify(self.casebook.get_title())},
            {"ordinals": self.ordinals, "slug": slugify(self.get_title())}
        ])

    def get_title(self):
        return self.title if self.title else "Untitled section"


class ResourceManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(casebook__isnull=False, resource_id__isnull=False)

class Resource(ContentNode):
    class Meta:
        proxy = True

    objects = ResourceManager()

    def get_absolute_url(self):
        return reverse('resource', args=[
            {"id": self.casebook.id, "slug": slugify(self.casebook.get_title())},
            {"ordinals": self.ordinals, "slug": slugify(self.get_title())}
        ])

    def get_title(self):
        if self.resource_type == 'Default':
            if self.resource.name:
                return self.resource.name
            else:
                return "Link to {}".format(urlparse(self.resource.url).netloc)
        elif self.resource_type == 'TextBlock':
            return self.resource.name
        elif self.resource_type == 'Case':
            return self.resource.get_name()
        else:
            raise NotImplementedError


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
    public = models.BooleanField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    content_type = models.CharField(max_length=255, blank=True, null=True)
    user = models.ForeignKey('User', on_delete=models.DO_NOTHING, related_name='defaults')
    ancestry = models.CharField(max_length=255, blank=True, null=True)
    created_via_import = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'defaults'

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='Default')


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


class RawContent(RailsModel):
    id = models.BigAutoField(primary_key=True)
    content = models.TextField(blank=True, null=True)
    source_type = models.CharField(max_length=50, blank=True, null=True)
    source_id = models.BigIntegerField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'raw_contents'
        unique_together = (('source_type', 'source_id'),)


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

    def __str__(self):
        if self.name == 'asker':
            return "{} ({} {})".format(self.name, self.authorizable_type, self.authorizable_id)
        return self.name


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
    data = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'sessions'


class TextBlock(RailsModel):
    name = models.CharField(max_length=255)
    content = models.CharField(max_length=5242880)
    public = models.BooleanField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    user = models.ForeignKey('User', blank=True, null=True, on_delete=models.DO_NOTHING)
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

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='TextBlock')


class UnpublishedRevision(RailsModel):
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
    verified_professor = models.BooleanField()
    professor_verification_requested = models.BooleanField()
    verified_email = models.BooleanField()

    roles = models.ManyToManyField(Role, through=RolesUser)

    class Meta:
        managed = False
        db_table = 'users'

    @property
    def email_domain(self):
        # TODO! In the meantime, return the full address
        # m = email_address.match /@(.+)$/
        # m.try(:[], 1) || '?.edu'
        return self.email_address

    @property
    def anonymous_name(self):
        return "{}#{}".format(self.email_domain, self.id)

    @property
    def display_name(self):
        """
            In rails this is also known as "display" and "simple_display"
        """
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

    def __str__(self):
        return self.display_name

    def non_draft_casebooks(self):
        """
            Casebooks, published or not, but excluding draft copies.
            Drafts of published casebooks should not show up on their own, but inline with the published casebook.
            Equivalent of Rails "owned_casebook_compacted"
        """
        return self.casebooks.filter(draft_mode_of_published_casebook=None)

    def published_casebooks(self):
        """
            Public casebooks owned by this user.
            Equivalent of Rails "user.owned.published"
        """
        return self.casebooks.filter(contentcollaborator__role='owner', public=True)


# make AnonymousUser API conform with User API
AnonymousUser.is_superadmin = False
