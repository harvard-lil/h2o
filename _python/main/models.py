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


class TimestampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


# Internal

class ArInternalMetadata(TimestampedModel):
    key = models.CharField(primary_key=True, max_length=255)
    value = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'ar_internal_metadata'

class SchemaMigration(models.Model):
    version = models.CharField(primary_key=True, max_length=255)

    class Meta:
        # managed = False
        db_table = 'schema_migrations'


class Session(TimestampedModel):
    data = models.TextField(blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'sessions'


# Application

class CaseCourt(TimestampedModel):
    name_abbreviation = models.CharField(max_length=150, blank=True, null=True)
    name = models.CharField(max_length=500, blank=True, null=True)
    capapi_id = models.IntegerField(blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'case_courts'


class Case(TimestampedModel):
    name_abbreviation = models.CharField(max_length=150)
    name = models.CharField(max_length=10000, blank=True, null=True)
    decision_date = models.DateField(blank=True, null=True)
    public = models.BooleanField()
    created_via_import = models.BooleanField()
    capapi_id = models.IntegerField(blank=True, null=True)
    attorneys = JSONField(blank=True, null=True)
    parties = JSONField(blank=True, null=True)
    opinions = JSONField(blank=True, null=True)
    citations = JSONField(blank=True, null=True)
    docket_number = models.CharField(max_length=20000, blank=True, null=True)
    header_html = models.CharField(max_length=15360, blank=True, null=True)
    content = models.CharField(max_length=5242880)
    annotations_count = models.IntegerField()

    case_court = models.ForeignKey('CaseCourt', models.PROTECT, related_name='cases')

    class Meta:
        # managed = False
        db_table = 'cases'

    def get_name(self):
        return self.name_abbreviation if self.name_abbreviation else self.name

    def __str__(self):
        return self.get_name()

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='Case')


class ContentAnnotation(TimestampedModel):
    start_paragraph = models.IntegerField()
    end_paragraph = models.IntegerField(blank=True, null=True)
    start_offset = models.IntegerField()
    end_offset = models.IntegerField()
    kind = models.CharField(max_length=2255)
    content = models.TextField(blank=True, null=True)
    global_start_offset = models.IntegerField(blank=True, null=True)
    global_end_offset = models.IntegerField(blank=True, null=True)

    resource = models.ForeignKey('ContentNode', models.PROTECT, related_name='annotations')

    class Meta:
        # managed = False
        db_table = 'content_annotations'


class ContentCollaborator(TimestampedModel):
    role = models.CharField(
        max_length=255,
        choices = (('owner', 'owner'), ('editor', 'editor'))
    )
    has_attribution = models.BooleanField()

    user = models.ForeignKey('User', models.CASCADE)
    content = models.ForeignKey('ContentNode', models.CASCADE)

    class Meta:
        # managed = False
        db_table = 'content_collaborators'
        unique_together = (('user', 'content'),)


class ContentNodeQueryset(models.QuerySet):
    """
        This queryset allows us to do ContentNode.objects.prefetch_resources() so that fetched content nodes will
        efficiently have their content_node.resource attribute pre-populated, using a total of three queries instead
        of one query per instance. This is based on the implementation of prefetch_related().

        Given:
        >>> full_casebook, django_assert_num_queries = [getfixture(f) for f in ['full_casebook', 'django_assert_num_queries']]
        >>> section = Section.objects.filter(casebook=full_casebook).first()

        Fetching all resources normally will take a linear number of queries -- each c.resource hits the DB:
        >>> with django_assert_num_queries(2+6):
        ...     resources = [c.resource for c in section.contents.all()]

        We can reduce to a constant number of queries -- 1 each to fetch Case, TextBlock, and Default items:
        >>> with django_assert_num_queries(1+3):
        ...     resources = [c.resource for c in section.contents.prefetch_resources()]

        Custom querysets for the Case, TextBlock, and Default items can be provided to further reduce queries:
        >>> with django_assert_num_queries(1+3+1):
        ...     resources = [c.resource for c in section.contents.prefetch_resources(case_query=Case.objects.select_related('case_court'))]
        ...     courts = [c.case_court for c in resources if type(c) == Case]
    """

    # keep track of input values from prefetch_resources()
    _prefetch_resources_done = False
    _prefetch_resources = None

    def prefetch_resources(self, case_query=None, textblock_query=None, link_query=None):
        """
            Return cloned queryset with attributes to trigger prefetching in _fetch_all.
        """
        clone = self._chain()
        clone._prefetch_resources = [case_query, textblock_query, link_query]
        return clone

    def _clone(self):
        """
            Ensure that prefetch_resources() attributes survive cloning.
        """
        c = super()._clone()
        c._prefetch_resources = self._prefetch_resources
        return c

    def _fetch_all(self):
        """
            Do the actual work: get IDs for all items in _result_cache, prefetch related Case/TextBlock/Default objects,
            and store them in each item's _resource attribute.
        """
        super()._fetch_all()
        if self._prefetch_resources and not self._prefetch_resources_done:
            self._prefetch_resources_done = True
            if not self._result_cache:
                return
            case_query, textblock_query, link_query = self._prefetch_resources
            case_query = case_query or Case.objects.all()
            textblock_query = textblock_query or TextBlock.objects.all()
            link_query = link_query or Default.objects.all()
            resources = {}
            for resource_type, query in (('Case', case_query), ('TextBlock', textblock_query), ('Default', link_query)):
                for obj in query.filter(id__in=[obj.resource_id for obj in self._result_cache if obj.resource_type == resource_type]):
                    resources[(resource_type, obj.id)] = obj
            for content_node in self._result_cache:
                if content_node.resource_id:
                    content_node._resource = resources.get((content_node.resource_type, content_node.resource_id))
                    content_node._resource_prefetched = True


class ContentNode(TimestampedModel):
    title = models.CharField(max_length=10000, blank=True, null=True)
    slug = models.CharField(max_length=10000, blank=True, null=True)
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    public = models.BooleanField()
    cloneable = models.BooleanField()
    draft_mode_of_published_casebook = models.BooleanField(blank=True, null=True, help_text='Unknown (None) or True; never False')
    ancestry = models.CharField(max_length=255, blank=True, null=True, help_text="List of parent IDs in tree, separated by slashes.")
    ordinals = ArrayField(models.IntegerField())
    headnote = models.TextField(blank=True, null=True)
    raw_headnote = models.TextField(blank=True, null=True)

    casebook = models.ForeignKey('Casebook', models.CASCADE, blank=True, null=True, related_name='contents')
    copy_of = models.ForeignKey('self', models.PROTECT, blank=True, null=True, related_name='clones')
    root_user = models.ForeignKey('User', blank=True, null=True, on_delete=models.PROTECT, related_name='casebooks_and_clones')
    # These fields define a relationship with a Case, Default, or Textblock
    # not yet described/available via the Django ORM
    resource_type = models.CharField(max_length=255, blank=True, null=True)
    resource_id = models.BigIntegerField(blank=True, null=True)
    # Can we make this relationship return casebook objects, not nodes?
    # I don't think so. Workaround: see "to_proxy"
    collaborators = models.ManyToManyField('User', through='ContentCollaborator', related_name='casebooks')

    # legacy fields, I believe
    is_alias = models.BooleanField(blank=True, null=True)
    playlist_id = models.BigIntegerField(blank=True, null=True)

    objects = ContentNodeQueryset.as_manager()

    class Meta:
        # managed = False
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

    _resource_prefetched = False
    _resource = None
    @property
    def resource(self):
        if self._resource_prefetched:
            return self._resource
        if not self.resource_id:
            return None
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

    def descendants(self):
        """
            Return all descendants of this node.

            >>> root, c_1, c_2, c_1_1, c_1_2 = getfixture('content_node_tree')
            >>> assert set(root.descendants()) == {c_1, c_2, c_1_1, c_1_2}
            >>> assert set(c_1.descendants()) == {c_1_1, c_1_2}
            >>> assert set(c_2.descendants()) == set()
        """
        child_ancestry = "%s/%s" % (self.ancestry, self.pk) if self.ancestry else str(self.pk)
        return type(self).objects.filter(Q(ancestry=child_ancestry) | Q(ancestry__startswith=child_ancestry+"/"))

    def root(self):
        """
            Return root node for this node, or None if no ancestors.

            >>> root, c_1, c_2, c_1_1, c_1_2 = getfixture('content_node_tree')
            >>> assert root.root() is None
            >>> assert c_1.root() == root
            >>> assert c_1_1.root() == root
        """
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

class Default(TimestampedModel):
    """
    These are actually Link Resource
    """
    name = models.CharField(max_length=1024, blank=True, null=True)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    url = models.CharField(max_length=1024)
    public = models.BooleanField()
    content_type = models.CharField(max_length=255, blank=True, null=True)
    ancestry = models.CharField(max_length=255, blank=True, null=True)
    created_via_import = models.BooleanField()

    # the person who created the TextBlock. what's the correct on_delete here?
    user = models.ForeignKey('User', on_delete=models.PROTECT, related_name='defaults')

    class Meta:
        # managed = False
        db_table = 'defaults'

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='Default')


class RawContent(TimestampedModel):
    id = models.BigAutoField(primary_key=True)
    content = models.TextField(blank=True, null=True)
    source_type = models.CharField(max_length=50, blank=True, null=True)
    source_id = models.BigIntegerField(blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'raw_contents'
        unique_together = (('source_type', 'source_id'),)


class Role(TimestampedModel):
    """
        User roles.
    """
    name = models.CharField(max_length=40, blank=True, null=True)
    authorizable_type = models.CharField(max_length=40, blank=True, null=True)
    authorizable_id = models.IntegerField(blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'roles'

    def __str__(self):
        if self.name == 'asker':
            return "{} ({} {})".format(self.name, self.authorizable_type, self.authorizable_id)
        return self.name


class RolesUser(TimestampedModel):
    """
        Join table for User and Role.
    """
    user = models.ForeignKey('User', blank=True, null=True, on_delete=models.CASCADE)
    role = models.ForeignKey(Role, blank=True, null=True, on_delete=models.CASCADE)

    class Meta:
        # managed = False
        db_table = 'roles_users'


class TextBlock(TimestampedModel):
    name = models.CharField(max_length=255)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    content = models.CharField(max_length=5242880)
    version = models.IntegerField()
    public = models.BooleanField(blank=True, null=True)
    created_via_import = models.BooleanField()
    annotations_count = models.IntegerField()

    # the person who created the TextBlock. what's the correct on_delete here?
    # don't know what it means currently when blank/null
    user = models.ForeignKey('User', blank=True, null=True, on_delete=models.PROTECT)

    # legacy fields, I believe
    enable_feedback = models.BooleanField()
    enable_discussions = models.BooleanField()
    enable_responses = models.BooleanField()

    class Meta:
        # managed = False
        db_table = 'text_blocks'

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='TextBlock')


class UnpublishedRevision(TimestampedModel):
    field = models.CharField(max_length=255)
    value = models.CharField(max_length=50000, blank=True, null=True)

    node = models.ForeignKey('ContentNode', on_delete=models.CASCADE, related_name='revisions', help_text='Node in the draft.')
    node_parent = models.ForeignKey('ContentNode', on_delete=models.CASCADE, related_name='draft_revisions', help_text='Corresponding node in the original, published casebook.')
    # I'm not sure why this is stored separately; redundant with node?
    casebook = models.ForeignKey('Casebook', on_delete=models.CASCADE, related_name='casebook_revisions', help_text='The draft casebook.')
    # I'm not sure that this field is in use, presently.
    annotation = models.ForeignKey('ContentAnnotation', blank=True, null=True, on_delete=models.CASCADE)

    class Meta:
        # managed = False
        db_table = 'unpublished_revisions'


class User(TimestampedModel):
    login = models.CharField(max_length=255, blank=True, null=True, unique=True)
    email_address = models.CharField(max_length=255, blank=True, null=True)
    title = models.CharField(max_length=255, blank=True, null=True)
    attribution = models.CharField(max_length=255)
    affiliation = models.CharField(max_length=255, blank=True, null=True)
    verified_email = models.BooleanField()
    verified_professor = models.BooleanField()
    professor_verification_requested = models.BooleanField()

    # used to assign super_admin or case_admin status
    roles = models.ManyToManyField(Role, through=RolesUser)

    # calculated
    login_count = models.IntegerField()
    last_request_at = models.DateTimeField(blank=True, null=True)
    last_login_at = models.DateTimeField(blank=True, null=True)
    current_login_at = models.DateTimeField(blank=True, null=True)
    last_login_ip = models.CharField(max_length=255, blank=True, null=True)
    current_login_ip = models.CharField(max_length=255, blank=True, null=True)

    # auth/crypto innards
    crypted_password = models.CharField(max_length=255, blank=True, null=True)
    password_salt = models.CharField(max_length=255, blank=True, null=True)
    persistence_token = models.CharField(max_length=255)
    oauth_token = models.CharField(max_length=255, blank=True, null=True)
    oauth_secret = models.CharField(max_length=255, blank=True, null=True)
    perishable_token = models.CharField(max_length=255, blank=True, null=True)

    # all legacy fields, I believe
    tz_name = models.CharField(max_length=255, blank=True, null=True)
    url = models.CharField(max_length=255, blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    canvas_id = models.CharField(max_length=255, blank=True, null=True)
    default_font = models.CharField(max_length=255, blank=True, null=True)
    default_font_size = models.CharField(max_length=255, blank=True, null=True)
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

    class Meta:
        # managed = False
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

    @property
    def is_staff(self):
        return self.is_superadmin

    # methods replicating Django's PermissionsMixin,
    # necessary for the Django admin to work
    # https://docs.djangoproject.com/en/2.2/topics/auth/customizing/#custom-users-and-permissions

    @property
    def is_superuser(self):
        return self.is_superadmin

    def has_perm(self, perm, obj=None):
        return self.is_superuser

    def has_module_perms(self, app_label):
        return self.is_superuser

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
