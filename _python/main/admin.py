from django import forms
from django.conf import settings
from django.contrib import admin
from django.db.models import Q, Count
from django.urls import reverse
from django.utils.html import format_html
from django.utils.safestring import mark_safe

from .utils import fix_after_rails, clone_model_instance
from .models import Case, CaseCourt, Default, User, Casebook, Section, \
    Resource, ContentCollaborator, ContentAnnotation, TextBlock, \
    Role, RolesUser



#
# Helpers
#

def edit_link(obj, as_str=False):
    """ Generate a link to the admin edit screen for the given object. """
    if not obj:
        return None
    url = reverse('admin:%s_%s_change' % (obj._meta.app_label,  obj._meta.model_name), args=[obj.id])
    if as_str:
        return format_html('<a href="{}">→{} ({})</a>', url, obj, obj.id)
    else:
        return format_html('<a href="{}">→{}</a>', url, obj.id)

#
# Admin site config
#

class CustomAdminSite(admin.AdminSite):
    site_header = 'H2O Admin'

admin_site = CustomAdminSite(name='h2oadmin')

# If using the default Django admin.SiteAdmin, rather than our custom class,
# we want to remove builtin models
# admin.site.unregister(Group)
# admin.site.unregister(BuiltInUser)

# change Django defaults, because 'extra' isn't helpful anymore now you can add more with javascript
admin.TabularInline.extra = 0
admin.StackedInline.extra = 0

# don't allow inline objects to be deleted or added by default:
admin.TabularInline.can_delete = False  # use True to allow deleting
admin.StackedInline.can_delete = False
admin.TabularInline.max_num = 0  # use max_num = None to allow adding
admin.StackedInline.max_num = 0


class BaseAdmin(admin.ModelAdmin):
    fix_after_rails("""
        The LogEntry class tracks additions, changes, and deletions of objects
        done through the admin interface. It requires the Django app to be
        fully integrated with the AUTH_USER_MODEL... which we aren't yet. So,
        for now, disable logging.
    """)
    def log_addition(self, request, object, message):
        pass
    def log_change(self, request, object, message):
        pass
    def log_deletion(self, request, object, object_repr):
        pass

    actions = None  # use ['delete_selected'] to allow delete action

    def has_add_permission(self, request):
        """
            Don't allow objects to be added by default. To override, use this on a subclass:

                def has_add_permission(self, request):
                    return super(BaseAdmin, self).has_add_permission(request)
        """
        return False

    def has_delete_permission(self, request, obj=None):
        """
            Don't allow objects to be deleted by default. To override, use this on a subclass:

                def has_delete_permission(self, request, obj=None):
                    return super(BaseAdmin, self).has_delete_permission(request, obj)
        """
        return False

#
# Filters
#

class InputFilter(admin.SimpleListFilter):
    """
    Text input filter, from:
    https://hakibenita.com/how-to-add-a-text-filter-to-django-admin
    """
    template = 'admin/input_filter.html'

    def lookups(self, request, model_admin):
        # Dummy, required to show the filter.
        return ((),)

    def choices(self, changelist):
        # Grab only the "all" option.
        all_choice = next(super().choices(changelist))
        all_choice['query_parts'] = (
            (k, v)
            for k, v in changelist.get_filters_params().items()
            if k != self.parameter_name
        )
        yield all_choice


class CasebookIdFilter(InputFilter):
    parameter_name = 'casebook'
    title = 'Casebook (by ID)'

    def queryset(self, request, queryset):
        value = self.value()
        if value is not None:
            return queryset.filter(casebook_id=value)


class CollaboratorNameFilter(InputFilter):
    parameter_name = 'collaborator-name'
    title = 'Collaborator (by name)'

    def queryset(self, request, queryset):
        value = self.value()
        if value is not None:
            users = User.objects.filter(Q(title__icontains=value) | Q(attribution__icontains=value))
            return queryset.filter(collaborators__in=users)


class CollaboratorIdFilter(InputFilter):
    parameter_name = 'collaborator-id'
    title = 'Collaborator (by id)'

    def queryset(self, request, queryset):
        value = self.value()
        if value is not None:
            users = User.objects.filter(id=value)
            return queryset.filter(collaborators__in=users)


class CourtIdFilter(InputFilter):
    parameter_name = 'court-id'
    title = 'Court (by id)'

    def queryset(self, request, queryset):
        value = self.value()
        if value is not None:
            return queryset.filter(case_court=value)


class ResourceIdFilter(InputFilter):
    parameter_name = 'resource-id'
    title = 'Resource (by id)'

    def queryset(self, request, queryset):
        value = self.value()
        if value is not None:
            return queryset.filter(resource_id=value)


class RoleNameFilter(InputFilter):
    parameter_name = 'role'
    title = 'Role'

    def queryset(self, request, queryset):
        value = self.value()
        if value is not None:
            return queryset.filter(roles__name__icontains=value)


#
# Inlines
#

class CollaboratorInline(admin.TabularInline):
    model = ContentCollaborator
    fields = ['role', 'user', 'content', 'has_attribution']
    raw_id_fields = ['user', 'content']
    max_num = None
    can_delete = True


class AnnotationInline(admin.TabularInline):
    model = ContentAnnotation
    readonly_fields = ['id', 'created_at', 'updated_at', 'start_paragraph', 'end_paragraph', 'start_offset', 'end_offset', 'kind']
    fields = ['id', 'resource', ('global_start_offset', 'global_end_offset'), ('start_paragraph', 'end_paragraph'), ('start_offset', 'end_offset'), 'kind', 'content', 'created_at', 'updated_at']
    raw_id_fields = ['resource']
    ordering = ['global_start_offset',  'global_end_offset']
    max_num = None
    can_delete = True

    def formfield_for_dbfield(self, db_field, **kwargs):
        formfield = super().formfield_for_dbfield(db_field, **kwargs)
        if db_field.name == 'content':
            formfield.widget = forms.TextInput(attrs=formfield.widget.attrs)
        return formfield


class RolesUserInline(admin.TabularInline):
    model = RolesUser
    list_select_related = ['user', 'role']
    fields = ['user', 'role']
    raw_id_fields = ['user', 'role']
    max_num = None
    can_delete = True

    verbose_name = "Role"
    verbose_name_plural = "Roles (e.g. superadmin, caseadmin)"


#
# Admins
#


## Casebooks

class CasebookAdmin(BaseAdmin):
    list_display = ['id', 'get_title', 'owner_link', 'public', 'source', 'draft_link', 'root_user', 'created_at', 'updated_at']
    list_filter = [CollaboratorNameFilter, CollaboratorIdFilter, 'public', 'draft_mode_of_published_casebook']
    search_fields = ['title']

    fields = ['title', 'subtitle', 'public', 'draft_mode_of_published_casebook', 'source', 'draft_link', 'ancestry', 'root_user', 'headnote', 'playlist_id', 'created_at', 'updated_at']
    readonly_fields = ['created_at', 'updated_at', 'owner_link', 'source', 'draft_link', 'ancestry', 'root_user', 'playlist_id']
    raw_id_fields = ['collaborators', 'copy_of', 'root_user', 'casebook']
    inlines = [CollaboratorInline]

    def save_model(self, request, obj, form, change):
        # Workaround -- we need to make some changes after save_related, but save_related can't access the object being
        # saved. Attach it to request here so we can access it later.
        super().save_model(request, obj, form, change)
        request.saved_obj = obj

    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)

        # Updating the collaborators on a casebook also updates the collaborators on a current draft, and vice versa.
        # Copy current collaborators from the saved object to its draft/draft_of:
        # TODO: testing the admin is tricky; this would be a good candidate for integration testing
        saved_obj = request.saved_obj
        other_casebook = saved_obj.draft or saved_obj.draft_of
        if other_casebook:
            other_casebook.contentcollaborator_set.all().delete()
            roles = saved_obj.contentcollaborator_set.prefetch_related(None)  # prefetch_related cancels out an earlier prefetch so we see fresh results
            ContentCollaborator.objects.bulk_create(clone_model_instance(c, content=other_casebook) for c in roles)

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('root_user', 'copy_of').prefetch_related('contentcollaborator_set__user').prefetch_draft()

    def owner_link(self, obj):
        return edit_link(obj.owner, True)
    owner_link.short_description = 'owner'

    def draft_link(self, obj):
        return edit_link(obj.draft)
    draft_link.short_description = 'draft'

    def source(self, obj):
        if obj.copy_of:
            return mark_safe('draft&nbsp;of' if obj.draft_mode_of_published_casebook else 'copy&nbsp;of') + edit_link(obj.copy_of)
    source.short_description = 'source'


class SectionAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'owner_link', 'casebook_link', 'copy_of', 'ordinals']
    list_select_related = ['casebook', 'copy_of']
    list_display = ['id', 'casebook_link', 'owner_link', 'get_title', 'ordinals', 'created_at', 'updated_at']
    list_filter = [CasebookIdFilter]
    search_fields = ['title', 'casebook__title']
    fields = ['casebook', 'ordinals', 'title', 'subtitle', 'copy_of', 'headnote', 'created_at', 'updated_at']
    raw_id_fields = ['collaborators', 'copy_of', 'root_user', 'casebook']

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('casebook', 'copy_of').prefetch_related('casebook__contentcollaborator_set__user')

    def owner_link(self, obj):
        return edit_link(obj.casebook.owner, True)
    owner_link.short_description = 'owner'

    def casebook_link(self, obj):
        return edit_link(obj.casebook, True)
    casebook_link.short_description = 'casebook'


class ResourceAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'owner_link', 'casebook_link', 'copy_of', 'resource_id', 'resource_type', 'ordinals']
    list_select_related = ['casebook', 'copy_of']
    list_display = ['id', 'casebook_link', 'owner_link', 'get_title', 'ordinals', 'resource_type', 'resource_id', 'annotation_count', 'created_at', 'updated_at']
    list_filter = [CasebookIdFilter, 'resource_type', ResourceIdFilter]
    search_fields = ['title', 'casebook__title']
    fields = ['casebook', 'ordinals', 'title', 'subtitle', 'copy_of', 'headnote', 'created_at', 'updated_at']
    raw_id_fields = ['collaborators', 'copy_of', 'root_user', 'casebook']
    inlines = [AnnotationInline]

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('casebook', 'copy_of').prefetch_related('casebook__contentcollaborator_set__user').annotate(annotations_count=Count('annotations'))

    def owner_link(self, obj):
        return edit_link(obj.casebook.owner, True)
    owner_link.short_description = 'owner'

    def casebook_link(self, obj):
        return edit_link(obj.casebook, True)
    casebook_link.short_description = 'casebook'

    def annotation_count(self, obj):
        return 'n/a' if obj.resource_type == 'Default' else obj.annotations_count


class AnnotationsAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'start_paragraph', 'end_paragraph', 'start_offset', 'end_offset', 'kind']
    fields = ['resource', ('global_start_offset', 'global_end_offset'), ('start_paragraph', 'end_paragraph'), ('start_offset', 'end_offset'), 'kind', 'content', 'created_at', 'updated_at']
    list_select_related = ['resource']
    list_display = ['id', 'resource_type', 'resource_id', 'kind', 'created_at', 'updated_at']
    list_filter = ['resource__resource_type']
    raw_id_fields = ['resource']

    def resource_type(self, obj):
        return obj.resource.resource_type
    resource_type.admin_order_field = 'resource__resource_type'

    def resource_id(self, obj):
        return obj.resource.resource_id
    resource_id.admin_order_field = 'resource__resource_id'


## Resources

class CaseAdmin(BaseAdmin):
    # Content is readonly until we implement the annotation-shifting logic on the python side
    readonly_fields = ['created_at', 'updated_at', 'content']
    list_select_related = ['case_court']
    list_display = ['id', 'name_abbreviation', 'public', 'capapi_link', 'created_via_import', 'related_resources', 'live_annotations_count', 'court_link', 'created_at', 'updated_at']
    list_filter = ['public', 'created_via_import', CourtIdFilter]
    search_fields = ['name_abbreviation', 'name']
    raw_id_fields = ['case_court']
    exclude = ('annotations_count',)

    def formfield_for_dbfield(self, db_field, **kwargs):
        formfield = super().formfield_for_dbfield(db_field, **kwargs)
        if db_field.name == 'content':
            formfield.widget = forms.Textarea(attrs=formfield.widget.attrs)
        return formfield

    def capapi_link(self, obj):
        if obj.capapi_id:
            return  format_html(
                '<a target="_blank" href="{}">{}</a>',
                settings.CAPAPI_CASE_URL_FSTRING.format(obj.capapi_id),
                obj.capapi_id
            )
    capapi_link.short_description = 'capapi id'

    def court_link(self, obj):
        return edit_link(obj.case_court)
    court_link.short_description = 'court'
    court_link.admin_order_field = 'case_court'

    def related_resources(self, obj):
        return format_html(
            '<a href="{}?resource_type=Case&resource-id={}">{}</a>',
            reverse('admin:main_resource_changelist'),
            obj.id,
            obj.related_resources().count()
        )

    def live_annotations_count(self, obj):
        return obj.related_annotations().count()
    live_annotations_count.short_description = 'Annotations'


class DefaultAdmin(BaseAdmin):
    # reminder that a "Default" is a Link Resource
    readonly_fields = ['created_at', 'updated_at', 'user_link', 'user', 'ancestry']
    list_select_related = ['user']
    list_display = ['id', 'name', 'url', 'public', 'related_resources', 'created_at', 'updated_at', 'content_type', 'user_link', 'ancestry', 'created_via_import']
    list_filter = ['public', 'content_type', 'created_via_import']
    search_fields = ['name', 'url']
    fields = ['name', 'url', 'description', 'public', 'created_at', 'updated_at', 'content_type', 'user', 'ancestry', 'created_via_import']

    def user_link(self, obj):
        return edit_link(obj.user, True)
    user_link.short_description = 'user'

    def related_resources(self, obj):
        return format_html(
            '<a href="{}?resource_type=Default&resource-id={}">{}</a>',
            reverse('admin:main_resource_changelist'),
            obj.id,
            obj.related_resources().count()
        )


class TextBlockAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'user', 'version']
    list_select_related = ['user']
    list_display = ['id', 'name', 'user_link', 'public', 'created_via_import', 'version', 'related_resources', 'live_annotations_count', 'created_at', 'updated_at']
    list_filter = ['version', 'created_via_import']
    fields = ['name', 'description', 'user', 'public', 'created_via_import', 'content', 'version', 'created_at', 'updated_at']

    def formfield_for_dbfield(self, db_field, **kwargs):
        formfield = super().formfield_for_dbfield(db_field, **kwargs)
        if db_field.name == 'content':
            formfield.widget = forms.Textarea(attrs=formfield.widget.attrs)
        return formfield

    def user_link(self, obj):
        return edit_link(obj.user, True)
    user_link.short_description = 'user'

    def related_resources(self, obj):
        return format_html(
            '<a href="{}?resource_type=TextBlock&resource-id={}">{}</a>',
            reverse('admin:main_resource_changelist'),
            obj.id,
            obj.related_resources().count()
        )

    def live_annotations_count(self, obj):
        return obj.related_annotations().count()
    live_annotations_count.short_description = 'Annotations'

## Users

class UserAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'display_name', 'last_request_at', 'last_login_at', 'login_count', 'login']
    list_display = ['id', 'display_name', 'login', 'email_address', 'verified_email', 'professor_verification_requested', 'verified_professor', 'get_roles', 'last_request_at', 'last_login_at', 'login_count', 'created_at', 'updated_at']
    list_filter = ['verified_email', 'verified_professor', 'professor_verification_requested', RoleNameFilter]
    search_fields = ['attribution', 'title', 'email_address']
    fields = ['title', 'attribution', 'login', 'email_address', 'verified_email', 'professor_verification_requested', 'verified_professor', 'affiliation', 'last_request_at', 'last_login_at', 'login_count', 'created_at', 'updated_at']
    inlines = [RolesUserInline]

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related('roles')

    def get_roles(self, obj):
        return ','.join(str(o) for o in set(r.name for r in obj.roles.all())) or None
    get_roles.short_description = 'Roles'

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)


class RolesUserAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'role', 'user']
    list_select_related = ['user', 'role']
    list_display = ['id', 'user', 'role', 'created_at', 'updated_at']
    list_filter = ['role__name']
    raw_id_fields = ['user', 'role']


class RoleAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'authorizable_type', 'authorizable_id']
    list_display = ['id', 'name', 'authorizable_type', 'authorizable_id', 'created_at', 'updated_at']
    list_filter = ['name', 'authorizable_type']
    ordering = ['-name']


class CollaboratorsAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'user', 'content']
    list_select_related = ['user', 'content']
    list_display = ['user', 'role']
    list_filter = ['role']
    ordering = ['role']
    raw_id_fields = ['user', 'content']


## Courts

class CaseCourtAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'capapi_link']
    list_display = ['id', 'name', 'name_abbreviation', 'created_at', 'case_count_link', 'updated_at', 'capapi_link']
    search_fields = ['name_abbreviation', 'name']

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(case_count=Count('cases'))

    def case_count(self, obj):
        return obj.case_count
    case_count.admin_order_field = 'case_count'

    def case_count_link(self, obj):
        return format_html(
            '<a href="{}?court-id={}">{}</a>',
            reverse('admin:main_case_changelist'),
            obj.id,
            obj.case_count
        )
    case_count_link.short_description = 'cases'
    case_count_link.admin_order_field = 'case_count'

    def capapi_link(self, obj):
        if obj.capapi_id:
            return  format_html(
                '<a target="_blank" href="{}">{}</a>',
                settings.CAPAPI_COURT_URL_FSTRING.format(obj.capapi_id),
                obj.capapi_id
            )
    capapi_link.short_description = 'capapi id'


# Register models on our CustomAdmin instance.
admin_site.register(Casebook, CasebookAdmin)
admin_site.register(Section, SectionAdmin)
admin_site.register(Resource, ResourceAdmin)
admin_site.register(ContentAnnotation, AnnotationsAdmin)
admin_site.register(Case, CaseAdmin)
admin_site.register(Default, DefaultAdmin)
admin_site.register(TextBlock, TextBlockAdmin)
admin_site.register(User, UserAdmin)
admin_site.register(RolesUser, RolesUserAdmin)
admin_site.register(Role, RoleAdmin)
admin_site.register(ContentCollaborator, CollaboratorsAdmin)
admin_site.register(CaseCourt, CaseCourtAdmin)
