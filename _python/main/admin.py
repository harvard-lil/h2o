from django import forms
from django.conf import settings
from django.contrib import admin
from django.contrib.auth.models import Group
from django.contrib.auth.models import User as BuiltInUser
from django.db.models import Q, Count
from django.urls import reverse
from django.utils.html import format_html

from .models import Case, CaseCourt, Default, User, Casebook, Section, \
    Resource, ContentCollaborator, ContentAnnotation, TextBlock, \
    Role, RolesUser


# remove builtin models
admin.site.unregister(Group)
admin.site.unregister(BuiltInUser)


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
    readonly_fields = ['created_at', 'updated_at']
    raw_id_fields = ['user', 'content']
    extra = 0


class AnnotationInline(admin.TabularInline):
    model = ContentAnnotation
    readonly_fields = ['created_at', 'updated_at', 'start_paragraph', 'end_paragraph', 'start_offset', 'end_offset', 'kind']
    fields = ['resource', ('global_start_offset', 'global_end_offset'), ('start_paragraph', 'end_paragraph'), ('start_offset', 'end_offset'), 'kind', 'content', 'created_at', 'updated_at']
    raw_id_fields = ['resource']
    extra = 0
    ordering = ['global_start_offset',  'global_end_offset']

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
    extra = 0


#
# Admins
#


class NonLoggingAdmin(admin.ModelAdmin):
    """
    The LogEntry class tracks additions, changes, and deletions of objects
    done through the admin interface. It requires the Django app to be
    fully integrated with the AUTH_USER_MODEL... which we aren't yet. So,
    for now, disable logging.
    """
    def log_addition(self, request, object, message):
        pass

    def log_change(self, request, object, message):
        pass

    def log_deletion(self, request, object, object_repr):
        pass


## Casebooks

@admin.register(Casebook)
class CasebookAdmin(NonLoggingAdmin):
    readonly_fields = ['created_at', 'updated_at', 'owner_link', 'clone_of', 'copy_of', 'ancestry', 'root_user', 'playlist_id']
    list_select_related = ['root_user', 'copy_of']
    list_display = ['id', 'get_title', 'owner_link', 'public', 'draft_mode_of_published_casebook', 'clone_of', 'root_user', 'created_at', 'updated_at']
    list_filter = [CollaboratorNameFilter, CollaboratorIdFilter, 'public', 'draft_mode_of_published_casebook']
    search_fields = ['title']
    fields = ['title', 'subtitle', 'public', 'draft_mode_of_published_casebook', 'copy_of', 'ancestry', 'root_user', 'headnote', 'playlist_id', 'created_at', 'updated_at']
    raw_id_fields = ['collaborators', 'copy_of', 'root_user', 'casebook']
    inlines = [CollaboratorInline]

    def owner_link(self, obj):
        if obj.owner:
            return format_html(
                '<a href="{}">{} ({})</a>',
                reverse('admin:main_user_change', args=(obj.owner.id,)),
                obj.owner.display_name,
                obj.owner.id
            )
    owner_link.short_description = 'owner'

    def clone_of(self, obj):
        if obj.copy_of:
            return format_html(
                '<a href="{}">{}</a>',
                reverse('admin:main_casebook_change', args=(obj.copy_of.id,)),
                str(obj.copy_of)
            )
    clone_of.short_description = 'copy of'


@admin.register(Section)
class SectionAdmin(NonLoggingAdmin):
    readonly_fields = ['created_at', 'updated_at', 'owner_link', 'casebook_link', 'copy_of']
    list_select_related = ['casebook', 'copy_of']
    list_display = ['id', 'casebook_link', 'owner_link', 'get_title', 'ordinals', 'created_at', 'updated_at']
    list_filter = [CasebookIdFilter]
    search_fields = ['title', 'casebook__title']
    fields = ['casebook', 'ordinals', 'title', 'subtitle', 'copy_of', 'headnote', 'created_at', 'updated_at']
    raw_id_fields = ['collaborators', 'copy_of', 'root_user', 'casebook']

    def owner_link(self, obj):
        if obj.casebook.owner:
            return format_html(
                '<a href="{}">{} ({})</a>',
                reverse('admin:main_user_change', args=(obj.casebook.owner.id,)),
                obj.casebook.owner.display_name,
                obj.casebook.owner.id
            )
    owner_link.short_description = 'owner'

    def casebook_link(self, obj):
        return format_html(
            '<a href="{}">{}</a>',
            reverse('admin:main_casebook_change', args=(obj.casebook.id,)),
            str(obj.casebook)
        )
    casebook_link.short_description = 'casebook'


@admin.register(Resource)
class ResourceAdmin(NonLoggingAdmin):
    readonly_fields = ['created_at', 'updated_at', 'owner_link', 'casebook_link', 'copy_of', 'resource_id', 'resource_type']
    list_select_related = ['casebook', 'copy_of']
    list_display = ['id', 'casebook_link', 'owner_link', 'get_title', 'ordinals', 'resource_type', 'resource_id', 'annotation_count', 'created_at', 'updated_at']
    list_filter = [CasebookIdFilter, 'resource_type', ResourceIdFilter]
    search_fields = ['title', 'casebook__title']
    fields = ['casebook', 'ordinals', 'title', 'subtitle', 'copy_of', 'headnote', 'created_at', 'updated_at']
    raw_id_fields = ['collaborators', 'copy_of', 'root_user', 'casebook']
    inlines = [AnnotationInline]

    def owner_link(self, obj):
        if obj.casebook.owner:
            return format_html(
                '<a href="{}">{} ({})</a>',
                reverse('admin:main_user_change', args=(obj.casebook.owner.id,)),
                obj.casebook.owner.display_name,
                obj.casebook.owner.id
            )
    owner_link.short_description = 'owner'

    def casebook_link(self, obj):
        return format_html(
            '<a href="{}">{} ({})</a>',
            reverse('admin:main_casebook_change', args=(obj.casebook.id,)),
            obj.casebook.get_title(),
            obj.casebook.id
        )
    casebook_link.short_description = 'casebook'

    def annotation_count(self, obj):
        # This makes a lot of database queries, but I can't think of a
        # better way, with the current models
        if obj.resource_type == 'Default':
            return None
        return obj.annotations.count()


@admin.register(ContentAnnotation)
class AnnotationsAdmin(NonLoggingAdmin):
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

@admin.register(Case)
class CaseAdmin(NonLoggingAdmin):
    readonly_fields = ['created_at', 'updated_at', 'annotations_count']
    list_select_related = ['case_court']
    list_display = ['id', 'name_abbreviation', 'public', 'capapi_link', 'created_via_import', 'related_resources', 'annotations_count', 'court_link', 'created_at', 'updated_at']
    list_filter = ['public', 'created_via_import', CourtIdFilter]
    search_fields = ['name_abbreviation', 'name']
    raw_id_fields = ['case_court']


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
        return format_html(
            '<a href="{}">{}</a>',
            reverse('admin:main_casecourt_change', args=(obj.case_court.id,)),
            obj.case_court.id
        )
    court_link.short_description = 'court'
    court_link.admin_order_field = 'court'

    def related_resources(self, obj):
        return format_html(
            '<a href="{}?resource_type=Case&resource-id={}">{}</a>',
            reverse('admin:main_resource_changelist'),
            obj.id,
            obj.related_resources().count()
        )


@admin.register(Default)
class DefaultAdmin(NonLoggingAdmin):
    # reminder that a "Default" is a Link Resource
    readonly_fields = ['created_at', 'updated_at', 'user_link', 'user', 'ancestry']
    list_select_related = ['user']
    list_display = ['id', 'name', 'url', 'public', 'related_resources', 'created_at', 'updated_at', 'content_type', 'user_link', 'ancestry', 'created_via_import']
    list_filter = ['public', 'content_type', 'created_via_import']
    search_fields = ['name', 'url']
    fields = ['name', 'url', 'description', 'public', 'created_at', 'updated_at', 'content_type', 'user', 'ancestry', 'created_via_import']

    def user_link(self, obj):
        return format_html(
            '<a href="{}">{} ({})</a>',
            reverse('admin:main_user_change', args=(obj.user.id,)),
            obj.user.display_name,
            obj.user.id
        )
    user_link.short_description = 'user'

    def related_resources(self, obj):
        return format_html(
            '<a href="{}?resource_type=Default&resource-id={}">{}</a>',
            reverse('admin:main_resource_changelist'),
            obj.id,
            obj.related_resources().count()
        )


@admin.register(TextBlock)
class TextBlockAdmin(NonLoggingAdmin):
    readonly_fields = ['created_at', 'updated_at', 'user', 'version', 'annotations_count']
    list_select_related = ['user']
    list_display = ['id', 'name', 'user_link', 'public', 'created_via_import', 'version', 'related_resources', 'annotations_count', 'created_at', 'updated_at']
    list_filter = ['version', 'created_via_import']
    fields = ['name', 'description', 'user', 'public', 'created_via_import', 'content', 'version', 'annotations_count', 'created_at', 'updated_at']

    def formfield_for_dbfield(self, db_field, **kwargs):
        formfield = super().formfield_for_dbfield(db_field, **kwargs)
        if db_field.name == 'content':
            formfield.widget = forms.Textarea(attrs=formfield.widget.attrs)
        return formfield

    def user_link(self, obj):
        if obj.user:
            return format_html(
                '<a href="{}">{} ({})</a>',
                reverse('admin:main_user_change', args=(obj.user.id,)),
                obj.user.display_name,
                obj.user.id
            )
    user_link.short_description = 'user'

    def related_resources(self, obj):
        return format_html(
            '<a href="{}?resource_type=TextBlock&resource-id={}">{}</a>',
            reverse('admin:main_resource_changelist'),
            obj.id,
            obj.related_resources().count()
        )

## Users

@admin.register(User)
class UserAdmin(NonLoggingAdmin):
    readonly_fields = ['created_at', 'updated_at', 'display_name']
    list_display = ['id', 'display_name', 'email_address', 'verified_email', 'professor_verification_requested', 'verified_professor', 'get_roles', 'last_request_at', 'last_login_at', 'login_count', 'created_at', 'updated_at']
    list_filter = ['verified_email', 'verified_professor', 'professor_verification_requested', RoleNameFilter]
    search_fields = ['attribution', 'title', 'email_address']
    fields = ['title', 'attribution', 'email_address', 'verified_email', 'professor_verification_requested', 'verified_professor', 'affiliation', 'last_request_at', 'last_login_at', 'login_count', 'created_at', 'updated_at']
    inlines = [RolesUserInline]

    def get_roles(self, obj):
        return ','.join(str(o) for o in obj.roles.distinct('name')) or None


@admin.register(RolesUser)
class RoleUserAdmin(NonLoggingAdmin):
    readonly_fields = ['created_at', 'updated_at']
    list_select_related = ['user', 'role']
    list_display = ['id', 'user', 'role']
    list_filter = ['role__name']
    raw_id_fields = ['user', 'role']



@admin.register(Role)
class RoleAdmin(NonLoggingAdmin):
    readonly_fields = ['created_at', 'updated_at']
    list_display = ['id', 'name', 'authorizable_type', 'authorizable_id', 'created_at', 'updated_at']
    list_filter = ['name', 'authorizable_type']
    ordering = ['-name']


@admin.register(ContentCollaborator)
class CollaboratorsAdmin(NonLoggingAdmin):
    readonly_fields = ['created_at', 'updated_at', 'user', 'content']
    list_select_related = ['user', 'content']
    list_display = ['user', 'role']
    list_filter = ['role']
    ordering = ['role']
    raw_id_fields = ['user', 'content']


## Courts

@admin.register(CaseCourt)
class CaseCourtAdmin(NonLoggingAdmin):
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
