from django_json_widget.widgets import JSONEditorWidget

from django import forms
from django.conf import settings
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.contrib.postgres import fields
from django.db.models import Q, Count
from django.urls import reverse
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from simple_history.admin import SimpleHistoryAdmin
from .utils import fix_after_rails, clone_model_instance
from .models import Case, Link, User, Casebook, Section, \
    Resource, TempCollaborator, ContentAnnotation, TextBlock, ContentNode


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
    formfield_overrides = {
        fields.JSONField: {'widget': JSONEditorWidget},
    }

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

    def enable_richeditor_for_field(self, fieldname, db_field, **kwargs):
        """
            A helper for enabling the editing of a field using a rich text editor.
            Models using this helper should adjust their change_form.html to inherit
            from "admin/change_form_with_richeditor.html"
        """
        formfield = super().formfield_for_dbfield(db_field, **kwargs)
        if db_field.name == fieldname:
            formfield.widget.attrs['class'] = formfield.widget.attrs['class'] + ' richtext-editor-src'
            formfield.widget = forms.Textarea(attrs=formfield.widget.attrs)
        return formfield

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
            return queryset.filter(new_casebook_id=value)


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


class ResourceIdFilter(InputFilter):
    parameter_name = 'resource-id'
    title = 'Resource (by id)'

    def queryset(self, request, queryset):
        value = self.value()
        if value is not None:
            return queryset.filter(resource_id=value)


#
# Inlines
#

class CollaboratorInline(admin.TabularInline):
    model = TempCollaborator
    fields = ['user', 'casebook', 'has_attribution', 'can_edit']
    raw_id_fields = ['user', 'casebook']
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


#
# Admins
#


## Casebooks

class CasebookAdmin(BaseAdmin, SimpleHistoryAdmin):
    list_display = ['id', 'title', 'source', 'created_at', 'updated_at', 'state']
    list_filter = [CollaboratorNameFilter, CollaboratorIdFilter]
    search_fields = ['title']

    fields = ['title', 'subtitle', 'source', 'provenance', 'headnote', 'created_at', 'updated_at' ,'draft', 'state']
    readonly_fields = ['created_at', 'updated_at', 'provenance', 'source', 'state']
    raw_id_fields = ['collaborators', 'draft']
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
        other_casebook = saved_obj.draft or saved_obj.draft_of.first()
        if other_casebook:
            other_casebook.contentcollaborator_set.all().delete()
            collaborators = saved_obj.contentcollaborator_set.prefetch_related(None)  # prefetch_related cancels out an earlier prefetch so we see fresh results
            TempCollaborator.objects.bulk_create(clone_model_instance(c, casebook=other_casebook) for c in collaborators)

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related('contentcollaborator_set__user')

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field('headnote', db_field, **kwargs)

    def source(self, obj):
        if obj.provenance:
            copied_from = Casebook.objects.filter(id=obj.provenance[-1]).get()
            return mark_safe('draft&nbsp;of' if obj.is_draft else 'copy&nbsp;of') + edit_link(copied_from)
    source.short_description = 'source'


class SectionAdmin(BaseAdmin, SimpleHistoryAdmin):
    readonly_fields = ['created_at', 'updated_at', 'casebook_link', 'provenance', 'ordinals']
    list_select_related = ['casebook']
    list_display = ['id', 'casebook_link', 'title', 'ordinals', 'created_at', 'updated_at']
    list_filter = [CasebookIdFilter]
    search_fields = ['title', 'new_casebook__title']
    fields = ['new_casebook', 'ordinals', 'title', 'subtitle', 'provenance', 'headnote', 'created_at', 'updated_at']
    raw_id_fields = ['collaborators', 'casebook']

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('new_casebook').prefetch_related('casebook__contentcollaborator_set__user')

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field('headnote', db_field, **kwargs)

    def casebook_link(self, obj):
        return edit_link(obj.new_casebook, True)
    casebook_link.short_description = 'casebook'


class ContentNodeAdmin(BaseAdmin, SimpleHistoryAdmin):
    readonly_fields = ['created_at', 'updated_at', 'casebook_link', 'provenance', 'resource_id', 'resource_type', 'ordinals']
    list_select_related = ['casebook']
    list_display = ['id', 'casebook_link', 'title', 'ordinals', 'resource_type', 'resource_id', 'annotation_count', 'created_at', 'updated_at']
    list_filter = [CasebookIdFilter, 'resource_type', ResourceIdFilter]
    search_fields = ['title', 'casebook__title']
    fields = ['casebook', 'ordinals', 'title', 'subtitle', 'provenance', 'headnote', 'created_at', 'updated_at']
    raw_id_fields = ['collaborators', 'casebook']
    inlines = [AnnotationInline]

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('casebook').prefetch_related('casebook__contentcollaborator_set__user').annotate(annotations_count=Count('annotations'))

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field('headnote', db_field, **kwargs)

    def casebook_link(self, obj):
        return edit_link(obj.casebook, True)
    casebook_link.short_description = 'casebook'

    def annotation_count(self, obj):
        return 'n/a' if obj.is_annotated == 'Link' else obj.annotations_count

class ResourceAdmin(BaseAdmin, SimpleHistoryAdmin):
    readonly_fields = ['created_at', 'updated_at', 'casebook_link', 'provenance', 'resource_id', 'resource_type', 'ordinals']
    list_select_related = ['casebook']
    list_display = ['id', 'casebook_link', 'title', 'ordinals', 'resource_type', 'resource_id', 'annotation_count', 'created_at', 'updated_at']
    list_filter = [CasebookIdFilter, 'resource_type', ResourceIdFilter]
    search_fields = ['title', 'new_casebook__title']
    fields = ['new_casebook', 'ordinals', 'title', 'subtitle', 'provenance', 'headnote', 'created_at', 'updated_at']
    raw_id_fields = ['collaborators', 'casebook']
    inlines = [AnnotationInline]

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('new_casebook').prefetch_related('casebook__contentcollaborator_set__user').annotate(annotations_count=Count('annotations'))

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field('headnote', db_field, **kwargs)

    def casebook_link(self, obj):
        return edit_link(obj.new_casebook, True)
    casebook_link.short_description = 'casebook'

    def annotation_count(self, obj):
        return 'n/a' if obj.resource_type == 'Link' else obj.annotations_count


class AnnotationsAdmin(BaseAdmin, SimpleHistoryAdmin):
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

class CaseAdmin(BaseAdmin, SimpleHistoryAdmin):
    readonly_fields = ['created_at', 'updated_at']
    list_select_related = []
    list_display = ['id', 'name_abbreviation', 'public', 'capapi_link', 'created_via_import', 'related_resources', 'live_annotations_count', 'created_at', 'updated_at']
    list_filter = ['public', 'created_via_import']
    search_fields = ['name_abbreviation', 'name']
    raw_id_fields = []
    exclude = ('annotations_count',)

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field('content', db_field, **kwargs)

    def capapi_link(self, obj):
        if obj.capapi_id:
            return  format_html(
                '<a target="_blank" href="{}">{}</a>',
                settings.CAPAPI_CASE_URL_FSTRING.format(obj.capapi_id),
                obj.capapi_id
            )
    capapi_link.short_description = 'capapi id'

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


class LinkAdmin(BaseAdmin, SimpleHistoryAdmin):
    readonly_fields = ['created_at', 'updated_at']
    list_display = ['id', 'name', 'url', 'public', 'related_resources', 'created_at', 'updated_at', 'content_type']
    list_filter = ['public', 'content_type']
    search_fields = ['name', 'url']
    fields = ['name', 'url', 'description', 'public', 'created_at', 'updated_at', 'content_type']

    def related_resources(self, obj):
        return format_html(
            '<a href="{}?resource_type=Link&resource-id={}">{}</a>',
            reverse('admin:main_resource_changelist'),
            obj.id,
            obj.related_resources().count()
        )


class TextBlockAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at']
    list_display = ['id', 'name', 'public', 'created_via_import', 'related_resources', 'live_annotations_count', 'created_at', 'updated_at']
    list_filter = ['created_via_import']
    fields = ['name', 'description', 'public', 'created_via_import', 'content', 'created_at', 'updated_at']

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field('content', db_field, **kwargs)

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

class UserAddForm(forms.ModelForm):
    """
        Override DjangoUserAdmin.add_form so "add user" uses a standard form, except for setting random user password
        on creation so the recover-password feature will work.
    """
    class Meta:
        model = User
        fields = '__all__'

    def save(self, commit=True):
        user = super().save(commit=False)
        self.instance.set_password(User.objects.make_random_password(length=20))
        if commit:
            user.save()
        return user


class UserAdmin(BaseAdmin, DjangoUserAdmin):
    ordering = ('-created_at',)
    add_form = UserAddForm
    add_form_template = None
    readonly_fields = ['created_at', 'updated_at', 'display_name', 'last_request_at', 'last_login_at', 'login_count', 'current_login_at', 'current_login_ip', 'last_login_ip']
    list_display = ['id', 'casebook_count', 'display_name', 'email_address', 'is_active', 'professor_verification_requested', 'verified_professor', 'is_staff', 'is_superuser', 'last_request_at', 'last_login_at', 'login_count', 'created_at', 'updated_at']
    list_filter = ['is_active', 'verified_professor', 'professor_verification_requested', 'is_staff', 'is_superuser']
    search_fields = ['attribution', 'email_address']
    fieldsets = (
        (None, {'fields': ('email_address', 'password')}),
        ('Personal info', {'fields': ('attribution', 'affiliation')}),
        ('Permissions', {
            'fields': ('is_active', 'professor_verification_requested', 'verified_professor', 'is_staff', 'is_superuser'),
        }),
        ('User activity', {'fields': (
            'last_request_at',
            'login_count',
            ('current_login_at', 'current_login_ip'),
            ('last_login_at', 'last_login_ip'),
            ('created_at', 'updated_at'))}),
    )
    add_fieldsets = (
        (None, {'fields': ('email_address',)}),
        ('Personal info', {'fields': ('attribution', 'affiliation')}),
        ('Permissions', {
            'fields': ('is_active', 'professor_verification_requested', 'verified_professor'),
        }),
    )

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(casebook_count=Count('casebooks'))

    def casebook_count(self, obj):
        return obj.casebook_count
    casebook_count.admin_order_field = 'casebook_count'

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)


class CollaboratorsAdmin(BaseAdmin):
    readonly_fields = ['created_at', 'updated_at', 'user', 'casebook']
    list_select_related = ['user', 'casebook']
    list_display = ['id', 'user', 'has_attribution', 'can_edit', 'casebook']
    list_filter = ['has_attribution']
    ordering = []
    raw_id_fields = ['user', 'casebook']


## Courts

# Register models on our CustomAdmin instance.
admin_site.register(Casebook, CasebookAdmin)
admin_site.register(Section, SectionAdmin)
admin_site.register(Resource, ResourceAdmin)
admin_site.register(ContentAnnotation, AnnotationsAdmin)
admin_site.register(Case, CaseAdmin)
admin_site.register(Link, LinkAdmin)
admin_site.register(TextBlock, TextBlockAdmin)
admin_site.register(User, UserAdmin)
admin_site.register(TempCollaborator, CollaboratorsAdmin)
admin_site.register(ContentNode, ContentNodeAdmin)
