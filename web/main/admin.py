# type: ignore
from django import forms
from django.conf import settings
from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin, GroupAdmin
from django.core.mail import send_mail
from django.core.paginator import Paginator
from django.db.models import Count, JSONField
from django.forms.models import BaseInlineFormSet
from django.http import HttpResponseRedirect
from django.urls import path, reverse
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from django_json_widget.widgets import JSONEditorWidget
from simple_history.admin import SimpleHistoryAdmin
from django.utils.functional import cached_property
from django.db import connection
from django.contrib.auth.models import Group

from .models import (
    Casebook,
    CasebookTag,
    CommonTitle,
    ContentAnnotation,
    ContentCollaborator,
    ContentNode,
    EmailWhitelist,
    Institution,
    LegalDocument,
    LegalDocumentSource,
    LiveSettings,
    Tag,
    User,
)
from .utils import clone_model_instance, fix_after_rails

#
# Helpers
#

# These models should never use count() queries because of their high row count or the cost of most filtered queries
ALWAYS_FAST_PAGINATE_MODELS = (ContentAnnotation,)


class FasterAdminPaginator(Paginator):
    """Does pagination estimation only if the total number of rows is high and there are no filters applied"""

    @cached_property
    def count(self) -> int:
        cursor = connection.cursor()
        cursor.execute(
            f"SELECT reltuples AS estimate FROM pg_class WHERE relname = '{self.object_list.query.model._meta.db_table}';"
        )
        estimate = int(cursor.fetchone()[0])
        if estimate > 10_000 and (
            not bool(self.object_list.query.where)
            or self.object_list.model in (ALWAYS_FAST_PAGINATE_MODELS)
        ):
            self.estimated_count = True
            self.estimated_count_ignores_filter = True
            return estimate
        try:
            return self.object_list.count()
        except (AttributeError, TypeError):
            # AttributeError if object_list has no count() method.
            # TypeError if object_list.count() requires arguments
            # (i.e. is of type list).
            return len(self.object_list)


def edit_link(obj, as_str=False):
    """Generate a link to the admin edit screen for the given object."""
    if not obj:
        return None
    url = reverse(f"admin:{obj._meta.app_label}_{obj._meta.model_name}_change", args=[obj.id])
    if as_str:
        return format_html('<a href="{}">→{}</a>', url, obj)
    else:
        return format_html('<a href="{}">→{}</a>', url, obj.id)


#
# Admin site config
#


class CustomAdminSite(admin.AdminSite):
    site_header = "H2O Admin"
    index_template = "admin/h2o_index.html"

    def get_urls(self):
        import reporting.admin  # noqa no-op import to register the reporting models
        from reporting.admin.usage_dashboard import view as usage_dashboard_view

        urls = super().get_urls()
        my_urls = [
            path("reporting/usage/", usage_dashboard_view, name="usage"),
        ]
        return my_urls + urls


admin_site = CustomAdminSite(name="h2oadmin")

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
    fix_after_rails(
        """
        The LogEntry class tracks additions, changes, and deletions of objects
        done through the admin interface. It requires the Django app to be
        fully integrated with the AUTH_USER_MODEL... which we aren't yet. So,
        for now, disable logging.
    """
    )

    def log_addition(self, request, object, message):
        pass

    def log_change(self, request, object, message):
        pass

    def log_deletion(self, request, object, object_repr):
        pass

    actions = None  # use ['delete_selected'] to allow delete action
    formfield_overrides = {
        JSONField: {"widget": JSONEditorWidget},
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
            formfield.widget.attrs["class"] = (
                formfield.widget.attrs["class"] + " richtext-editor-src"
            )
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

    template = "admin/input_filter.html"

    def lookups(self, request, model_admin):
        # Dummy, required to show the filter.
        return ((),)

    def choices(self, changelist):
        # Grab only the "all" option.
        all_choice = next(super().choices(changelist))
        all_choice["query_parts"] = (
            (k, v) for k, v in changelist.get_filters_params().items() if k != self.parameter_name
        )
        yield all_choice


class CasebookIdFilter(InputFilter):
    parameter_name = "casebook"
    title = "Casebook (by ID)"

    def queryset(self, request, queryset):
        value = self.value()
        if value:
            return queryset.filter(casebook_id=value)


class CollaboratorNameFilter(InputFilter):
    parameter_name = "collaborator-name"
    title = "Collaborator (by name)"

    def queryset(self, request, queryset):
        value = self.value()
        if value:
            users = User.objects.filter(attribution__icontains=value)
            return queryset.filter(collaborators__in=users)


class CollaboratorIdFilter(InputFilter):
    parameter_name = "collaborator-id"
    title = "Collaborator (by id)"

    def queryset(self, request, queryset):
        value = self.value()
        if value:
            users = User.objects.filter(id=value)
            return queryset.filter(collaborators__in=users)


class CasebookStateFilter(admin.SimpleListFilter):
    title = "casebook state"
    parameter_name = "state"

    def lookups(self, request, model_admin):
        return [(tag.value, tag.name) for tag in Casebook.LifeCycle]

    def queryset(self, request, queryset):
        value = self.value()
        return queryset.filter(state=value) if value else queryset


class CasebookExportFailsFilter(admin.SimpleListFilter):
    title = "export failures"
    parameter_name = "export_fails"

    def lookups(self, request, model_admin):
        return [
            ("No failures", "No failures"),
            ("Some failures", "Some failures"),
            ("Locked", "Locked"),
        ]

    def queryset(self, request, queryset):
        val = self.value()
        if not val:
            return queryset
        if val == "No failures":
            return queryset.filter(export_fails=0)
        if val == "Some failures":
            return queryset.filter(export_fails__gt=0)
        if val == "Locked":
            return queryset.filter(export_fails__gte=settings.MAX_EXPORT_ATTEMPTS)
        return queryset


class ResourceIdFilter(InputFilter):
    parameter_name = "resource-id"
    title = "Resource (by id)"

    def queryset(self, request, queryset):
        value = self.value()
        if value:
            return queryset.filter(resource_id=value)


class LegalDocumentSourceFilter(InputFilter):
    parameter_name = "doc-source"
    title = "Document (by source id)"

    def queryset(self, request, queryset):
        value = self.value()
        if value:
            return queryset.filter(source_id=value)


class ResourceTypeFilter(admin.SimpleListFilter):
    title = "Resource type"
    parameter_name = "resource_type"

    def lookups(self, request, model_admin):
        return [
            ("LegalDocument", "Legal document"),
            ("Link", "Link"),
            ("Section", "Section"),
            ("Temp", "Temp"),
            ("TextBlock", "Text block"),
        ]

    def queryset(self, request, queryset):
        if self.value():
            return queryset.filter(resource_type=self.value())
        return queryset


class ContentAnnotationResourceTypeFilter(ResourceTypeFilter):
    # Only these types can be meaningfully annotated
    def lookups(self, request, model_admin):
        return [
            ("LegalDocument", "Legal document"),
            ("TextBlock", "Text block"),
        ]

    def queryset(self, request, queryset):
        if self.value():
            return queryset.filter(resource__resource_type=self.value())
        return queryset


#
# Inlines
#


class CollaboratorInline(admin.TabularInline):
    model = ContentCollaborator
    fields = ["user", "casebook", "has_attribution", "can_edit"]
    raw_id_fields = ["user", "casebook"]
    max_num = None
    can_delete = True


class AnnotationInline(admin.TabularInline):
    model = ContentAnnotation
    readonly_fields = ["id", "created_at", "updated_at", "kind"]
    fields = [
        "id",
        "resource",
        ("global_start_offset", "global_end_offset"),
        "kind",
        "content",
        "created_at",
        "updated_at",
    ]
    raw_id_fields = ["resource"]
    ordering = ["global_start_offset", "global_end_offset"]
    max_num = None
    can_delete = True

    def formfield_for_dbfield(self, db_field, **kwargs):
        formfield = super().formfield_for_dbfield(db_field, **kwargs)
        if db_field.name == "content":
            formfield.widget = forms.TextInput(attrs=formfield.widget.attrs)
        return formfield


#
# Admins
#


## Casebooks


class CasebookAdmin(BaseAdmin, SimpleHistoryAdmin):
    list_display = ["id", "title", "source", "created_at", "updated_at", "state"]
    list_filter = [
        CollaboratorNameFilter,
        CollaboratorIdFilter,
        CasebookStateFilter,
        CasebookExportFailsFilter,
    ]
    search_fields = ["title"]

    fields = [
        "title",
        "subtitle",
        "source",
        "provenance",
        "headnote",
        "description",
        "cover_image",
        "created_at",
        "updated_at",
        "draft",
        "state",
        "export_fails",
        "listed_publicly",
    ]
    readonly_fields = [
        "created_at",
        "updated_at",
        "provenance",
        "source",
    ]
    raw_id_fields = ["collaborators", "draft"]
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
        other_casebook = saved_obj.draft or Casebook.objects.filter(draft=saved_obj).first()
        if other_casebook:
            other_casebook.contentcollaborator_set.all().delete()
            collaborators = saved_obj.contentcollaborator_set.prefetch_related(
                None
            )  # prefetch_related cancels out an earlier prefetch so we see fresh results
            ContentCollaborator.objects.bulk_create(
                clone_model_instance(c, casebook=other_casebook) for c in collaborators
            )

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related("contentcollaborator_set__user")

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field("headnote", db_field, **kwargs)

    def source(self, obj):
        if obj.provenance:
            copied_from = Casebook.objects.filter(id=obj.provenance[-1]).get()
            return mark_safe("draft&nbsp;of" if obj.is_draft else "copy&nbsp;of") + edit_link(
                copied_from
            )

    source.short_description = "source"


class ContentNodeAdmin(BaseAdmin, SimpleHistoryAdmin):
    readonly_fields = [
        "created_at",
        "updated_at",
        "casebook_link",
        "provenance",
        "resource_id",
        "resource_type",
        "ordinals",
        "display_ordinals",
    ]
    list_select_related = ["casebook"]
    list_display = [
        "id",
        "casebook_link",
        "title",
        "ordinals",
        "display_ordinals",
        "resource_type",
        "resource_id",
        "created_at",
        "updated_at",
    ]
    list_filter = [CasebookIdFilter, ResourceTypeFilter, ResourceIdFilter]
    search_fields = ["title", "casebook__title"]
    fields = [
        "casebook",
        "ordinals",
        "display_ordinals",
        "resource_id",
        "resource_type",
        "title",
        "subtitle",
        "provenance",
        "headnote",
        "created_at",
        "updated_at",
        "does_display_ordinals",
        "is_instructional_material",
    ]
    raw_id_fields = ["casebook"]
    inlines = [AnnotationInline]

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field("headnote", db_field, **kwargs)

    def casebook_link(self, obj):
        return edit_link(obj.casebook, True)

    casebook_link.short_description = "casebook"

    def save_model(self, request, obj, form, *args, **kwargs):
        """If either of the node-numbering options have been toggled this session, update the
        content tree for the whole casebook"""
        super().save_model(request, obj, form, *args, **kwargs)

        if (
            "is_instructional_material" in form.cleaned_data
            or "does_display_ordinals" in form.cleaned_data
        ):
            obj.casebook.content_tree__repair()

    ordering = ("-id",)
    paginator = FasterAdminPaginator
    show_full_result_count = False


class AnnotationsAdmin(BaseAdmin, SimpleHistoryAdmin):
    readonly_fields = ["created_at", "updated_at", "kind", "resource", "casebook"]
    fields = [
        "resource",
        "casebook",
        ("global_start_offset", "global_end_offset"),
        "kind",
        "content",
        "created_at",
        "updated_at",
    ]
    list_select_related = ["resource", "resource__casebook"]
    list_display = [
        "id",
        "casebook",
        "resource",
        "resource_type",
        "kind",
        "created_at",
        "updated_at",
    ]
    list_filter = ["kind", ContentAnnotationResourceTypeFilter]

    # This table isn't ordered on an index by default; use this as a proxy for recency
    ordering = ("-id",)

    def resource_type(self, obj) -> str:
        return obj.resource.resource_type

    def casebook(self, obj) -> Casebook:
        return obj.resource.casebook

    def resource(self, obj) -> ContentNode:
        return obj.resource

    paginator = FasterAdminPaginator
    show_full_result_count = False


class TagAdmin(BaseAdmin, SimpleHistoryAdmin):
    list_display = [
        "id",
        "slug",
        "display_text",
        "created_at",
        "updated_at",
        "casebook_count",
        "category",
    ]
    search_fields = ["display_text", "slug"]
    fields = ["display_text", "slug", "category"]
    prepopulated_fields = {"slug": ("display_text",)}

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(casebook_count=Count("casebooks"))

    @admin.display(
        ordering="casebook_count",
        description="Casebooks with this tag",
    )
    def casebook_count(self, obj):
        return obj.casebook_count

    class Meta:
        model = Tag
        fields = "__all__"


class CasebookTagAdmin(BaseAdmin, SimpleHistoryAdmin):
    list_display = [
        "casebook",
        "tag",
        "created_by",
        "created_at",
        "updated_at",
    ]
    search_fields = ["casebook", "tag"]
    fields = ["casebook", "tag"]

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)

    def save_model(self, request, obj, form, change):
        obj.created_by = request.user
        obj.save()


## Users


class UserAddForm(forms.ModelForm):
    """
    Override DjangoUserAdmin.add_form so "add user" uses a standard form, except for setting random user password
    on creation so the recover-password feature will work.
    """

    class Meta:
        model = User
        fields = "__all__"

    def save(self, commit=True):
        user = super().save(commit=False)
        self.instance.set_password(User.objects.make_random_password(length=20))
        if commit:
            user.save()
        return user


class UserAdmin(BaseAdmin, DjangoUserAdmin):
    ordering = ("-created_at",)
    add_form = UserAddForm
    add_form_template = None
    readonly_fields = [
        "created_at",
        "updated_at",
        "display_name",
        "last_request_at",
        "last_login_at",
        "login_count",
        "current_login_at",
        "current_login_ip",
        "last_login_ip",
    ]
    list_display = [
        "id",
        "email_address",
        "display_name",
        "casebook_count",
        "institution",
        "professor_verification_requested",
        "verified_professor",
        "user_groups",
        "is_active",
        "last_login_at",
        "login_count",
        "created_at",
        "updated_at",
    ]
    list_filter = [
        "groups",
        "verified_professor",
        "professor_verification_requested",
        "is_active",
        "is_superuser",
        "is_staff",
    ]
    search_fields = ["attribution", "email_address"]
    fieldsets = (
        (None, {"fields": ("email_address", "password")}),
        ("Personal info", {"fields": ("attribution", "institution", "affiliation", "public_url")}),
        (
            "Permissions",
            {
                "fields": (
                    "is_active",
                    "professor_verification_requested",
                    "verified_professor",
                    "is_staff",
                    "is_superuser",
                    "groups",
                ),
            },
        ),
        (
            "User activity",
            {
                "fields": (
                    "last_request_at",
                    "login_count",
                    ("current_login_at", "current_login_ip"),
                    ("last_login_at", "last_login_ip"),
                    ("created_at", "updated_at"),
                )
            },
        ),
    )
    add_fieldsets = (
        (None, {"fields": ("email_address",)}),
        ("Personal info", {"fields": ("attribution", "institution", "affiliation")}),
        (
            "Permissions",
            {
                "fields": ("is_active", "professor_verification_requested", "verified_professor"),
            },
        ),
    )

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(casebook_count=Count("casebooks"))

    def casebook_count(self, obj):
        return obj.casebook_count

    def user_groups(self, obj):
        return ", ".join([g.name for g in obj.groups.all()])

    casebook_count.admin_order_field = "casebook_count"

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)

    def has_delete_permission(self, request, obj=None):
        return super(BaseAdmin, self).has_delete_permission(request, obj)

    def response_change(self, request, obj):
        if "_prof_verification" in request.POST:
            user = obj
            email_body = request.POST.get("verification_email_contents", None)
            email_subject = request.POST.get("verification_subject", None)
            email_from = settings.DEFAULT_FROM_EMAIL
            email_to = user.email_address
            try:
                send_mail(email_subject, email_body, email_from, [email_to], fail_silently=False)
            except Exception:
                messages.add_message(request, messages.WARNING, "Email failed to send successfully")
                return HttpResponseRedirect(".")
            user.verified_professor = True
            user.save()
            self.message_user(request, "Email sent, Professor Verified.")
        return super().response_change(request, obj)


class CollaboratorsAdmin(BaseAdmin):
    readonly_fields = ["created_at", "updated_at", "user", "casebook"]
    list_select_related = ["user", "casebook"]
    list_display = ["id", "user", "has_attribution", "can_edit", "casebook"]
    list_filter = ["has_attribution"]
    ordering = []
    raw_id_fields = ["user", "casebook"]


class EmailWhitelistAdmin(BaseAdmin):
    fields = ["university_name", "university_url", "email_domain"]
    list_filter = ["university_name", "email_domain"]
    list_display = ["email_domain", "university_name", "university_url"]

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)


class InstitutionAdmin(BaseAdmin):
    prepopulated_fields = {"slug": ("name",)}
    list_display = ["name", "url", "email_domains", "user_count"]

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(user_count=Count("user"))

    @admin.display(
        ordering="user_count",
        description="Users in this institution",
    )
    def user_count(self, obj):
        return obj.user_count

    class Meta:
        model = Institution
        fields = "__all__"


class LegalDocumentSourceAdmin(BaseAdmin):
    readonly_fields = []
    list_select_related = []
    list_display = ["id", "name", "active", "priority", "date_added", "imported_documents"]
    list_filter = ["active"]
    search_fields = ["name"]
    raw_id_fields = []

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field("content", db_field, **kwargs)

    def imported_documents(self, obj):
        base_url = reverse("admin:main_legaldocument_changelist")
        return format_html(
            f'<a href="{base_url}?resource_type=LegalDocument&doc-source={obj.id}">{obj.documents.count()}</a>'
        )


class LegalDocumentForm(forms.ModelForm):
    """Override to so that metadata displays with a view-only JSON widget"""

    class Meta:
        model = LegalDocument
        fields = "__all__"
        widgets = {
            "metadata": JSONEditorWidget(options={"mode": "view", "modes": ["view"]}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields.get("metadata").disabled = True


class LegalDocumentAdmin(BaseAdmin, SimpleHistoryAdmin):
    form = LegalDocumentForm

    readonly_fields = [
        "needs_fixing",
        "source_name",
        "created_at",
        "updated_at",
        "source_ref",
        "effective_date",
        "publication_date",
        "updated_date",
    ]
    list_select_related = []
    list_display = [
        "id",
        "short_name",
        "source_name",
        "source_ref",
        "doc_class",
        "live_annotations_count",
        "created_at",
        "updated_at",
    ]
    list_filter = ["doc_class", LegalDocumentSourceFilter]
    search_fields = ["short_name", "name", "source_ref"]
    raw_id_fields = []
    exclude = ("annotations_count", "source")

    def has_add_permission(self, request):
        return super(BaseAdmin, self).has_add_permission(request)

    def formfield_for_dbfield(self, db_field, **kwargs):
        return self.enable_richeditor_for_field("content", db_field, **kwargs)

    def needs_fixing(self, obj):
        return "Footnotes" if obj.has_bad_footnotes() else "Passes checks"

    def source_name(self, obj):
        return obj.source.name

    def live_annotations_count(self, obj):
        return obj.related_annotations().count()

    live_annotations_count.short_description = "Annotations"


class CasebookInSeriesFormset(BaseInlineFormSet):
    """Return the casebooks in this series in the inline list, excluding the
    casebook marked as `current` in the CommonTitle model itself, as removing
    that would cause the instance to be in an inconsistent state."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.queryset = self.model.objects.filter(common_title_id=self.instance.pk).exclude(
            pk=self.instance.current.pk
        )

    def delete_existing(self, obj: Casebook, **kwargs):
        """Drop this item from the Series, but don't actually delete it"""
        # This overrides
        # https://github.com/django/django/blob/e03cdf76e78ea992763df4d3e16217d298929301/django/forms/models.py#L762-L765

        obj.common_title = None
        obj.save()


class CasebookInSeriesInline(admin.TabularInline):
    model = Casebook
    formset = CasebookInSeriesFormset
    can_delete = True
    readonly_fields = ("id", "title", "authors")
    fields = (
        "id",
        "title",
        "authors",
    )

    template = "admin/main/casebook/inline_series.html"

    def authors(self, instance) -> str:
        return ", ".join(
            [
                f"{u.attribution if u.attribution != 'Anonymous' else u.email_address}"
                for u in instance.collaborators.all().order_by("-verified_professor")
            ]
        )


class CommonTitleAdmin(BaseAdmin):
    raw_id_fields = ["current"]
    inlines = [CasebookInSeriesInline]
    list_display = ["name", "casebook_count", "current"]

    def casebook_count(self, instance) -> int:
        return Casebook.objects.filter(common_title_id=instance.pk).count()


class LiveSettingsAdmin(BaseAdmin):
    readonly_fields = []
    list_select_related = []
    list_display = ["id", "prevent_exports"]
    list_filter = []
    search_fields = []
    raw_id_fields = []

    def has_add_permission(self, request):
        return LiveSettings.load().id is None and super(BaseAdmin, self).has_add_permission(request)


# Register models on our CustomAdmin instance.
admin_site.register(Casebook, CasebookAdmin)
admin_site.register(ContentAnnotation, AnnotationsAdmin)
admin_site.register(User, UserAdmin)
admin_site.register(ContentCollaborator, CollaboratorsAdmin)
admin_site.register(Institution, InstitutionAdmin)
admin_site.register(ContentNode, ContentNodeAdmin)
admin_site.register(EmailWhitelist, EmailWhitelistAdmin)
admin_site.register(LegalDocumentSource, LegalDocumentSourceAdmin)
admin_site.register(LegalDocument, LegalDocumentAdmin)
admin_site.register(CommonTitle, CommonTitleAdmin)
admin_site.register(LiveSettings, LiveSettingsAdmin)
admin_site.register(Tag, TagAdmin)
admin_site.register(CasebookTag, CasebookTagAdmin)
admin_site.register(Group, GroupAdmin)
