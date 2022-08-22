import json
import logging
import uuid
from collections import OrderedDict
from datetime import datetime
from functools import wraps
from test.test_helpers import assert_url_equal, check_response, dump_content_tree_children

from django.conf import settings
from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test

from django.contrib.auth.views import PasswordResetView, redirect_to_login
from django.core.exceptions import PermissionDenied
from django.core.validators import URLValidator
from django.db import transaction
from django.db.models import Q
from django.forms import HiddenInput, modelformset_factory
from django.http import (
    Http404,
    HttpRequest,
    HttpResponse,
    HttpResponseBadRequest,
    HttpResponseForbidden,
    HttpResponseRedirect,
    HttpResponseServerError,
    JsonResponse,
)
from django.shortcuts import get_object_or_404, render
from django.urls import reverse
from django.utils.decorators import method_decorator
from django.utils.html import escape
from django.utils.text import Truncator
from django.views import View
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import requires_csrf_token
from django.views.decorators.http import require_http_methods, require_POST
from pytest import raises as assert_raises
from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from simple_history.utils import bulk_create_with_history

from .forms import (
    CasebookForm,
    CasebookFormWithCoverImage,
    CasebookSettingsTransitionForm,
    CollaboratorFormSet,
    InviteCollaboratorForm,
    LinkForm,
    NewTextBlockForm,
    ResourceForm,
    SectionForm,
    SignupForm,
    TextBlockForm,
    UserProfileForm,
)
from .models import (
    Casebook,
    CasebookEditLog,
    CasebookFollow,
    CommonTitle,
    ContentAnnotation,
    ContentCollaborator,
    ContentNode,
    ContentNodeQuerySet,
    LegalDocument,
    LegalDocumentSource,
    Link,
    LiveSettings,
    Resource,
    SavedImage,
    SearchIndex,
    FullTextSearchIndex,
    Section,
    TextBlock,
    User,
)
from .serializers import (
    AnnotationSerializer,
    CasebookInfoSerializer,
    CasebookListSerializer,
    CommonTitleSerializer,
    LegalDocumentSearchParamsSerializer,
    LegalDocumentSerializer,
    LegalDocumentSourceSerializer,
    NewAnnotationSerializer,
    NewCommonTitleSerializer,
    TextBlockSerializer,
    UpdateAnnotationSerializer,
    manually_serialize_content_query,
)
from .storages import get_s3_storage
from .test.test_permissions_helpers import (
    directly_editable_resource,
    directly_editable_section,
    no_perms_test,
    patch_directly_editable_resource,
    perms_test,
    post_directly_editable_resource,
    viewable_resource,
    viewable_section,
)
from .utils import (
    StringFileResponse,
    fix_after_rails,
    get_link_title,
    send_verification_email,
    LambdaExportTooLarge,
    validate_image,
    BadFiletypeError,
)

logger = logging.getLogger("django")
### helpers ###


def login_required_response(request: HttpRequest, always_raise=False):
    if request.user.is_authenticated or always_raise:
        raise PermissionDenied
    else:
        return redirect_to_login(request.build_absolute_uri())


def find_from_title_slugs(user_slug=None, title_slug=None, content_param=None):
    if title_slug is None:
        return (None, None)
    titles = (
        CommonTitle.objects.filter(public_url=title_slug)
        .prefetch_related("casebooks")
        .prefetch_related("casebooks__contentcollaborator_set")
        .filter(casebooks__collaborators__public_url=user_slug)
    )
    title = titles.distinct().first()
    if not title:
        return (None, None)
    casebook = title.current
    if not content_param:
        return ("Casebook", casebook)
    section = ContentNode.objects.filter(
        casebook=casebook, ordinals=content_param["ordinals"]
    ).first()
    if not section:
        return (None, None)
    if section.is_resource:
        return ("Resource", section)
    return ("Section", section)


def hydrate_params(func):
    """
    Fetch casebook specified by the casebook_param URL parameter, as well as
    section_param, resource_param, or node_param if included in the URL.
    Results are passed into the view as casebook=, section=, resource=, and node=.

    >>> outer_casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
    >>> @hydrate_params
    ... def my_view(request, casebook, section, resource, node):
    ...     assert casebook == outer_casebook
    ...     assert section == s_1
    ...     assert resource == r_1_1
    ...     assert node == r_1_2
    >>> my_view(None,
    ...     casebook_param={'id': outer_casebook.id},
    ...     section_param={'ordinals': s_1.ordinals},
    ...     resource_param={'ordinals': r_1_1.ordinals},
    ...     node_param={'ordinals': r_1_2.ordinals},
    ... )
    """

    @wraps(func)
    def wrapper(request, *args, **kwargs):
        casebook_param = kwargs.pop("casebook_param", None)
        if casebook_param:
            candidate_casebooks = [
                x
                for x in Casebook.objects.filter(
                    Q(pk=casebook_param["id"]) | Q(old_casebook=casebook_param["id"])
                ).all()
            ]
            new_cb_ids = [x for x in candidate_casebooks if x.id == casebook_param["id"]]
            if new_cb_ids:
                cb_param = {"casebook": casebook_param["id"]}
                kwargs["casebook"] = new_cb_ids[0]
            else:
                old_cb_ids = [
                    x for x in candidate_casebooks if x.old_casebook_id == casebook_param["id"]
                ]
                if old_cb_ids:
                    cb_param = {"casebook": casebook_param["id"]}
                    kwargs["casebook"] = old_cb_ids[0]
                else:
                    raise Http404
        for param in (
            "section_param",
            "section_id",
            "resource_param",
            "resource_id",
            "node_param",
            "node_id",
        ):
            param_value = kwargs.pop(param, None)
            if not param_value:
                continue
            key, search_key = param.split("_", 1)
            if search_key == "param":
                temp_obj = get_object_or_404(
                    ContentNode.objects.filter(**cb_param).select_related("casebook"),
                    ordinals=param_value["ordinals"],
                )
                kwargs[key] = temp_obj
                kwargs["casebook"] = kwargs[key].casebook
            else:
                temp_obj = get_object_or_404(
                    ContentNode.objects.filter(**cb_param).select_related("casebook"),
                    id=param_value["id"],
                )
                kwargs[key] = temp_obj
                kwargs["casebook"] = kwargs[key].casebook
        return func(request, *args, **kwargs)

    return wrapper


def user_has_perm(kwarg, method):
    """
    Raise permission denied unless view_kwargs[kwarg].method(request.user) returns True.
    """

    def decorator(func):
        @wraps(func)
        def wrapper(request, *args, **kwargs):
            # Temporary Resource kludge
            if not (kwarg in kwargs and getattr(kwargs[kwarg], method)(request.user)):
                return login_required_response(request)
            return func(request, *args, **kwargs)

        return wrapper

    return decorator


def actions(request, context):
    """
    This describes what can be done to a given node, or to its containing
    casebook, by a user, on a particular page.

    See node_decorate.rb, action_button_builder.rb, and _actions.html.erb

    Given:
    >>> published, private, with_draft, client = [getfixture(f) for f in ['full_casebook', 'full_private_casebook', 'full_casebook_with_draft', 'client']]
    >>> published_section = published.sections.first()
    >>> published_resource = published.resources.first()
    >>> private_section = private.sections.first()
    >>> private_resource = private.resources.first()
    >>> with_draft_section = with_draft.sections.first()
    >>> with_draft_resource = with_draft.resources.first()
    >>> draft = with_draft.draft
    >>> draft_section = draft.sections.first()
    >>> draft_resource = draft.resources.first()

    ##
    # These pages allow the same actions regardless of node types
    ##

    When a logged out user visits casebooks, sections, and resources:
    >>> for o in [published, published_section, published_resource]:
    ...     check_response(
    ...         client.get(o.get_absolute_url()),
    ...         content_includes='actions="exportable"'
    ...     )

    When a collaborator views a published casebook WITHOUT a draft, or
    any of that casebook's sections or resources:
    >>> for o in [published, published_section, published_resource]:
    ...     check_response(
    ...         client.get(o.get_absolute_url(), as_user=published.testing_editor),
    ...         content_includes='actions="exportable,cloneable,can_create_draft"'
    ...     )

    When a collaborator views a published casebook WITH a draft, or
    any of that casebook's sections or resources:
    >>> for o in [with_draft, with_draft_section, with_draft_resource]:
    ...     check_response(
    ...         client.get(o.get_absolute_url(), as_user=with_draft.testing_editor),
    ...         content_includes='actions="exportable,cloneable,publishable,can_view_existing_draft"'
    ...     )

    When a collaborator views the "preview" page of a private, never published casebook, or
    the preview pages of any of that casebook's sections or resources:
    >>> for o in [private, private_section, private_resource]:
    ...     check_response(
    ...         client.get(o.get_absolute_url(), as_user=private.testing_editor),
    ...         content_includes='actions="exportable,cloneable,publishable,can_be_directly_edited"'
    ...     )

    When a collaborator views the "preview" page of a draft of an already-published casebook, or
    the preview pages of any of that casebook's sections or resources:
    >>> for o in [draft, draft_section, draft_resource]:
    ...     check_response(
    ...         client.get(o.get_absolute_url(), as_user=draft.testing_editor),
    ...         content_includes='actions="exportable,publishable,can_be_directly_edited"'
    ...     )

    ##
    # These pages allow different actions, depending on the node type
    ##

    # Casebook

    When a collaborator views the "edit" page of a private, never-published casebook
    >>> check_response(
    ...    client.get(private.get_edit_url(), as_user=private.testing_editor),
    ...    content_includes='actions="exportable,cloneable,previewable,publishable,can_save_nodes,can_add_nodes"'
    ... )

    When a collaborator views the "edit" page of a draft of an already-published casebook
    >>> check_response(
    ...    client.get(draft.get_edit_url(), as_user=draft.testing_editor),
    ...    content_includes='actions="exportable,previewable,publishable,can_save_nodes,can_add_nodes"'
    ... )

    # Section

    When a collaborator views the "edit" page of a section in a private, never-published casebook
    >>> check_response(
    ...     client.get(private_section.get_edit_url(), as_user=private.testing_editor),
    ...     content_includes='actions="exportable,previewable,can_save_nodes,can_add_nodes"'
    ... )

    When a collaborator views the "edit" page of a section in draft of an already-published casebook
    >>> check_response(
    ...     client.get(draft_section.get_edit_url(), as_user=draft.testing_editor),
    ...     content_includes='actions="exportable,previewable,publishable,can_save_nodes,can_add_nodes"'
    ... )

    # Resource

    When a collaborator views the "edit" page of a resource in a private, never-published casebook
    >>> check_response(
    ...     client.get(private_resource.get_edit_url(), as_user=private.testing_editor),
    ...     content_includes='actions="exportable,previewable,can_save_nodes"'
    ... )

    When a collaborator views the "edit" page of a resource in draft of an already-published casebook
    >>> check_response(
    ...     client.get(draft_resource.get_edit_url(), as_user=draft.testing_editor),
    ...     content_includes='actions="exportable,previewable,publishable,can_save_nodes"'
    ... )

    When a collaborator views the "annotate" page of a resource in a private, never-published casebook
    >>> check_response(
    ...     client.get(private_resource.get_annotate_url(), as_user=private.testing_editor),
    ...     content_includes='actions="exportable,previewable"'
    ... )

    When a collaborator views the "annotate" page of a resource in draft of an already-published casebook
    >>> check_response(
    ...     client.get(draft_resource.get_annotate_url(), as_user=draft.testing_editor),
    ...     content_includes='actions="exportable,previewable,publishable"'
    ... )

    """
    view = request.resolver_match.view_name
    node = context.get("casebook") or context.get("section") or context.get("resource")

    cloneable = (
        request.user.is_authenticated
        and view in ["casebook", "section", "resource", "edit_casebook"]
        and node.permits_cloning
    )

    publishable = (
        node.editable_by(request.user)
        and node.can_publish
        and (view in ["edit_casebook", "casebook", "section", "resource"])
        or node.is_draft
    )

    can_follow = False
    can_unfollow = False
    if (
        request.user
        and request.user.is_authenticated
        and not (request.user in node.casebook.all_collaborators)
    ):
        can_unfollow = node.followed_by(request.user)
        can_follow = not can_unfollow

    actions = OrderedDict(
        [
            ("exportable", True),
            ("cloneable", cloneable),
            ("previewable", context.get("editing", False)),
            ("publishable", publishable),
            ("can_save_nodes", view in ["edit_casebook", "edit_section", "edit_resource"]),
            ("can_add_nodes", view in ["edit_casebook", "edit_section"]),
            (
                "can_be_directly_edited",
                view in ["casebook", "resource", "section"]
                and node.directly_editable_by(request.user),
            ),
            (
                "can_create_draft",
                view in ["casebook", "resource", "section"]
                and node.allows_draft_creation_by(request.user),
            ),
            (
                "can_view_existing_draft",
                view in ["casebook", "resource", "section"]
                and node.has_draft
                and node.editable_by(request.user),
            ),
            ("can_follow", can_follow),
            ("can_unfollow", can_unfollow),
        ]
    )
    # for ease of testing, include a list of truthy actions
    actions["action_list"] = ",".join([a for a in actions if actions[a]])
    return actions


def render_with_actions(
    request, template_name, context=None, content_type=None, status=None, using=None
):
    if context is None:
        context = {}
    if request.user and hasattr(request.user, "casebooks") and "section" in context:
        context["clone_section_targets"] = json.dumps(
            [
                {
                    "title": f"{user_casebook.title} ({user_casebook.created_at.year})",
                    "form_target": reverse(
                        "clone_nodes", args=[context["casebook"], context["section"], user_casebook]
                    ),
                }
                for user_casebook in request.user.directly_editable_casebooks
            ]
        )

    if request.user and request.user.is_superuser:
        context["super_user"] = True
    return render(
        request,
        template_name,
        {**context, **actions(request, context)},
        content_type,
        status,
        using,
    )


### error handlers ###


def bad_request(request, exception):
    """
    Custom view for 400 failures, required for proper rendering of
    our custom template, which uses injected context variables.
    https://github.com/django/django/blob/master/django/views/defaults.py#L97
    """
    return HttpResponseBadRequest(render(request, "400.html"))


def csrf_failure(request, reason="CSRF Failure."):
    """
    Custom view for CSRF failures, required for proper rendering of
    our custom template, which uses injected context variables.
    https://github.com/django/django/blob/master/django/views/defaults.py#L146
    """
    return HttpResponseForbidden(render(request, "403_csrf.html"))


def server_error(request):
    """
    Custom view for 500 failures, required for proper rendering of
    our custom template, which uses injected context variables.
    https://github.com/django/django/blob/master/django/views/defaults.py#L97
    """
    return HttpResponseServerError(render(request, "500.html"))


### views ###


class CasebookTOCView(APIView):
    @never_cache
    @method_decorator(requires_csrf_token)
    @method_decorator(
        perms_test(
            [
                {
                    "args": ["full_casebook"],
                    "results": {200: [None, "other_user", "full_casebook.testing_editor"]},
                },
                {
                    "args": ["full_private_casebook"],
                    "results": {
                        200: ["full_private_casebook.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
                {
                    "args": ["full_casebook_with_draft.draft"],
                    "results": {
                        200: ["full_casebook_with_draft.draft.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
            ]
        )
    )
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "viewable_by"))
    def get(self, request, casebook, format=None):
        return Response(self.format_casebook(casebook, request), status=200)

    @staticmethod
    def format_casebook(casebook: Casebook, request: HttpRequest):
        return {
            "id": casebook.id,
            "children": manually_serialize_content_query(casebook.nodes_for_user(request.user)),
        }


class CasebookInfoView(APIView):
    @never_cache
    @method_decorator(requires_csrf_token)
    @method_decorator(
        perms_test(
            [
                {
                    "args": ["full_casebook"],
                    "results": {200: [None, "other_user", "full_casebook.testing_editor"]},
                },
                {
                    "args": ["full_private_casebook"],
                    "results": {
                        200: ["full_private_casebook.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
                {
                    "args": ["full_casebook_with_draft.draft"],
                    "results": {
                        200: ["full_casebook_with_draft.draft.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
            ]
        )
    )
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "viewable_by"))
    def get(self, request, casebook, format=None):
        return Response(CasebookInfoSerializer(casebook).data)


class SectionTOCView(APIView):
    """
    This presents a Toc in a heirarchical form.
    """

    @never_cache
    @method_decorator(requires_csrf_token)
    @method_decorator(perms_test(viewable_section))
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "viewable_by"))
    @method_decorator(user_has_perm("section", "viewable_by"))
    def get(self, request, casebook, section, format=None):
        # in order to serialize correctly, we need return the top-level section
        # and nested lists of children. section.contents does not include the
        # section content node itself, so we get the section node and OR it
        # together to add it to the section.contents query
        [mscq] = manually_serialize_content_query(
            ContentNode.objects.filter(id=section.id) | section.contents
        )
        return Response(mscq)

    @method_decorator(requires_csrf_token)
    @method_decorator(perms_test(directly_editable_section))
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "directly_editable_by"))
    @method_decorator(user_has_perm("section", "directly_editable_by"))
    def delete(self, request, casebook, section, format=None):
        section.delete()
        return Response(status=200)

    @method_decorator(requires_csrf_token)
    @method_decorator(
        perms_test(
            [
                {
                    "args": ["full_casebook", "full_casebook.sections.first"],
                    "results": {
                        403: ["other_user", "full_casebook.testing_editor"],
                        "login": [None],
                    },
                },
                {
                    "args": ["full_private_casebook", "full_private_casebook.sections.first"],
                    "results": {
                        400: ["full_private_casebook.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
                {
                    "args": [
                        "full_casebook_with_draft.draft",
                        "full_casebook_with_draft.draft.sections.first",
                    ],
                    "results": {
                        400: ["full_casebook_with_draft.draft.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
            ]
        )
    )
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "directly_editable_by"))
    @method_decorator(user_has_perm("section", "directly_editable_by"))
    def patch(self, request, casebook, section, format=None):
        try:
            data = json.loads(request.body.decode("utf-8"))
            if "parent" in data and data["parent"]:
                parent_id = data["parent"]
                subsection = Section.objects.filter(id=parent_id).get()
                start_ordinals = subsection.ordinals
            else:
                start_ordinals = []
            new_ordinals = start_ordinals + [data["index"] + 1]
        except Exception:
            return HttpResponseBadRequest(b"Request Body should match: {parent: id, index: Number}")

        try:
            section.content_tree__move_to(new_ordinals)
        except ValueError as e:
            return HttpResponseBadRequest(f"Invalid ordinals: {e.args[0]}".encode("utf8"))
        except IndexError:
            casebook.content_tree__repair()

        return Response(CasebookTOCView.format_casebook(casebook, request), status=200)


class AnnotationListView(APIView):
    @method_decorator(
        perms_test(
            {
                "args": ["resource"],
                "results": {
                    200: ["resource.casebook.testing_editor", "other_user", "admin_user", None]
                },
            },
            {
                "args": ["full_casebook_with_draft.draft.resources.first"],
                "results": {
                    200: ["full_casebook_with_draft.draft.testing_editor", "admin_user"],
                    403: ["other_user"],
                    "login": [None],
                },
            },
        )
    )
    @method_decorator(user_has_perm("resource", "viewable_by"))
    def get(self, request, resource, format=None):
        """
        Return all annotations associated with a Resource node.
        """
        return Response(AnnotationSerializer(resource.annotations.valid(), many=True).data)

    @method_decorator(perms_test(post_directly_editable_resource))
    @method_decorator(user_has_perm("resource", "directly_editable_by"))
    def post(self, request, resource, format=None):
        """
        Create a new annotation associated with a Resource node.

        Given:
        >>> casebook, client = [getfixture(f) for f in ['full_private_casebook', 'client']]
        >>> resource = casebook.resources.first()
        >>> assert resource.annotations.count() == 0
        >>> data = {'id': -1, 'kind': 'note', 'content': 'Some content', 'start_offset': 0, 'end_offset': 10}
        >>> payload = json.dumps({'annotation': data})

        Post the required data as JSON to create a new annotation:
        >>> url = reverse('annotation_list', args=[resource])
        >>> response = client.post(url, payload, content_type="application/json", as_user=resource.testing_editor)
        >>> check_response(response, status_code=201)
        >>> resource.refresh_from_db()
        >>> assert resource.annotations.count() == 1
        >>> assert all([response.data[key] == data[key] for key in ['kind', 'content', 'start_offset', 'end_offset']])
        >>> assert (response.data['id'] != data['id']) and response.data['id'] > 0

        (If you omit any required data, an annotation is not created)
        >>> for key in ['kind', 'content', 'start_offset', 'end_offset']:
        ...     payload = json.dumps({k:v for k,v in data.items() if k != key})
        ...     check_response(client.post(url, payload, content_type="application/json", as_user=resource.testing_editor), status_code=400)
        """
        serializer = NewAnnotationSerializer(data=request.data.get("annotation"))
        resource.reading_length = None
        resource.save()
        if serializer.is_valid():
            serializer.save(resource=resource)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AnnotationDetailView(APIView):
    def initial(self, request, *args, **kwargs):
        fix_after_rails(
            "Let's not use resource in these URLs; let's just use annotation, and load resource as needed from there."
        )
        if kwargs.get("annotation").resource != kwargs.get("resource"):
            return Response(status=status.HTTP_404_NOT_FOUND)
        return super().initial(request, *args, **kwargs)

    @method_decorator(
        perms_test(
            [
                {
                    "args": ["published_annotation.resource", "published_annotation"],
                    "results": {
                        403: ["published_annotation.resource.testing_editor", "other_user"],
                        "login": [None],
                    },
                },
                {
                    "args": ["private_annotation.resource", "private_annotation"],
                    "results": {
                        400: ["private_annotation.resource.testing_editor"],
                        403: ["other_user"],
                        "login": [None],
                    },
                },
            ]
        )
    )
    @method_decorator(user_has_perm("resource", "directly_editable_by"))
    def patch(self, request, resource, annotation, format=json):
        """
        Update the 'content' field of an annotation associated with a Resource node.

        Given:
        >>> annotation, client = [getfixture(f) for f in ['private_annotation', 'client']]
        >>> original_content = annotation.content
        >>> new_content = 'New Content'
        >>> payload = json.dumps({'annotation': {'id': annotation.id, 'content': new_content}})

        Alter the content of an annotation:
        >>> url = reverse('annotation_detail', args=[annotation.resource, annotation])
        >>> response = client.patch(url, payload, content_type="application/json", as_user=annotation.resource.testing_editor)
        >>> check_response(response)
        >>> annotation.refresh_from_db()
        >>> assert annotation.content == new_content

        (At present, you may not alter anything else.)
        >>> payload = json.dumps({'annotation': {'id': annotation.id, 'kind': 'highlight'}})
        >>> check_response(client.patch(url, payload, status_code=400, content_type="application/json", as_user=annotation.resource.testing_editor))
        >>> payload = json.dumps({'annotation': {'id': annotation.id, 'start_offset': 1000}})
        >>> check_response(client.patch(url, payload, status_code=400, content_type="application/json", as_user=annotation.resource.testing_editor))
        >>> payload = json.dumps({'annotation': {'id': annotation.id, 'end_offset': 1000}})
        >>> check_response(client.patch(url, payload, status_code=400, content_type="application/json", as_user=annotation.resource.testing_editor))
        """
        serializer = UpdateAnnotationSerializer(
            annotation, data=request.data.get("annotation"), partial=True
        )
        if serializer.is_valid():
            annotation.resource.reading_length = None
            annotation.resource.save()
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @method_decorator(
        perms_test(
            [
                {
                    "args": ["published_annotation.resource", "published_annotation"],
                    "results": {
                        403: ["published_annotation.resource.testing_editor", "other_user"],
                        "login": [None],
                    },
                },
                {
                    "args": ["private_annotation.resource", "private_annotation"],
                    "results": {
                        204: ["private_annotation.resource.testing_editor"],
                        403: ["other_user"],
                        "login": [None],
                    },
                },
            ]
        )
    )
    @method_decorator(user_has_perm("resource", "directly_editable_by"))
    def delete(self, request, resource, annotation, format=None):
        """
        Delete an annotation associated with a Resource node.

        Given:
        >>> annotation, client = [getfixture(f) for f in ['private_annotation', 'client']]

        Delete the annotation:
        >>> url = reverse('annotation_detail', args=[annotation.resource, annotation])
        >>> check_response(client.delete(url, as_user=annotation.resource.testing_editor), status_code=204)
        >>> with assert_raises(ContentAnnotation.DoesNotExist):
        ...     annotation.refresh_from_db()
        """
        annotation.delete()
        annotation.resource.reading_length = None
        annotation.resource.save()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CommonTitleView(APIView):
    @method_decorator(requires_csrf_token)
    @no_perms_test
    def post(self, request):
        """
        Given:
        >>> private, with_draft, client, user_factory = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client', 'user_factory']]
        >>> draft = with_draft.draft

        A user must be logged in to create a new CommonTitle
        >>> check_response(
        ...     client.post(reverse('new_title'), json.dumps({'name': 'l', 'public_url':'l', 'current':with_draft.id, 'casebooks':[{'id':with_draft.id}]}),content_type="application/json", as_user=None),
        ...     status_code=403
        ... )
        >>> other_user = user_factory()
        >>> check_response(
        ...     client.post(reverse('new_title'), json.dumps({'name': 'l', 'public_url':'l', 'current':with_draft.id, 'casebooks':[{'id':with_draft.id}]}),content_type="application/json", as_user=other_user),
        ...     status_code=403
        ... )
        >>> check_response(
        ...     client.post(reverse('new_title'), json.dumps({'name': 'l', 'public_url':'l', 'current':with_draft.id, 'casebooks':[{'id':with_draft.id}]}),content_type="application/json", as_user=with_draft.testing_editor),
        ...     status_code=200
        ... )
        """
        serializer = NewCommonTitleSerializer(data=request.data)
        if serializer.is_valid():
            cb_data = serializer.validated_data["casebooks"]
            casebooks = set(Casebook.objects.filter(id__in={cb["id"] for cb in cb_data}))
            if len(cb_data) != len(casebooks):
                raise ValidationError
            for casebook in casebooks:
                if not casebook.editable_by(request.user):
                    return HttpResponseForbidden({})
            if serializer.validated_data["current"] not in casebooks:
                raise ValidationError
            val = serializer.save()
            return Response(CommonTitleSerializer(val, context={"request": request}).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, title_id=None):
        """
        Given:
        >>> private, with_draft, client, user_factory = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client', 'user_factory']]
        >>> other_user = user_factory()
        >>> ct = CommonTitle.objects.create(name='foo', public_url='foo', current=with_draft)
        >>> with_draft.common_title = ct
        >>> with_draft.save()
        >>> check_response(
        ...     client.delete(reverse('edit_title', args=[ct.id]), as_user=other_user),
        ...     status_code=403
        ... )
        >>> check_response(
        ...     client.delete(reverse('edit_title', args=[ct.id]), as_user=with_draft.testing_editor),
        ...     status_code=204
        ... )
        """
        title = get_object_or_404(CommonTitle.objects.filter(id=title_id))
        for cb in title.casebooks.all():
            if not cb.editable_by(request.user):
                return HttpResponseForbidden({})
            cb.commont_title = None
        title.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    def put(self, request, title_id=None):
        """
        Given:
        >>> private, with_draft, client, user_factory = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client', 'user_factory']]
        >>> other_user = user_factory()
        >>> ct = CommonTitle.objects.create(name='foo', public_url='foo', current=with_draft)
        >>> with_draft.common_title = ct
        >>> with_draft.save()
        >>> check_response(
        ...     client.put(reverse('edit_title', args=[ct.id]), json.dumps({'name': 'l', 'public_url':'l', 'current':{'id':with_draft.id}, 'casebooks':[{'id':with_draft.id},{'id':private.id}]}),content_type="application/json", as_user=None),
        ...     status_code=403
        ... )
        >>> other_user = user_factory()
        >>> check_response(
        ...     client.put(reverse('edit_title', args=[ct.id]), json.dumps({'name': 'l', 'public_url':'l', 'current':{'id':with_draft.id}, 'casebooks':[{'id':with_draft.id},{'id':private.id}]}),content_type="application/json", as_user=other_user),
        ...     status_code=403
        ... )
        >>> private.add_collaborator(with_draft.testing_editor, can_edit=True)
        >>> check_response(
        ...     client.put(reverse('edit_title', args=[ct.id]), json.dumps({'name': 'l', 'public_url':'l', 'current':{'id':with_draft.id}, 'casebooks':[{'id':with_draft.id},{'id':private.id}]}),content_type="application/json", as_user=with_draft.testing_editor),
        ...     status_code=200
        ... )
        """
        og_title = get_object_or_404(CommonTitle.objects.filter(id=title_id))
        serializer = CommonTitleSerializer(og_title, data=request.data, partial=True)
        if serializer.is_valid():
            old_casebooks = set(Casebook.objects.filter(common_title=title_id).all())
            for casebook in old_casebooks:
                if not casebook.editable_by(request.user):
                    return HttpResponseForbidden({})
            for casebook in Casebook.objects.filter(
                id__in={x["id"] for x in request.data["casebooks"]}
            ).all():
                if not casebook.editable_by(request.user):
                    return HttpResponseForbidden({})
                if casebook in old_casebooks:
                    old_casebooks.remove(casebook)
            if (
                serializer.validated_data["current"]
                not in serializer.validated_data["public_casebooks"]
            ):
                return HttpResponseBadRequest({})
            for ocb in old_casebooks:
                ocb.common_title = None
            Casebook.objects.bulk_update(list(old_casebooks), ["common_title"])
            val = serializer.save()
            data = CommonTitleSerializer(val, context={"request": request}).data
            return Response(data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@perms_test({"results": {200: ["user", None]}})
def index(request):
    if request.user.is_authenticated:
        return dashboard(request, user_id=request.user.id)
    else:
        return render(request, "index.html")


@perms_test({"args": ["user.id"], "results": {200: ["user", None]}})
def dashboard(request, user_id=None, user_slug=None):
    """
    Show given user's casebooks.

    Given:
    >>> casebook, casebook_factory, client, admin_user, user_factory = [getfixture(f) for f in ['casebook', 'casebook_factory', 'client', 'admin_user', 'user_factory']]
    >>> user = casebook.collaborators.first()
    >>> non_collaborating_user = user_factory()
    >>> private_casebook = casebook_factory(contentcollaborator_set__user=user, state=Casebook.LifeCycle.PRIVATELY_EDITING.value)
    >>> draft_casebook = casebook_factory(contentcollaborator_set__user=user, state=Casebook.LifeCycle.DRAFT.value, provenance=[casebook.id])
    >>> casebook.draft = draft_casebook
    >>> casebook.save()
    >>> url = reverse('dashboard', args=[user.id])

    All users can see public casebooks:
    >>> check_response(client.get(url), content_includes=casebook.title)

    Other users cannot see non-public casebooks:
    >>> check_response(client.get(url), content_excludes=private_casebook.title)
    >>> check_response(client.get(url, as_user=non_collaborating_user), content_excludes=private_casebook.title)

    Users can see their own non-public casebooks:
    >>> check_response(client.get(url, as_user=user), content_includes=private_casebook.title)

    Admins can see a user's non-public casebooks:
    >>> check_response(client.get(url, as_user=admin_user), content_includes=private_casebook.title)

    Drafts of published books aren't listed:
    >>> check_response(client.get(url), content_excludes=draft_casebook.title)
    >>> check_response(client.get(url, as_user=user), content_excludes=draft_casebook.title)
    >>> check_response(client.get(url, as_user=admin_user), content_excludes=draft_casebook.title)

    Drafts of published books are described as "unpublished changes" to owners and admins:
    >>> check_response(client.get(url, as_user=user), content_includes="draft_url")

    Drafts of published books are not apparent to other users:
    >>> check_response(client.get(url), content_excludes="This casebook has unpublished changes.")
    >>> check_response(client.get(url, as_user=non_collaborating_user), content_excludes="This casebook has unpublished changes.")
    """
    if user_slug:
        user = get_object_or_404(User, public_url=user_slug)
    elif user_id:
        user = get_object_or_404(User, pk=user_id)
    else:
        raise Http404
    all_casebooks = [
        x
        for x in user.casebooks.exclude(state=Casebook.LifeCycle.ARCHIVED.value)
        .exclude(state=Casebook.LifeCycle.DRAFT.value)
        .exclude(state=Casebook.LifeCycle.PREVIOUS_SAVE.value)
        .all()
        if x.viewable_by(request.user)
    ]
    titles = set([cb.common_title for cb in all_casebooks if cb.common_title])
    loose_casebooks = [x for x in all_casebooks if not x.common_title]
    data = json.dumps(
        {
            "casebooks": CasebookListSerializer(
                loose_casebooks, many=True, context={"request": request}
            ).data,
            "titles": CommonTitleSerializer(titles, many=True, context={"request": request}).data,
            "user": {
                "name": user.display_name,
                "public_url": user.public_url,
                "active": user == request.user,
                "pronouns": user.pronouns,
                "personal_site": user.personal_site,
                "short_bio": user.short_bio,
            },
        }
    )
    return render(request, "dashboard.html", {"user": user, "casebooks": data})


@no_perms_test
def archived_casebooks(request):
    return render(request, "archived_casebooks.html", {"user": request.user})


@no_perms_test
def sign_up(request):
    r"""
    Given:
    >>> _, client, mailoutbox = [getfixture(f) for f in ['db', 'client', 'mailoutbox']]
    >>> assert len(mailoutbox) == 0

    Signup flow -- can sign up with a .edu or .gov account:
    >>> check_response(client.get(reverse('sign_up')), content_includes=['Sign up for an account'])
    >>> check_response(client.post(reverse('sign_up'), {'email_address': 'not_edu@example.com'}), content_includes=['Email address is not .edu or .gov'])
    >>> check_response(client.post(reverse('sign_up'), {'email_address': 'user@example.edu'}, follow=True), content_includes=['Please check your email for a link'])

    Can confirm the account and set a password with the emailed URL:
    >>> assert len(mailoutbox) == 1
    >>> confirm_url = mailoutbox[0].body.rstrip().split("\n")[-1]
    >>> check_response(client.get(confirm_url[:-1]+'wrong/'), content_includes=['The password reset link was invalid'])
    >>> new_password_form_response = client.get(confirm_url, follow=True)
    >>> check_response(new_password_form_response, content_includes=['Please enter your new password twice'])
    >>> check_response(client.post(new_password_form_response.redirect_chain[0][0], {'new_password1': 'anewpass', 'new_password2': 'anewpass'}, follow=True), content_includes=['Your password has been updated'])

    Can log in with the new account:
    >>> check_response(client.post(reverse('login'), {'username': 'user@example.edu', 'password': 'anewpass'}, follow=True),
    ...                  content_includes=['&quot;name&quot;: &quot;Anonymous&quot;',
    ...                                    '&quot;public_url&quot;: null',
    ...                                    '&quot;active&quot;: true']
    ...                )

    Received the welcome email after setting password:
    >>> assert len(mailoutbox) == 2
    >>> assert mailoutbox[1].subject == 'Welcome to H2O!'
    >>> assert settings.GUIDE_URL in mailoutbox[1].body
    """
    form = SignupForm(request.POST or None, request=request)
    if request.method == "POST":
        if form.is_valid():
            form.save()
            messages.success(
                request,
                "Thanks! Please check your email for a link that will let you confirm your account and set a password.",
            )
            return HttpResponseRedirect(reverse("index"))
    return render(request, "registration/sign_up.html", {"form": form})


@perms_test({"results": {200: ["user"], "login": [None]}})
@login_required
def edit_user(request):
    """
    Given:
    >>> user, client, mailoutbox = [getfixture(f) for f in ['user', 'client', 'mailoutbox']]
    >>> url = reverse('edit_user')
    >>> post_kwargs = {'email_address': user.email_address, 'affiliation': user.affiliation, 'attribution': user.attribution}

    Verified professor flow:
    >>> check_response(client.get(url, as_user=user), content_includes=['Request Professor Verification'])
    >>> check_response(client.post(url, {'professor_verification_requested': 'on', **post_kwargs}, as_user=user), content_includes=['Your changes have been saved', 'Professor Verification Requested'])
    >>> assert len(mailoutbox) == 1
    >>> user.verified_professor = True; user.save()
    >>> check_response(client.get(url, as_user=user), content_includes=['Verified Professor'])
    >>> check_response(client.post(url, post_kwargs, as_user=user), content_includes=['Your changes have been saved'])
    >>> assert len(mailoutbox) == 1  # no emails sent if setting isn't changed
    """
    form = UserProfileForm(request.POST or None, instance=request.user, request=request)
    if request.method == "POST":
        if form.is_valid():
            form.save()
            messages.success(request, "Your changes have been saved.")
            form = UserProfileForm(
                instance=request.user
            )  # workaround so professor verification checkbox updates
    return render(request, "user_edit.html", {"form": form})


@perms_test({"results": {302: ["user"], "login": [None]}})
# https://github.com/harvard-lil/h2o/issues/1046
# @require_POST
@login_required
def new_casebook(request):
    """
    Create a new casebook for a user and redirect to its edit page.

    Given:
    >>> client, user = [getfixture(f) for f in ['client', 'user']]
    >>> assert user.casebooks.count() == 0

    Create a casebook and redirect to its edit page.
    >>> response = client.get(reverse('new_casebook'), as_user=user, follow=True)
    >>> check_response(response)
    >>> assert user.casebooks.count() == 1
    >>> assert_url_equal(response, user.casebooks.first().get_edit_url())
    """
    casebook = Casebook()
    casebook.state = Casebook.LifeCycle.PRIVATELY_EDITING.value
    casebook.save()
    casebook.add_collaborator(user=request.user, has_attribution=True, can_edit=True)
    return HttpResponseRedirect(casebook.get_edit_url())


@perms_test(
    {"args": ["casebook"], "results": {200: [None, "other_user", "casebook.testing_editor"]}},
    {
        "args": ["private_casebook"],
        "results": {200: ["private_casebook.testing_editor"], "login": [None], 403: ["other_user"]},
    },
    {
        "args": ["draft_casebook"],
        "results": {200: ["draft_casebook.testing_editor"], "login": [None], 403: ["other_user"]},
    },
    *viewable_resource,
    *viewable_section,
)
@requires_csrf_token
@hydrate_params
@user_has_perm("casebook", "viewable_by")
def show_credits(request, casebook, section=None):
    if section:
        contents = [x for x in section.contents.all()] + [section]
    else:
        contents = [x for x in casebook.contents.all()]

    contents.sort(key=lambda x: x.ordinals)
    originating_node = set(
        [cloned_node for child_content in contents for cloned_node in child_content.provenance]
    )
    prior_art = {
        x.id: x
        for x in ContentNode.objects.filter(id__in=originating_node)
        .select_related("casebook")
        .prefetch_related("casebook__contentcollaborator_set__user")
        .all()
    }
    casebook_mapping = {}
    cloned_sections = {}
    for node in contents:
        if not node.provenance:
            continue
        known_priors = [prior_art[p] for p in node.provenance if p in prior_art]
        known_clones = [p.casebook for p in known_priors]
        if not known_clones:
            continue
        immediate_clone = known_clones[-1]
        incidental_clones = known_clones[:-1]
        cs_set = cloned_sections.get(immediate_clone.id, set())
        cs_set.add(".".join(map(str, node.ordinals)))
        cloned_sections[immediate_clone.id] = cs_set
        nesting_depth = sum(
            map(
                lambda x: x in cs_set,
                [".".join(map(str, node.ordinals[:y])) for y in range(len(node.ordinals))],
            )
        )
        if immediate_clone.id not in casebook_mapping:
            casebook_mapping[immediate_clone.id] = {
                "casebook": immediate_clone,
                "immediate_authors": {
                    c.user
                    for c in immediate_clone.contentcollaborator_set.all()
                    if c.has_attribution and c.user.display_name != "Anonymous"
                },
                "incidental_authors": set(),
                "nodes": [],
            }
        casebook_mapping[immediate_clone.id]["incidental_authors"] |= {
            c.user
            for clone in incidental_clones
            for c in clone.contentcollaborator_set.all()
            if c.has_attribution
            and c.user.display_name != "Anonymous"
            and c.user not in casebook_mapping[immediate_clone.id]["immediate_authors"]
        }
        casebook_mapping[immediate_clone.id]["nodes"].append(
            (node, known_priors[-1], nesting_depth)
        )

    node_type = "casebook"
    if section:
        if section.resource_type == "Section" or not section.resource_type:
            node_type = "section"
        else:
            node_type = "resource"
    params = {
        "contributing_casebooks": [v for v in casebook_mapping.values()],
        "casebook": casebook,
        "section": section,
        "type": node_type,
        "tabs": (section if section else casebook).tabs_for_user(
            request.user, current_tab="Credits"
        ),
        "casebook_color_class": casebook.casebook_color_indicator,
        "edit_mode": casebook.directly_editable_by(request.user),
    }
    return render(request, "casebook_page_credits.html", params)


@perms_test(
    {"args": ["casebook"], "results": {200: [None, "other_user", "casebook.testing_editor"]}},
    {
        "args": ["private_casebook"],
        "results": {200: ["private_casebook.testing_editor"], "login": [None], 403: ["other_user"]},
    },
    {
        "args": ["draft_casebook"],
        "results": {200: ["draft_casebook.testing_editor"], "login": [None], 403: ["other_user"]},
    },
    *viewable_resource,
    *viewable_section,
)
@requires_csrf_token
@hydrate_params
@user_has_perm("casebook", "viewable_by")
def show_related(request, casebook, section=None):
    def get_root_key(cn):
        if cn.resource_type == "LegalDocument":
            return f"{cn.resource.source.search_class}-{cn.resource.source_ref}"
        else:
            root_cn = ContentNode.objects.filter(
                id=cn.provenance[0] if cn.provenance else cn.id
            ).first()
            if not root_cn:
                raise Http404
            if cn.resource_type == "TextBlock":
                return f"text-{root_cn.resource_id}"
        return f"section-{root_cn.id}"

    subject = section if section else casebook
    contents = [x for x in subject.contents.prefetch_resources().all()] + (
        [section] if section else []
    )
    descendants = {x for x in subject.descendant_nodes.all()}
    related_docs = {x for x in subject.related_docs.all() if x not in descendants}
    related_map = dict()
    for cn in contents:
        root_key = get_root_key(cn)
        related_map[root_key] = [cn]

    content_keys = {get_root_key(cn) for cn in contents if cn.resource_type == "LegalDocument"}
    related_casebooks = (
        {cn.casebook for cn in descendants}
        .union({cn.casebook for cn in related_docs})
        .difference({casebook})
    )
    novel_docs = dict()
    for cn in (
        ContentNode.objects.filter(casebook__in=related_casebooks, resource_type="LegalDocument")
        .prefetch_related("casebook")
        .all()
    ):
        if get_root_key(cn) not in content_keys:
            if cn.resource in novel_docs:
                novel_docs[cn.resource] += 1
            else:
                novel_docs[cn.resource] = 1

    novel_docs = sorted([(k, v) for k, v in novel_docs.items()], key=lambda x: -x[1])
    for cn in descendants:
        root_key = get_root_key(cn)
        if root_key in related_map:
            related_map[root_key].append(cn)
        else:
            logger.warning(f"Unknown relation: {cn.id} -- {root_key}")
            raise Http404
    for cn in related_docs:
        root_key = get_root_key(cn)
        if root_key in related_map:
            related_map[root_key].append(cn)
        else:
            logger.warning(f"Unknown relation: {cn.id} -- {root_key}")
            raise Http404

    related_content = sorted(
        ({"local": x[0], "related": x[1:]} for x in related_map.values() if len(x) > 1),
        key=lambda x: x["local"].ordinals,
    )

    node_type = "casebook"
    if section:
        if section.resource_type == "Section" or not section.resource_type:
            node_type = "section"
        else:
            node_type = "resource"
    params = {
        "related_content": related_content,
        "related_casebooks": related_casebooks,
        "novel_docs": novel_docs,
        "casebook": casebook,
        "section": section,
        "type": node_type,
        "tabs": (section if section else casebook).tabs_for_user(
            request.user, current_tab="Related"
        ),
        "casebook_color_class": casebook.casebook_color_indicator,
        "edit_mode": casebook.directly_editable_by(request.user),
    }
    return render(request, "casebook_page_related.html", params)


@no_perms_test
@hydrate_params
@user_has_perm("casebook", "viewable_by")
def casebook_history(request, casebook):
    if request.user and request.user.id:
        cb_follow = CasebookFollow.objects.filter(user=request.user, casebook=casebook).first()
        if cb_follow:
            cb_follow.updated_at = datetime.now()
            cb_follow.save()
    params = {
        "casebook": casebook,
        "tabs": casebook.tabs_for_user(request.user, current_tab="History"),
        "casebook_color_class": casebook.casebook_color_indicator,
        "edit_mode": casebook.directly_editable_by(request.user),
    }
    return render(request, "casebook_history.html", params)


@requires_csrf_token
@perms_test(
    {"method": "post", "args": ["casebook"], "results": {302: ["other_user"]}},
    {"method": "post", "args": ["draft_casebook"], "results": {403: ["other_user"]}},
)
@require_POST
@login_required
@hydrate_params
def follow_casebook(request, casebook):
    if request.user in casebook.all_collaborators or not casebook.is_public:
        return HttpResponseForbidden("You cannot follow a casebook you are a collaborator on.")
    check = CasebookFollow.objects.filter(user=request.user, casebook=casebook).first()
    if check:
        check.delete()
    else:
        CasebookFollow.objects.create(user=request.user, casebook=casebook)
    return HttpResponseRedirect(request.META.get("HTTP_REFERER", casebook.get_absolute_url()))


@requires_csrf_token
@no_perms_test
@hydrate_params
@user_has_perm("casebook", "editable_by")
def casebook_settings(request, casebook):
    ModificationFormSet = modelformset_factory(
        ContentCollaborator,
        fields=("id", "can_edit", "has_attribution"),
        widgets={"id": HiddenInput()},
        formset=CollaboratorFormSet,
        extra=0,
        can_delete=True,
    )
    collaborator_queryset = (
        casebook.contentcollaborator_set.order_by("id").select_related("user").all()
    )
    modify_collaborator_form = ModificationFormSet(
        queryset=collaborator_queryset, auto_id="", prefix="form"
    )
    invite_collaborator_form = InviteCollaboratorForm(initial={"casebook": casebook.id})
    editors = [c for c in collaborator_queryset if c.can_edit]
    only_editor = len(editors) == 1 and editors[0].user.id == request.user.id
    if request.method == "POST":
        data = dict(request.POST)
        form_type = data.pop("submission_type", None)
        if form_type:
            form_type = form_type.pop()
            if form_type == "modify_collaborators":
                for k in data.keys():
                    data[k] = data[k].pop()
                modify_collaborator_form = ModificationFormSet(
                    data=data, queryset=collaborator_queryset, auto_id="", prefix="form"
                )
                if modify_collaborator_form.is_valid():
                    modify_collaborator_form.save()
                    modify_collaborator_form = ModificationFormSet(
                        queryset=casebook.contentcollaborator_set.order_by("id")
                        .select_related("user")
                        .all(),
                        auto_id="",
                        prefix="form",
                    )
            if form_type == "add_collaborator":
                invite_collab_form = InviteCollaboratorForm(request.POST)
                if invite_collab_form.is_valid():
                    invite_collab_form.save(request)
                    modify_collaborator_form = ModificationFormSet(
                        queryset=casebook.contentcollaborator_set.order_by("id")
                        .select_related("user")
                        .all(),
                        auto_id="",
                        prefix="form",
                    )
            if form_type == "change_visibility":
                settings = CasebookSettingsTransitionForm(request.POST)
                if settings.is_valid():
                    transition_to = (
                        settings["transition_to"].value()
                        if "transition_to" in settings.fields
                        else None
                    )
                    if transition_to and casebook.can_transition_to(transition_to):
                        casebook.transition_to(transition_to)
            if form_type == "leave_collaboration":
                if not only_editor:
                    collab = ContentCollaborator.objects.filter(
                        casebook=casebook, user=request.user
                    ).first()
                    if collab:
                        collab.delete()
                    return HttpResponseRedirect("/")

    only_editor = not [
        c for c in collaborator_queryset if c.can_edit and not c.user.id == request.user.id
    ]
    params = {
        "casebook": casebook,
        "tabs": casebook.tabs_for_user(request.user, current_tab="Settings"),
        "casebook_color_class": casebook.casebook_color_indicator,
        "edit_mode": casebook.directly_editable_by(request.user),
        "modify_collaborator_form": modify_collaborator_form,
        "invite_collaborator_form": invite_collaborator_form,
        "only_editor": only_editor,
    }
    return render(request, "casebook_settings.html", params)


@no_perms_test
@hydrate_params
def casebook_outline(request, casebook):
    params = {
        "casebook": casebook,
        "tabs": casebook.tabs_for_user(request.user, current_tab="Settings"),
        "casebook_color_class": "casebook-archived"
        if casebook.is_archived
        else "casebook-preview casebook-public",
        "edit_mode": casebook.directly_editable_by(request.user),
    }
    return render(request, "casebook_outline_edit.html", params)


class CasebookView(View):
    @method_decorator(
        perms_test(
            {
                "args": ["casebook"],
                "results": {200: [None, "other_user", "casebook.testing_editor"]},
            },
            {
                "args": ["private_casebook"],
                "results": {
                    200: ["private_casebook.testing_editor"],
                    "login": [None],
                    403: ["other_user"],
                },
            },
            {
                "args": ["draft_casebook"],
                "results": {
                    200: ["draft_casebook.testing_editor"],
                    "login": [None],
                    403: ["other_user"],
                },
            },
        )
    )
    @method_decorator(requires_csrf_token)
    @method_decorator(hydrate_params)
    def get(self, request: HttpRequest, casebook: Casebook):
        """
        Show a casebook's front page.

        Given:
        >>> casebook, casebook_factory, client, admin_user, user_factory = [getfixture(f) for f in ['casebook', 'casebook_factory', 'client', 'admin_user', 'user_factory']]
        >>> user = casebook.collaborators.first()
        >>> non_collaborating_user = user_factory()
        >>> private_casebook = casebook_factory(contentcollaborator_set__user=user, state=Casebook.LifeCycle.PRIVATELY_EDITING.value)
        >>> draft_casebook = casebook_factory(contentcollaborator_set__user=user, state=Casebook.LifeCycle.DRAFT.value, provenance=[casebook.id])

        All users can see public casebooks:
        >>> check_response(client.get(casebook.get_absolute_url(), content_includes=casebook.title))

        Users can see their own non-public casebooks in preview mode:
        >>> check_response(client.get(private_casebook.get_absolute_url(), as_user=user), content_includes=[private_casebook.title, "You are viewing a private casebook"])

        Owners see the "preview mode" of draft casebooks:
        >>> check_response(client.get(draft_casebook.get_absolute_url(), as_user=user), content_includes="You are viewing a preview")
        """
        if not casebook.viewable_by(request.user):
            if casebook.is_previous_save:
                parent = casebook.version_tree__parent()
                return HttpResponseRedirect(reverse("casebook", args=[parent]))
            if (
                request.user.is_authenticated
                and casebook.contentcollaborator_set.filter(
                    user=request.user, can_edit=True
                ).exists()
            ):
                return HttpResponseRedirect(reverse("casebook_settings", args=[casebook]))
            else:
                return login_required_response(request)

        if casebook.is_previous_save:
            parent = casebook.version_tree__parent()
            url = reverse("casebook", args=[parent])
            if parent.draft and parent.draft.directly_editable_by(request.user):
                url = reverse("edit_casebook", args=[parent.draft])
            return HttpResponseRedirect(url)

        contents = casebook.contents.prefetch_resources()

        return render_with_actions(
            request,
            "casebook_page.html",
            {
                "casebook": casebook,
                "tabs": casebook.tabs_for_user(request.user),
                "casebook_color_class": casebook.casebook_color_indicator,
                "contents": contents,
                "publish_check": json.dumps(
                    {
                        "isVerifiedProfessor": request.user.is_authenticated
                        and request.user.verified_professor,
                        "coverImageFlag": settings.COVER_IMAGES,
                        "coverImageExists": bool(
                            casebook.cover_image
                        ),  # Handling both blank and None
                        "descriptionExists": bool(casebook.description),
                    }
                ),
            },
        )

    @method_decorator(
        perms_test(
            {
                "args": ["private_casebook"],
                "results": {
                    302: ["private_casebook.testing_editor"],
                    "login": [None],
                    403: ["other_user"],
                },
            },
            {
                "args": ["draft_casebook"],
                "results": {
                    302: ["draft_casebook.testing_editor"],
                    "login": [None],
                    403: ["other_user"],
                },
            },
            {"args": ["casebook"], "results": {403: ["casebook.testing_editor"]}},
        )
    )
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "editable_by"))
    def patch(self, request, casebook):
        """
        Publish a casebook.
        https://github.com/harvard-lil/h2o/issues/1047

        Given:
        >>> casebook, casebook_factory, client, admin_user, user_factory = [getfixture(f) for f in ['casebook', 'casebook_factory', 'client', 'admin_user', 'user_factory']]
        >>> user = casebook.collaborators.first()
        >>> non_collaborating_user = user_factory()
        >>> private_casebook = casebook_factory(contentcollaborator_set__user=user, state=Casebook.LifeCycle.PRIVATELY_EDITING.value)
        >>> draft_casebook = casebook_factory(contentcollaborator_set__user=user, state=Casebook.LifeCycle.DRAFT.value, provenance=[casebook.id])
        >>> casebook.draft = draft_casebook
        >>> draft_casebook.save()
        >>> casebook.save()

        Newly-composed (private, never-published) casebooks, when published, become public.
        >>> response = client.patch(private_casebook.get_absolute_url(), as_user=user, follow=True)
        >>> check_response(
        ...     response,
        ...     content_includes=private_casebook.title,
        ...     content_excludes="You are viewing a preview"
        ... )
        >>> private_casebook.refresh_from_db()
        >>> assert_url_equal(response, private_casebook.get_absolute_url())
        >>> assert private_casebook.is_public

        Drafts of already-published casebooks, when published, replace their parent.
        >>> response = client.patch(draft_casebook.get_absolute_url(), as_user=user, follow=True)
        >>> check_response(
        ...     response,
        ...     content_includes=draft_casebook.title,
        ...     content_excludes="You are viewing a preview"
        ... )
        >>> casebook.refresh_from_db()
        >>> assert_url_equal(response, casebook.get_absolute_url())
        >>> assert casebook.is_public
        """
        # check permissions
        if casebook.is_public:
            raise PermissionDenied("Only private casebooks may be published.")
        if not casebook.can_publish:
            return HttpResponseBadRequest("Casebook is not publishable")
        if casebook.is_draft:
            casebook = casebook.merge_draft()
        else:
            casebook.state = Casebook.LifeCycle.PUBLISHED.value
            CasebookEditLog.objects.create(
                casebook=casebook, change=CasebookEditLog.ChangeType.ORIGINAL_PUBLISH.value
            )
            casebook.save()

        # The javascript that makes these PATCH requests expects a redirect
        # to the published casebook.
        # https://github.com/harvard-lil/h2o/issues/1050
        return HttpResponseRedirect(reverse("casebook", args=[casebook]))


@perms_test(
    {
        "method": "post",
        "args": ["casebook"],
        "results": {302: ["casebook.testing_editor", "other_user"], "login": [None]},
    },
    {
        "method": "post",
        "args": ["draft_casebook"],
        "results": {403: ["casebook.testing_editor", "other_user"], "login": [None]},
    },
)
@require_POST
@login_required
@hydrate_params
def clone_casebook(request, casebook):
    """
    Clone a casebook and redirect to edit page for clone.
    """
    if casebook.permits_cloning:
        clone = casebook.clone(request.user)
        return HttpResponseRedirect(reverse("edit_casebook", args=[clone]))
    raise PermissionDenied


@no_perms_test
def clone_casebook_nodes(request, from_casebook_dict, from_section_dict, to_casebook_dict):
    from_section = get_object_or_404(
        ContentNode.objects.filter(
            casebook=from_casebook_dict["id"], ordinals=from_section_dict["ordinals"]
        )
    )
    to_casebook = get_object_or_404(Casebook.objects.filter(id=to_casebook_dict["id"]))
    if not from_section.permits_cloning:
        raise PermissionDenied
    if not to_casebook.directly_editable_by(request.user):
        raise PermissionDenied
    from_section.content_tree__load()
    nodes_to_clone = [from_section] + [d for d in from_section.content_tree__descendants]
    to_casebook.clone_nodes(nodes_to_clone, append=True)
    to_casebook.refresh_from_db()
    new_add = to_casebook.children.order_by("-ordinals").first()
    link_hash = new_add.ordinal_string() + "-" + new_add.get_slug()
    return HttpResponseRedirect(to_casebook.get_edit_url() + "#" + link_hash)


@perms_test(
    {
        "method": "post",
        "args": ["casebook"],
        "results": {302: ["casebook.testing_editor"], 403: ["other_user"], "login": [None]},
    },
    # casebook owner can make drafts
    {
        "method": "post",
        "args": ["private_casebook"],
        "results": {403: ["private_casebook.testing_editor", "other_user"], "login": [None]},
    },
    # no drafts of private casebooks
    {
        "method": "post",
        "args": ["draft_casebook"],
        "results": {403: ["draft_casebook.testing_editor", "other_user"], "login": [None]},
    },
    # no drafts of draft casebooks
)
@require_POST
@hydrate_params
@user_has_perm("casebook", "allows_draft_creation_by")
def create_draft(request, casebook):
    """
    Create a draft of a casebook and redirect to its edit page.
    """
    clone = casebook.make_draft()
    return HttpResponseRedirect(reverse("edit_casebook", args=[clone]))


@perms_test(
    {
        "method": "post",
        "args": ["casebook"],
        "results": {302: ["casebook.testing_editor", "other_user"]},
    },
    {
        "method": "post",
        "args": ["draft_casebook"],
        "results": {200: ["draft_casebook.testing_editor"], 302: ["other_user"]},
    },
    {
        "method": "post",
        "args": ["private_casebook"],
        "results": {200: ["private_casebook.testing_editor"], 302: ["other_user"]},
    },
)
@require_http_methods(["GET", "POST"])
@requires_csrf_token
@hydrate_params
def edit_casebook(request, casebook: Casebook):
    """
    Given:
    >>> private, with_draft, for_verified_prof, client = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'full_private_casebook_for_verified_prof', 'client']]
    >>> draft = with_draft.draft

    Users can edit their unpublished and draft casebooks:
    >>> new_title = 'owner-edited title'
    >>> check_response(
    ...    client.get(private.get_edit_url(), as_user=private.testing_editor),
    ...    content_includes=[private.title, "You are viewing a private casebook"],
    ... )
    >>> check_response(
    ...     client.post(private.get_edit_url(), {'title': new_title}, as_user=private.testing_editor),
    ...     content_includes=new_title,
    ...     content_excludes=private.title
    ... )
    >>> check_response(
    ...    client.get(draft.get_edit_url(), as_user=draft.testing_editor),
    ...    content_includes=[draft.title, "This casebook is a draft"],
    ... )
    >>> check_response(
    ...     client.post(draft.get_edit_url(), {'title': new_title}, as_user=draft.testing_editor),
    ...     content_includes=new_title,
    ...     content_excludes=draft.title
    ... )

    Verified professors may upload cover images; standard users may not:
    >>> check_response(
    ...    client.get(draft.get_edit_url(), as_user=draft.testing_editor),
    ...    content_excludes=["Cover Image", 'type="file"'],
    ... )
    >>> check_response(
    ...    client.get(for_verified_prof.get_edit_url(), as_user=for_verified_prof.attributed_authors[0]),
    ...    content_includes=["Cover Image", 'type="file"'],
    ... )
    """
    if not request.user.is_authenticated or not casebook.directly_editable_by(request.user):
        return HttpResponseRedirect(reverse("casebook", args=[casebook]))

    form_class = (
        CasebookFormWithCoverImage
        if settings.COVER_IMAGES and (request.user.is_superuser or request.user.verified_professor)
        else CasebookForm
    )
    form = form_class(request.POST or None, request.FILES or None, instance=casebook)
    if request.method == "POST" and form.is_valid():
        form.save()
        form = form_class(instance=casebook)

    casebook.contents.prefetch_resources()
    search_sources = LegalDocumentSource.objects.all()
    if not (request.user and request.user.is_superuser):
        search_sources = search_sources.filter(active=True)
    doc_sources = list(search_sources.order_by("priority").all())
    serialized_sources = LegalDocumentSourceSerializer(doc_sources, many=True).data
    search_sources_json = json.dumps(serialized_sources)

    return render_with_actions(
        request,
        "casebook_page.html",
        {
            "casebook": casebook,
            "editing": True,
            "search_sources_json": search_sources_json,
            "tabs": casebook.tabs_for_user(request.user, current_tab="Edit"),
            "casebook_color_class": casebook.casebook_color_indicator,
            "form": form,
            "publish_check": json.dumps(
                {
                    "isVerifiedProfessor": request.user.is_authenticated
                    and request.user.verified_professor,
                    "coverImageFlag": settings.COVER_IMAGES,
                    "coverImageExists": bool(casebook.cover_image),  # Handling both blank and None
                    "descriptionExists": bool(casebook.description),
                }
            ),
        },
    )


@transaction.atomic
def create_from_form(casebook, parent_section, form):
    fresh_body = form.save()
    ordinals, display_ordinals = parent_section.content_tree__get_next_available_child_ordinals()
    fresh_resource = Resource(
        title=fresh_body.get_name(),
        casebook=casebook,
        ordinals=ordinals,
        display_ordinals=display_ordinals,
        resource_id=fresh_body.id,
        resource_type=type(fresh_body).__name__,
    )
    fresh_resource.save()
    return HttpResponseRedirect(fresh_resource.get_edit_url())


@perms_test(
    {
        "method": "post",
        "args": ["casebook"],
        "results": {403: ["casebook.testing_editor", "other_user"], "login": [None]},
    },
    {
        "method": "post",
        "args": ["draft_casebook"],
        "results": {400: ["draft_casebook.testing_editor"], 403: ["other_user"], "login": [None]},
    },
    {
        "method": "post",
        "args": ["private_casebook"],
        "results": {400: ["private_casebook.testing_editor"], 403: ["other_user"], "login": [None]},
    },
)
@require_http_methods(["POST"])
@hydrate_params
@user_has_perm("casebook", "directly_editable_by")
def new_section(request, casebook):
    """
    Creates a new section as a last child of the given casebook+section

        Given:
        >>> client = getfixture('client')
        >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
        >>> casebook.state = Casebook.LifeCycle.PRIVATELY_EDITING.value
        >>> casebook.save()

        A simple POST adds a new section to the end of the casebook.
        >>> url = reverse('new_section', args=[casebook])
        >>> response = client.post(url, {'title': 'Made up title'}, as_user=casebook.testing_editor, follow=True)
        >>> check_response(response)
        >>> s_3 = casebook.contents.last()
        >>> assert not s_3.resource
        >>> assert s_3.ordinals == [3]
        >>> assert s_3.title == 'Made up title'
        >>> assert dump_content_tree_children(casebook) == [s_1, s_2, s_3]
        >>> assert_url_equal(response, s_3.get_edit_url())

    """
    form = SectionForm(request.POST or None)
    parent_section_id = request.POST.get("section", None)
    parent_section = Section.objects.get(id=parent_section_id) if parent_section_id else casebook
    if form.is_valid():
        fresh_section = form.save(commit=False)
        (
            ordinals,
            display_ordinals,
        ) = parent_section.content_tree__get_next_available_child_ordinals()
        fresh_section.ordinals = ordinals
        fresh_section.display_ordinals = display_ordinals
        fresh_section.casebook = casebook
        fresh_section.save()
        return HttpResponseRedirect(fresh_section.get_edit_url())
    else:
        return JsonResponse(form.errors.as_data(), status=status.HTTP_400_BAD_REQUEST)


@perms_test(
    {
        "method": "post",
        "args": ["casebook"],
        "results": {403: ["casebook.testing_editor", "other_user"], "login": [None]},
    },
    {
        "method": "post",
        "args": ["draft_casebook"],
        "results": {400: ["draft_casebook.testing_editor"], 403: ["other_user"], "login": [None]},
    },
    {
        "method": "post",
        "args": ["private_casebook"],
        "results": {400: ["private_casebook.testing_editor"], 403: ["other_user"], "login": [None]},
    },
)
@require_http_methods(["POST"])
@hydrate_params
@user_has_perm("casebook", "directly_editable_by")
def new_text(request, casebook):
    """
    Creates a new TextBlock as the last child of casebook or section


    Given:
        >>> client = getfixture('client')
        >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
        >>> casebook.state = Casebook.LifeCycle.PRIVATELY_EDITING.value
        >>> casebook.save()
        >>> url = reverse('new_text', args=[casebook])
        >>> data = {'name': 'Eureka!', 'content': '<em>Eureka</em>', 'section': s_1.id}
        >>> response = client.post(url, data, as_user=casebook.testing_editor, follow=True)
        >>> check_response(response)
        >>> r_1_5 = s_1.contents.last()
        >>> assert r_1_5.resource
        >>> assert r_1_5.ordinals == [1,5]
        >>> assert all([isinstance(r_1_5.resource, TextBlock), r_1_5.resource.name == data['name'], r_1_5.resource.content == data['content']])
        >>> assert r_1_5.title == r_1_5.resource.get_name()
        >>> assert dump_content_tree_children(s_1) == [r_1_1, r_1_2, r_1_3, s_1_4, r_1_5]
    """
    form = NewTextBlockForm(request.POST or None)
    parent_section_id = request.POST.get("section", None)
    parent_section = Section.objects.get(id=parent_section_id) if parent_section_id else casebook
    if form.is_valid():
        return create_from_form(casebook, parent_section, form)
    else:
        return JsonResponse(form.errors.get_json_data(), status=status.HTTP_400_BAD_REQUEST)


@perms_test(
    {
        "method": "post",
        "args": ["casebook"],
        "results": {403: ["casebook.testing_editor", "other_user"], "login": [None]},
    },
    {
        "method": "post",
        "args": ["draft_casebook"],
        "results": {400: ["draft_casebook.testing_editor"], 403: ["other_user"], "login": [None]},
    },
    {
        "method": "post",
        "args": ["private_casebook"],
        "results": {400: ["private_casebook.testing_editor"], 403: ["other_user"], "login": [None]},
    },
)
@require_http_methods(["POST"])
@hydrate_params
@user_has_perm("casebook", "directly_editable_by")
def new_link(request, casebook):
    """
    Creates a new Link as the last child of a casebook or section

    Given:
        >>> client = getfixture('client')
        >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
        >>> casebook.state = Casebook.LifeCycle.PRIVATELY_EDITING.value
        >>> casebook.save()
        >>> url = reverse('new_link', args=[casebook])
        >>> data = {'url': 'http://example.com', 'section': s_1.id}
        >>> response = client.post(url, data, as_user=casebook.testing_editor, follow=True)
        >>> check_response(response)
        >>> r_1_5 = s_1.contents.last()
        >>> assert r_1_5.resource
        >>> assert r_1_5.ordinals == [1,5]
        >>> assert all([isinstance(r_1_5.resource, Link), r_1_5.resource.url == data['url']])
        >>> assert r_1_5.title == r_1_5.resource.get_name()
        >>> assert dump_content_tree_children(s_1) == [r_1_1, r_1_2, r_1_3, s_1_4, r_1_5]
        >>> assert_url_equal(response, r_1_5.get_edit_url())

    """
    form = LinkForm(request.POST or None)
    parent_section_id = request.POST.get("section", None)
    parent_section = Section.objects.get(id=parent_section_id) if parent_section_id else casebook
    if form.is_valid():
        name = get_link_title(form.cleaned_data["url"])
        if "name" not in form.cleaned_data or not form.cleaned_data["name"]:
            form.cleaned_data["name"] = name
            form = LinkForm(form.cleaned_data)
            form.is_valid()
        return create_from_form(casebook, parent_section, form)
    else:
        return JsonResponse(form.errors.get_json_data(), status=status.HTTP_400_BAD_REQUEST)


@perms_test(
    {
        "method": "post",
        "args": ["casebook"],
        "results": {403: ["casebook.testing_editor", "other_user"], "login": [None]},
    },
    {
        "method": "post",
        "args": ["draft_casebook"],
        "results": {400: ["draft_casebook.testing_editor"], 403: ["other_user"], "login": [None]},
    },
    {
        "method": "post",
        "args": ["private_casebook"],
        "results": {400: ["private_casebook.testing_editor"], 403: ["other_user"], "login": [None]},
    },
)
@require_http_methods(["POST"])
@hydrate_params
@user_has_perm("casebook", "directly_editable_by")
def new_legal_doc(request, casebook):
    """
    Creates a new LegalDoc as the last child of a casebook or section
    """

    if "resource_id" not in request.POST:
        return JsonResponse(
            {"resource_id": [{"message": "A resource id must be provided to use a case"}]},
            status=status.HTTP_400_BAD_REQUEST,
        )
    doc_id = request.POST["resource_id"]
    doc = get_object_or_404(LegalDocument.objects.filter(id=doc_id))
    parent_section_id = request.POST.get("section", None)
    parent_section = Section.objects.get(id=parent_section_id) if parent_section_id else casebook
    ordinals, display_ordinals = parent_section.content_tree__get_next_available_child_ordinals()
    fresh_resource = Resource(
        title=doc.get_name(),
        casebook=casebook,
        ordinals=ordinals,
        display_ordinals=display_ordinals,
        resource_id=doc.id,
        resource_type="LegalDocument",
    )
    fresh_resource.save()
    return HttpResponseRedirect(reverse("annotate_resource", args=[casebook, fresh_resource]))


def switch_node_type(request, casebook, content_node):
    """
    Change the type of a resource in a casebook.

    Given:
    >>> private, client = [getfixture(f) for f in ['full_private_casebook', 'client']]
    >>> private_resource = private.resources.first()
    >>> _ = private_resource.resource.delete()
    >>> private_resource.resource_id = None
    >>> private_resource.resource_type = 'Temp'
    >>> private_resource.save()

    >>> owner = private_resource.testing_editor
    >>> data = '{"from": "Temp", "to": "Link", "url": "https://example.com/"}'
    >>> url = reverse('resource', args=[private_resource.casebook, private_resource])
    >>> response = client.patch(url, data, as_user=owner)
    >>> assert response.status_code == 302
    >>> private_resource.refresh_from_db()
    >>> assert private_resource.resource_type == 'Link'
    """
    if not content_node.is_transmutable():
        return HttpResponseBadRequest("Work has begun on this resource, and it cannot be changed.")
    try:
        data = json.loads(request.body.decode("utf-8"))
        old_type = data["from"]
        if content_node.resource_type != old_type:
            return HttpResponseBadRequest("Resource is not of " + old_type)
        new_type = data["to"]
        if old_type == new_type:
            return HttpResponseBadRequest("To and From are the same")
        if content_node.has_body and content_node.resource_type == "TextBlock":
            old_resource = content_node.resource
        else:
            old_resource = None
        if new_type == "LegalDocument":
            source_id = data.get("source_id", None)
            source_ref = data.get("id", None)
            if source_id is not None:
                content_node.title = data.get("title", content_node.title)

                source = LegalDocumentSource.objects.get(id=int(source_id))
                if source and source_ref:
                    legal_doc = internal_doc_id_from_source(source, source_ref)
                    content_node.resource_type = new_type
                    content_node.resource_id = legal_doc.id
            else:
                content_node.resource_type = "Temp"
                content_node.resource_id = None
            content_node.save()
        elif new_type == "Link":
            url = data.get("url", "https://opencasebook.org/")
            content_node.resource_type = new_type
            link = Link(name=content_node.title, url=url, public=True)
            link.save()
            content_node.resource_id = link.id
            content_node.save()
        elif new_type == "TextBlock":
            content = data.get("content", "")
            text_block = TextBlock(name=content_node.title[0:250], content=content)
            text_block.save()
            text_block.refresh_from_db()
            content_node.resource_id = text_block.id
            content_node.resource_type = new_type
            content_node.save()
            logger.info(
                f"TB: {text_block.id}, CN.rid: {content_node.resource_id}, OR: {old_resource.id if old_resource else None}"
            )
        elif new_type == "Section":
            content_node.resource_type = new_type
            content_node.resource_id = None
            content_node.save()
    except Exception:
        return HttpResponseBadRequest("Improperly formatted request")
    if old_resource:
        logger.info(f"Deleting resource: {old_resource.id}")
        old_resource.delete()
    return HttpResponseRedirect(content_node.get_preferred_url)


class SectionView(View):
    @method_decorator(perms_test(viewable_section))
    @method_decorator(requires_csrf_token)
    @method_decorator(hydrate_params)
    def get(self, request, casebook, section):
        """
        Show a section within a casebook.

        Given:
        >>> published, private, with_draft, client = [getfixture(f) for f in ['full_casebook', 'full_private_casebook', 'full_casebook_with_draft', 'client']]
        >>> published_section = published.sections.first()
        >>> private_section = private.sections.first()
        >>> draft_section = with_draft.draft.sections.first()

        All users can see sections in public casebooks:
        >>> check_response(client.get(published_section.get_absolute_url(), content_includes=published_section.title))

        Users can see sections in their own non-public casebooks in preview mode:
        >>> check_response(
        ...     client.get(private_section.get_absolute_url(), as_user=private_section.testing_editor),
        ...     content_includes=[private_section.title, "You are viewing a private"],
        ... )

        Owners see the "preview mode" of sections in draft casebooks:
        >>> check_response(client.get(draft_section.get_absolute_url(), as_user=draft_section.testing_editor), content_includes="You are viewing a preview")
        """
        # canonical redirect
        if not casebook.viewable_by(request.user):
            if (
                request.user.is_authenticated
                and casebook.contentcollaborator_set.filter(
                    user=request.user, can_edit=True
                ).exists()
            ):
                return HttpResponseRedirect(reverse("casebook_settings", args=[casebook]))
            else:
                return login_required_response(request)

        canonical = section.get_absolute_url()
        if request.path != canonical:
            return HttpResponseRedirect(canonical)
        return render_with_actions(
            request,
            "casebook_page.html",
            {
                "casebook": casebook,
                "section": section,
                "tabs": section.tabs_for_user(request.user),
                "casebook_color_class": casebook.casebook_color_indicator,
                "edit_mode": casebook.directly_editable_by(request.user),
                "previous_and_next_urls": section.get_previous_and_next_node_urls(
                    user=request.user
                ),
                "publish_check": json.dumps(
                    {
                        "isVerifiedProfessor": request.user.is_authenticated
                        and request.user.verified_professor,
                        "coverImageFlag": settings.COVER_IMAGES,
                        "coverImageExists": bool(
                            casebook.cover_image
                        ),  # Handling both blank and None
                        "descriptionExists": bool(casebook.description),
                    }
                ),
            },
        )

    @method_decorator(perms_test(directly_editable_section))
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "directly_editable_by"))
    def delete(self, request, casebook, section):
        """
        Delete a section from a casebook

        Given:
        >>> private, with_draft, client = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client']]
        >>> private_section = private.sections.first()
        >>> draft_section = with_draft.draft.sections.first()

        Users can delete sections in their unpublished and draft casebooks:
        >>> for section in [private_section, draft_section]:
        ...     owner = section.testing_editor
        ...     url = reverse('section', args=[section.casebook, section])
        ...     check_response(client.delete(url, as_user=owner))
        ...     with assert_raises(ContentNode.DoesNotExist):
        ...         section.refresh_from_db()
        """
        fix_after_rails("Let's return 204 instead of 200.")
        section.delete()
        return HttpResponse()

    @method_decorator(
        perms_test(
            [
                {
                    "method": "patch",
                    "args": ["full_casebook", "full_casebook.sections.first"],
                    "results": {
                        403: ["other_user", "full_casebook.testing_editor"],
                        "login": [None],
                    },
                },
                {
                    "method": "patch",
                    "args": ["full_private_casebook", "full_private_casebook.sections.first"],
                    "results": {
                        400: ["full_private_casebook.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
                {
                    "method": "patch",
                    "args": [
                        "full_casebook_with_draft.draft",
                        "full_casebook_with_draft.draft.sections.first",
                    ],
                    "results": {
                        400: ["full_casebook_with_draft.draft.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
            ]
        )
    )
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "directly_editable_by"))
    def patch(self, request, casebook, section):
        return switch_node_type(request, casebook, section)


@perms_test(directly_editable_section)
@require_http_methods(["GET", "POST"])
@requires_csrf_token
@hydrate_params
@user_has_perm("casebook", "directly_editable_by")
def edit_section(request, casebook, section):
    """
    Let authorized users update Section metadata.

    Given:
    >>> private, with_draft, client = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client']]
    >>> private_section = private.sections.first()
    >>> draft_section = with_draft.draft.sections.first()

    Users can edit sections in their unpublished and draft casebooks:
    >>> for section in [private_section, draft_section]:
    ...     new_title = 'owner-edited title'
    ...     check_response(
    ...         client.get(section.get_edit_url(), as_user=section.testing_editor),
    ...         content_includes=[section.title, "casebook-draft"],
    ...     )
    ...     check_response(
    ...         client.post(section.get_edit_url(), {'title': new_title}, as_user=section.testing_editor),
    ...         content_includes=new_title,
    ...         content_excludes=section.title
    ...     )
    """
    # NB: The Rails app does NOT redirect here to a canonical URL; it silently accepts any slug.
    # Duplicating that here.
    form = SectionForm(request.POST or None, instance=section)
    if request.method == "POST" and form.is_valid():
        form.save()
    section.contents.prefetch_resources()
    search_sources = LegalDocumentSource.objects
    if not (request.user and request.user.is_superuser):
        search_sources = search_sources.filter(active=True)
    doc_sources = list(search_sources.order_by("priority").all())
    serialized_sources = LegalDocumentSourceSerializer(doc_sources, many=True).data
    search_sources_json = json.dumps(serialized_sources)
    return render_with_actions(
        request,
        "casebook_page.html",
        {
            "casebook": casebook,
            "section": section,
            "search_sources_json": search_sources_json,
            "tabs": section.tabs_for_user(request.user, current_tab="Edit"),
            "casebook_color_class": casebook.casebook_color_indicator,
            "editing": True,
            "form": form,
            "publish_check": json.dumps(
                {
                    "isVerifiedProfessor": request.user.is_authenticated
                    and request.user.verified_professor,
                    "coverImageFlag": settings.COVER_IMAGES,
                    "coverImageExists": bool(casebook.cover_image),  # Handling both blank and None
                    "descriptionExists": bool(casebook.description),
                }
            ),
        },
    )


class ResourceView(View):
    @method_decorator(perms_test(viewable_resource))
    @method_decorator(requires_csrf_token)
    @method_decorator(hydrate_params)
    def get(self, request, casebook: Casebook, resource: Resource):
        """
        Show a resource within a casebook.

        Given:
        >>> published, private, with_draft, prof_only, client, verified_professor_factory, user_factory = [getfixture(f)
        ...     for f in ['full_casebook',
        ...    'full_private_casebook', 'full_casebook_with_draft', 'full_casebook_parts_with_prof_only_resource',
        ...    'client', 'verified_professor_factory', 'user_factory']]
        >>> published_resource = published.resources.first()
        >>> private_resource = private.resources.first()
        >>> draft_resource = with_draft.draft.resources.first()
        >>> prof_only_resource = prof_only[0].resources[1]
        >>> assert prof_only_resource.is_instructional_material

        All users can see resources in public casebooks:
        >>> check_response(client.get(published_resource.get_absolute_url(), content_includes=published_resource.title))

        Users can see resources in their own non-public casebooks in preview mode:
        >>> check_response(
        ...     client.get(private_resource.get_absolute_url(), as_user=private_resource.testing_editor),
        ...     content_includes=[private_resource.title, "You are viewing a private"],
        ... )

        Owners see the "preview mode" of resources in draft casebooks:
        >>> check_response(client.get(draft_resource.get_absolute_url(),
        ...     as_user=draft_resource.testing_editor), content_includes="You are viewing a preview")

        Professors can see professor-only resources
        >>> other_prof = verified_professor_factory()
        >>> check_response(client.get(prof_only_resource.get_absolute_url(), as_user=other_prof,
        ...     content_includes="This is instructional"))

        Other users and anonymous users cannot
        >>> other_user = user_factory()
        >>> assert 403 == client.get(prof_only_resource.get_absolute_url(), as_user=other_user).status_code
        >>> assert 403 == client.get(prof_only_resource.get_absolute_url()).status_code

        """
        if not resource.viewable_by(request.user):
            if (
                request.user.is_authenticated
                and casebook.contentcollaborator_set.filter(
                    user=request.user, can_edit=True
                ).exists()
            ):
                return HttpResponseRedirect(reverse("casebook_settings", args=[casebook]))

            else:
                if casebook.is_previous_save:
                    if not casebook.provenance:
                        return login_required_response(request)
                    current_casebook = Casebook.objects.filter(id=casebook.provenance[-1]).get()
                    if not resource:
                        return HttpResponseRedirect(casebook.get_absolute_url())
                    casebook.content_tree__load()
                    current_node = resource
                    while current_node:
                        time_step = (
                            current_node.provenance
                            and ContentNode.objects.filter(id=current_node.provenance[-1]).first()
                        )
                        if time_step:
                            if time_step.casebook == current_casebook:
                                return HttpResponseRedirect(time_step.get_absolute_url())
                            else:
                                current_node = time_step
                                next
                        else:
                            current_node.content_tree__load()
                            current_node = current_node.content_tree__parent
                    return HttpResponseRedirect(casebook.get_absolute_url())
                return login_required_response(
                    request, always_raise=resource.is_instructional_material
                )
        # canonical redirect
        section = resource
        canonical = section.get_absolute_url()
        if request.path != canonical:
            return HttpResponseRedirect(canonical)

        if section.resource_type == "TextBlock":
            body_json = json.dumps(TextBlockSerializer(section.resource).data)
        elif section.resource_type == "LegalDocument":
            body_json = json.dumps(LegalDocumentSerializer(section.resource).data)
        else:
            body_json = ""

        return render_with_actions(
            request,
            "casebook_page.html",
            {
                "casebook": casebook,
                "section": section,
                "body_json": body_json,
                "contents": section,
                "include_vuejs": section.annotatable,
                "edit_mode": section.directly_editable_by(request.user),
                "tabs": section.tabs_for_user(request.user),
                "casebook_color_class": casebook.casebook_color_indicator,
                "previous_and_next_urls": resource.get_previous_and_next_node_urls(
                    user=request.user
                ),
                "publish_check": json.dumps(
                    {
                        "isVerifiedProfessor": request.user.is_authenticated
                        and request.user.verified_professor,
                        "coverImageFlag": settings.COVER_IMAGES,
                        "coverImageExists": bool(
                            casebook.cover_image
                        ),  # Handling both blank and None
                        "descriptionExists": bool(casebook.description),
                    }
                ),
            },
        )

    @method_decorator(perms_test(directly_editable_resource))
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "directly_editable_by"))
    def delete(self, request, casebook, resource):
        """
        Delete a resource from a casebook

        Given:
        >>> private, with_draft, client = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client']]
        >>> private_resource = private.resources.first()
        >>> draft_resource = with_draft.draft.resources.first()

        Users can delete resources in their unpublished and draft casebooks:
        >>> for resource in [private_resource, draft_resource]:
        ...     owner = resource.testing_editor
        ...     url = reverse('resource', args=[resource.casebook, resource])
        ...     check_response(client.delete(url, as_user=owner))
        ...     with assert_raises(ContentNode.DoesNotExist):
        ...         resource.refresh_from_db()
        """
        fix_after_rails("Let's return 204 instead of 200.")
        resource.delete()
        return HttpResponse()

    @method_decorator(
        perms_test(
            [
                {
                    "method": "patch",
                    "args": ["full_casebook", "full_casebook.resources.first"],
                    "results": {
                        403: ["other_user", "full_casebook.testing_editor"],
                        "login": [None],
                    },
                },
                {
                    "method": "patch",
                    "args": ["full_private_casebook", "full_private_casebook.resources.first"],
                    "results": {
                        400: ["full_private_casebook.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
                {
                    "method": "patch",
                    "args": [
                        "full_casebook_with_draft.draft",
                        "full_casebook_with_draft.draft.resources.first",
                    ],
                    "results": {
                        400: ["full_casebook_with_draft.draft.testing_editor"],
                        "login": [None],
                        403: ["other_user"],
                    },
                },
            ]
        )
    )
    @method_decorator(hydrate_params)
    @method_decorator(user_has_perm("casebook", "directly_editable_by"))
    def patch(self, request, casebook, resource):
        return switch_node_type(request, casebook, resource)


@perms_test(directly_editable_resource)
@require_http_methods(["GET", "POST"])
@requires_csrf_token
@hydrate_params
@user_has_perm("casebook", "directly_editable_by")
def edit_resource(request, casebook, resource):
    """
    Let authorized users update Resource metadata.

    Given:
    >>> private, with_draft, client = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client']]
    >>> draft = with_draft.draft
    >>> private_resources = {'TextBlock': private.contents.all()[1], 'LegalDocument': private.contents.all()[2], 'Link': private.contents.all()[3]}
    >>> draft_resources = {'TextBlock': draft.contents.all()[1], 'LegalDocument': draft.contents.all()[2], 'Link': draft.contents.all()[3]}

    Users can edit resources in their unpublished and draft casebooks:
    >>> for resource in [*private_resources.values(), *draft_resources.values()]:
    ...     original_title = resource.title
    ...     new_title = 'owner-edited title'
    ...     check_response(
    ...         client.get(resource.get_edit_url(), as_user=resource.testing_editor),
    ...         content_includes=[resource.title, "casebook-draft"],
    ...     )
    ...     form_body = {'title': new_title}
    ...     if resource.resource_type == 'Link':
    ...         form_body['url'] = resource.resource.url
    ...     check_response(
    ...         client.post(resource.get_edit_url(), form_body, as_user=resource.testing_editor),
    ...         content_includes=new_title,
    ...         content_excludes=original_title
    ...     )

    You can edit the URL associated with a 'Link' resource, from its edit page:
    >>> for resource in [private_resources['Link'], draft_resources['Link']]:
    ...     original_url = resource.resource.url
    ...     new_url = "http://new-test-url.com"
    ...     check_response(
    ...         client.post(resource.get_edit_url(), {'title': resource.title, 'url': new_url}, as_user=resource.testing_editor),
    ...         content_includes=new_url,
    ...         content_excludes=original_url
    ...     )

    You can edit the text associated with a 'TextBlock' resource, from its edit page:
    >>> for resource in [private_resources['TextBlock'], draft_resources['TextBlock']]:
    ...     original_text = resource.resource.content
    ...     new_text = "<p>I'm new text</p>"
    ...     check_response(
    ...         client.post(resource.get_edit_url(), {'title': resource.title, 'content': new_text}, as_user=resource.testing_editor),
    ...         content_includes=escape(new_text),
    ...         content_excludes=escape(original_text)
    ...     )
    """
    if not (resource.is_resource or resource.is_temporary):
        return HttpResponseRedirect(reverse("edit_section", args=[casebook, resource]))
    form = ResourceForm(request.POST or None, instance=resource)

    # Let users edit Link and TextBlock resources directly from this page
    embedded_resource_form = None
    if resource.resource_type == "Link":
        embedded_resource_form = LinkForm(request.POST or None, instance=resource.resource)
    elif resource.resource_type == "TextBlock":
        embedded_resource_form = TextBlockForm(request.POST or None, instance=resource.resource)

    # Save changes, if appropriate
    if request.method == "POST":
        if embedded_resource_form:
            if form.is_valid() and embedded_resource_form.is_valid():
                embedded_resource_form.save()
                form.save()
                resource.resource.refresh_from_db()
                resource.refresh_from_db()
            else:
                return server_error(request)
        else:
            if form.is_valid():
                form.save()
                resource.resource.refresh_from_db()
                resource.refresh_from_db()
            else:
                return server_error(request)
    if resource.resource_type == "TextBlock":
        body_json = json.dumps(TextBlockSerializer(resource.resource).data)
    elif resource.resource_type == "LegalDocument":
        body_json = json.dumps(LegalDocumentSerializer(resource.resource).data)
    else:
        body_json = ""

    # Check to see if an update to a case is available
    case_has_update = False
    checked_case_for_updates = False
    can_check_for_updates = False
    if resource.resource_type == "LegalDocument" and request.user.is_superuser:
        can_check_for_updates = True
        case_has_update = resource.resource.has_newer_version()
        checked_case_for_updates = resource.resource.source.name != "Legacy"

    return render_with_actions(
        request,
        "casebook_page.html",
        {
            "casebook": casebook,
            "section": resource,
            "editing": True,
            "case_has_update": case_has_update,
            "can_check_for_updates": can_check_for_updates,
            "checked_case_for_updates": checked_case_for_updates,
            "tabs": resource.tabs_for_user(request.user, current_tab="Edit"),
            "casebook_color_class": casebook.casebook_color_indicator,
            "form": form,
            "embedded_resource_form": embedded_resource_form,
            "body_json": body_json,
            "super": request.user.is_superuser,
            "publish_check": json.dumps(
                {
                    "isVerifiedProfessor": request.user.is_authenticated
                    and request.user.verified_professor,
                    "coverImageFlag": settings.COVER_IMAGES,
                    "coverImageExists": bool(casebook.cover_image),  # Handling both blank and None
                    "descriptionExists": bool(casebook.description),
                }
            ),
        },
    )


@perms_test(directly_editable_resource)
@requires_csrf_token
@hydrate_params
@user_has_perm("casebook", "directly_editable_by")
def annotate_resource(request, casebook, resource):
    # NB: The Rails app does NOT redirect here to a canonical URL; it silently accepts any slug.
    # Duplicating that here.
    if resource.resource_type == "TextBlock":
        resource.json = json.dumps(TextBlockSerializer(resource.resource).data)
    elif resource.resource_type == "LegalDocument":
        resource.json = json.dumps(LegalDocumentSerializer(resource.resource).data)
    else:
        # Only Cases and TextBlocks can be annotated.
        # Rails serves the "edit" page contents at both "edit" and "annotate" when resources can't be annotated;
        # let's redirect instead.
        return HttpResponseRedirect(reverse("edit_resource", args=[resource.casebook, resource]))

    search_sources = LegalDocumentSource.objects
    if not (request.user and request.user.is_superuser):
        search_sources = search_sources.filter(active=True)
    doc_sources = list(search_sources.order_by("priority").all())
    serialized_sources = LegalDocumentSourceSerializer(doc_sources, many=True).data
    search_sources_json = json.dumps(serialized_sources)

    body_json = resource.json
    return render_with_actions(
        request,
        "resource_annotate.html",
        {
            "casebook": casebook,
            "resource": resource,
            "include_vuejs": resource.resource_type in ["LegalDocument", "TextBlock"],
            "search_sources_json": search_sources_json,
            "editing": True,
            "edit_mode": True,
            "body_json": body_json,
        },
    )


@perms_test(patch_directly_editable_resource)
@require_http_methods(["PATCH"])
@hydrate_params
@user_has_perm("casebook", "directly_editable_by")
def reorder_node(request, casebook, section=None, node=None):
    """
    Given:
    >>> client, *_ = [getfixture(f) for f in ['client']]
    >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
    >>> casebook.state = Casebook.LifeCycle.PRIVATELY_EDITING.value
    >>> casebook.save()
    >>> payload = json.dumps({'child': {'ordinals': [1, 4, 3]}})

    Can reorder nodes on the casebook page:
    >>> url = reverse('reorder_node', args=[casebook, r_1_4_1])
    >>> response = client.patch(url, payload, content_type="application/json", as_user=casebook.testing_editor, follow=True)
    >>> check_response(response)
    >>> assert dump_content_tree_children(s_1_4) == [r_1_4_2, r_1_4_3, r_1_4_1]
    >>> assert_url_equal(response, casebook.get_edit_url())

    Can reorder nodes on the section page:
    >>> r_1_4_2.refresh_from_db()
    >>> url = reverse('reorder_node', args=[casebook, s_1, r_1_4_2])
    >>> response = client.patch(url, payload, content_type="application/json", as_user=casebook.testing_editor, follow=True)
    >>> check_response(response)
    >>> assert dump_content_tree_children(s_1_4) == [r_1_4_3, r_1_4_1, r_1_4_2]
    >>> assert_url_equal(response, s_1.get_edit_url())
    """

    # parse request:
    try:
        data = json.loads(request.body.decode("utf-8"))
        new_ordinals = [int(i) for i in data["child"]["ordinals"]]
    except Exception:
        return HttpResponseBadRequest(
            b"Request body should match data['child']['ordinals'] == [&lsaquo;list of ints&rsaquo']"
        )

    # update ordinals
    try:
        node.content_tree__move_to(new_ordinals)
    except ValueError as e:
        return HttpResponseBadRequest(f"Invalid ordinals: {e.args[0]}".encode("utf8"))

    # redirect back where we came from
    if section:
        return HttpResponseRedirect(reverse("edit_section", args=[casebook, section]))
    else:
        return HttpResponseRedirect(reverse("edit_casebook", args=[casebook]))


def internal_doc_id_from_source(legal_doc_source, id):
    most_recent_doc = legal_doc_source.pull(id)
    most_recent_saved_doc = legal_doc_source.most_recent_with_id(id)
    if (
        not most_recent_saved_doc
        or most_recent_doc.effective_date > most_recent_saved_doc.effective_date
    ):
        most_recent_doc.save()
        return most_recent_doc
    return most_recent_saved_doc


@perms_test(
    {"method": "post", "args": ["legal_doc_source.id"], "results": {400: ["user"], "login": [None]}}
)
@require_POST
@login_required
def import_from_source(request, source=None):
    """
    Given a posted CAP ID, return the internal ID for the same case, first ingesting the case from CAP if necessary.

    Given:
    >>> capapi_mock, client, user, legal_document_factory = [getfixture(i) for i in ['capapi_mock', 'client', 'user', 'legal_document_factory']]
    >>> existing_doc = legal_document_factory(source_ref=9999)
    >>> url = reverse('from_source', args=[existing_doc.source.id])

    Existing cases will be returned without hitting the CAP API:
    >>> response = client.post(url, json.dumps({'id': 9999}), content_type="application/json", as_user=user)
    >>> check_response(response, content_includes=f'{{"id": {existing_doc.id+1}}}', content_type='application/json')

    Non-existing cases will be fetched and created:
    >>> response = client.post(url, json.dumps({'id': 12345}), content_type="application/json", as_user=user)
    >>> check_response(response, content_type='application/json')
    >>> doc = LegalDocument.objects.get(id=json.loads(response.content.decode())['id'])
    >>> assert doc.name == 'Test Doc 1'
    """
    legal_doc_source = get_object_or_404(LegalDocumentSource.objects.filter(id=source))
    # parse ID from request:
    try:
        data = json.loads(request.body.decode("utf-8"))
        id = data["id"]
    except Exception:
        return HttpResponseBadRequest("Request body should match {'id': &lsaquo;string&rsaquo'}")

    most_recent_doc = legal_doc_source.pull(id)
    most_recent_saved_doc = (
        LegalDocument.objects.filter(source=legal_doc_source, source_ref=id)
        .order_by("-effective_date", "-publication_date")
        .first()
    )
    if (
        most_recent_saved_doc
        and most_recent_doc.effective_date <= most_recent_saved_doc.effective_date
    ):
        return JsonResponse({"id": most_recent_saved_doc.id})
    most_recent_doc.save()
    return JsonResponse({"id": most_recent_doc.id})


@perms_test(
    {"args": ["legal_document.id"], "results": {200: ["user", None]}},
)
def display_legal_doc(request, legal_doc_id=None):
    legal_doc = get_object_or_404(LegalDocument, id=legal_doc_id)
    legal_doc.json = json.dumps(LegalDocumentSerializer(legal_doc).data)
    return render(request, "legal_doc.html", {"legal_doc": legal_doc, "include_vuejs": True})


@perms_test(
    {"args": ["resource"], "results": {403: ["user", None]}},
)
def update_legal_doc(request, node=None):
    if not node:
        raise Http404
    if not request.user.is_superuser:
        return HttpResponseForbidden({})
    original_legal_doc = node.resource
    new_legal_doc = original_legal_doc.get_latest_version()
    if new_legal_doc == original_legal_doc:
        return HttpResponseRedirect(reverse("edit_section", args=[node.casebook, node]))
    new_legal_doc.save()
    ContentAnnotation.update_annotations(
        node.annotations.all(), original_legal_doc.content, new_legal_doc.content
    )
    node.resource_id = new_legal_doc.id
    node.save()
    return HttpResponseRedirect(reverse("annotate_resource", args=[node.casebook, node]))


@method_decorator(
    perms_test(
        {
            "args": ["casebook", '"docx"'],
            "results": {200: [None, "other_user", "casebook.testing_editor"]},
        },
        {
            "args": ["private_casebook", '"docx"'],
            "results": {
                200: ["private_casebook.testing_editor"],
                "login": [None],
                403: ["other_user"],
            },
        },
        {
            "args": ["draft_casebook", '"docx"'],
            "results": {
                200: ["draft_casebook.testing_editor"],
                "login": [None],
                403: ["other_user"],
            },
        },
    )
)
@user_has_perm("node", "viewable_by")
def export(request, node, file_type="docx"):
    """
    Export casebook. File type can be 'docx' or 'html' (in which case we dump pre-pandoc html directly to the
    browser), and ?annotations=true will include annotations in the exported file.
    """
    if file_type not in ("docx", "html"):
        raise Http404
    docx_footnotes = (
        request.GET.get("docx_footnotes") == "true"
        if "docx_footnotes" in request.GET
        else settings.FORCE_DOCX_FOOTNOTES
    )
    docx_sections = (
        request.GET.get("docx_sections") == "true"
        if "docx_sections" in request.GET
        else settings.FORCE_DOCX_SECTIONS
    )
    include_annotations = request.GET.get("annotations") == "true"
    export_options = {"request": request}
    export_options["docx_footnotes"] = docx_footnotes
    export_options["docx_sections"] = docx_sections
    # get response data
    try:
        response_data = node.export(
            include_annotations,
            file_type,
            export_options=export_options,
            docx_footnotes=docx_footnotes,
        )
    except LambdaExportTooLarge as too_large:
        logger.warning(f"Export node({node.id}): " + too_large.args[0])
        return render(request, "export_too_large.html", {"casebook": node})
    if response_data is None:
        return render(request, "export_error.html", {"casebook": node})
    # return html
    if file_type == "html":
        return HttpResponse(response_data)

    # return docx
    filename = f"{Truncator(node.title).words(45, truncate='-')}{'_annotated' if include_annotations else ''}.docx"
    return StringFileResponse(
        response_data, as_attachment=True, filename=filename, response_flag_cookie=True
    )


@user_passes_test(lambda u: u.is_superuser)
@hydrate_params
@user_has_perm("casebook", "viewable_by")
@method_decorator(
    perms_test(
        {
            "args": ["casebook"],
            "results": {
                403: [
                    "admin_user"
                ],  # This will be a Forbidden response unless the LiveSetting is enabled
                "login": [None],
                302: ["casebook.testing_editor"],
            },
        },
    )
)
def as_printable_html(request: HttpRequest, casebook: Casebook, page=1):
    """Load the content of the casebook by top-level nodes, and pass it to an HTML template
    designed to render it in-place, without site chrome, suitable for printing"""

    # Only available if enabled in LiveSettings:
    if not LiveSettings.load().enable_printable_html_export:
        return HttpResponseForbidden("This feature is not currently enabled")

    children: ContentNodeQuerySet = casebook.children

    logger.info(f"Exporting Casebook {casebook.id}, starting from page {page}: serializing to HTML")

    from django.core.paginator import Paginator

    paginator = Paginator(children, 1)
    page = paginator.page(page)
    section = page[0]
    children = (
        ContentNode.objects.filter(casebook=casebook, ordinals__0=section.ordinals[0])
        .prefetch_resources()
        .prefetch_related("annotations")
        .order_by("ordinals")
    )

    return render(
        request,
        "export/as_printable_html/casebook.html",
        {
            "casebook": casebook,
            "section": section,
            "paginator": paginator,
            "page": page,
            "children": children,
            "export_date": datetime.now().strftime("%Y-%m-%d"),
            "include_annotations": True,
        },
    )


def reset_password(request):
    """
    Displays the reset password form. We wrap the default Django view to send
    an email verification email if unconfirmed users try to reset their password.

    Given:
    >>> client, user, unconfirmed_user, mailoutbox = [getfixture(i) for i in ['client', 'user', 'unconfirmed_user', 'mailoutbox']]
    >>> url = reverse('password_reset')

    Confirmed users receive the password reset email as usual:
    >>> response = client.post(url, {"email": user.email_address})
    >>> assert len(mailoutbox) == 1
    >>> assert 'Password reset' in  mailoutbox[0].subject

    Unconfirmed users receive the verification email:
    >>> response = client.post(url, {"email": unconfirmed_user.email_address})
    >>> assert len(mailoutbox) == 2
    >>> assert 'An H2O account has been created for you' in  mailoutbox[1].subject
    """
    if request.method == "POST":
        try:
            target_user = User.objects.get(email_address=request.POST.get("email"))
        except User.DoesNotExist:
            target_user = None
        if target_user and not target_user.is_active:
            send_verification_email(request, target_user)

    return PasswordResetView.as_view()(request)


@perms_test({"method": "post", "args": ["casebook"], "results": {403: ["user"], "login": [None]}})
@login_required
@require_POST
@hydrate_params
@user_has_perm("casebook", "directly_editable_by")
def new_from_outline(request, casebook=None):
    """
        Given:
        >>> casebook, client = [getfixture(f) for f in ['full_private_casebook', 'client']]
        >>> orig = getfixture('full_private_casebook')
        >>> textblock = {'title': 'Test TextBlock', 'subtitle': 'Test TextBlock subtitle', 'headnote': 'Test TextBlock headnote', 'resource_type':'TextBlock'}
        >>> case = {'title': 'Test Case', 'subtitle': 'Test Case subtitle', 'headnote': 'Test Case headnote', 'resource_type':'LegalDocument'}
        >>> section = {'title': 'Test Section', 'subtitle': 'Test Section subtitle', 'headnote':'Test Section headnote', 'children':[textblock, case]}
        >>> data = {'data':[section,textblock]}
        >>> payload = json.dumps(data)

        Post the required data as JSON to create a new annotation:
        >>> url = reverse('new_from_outline', args=[casebook])
        >>> response = client.post(url, payload, content_type="application/json", as_user=casebook.testing_editor)
        >>> check_response(response, status_code=200, content_type='application/json')
        >>> casebook.refresh_from_db()
        >>> contents = [{'title':x.title,'subtitle':x.subtitle,'headnote':x.headnote,'resource_type':x.resource_type, 'ordinals':x.ordinals} for x in casebook.contents.all()]
        >>> assert contents[9:] == [\
             {'title': 'Test Section', 'subtitle': 'Test Section subtitle', 'headnote': 'Test Section headnote', 'resource_type': 'Section', 'ordinals': [3]}, \
             {'title': 'Test TextBlock', 'subtitle': 'Test TextBlock subtitle', 'headnote': 'Test TextBlock headnote', 'resource_type': 'TextBlock', 'ordinals': [3, 1]}, \
             {'title': 'Test Case', 'subtitle': 'Test Case subtitle', 'headnote': 'Test Case headnote', 'resource_type': 'Temp', 'ordinals': [3, 2]}, \
             {'title': 'Test TextBlock', 'subtitle': 'Test TextBlock subtitle', 'headnote': 'Test TextBlock headnote', 'resource_type': 'TextBlock', 'ordinals': [4]}]
    """

    def unnest_with_ordinals(ordinals, nodes):
        local_ords = ordinals[:]
        for node in nodes:
            children = node.pop("children", [])
            node["ordinals"] = local_ords[:]
            yield node
            for res in unnest_with_ordinals(local_ords + [1], children):
                yield res
            local_ords[-1] += 1

    @transaction.atomic
    def add_sections_and_resources(parent_section, nodes):
        start_ordinal, _ = parent_section.content_tree__get_next_available_child_ordinals()
        all_nodes = list(unnest_with_ordinals(start_ordinal, nodes))
        content_nodes = []
        content_node_annotations = []
        for node in all_nodes:
            skip_add_node = False
            node["casebook"] = parent_section.casebook
            if ("title" not in node) or node["title"].strip() == "":
                node["title"] = "Untitled"
            if "resource_type" not in node:
                node["resource_type"] = "Section"
            elif node["resource_type"] == "Clone":
                target_node = None
                target_casebook = None
                if "titleSlug" in node:
                    content_type, content = find_from_title_slugs(
                        user_slug=node.pop("userSlug", None),
                        title_slug=node.pop("titleSlug", None),
                        content_param=node.pop("ordSlug", None),
                    )
                    if content_type == "Casebook":
                        target_casebook = content
                    elif content_type == "Section" or content_type == "Resource":
                        target_node = content
                    else:
                        next
                else:
                    target_casebook_id = int(node.get("casebookId", "").split("-")[0])
                    if "sectionId" in node or "resourceId" in node:
                        target_id = node.get("sectionId", node.get("resourceId", None))
                        target_node = ContentNode.objects.get(id=target_id)
                    elif "sectionOrd" in node or "resourceOrd" in node:
                        target_ord_str = node.get("sectionOrd", node.get("resourceOrd", "")).split(
                            "-"
                        )[0]
                        target_ord = [int(x) for x in target_ord_str.split(".")]
                        target_node = ContentNode.objects.get(
                            casebook_id=target_casebook_id, ordinals=target_ord
                        )

                cloned_resources, cloned_content_nodes, cloned_annotations = [[], [], []]

                if not target_node:
                    if not target_casebook:
                        target_casebook = Casebook.objects.get(id=target_casebook_id)
                    if not target_casebook.permits_cloning or target_casebook.editable_by(
                        request.user
                    ):
                        next
                    node["title"] = target_casebook.title + " (Cloned)"
                    node.pop("casebookId", None)
                    shell_node = ContentNode(**node)
                    shell_node.resource_type = "Section"
                    child_nodes = list(target_casebook.contents.all())
                    (
                        cloned_resources,
                        cloned_content_nodes,
                        cloned_annotations,
                    ) = casebook.collect_cloning_nodes(child_nodes)
                    for child in cloned_content_nodes:
                        child.ordinals = shell_node.ordinals + child.ordinals
                    cloned_content_nodes.append(shell_node)
                elif target_node.permits_cloning or target_node.casebook.editable_by(request.user):
                    target_and_children = [target_node] + list(target_node.contents.all())
                    (
                        cloned_resources,
                        cloned_content_nodes,
                        cloned_annotations,
                    ) = casebook.collect_cloning_nodes(target_and_children)
                    # casebook.save_and_parent_cloned_resources(cloned_resources)
                    old_ordinals = cloned_content_nodes[0].ordinals
                    for child in cloned_content_nodes:
                        child.ordinals[0 : len(old_ordinals)] = node["ordinals"]
                else:
                    next
                casebook.save_and_parent_cloned_resources(cloned_resources)
                content_nodes += cloned_content_nodes
                skip_add_node = True
                content_node_annotations += cloned_annotations

            elif node["resource_type"] == "LegalDocument":
                node.pop("searchString", None)
                node["resource_type"] = "Temp"
            elif node["resource_type"] == "TextBlock":
                text_block = TextBlock(name=node["title"][0:250])
                text_block.save()
                node["resource_id"] = text_block.id
            elif node["resource_type"] == "Link":
                looks_like_url = URLValidator()
                if "url" in node:
                    url = node["url"]
                else:
                    url = node["title"]
                try:
                    looks_like_url(url)
                except Exception:
                    try:
                        url = "https://" + url
                        looks_like_url(url)
                    except Exception:
                        url = "https://opencasebook.org/"

                title = None
                if "title" not in node or node["title"] == "Untitled" or url == node["title"]:
                    title = get_link_title(url)
                    node["title"] = title
                else:
                    title = node["title"]
                link = Link(name=title, url=url)
                link.save()
                node["resource_id"] = link.id
                node.pop("url", None)
            elif node["resource_type"] == "Unknown":
                node["resource_type"] = "Temp"
            # resource_type may be 'Temp' for skipped nodes
            node.pop("searchString", None)
            node.pop("display_type", None)
            if not skip_add_node:
                content_nodes.append(ContentNode(**node))
        bulk_create_with_history(
            content_nodes, ContentNode, batch_size=500, default_change_reason="Bulk Create"
        )
        if content_node_annotations:
            casebook.save_and_parent_cloned_annotations(content_node_annotations)

    body = json.loads(request.body.decode("utf-8"))
    section_id = body.get("section", None)
    section = None
    if section_id:
        section = ContentNode.objects.get(id=int(section_id))
    nodes = body.get("data", None)
    if not nodes:
        return Response("", status=status.HTTP_400_BAD_REQUEST)
    parent_section = section or casebook
    add_sections_and_resources(parent_section, nodes)
    parent_section.content_tree__repair()
    if section:
        # in order to serialize correctly, we need return the top-level section
        # and nested lists of children. section.contents does not include the
        # section content node itself, so we get the section node and OR it
        # together to add it to the section.contents query
        [mscq] = manually_serialize_content_query(
            ContentNode.objects.filter(id=section.id) | section.contents
        )
        return JsonResponse(mscq, status=200)
    return JsonResponse(CasebookTOCView.format_casebook(casebook, request), status=200)


@no_perms_test
def pretty_url_dispatch(request, user_slug=None, title_slug=None, content_param=None):
    content_type, content = find_from_title_slugs(
        user_slug=user_slug, title_slug=title_slug, content_param=content_param
    )
    if content_type == "Casebook":
        return CasebookView.as_view()(request, content)
    if content_type == "Section":
        return SectionView.as_view()(request, content.casebook, content)
    if content_type == "Resource":
        return ResourceView.as_view()(request, content.casebook, content)
    raise Http404


# Searching


@perms_test({"method": "get", "args": [], "results": {200: ["user"], "login": [None]}})
@login_required
def search_sources(request):
    sources = LegalDocumentSource.objects
    if not (request.user and request.user.is_superuser):
        sources = sources.filter(active=True)
    doc_sources = list(sources.order_by("priority").all())
    serialized = LegalDocumentSourceSerializer(doc_sources, many=True)
    return JsonResponse({"sources": serialized.data}, status=200)


@perms_test(
    {"method": "get", "args": ["legal_doc_source.id"], "results": {200: ["user"], "login": [None]}}
)
@login_required
def search_using(request, source):
    src = get_object_or_404(LegalDocumentSource.objects.filter(id=source))
    params = LegalDocumentSearchParamsSerializer(data=request.GET)
    if not params.is_valid():
        return JsonResponse(params.errors, status=500)
    results = src.api_model().search(params.save())
    return JsonResponse({"results": results}, status=200)


internal_search_categories = set(("legal_doc", "casebook", "user"))


@no_perms_test
def internal_search(request):
    """
    Search page.

    Given:
    >>> capapi_mock, client, casebook_factory = [getfixture(i) for i in ['capapi_mock', 'client', 'casebook_factory']]
    >>> casebooks = [casebook_factory(contentcollaborator_set__user__verified_professor=True) for i in range(3)]
    >>> url = reverse('internal_search')
    >>> SearchIndex().create_search_index()

    Show all casebooks by default:
    >>> check_response(client.get(url), content_includes=[c.title for c in casebooks])

    See SearchIndex._search tests for more specific tests.
    """
    # read query parameters
    category = request.GET.get("type", "")
    if category not in internal_search_categories:
        category = "casebook"
    try:
        page = int(request.GET.get("page"))
    except (TypeError, ValueError):
        page = 1
    query = request.GET.get("q")

    # else query postgres:
    filters = {}
    author = request.GET.get("author")
    school = request.GET.get("school")
    if author:
        filters["attribution"] = author
    if school:
        filters["affiliation"] = school

    results, counts, facets = SearchIndex.search(
        category,
        page=page,
        query=query,
        filters=filters,
        facet_fields=["attribution", "affiliation"],
        order_by=request.GET.get("sort"),
    )
    results.from_capapi = False
    return render(
        request,
        "search/show.html",
        {
            "results": results,
            "counts": counts,
            "facets": facets,
            "category": category,
        },
    )


casebook_search_categories = set(("legal_doc_fulltext", "textblock", "link"))


@no_perms_test
@hydrate_params
def casebook_search(request, casebook):
    """
    Search content of a specific casebook. Currently only searches legal docs.

        Given:
        >>> _, legal_document_factory, casebook_factory, content_node_factory = [getfixture(i) for i in ['reset_sequences', 'legal_document_factory', 'casebook_factory', 'content_node_factory']]
        >>> capapi_mock, client = [getfixture(i) for i in ['capapi_mock', 'client']]
        >>> casebooks = [casebook_factory() for i in range(3)]
        >>> nodes = [content_node_factory() for i in range(3)]
        >>> docs = [legal_document_factory() for i in range(3)]
        >>> for d, n in zip(docs, nodes):
        ...     n.resource_type = 'LegalDocument'
        ...     n.resource_id = d.id
        ...     n.casebook_id = casebooks[0].id
        ...     n.ordinals = [1, 1]
        ...     n.save()
        >>> FullTextSearchIndex().create_search_index()
        >>> url = reverse('casebook_search', args=[casebooks[0].id])

    Show all legal documents by default:
    >>> check_response(client.get(url), content_includes=[d.name for d in docs])
    """
    # read query parameters
    try:
        page = int(request.GET.get("page"))
    except (TypeError, ValueError):
        page = 1
    query = request.GET.get("q")
    category = request.GET.get("type", "")
    if category not in casebook_search_categories:
        category = "legal_doc_fulltext"

    results = FullTextSearchIndex.casebook_fts(
        casebook.id,
        category,
        page=page,
        query_str=query,
        # order_by=request.GET.get('sort')
    )
    results.from_capapi = False
    return render(
        request,
        "casebook_page_search.html",
        {
            "results": results,
            "casebook": casebook,
            "category": category,
            "tabs": casebook.tabs_for_user(request.user, current_tab="Search Inside"),
            "casebook_color_class": casebook.casebook_color_indicator,
            "edit_mode": casebook.directly_editable_by(request.user),
        },
    )


image_storage = get_s3_storage(bucket_name="h2o.images")


@login_required
def upload_image(request):
    """
    For use with the TinyMCE editor.

    >>> import base64
    >>> import io
    >>> import json

    >>> client = getfixture('client')
    >>> user = getfixture('admin_user')
    >>> img = io.BytesIO(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
    >>> img.name = 'Test.png'
    >>> bad_img = io.BytesIO(b'bad to the bone')
    >>> bad_img.name = 'Test.png'
    >>> url = reverse('upload_image', args=[])

    >>> res = client.post(url, {'image': img, 'name': 'Test'})
    >>> assert(res.status_code==302 and res.url==f'/accounts/login/?next={url}')

    >>> _ = img.seek(0)

    >>> res = client.post(url, {'image':img, 'name': 'Test'}, as_user=user)
    >>> assert(res.status_code == 200)
    >>> assert('location' in json.loads(res.content))

    >>> res = client.post(url, {'image':bad_img, 'name': 'Test'}, as_user=user)
    >>> assert(res.status_code == 403)
    >>> assert(b'supported at this time' in res.content)
    """
    # TinyMCE requires a response like {"location": [url]}
    if not (request.user.is_superuser or request.user.verified_professor):
        raise Http404
    if "image" not in request.FILES:
        return HttpResponseBadRequest("No image data")
    image_file = request.FILES.get("image")
    original_name = request.POST.get("name", None)
    suffix = image_file.name[len(original_name) :]
    s3_uuid = uuid.uuid4()
    image_file.name = str(s3_uuid) + suffix

    try:
        validate_image(image_file)
    except BadFiletypeError as e:
        return HttpResponseForbidden(str(e))

    saved_image = SavedImage(
        name=original_name, image=image_file, external_id=s3_uuid, uploaded_by=request.user
    )
    saved_image.save()
    url = request.build_absolute_uri(saved_image.url)
    return JsonResponse({"location": url})


def view_image(request, image_uuid):
    """
    Redirect to S3 with temp creds.

    """
    saved_image = get_object_or_404(SavedImage.objects.filter(external_id=image_uuid))
    return HttpResponseRedirect(saved_image.image.url)
