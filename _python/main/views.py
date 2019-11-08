from collections import OrderedDict
import json
from functools import wraps

from pyquery import PyQuery
import requests
from rest_framework.decorators import api_view
from rest_framework.response import Response

from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.contrib.auth.views import redirect_to_login
from django.core.exceptions import PermissionDenied
from django.http import HttpResponseRedirect, HttpResponseBadRequest, JsonResponse, Http404
from django.shortcuts import render, get_object_or_404
from django.urls import reverse
from django.utils.decorators import method_decorator
from django.views.decorators.http import require_POST, require_http_methods
from django.views import View

from test_helpers import check_response, assert_url_equal, dump_content_tree_children
from pytest import raises as assert_raises

from .utils import parse_cap_decision_date, fix_after_rails
from .serializers import ContentAnnotationSerializer, CaseSerializer, TextBlockSerializer
from .models import Casebook, Resource, Case, User, CaseCourt, ContentNode
from .forms import CasebookForm, SectionForm, ResourceForm, LinkForm, TextBlockForm


### helpers ###

def login_required_response(request):
    if request.user.is_authenticated:
        # In the Rails application, this usually (always?) forwards
        # a user to their own dashboard and flashes a message about
        # insufficient permissions instead. Per discussion, we've
        # decided not to implement that for now: the experience
        # should be rare, and it's not obvious that the redirection
        # provides a superior user experience. We can readdress if
        # this turns out to matter to users.
        raise PermissionDenied
    else:
        return redirect_to_login(request.build_absolute_uri())


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
        casebook_param = kwargs.pop('casebook_param')
        for param in ('section_param', 'resource_param', 'node_param'):
            param_value = kwargs.pop(param, None)
            if not param_value:
                continue
            key = param.split('_', 1)[0]
            kwargs[key] = get_object_or_404(ContentNode.objects.select_related('casebook'), casebook=casebook_param['id'], ordinals=param_value['ordinals'])
            kwargs['casebook'] = kwargs[key].casebook
        if 'casebook' not in kwargs:
            kwargs['casebook'] = get_object_or_404(Casebook, id=casebook_param['id'])
        return func(request, *args, **kwargs)
    return wrapper


def user_has_casebook_perm(casebook_method):
    """
        Raise permission denied unless the 'casebook' parameter specifies a casebook that has the required permission
        for the current user. This decorator must come after @hydrate_params.

        TODO: this is currently implicitly tested by CasebookView.get, but we need a comprehensive permissions test
        similar to Perma's.
    """
    def decorator(func):
        @wraps(func)
        def wrapper(request, *args, **kwargs):
            if not getattr(kwargs['casebook'], casebook_method)(request.user):
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
        >>> draft = with_draft.drafts()
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
        ...         client.get(o.get_absolute_url(), as_user=published.owner),
        ...         content_includes='actions="exportable,cloneable,can_create_draft"'
        ...     )

        When a collaborator views a published casebook WITH a draft, or
        any of that casebook's sections or resources:
        >>> for o in [with_draft, with_draft_section, with_draft_resource]:
        ...     check_response(
        ...         client.get(o.get_absolute_url(), as_user=with_draft.owner),
        ...         content_includes='actions="exportable,cloneable,can_view_existing_draft"'
        ...     )

        When a collaborator views the "preview" page of a private, never published casebook, or
        the preview pages of any of that casebook's sections or resources:
        >>> for o in [private, private_section, private_resource]:
        ...     check_response(
        ...         client.get(o.get_absolute_url(), as_user=private.owner),
        ...         content_includes='actions="exportable,cloneable,publishable,can_be_directly_edited"'
        ...     )

        When a collaborator views the "preview" page of a draft of an already-published casebook, or
        the preview pages of any of that casebook's sections or resources:
        >>> for o in [draft, draft_section, draft_resource]:
        ...     check_response(
        ...         client.get(o.get_absolute_url(), as_user=draft.owner),
        ...         content_includes='actions="exportable,publishable,can_be_directly_edited"'
        ...     )

        ##
        # These pages allow different actions, depending on the node type
        ##

        # Casebook

        When a collaborator views the "edit" page of a private, never-published casebook
        >>> check_response(
        ...    client.get(private.get_edit_url(), as_user=private.owner),
        ...    content_includes='actions="exportable,cloneable,previewable,publishable,can_save_nodes,can_add_nodes"'
        ... )

        When a collaborator views the "edit" page of a draft of an already-published casebook
        >>> check_response(
        ...    client.get(draft.get_edit_url(), as_user=draft.owner),
        ...    content_includes='actions="exportable,previewable,publishable,can_save_nodes,can_add_nodes"'
        ... )

        # Section

        When a collaborator views the "edit" page of a section in a private, never-published casebook
        >>> check_response(
        ...     client.get(private_section.get_edit_url(), as_user=private.owner),
        ...     content_includes='actions="exportable,previewable,can_save_nodes,can_add_nodes"'
        ... )

        When a collaborator views the "edit" page of a section in draft of an already-published casebook
        >>> check_response(
        ...     client.get(draft_section.get_edit_url(), as_user=draft.owner),
        ...     content_includes='actions="exportable,previewable,publishable,can_save_nodes,can_add_nodes"'
        ... )

        # Resource

        When a collaborator views the "edit" page of a resource in a private, never-published casebook
        >>> check_response(
        ...     client.get(private_resource.get_edit_url(), as_user=private.owner),
        ...     content_includes='actions="exportable,previewable,can_save_nodes"'
        ... )

        When a collaborator views the "edit" page of a resource in draft of an already-published casebook
        >>> check_response(
        ...     client.get(draft_resource.get_edit_url(), as_user=draft.owner),
        ...     content_includes='actions="exportable,previewable,publishable,can_save_nodes"'
        ... )

        When a collaborator views the "annotate" page of a resource in a private, never-published casebook
        >>> check_response(
        ...     client.get(private_resource.get_annotate_url(), as_user=private.owner),
        ...     content_includes='actions="exportable,previewable"'
        ... )

        When a collaborator views the "annotate" page of a resource in draft of an already-published casebook
        >>> check_response(
        ...     client.get(draft_resource.get_annotate_url(), as_user=draft.owner),
        ...     content_includes='actions="exportable,previewable,publishable"'
        ... )

    """
    view = request.resolver_match.view_name
    node = context.get('casebook') or context.get('section') or context.get('resource')

    cloneable = request.user.is_authenticated and \
                view in ['casebook', 'section', 'resource', 'edit_casebook'] and \
                node.permits_cloning

    publishable = view == 'edit_casebook' or \
                 (node.is_private and view in ['casebook', 'section', 'resource']) or \
                 node.is_or_belongs_to_draft

    actions = OrderedDict([
        ('exportable', True),
        ('cloneable', cloneable),
        ('previewable', context.get('editing', False)),
        ('publishable', publishable),
        ('can_save_nodes', view in ['edit_casebook', 'edit_section', 'edit_resource']),
        ('can_add_nodes', view in ['edit_casebook', 'edit_section']),
        ('can_be_directly_edited', view in ['casebook', 'resource', 'section'] and node.directly_editable_by(request.user)),
        ('can_create_draft', view in ['casebook', 'resource', 'section'] and node.allows_draft_creation_by(request.user)),
        ('can_view_existing_draft', view in ['casebook', 'resource', 'section'] and node.has_draft and node.editable_by(request.user))
    ])
    # for ease of testing, include a list of truthy actions
    actions['action_list'] = ','.join([a for a in actions if actions[a]])
    return actions


def render_with_actions(request, template_name, context=None, content_type=None, status=None, using=None):
    if context is None:
        context = {}

    return render(request, template_name, {
        **context,
        **actions(request, context)
    }, content_type, status, using)


### views ###

@api_view(['GET'])
def annotations(request, resource_id, format=None):
    """
        /resources/:resource_id/annotations view.
        Was: app/controllers/content/annotations_controller.rb
    """
    resource = get_object_or_404(Resource.objects.select_related('casebook'), pk=resource_id)

    # check permissions
    if not resource.casebook.viewable_by(request.user):
        return login_required_response(request)

    if request.method == 'GET':
        return Response(ContentAnnotationSerializer(resource.annotations.all(), many=True).data)


def index(request):
    if request.user.is_authenticated:
        return render(request, 'dashboard.html', {'user': request.user})
    else:
        return render(request, 'index.html')


def dashboard(request, user_id):
    """
        Show given user's casebooks.

        Given:
        >>> casebook, casebook_factory, client, admin_user, user_factory = [getfixture(f) for f in ['casebook', 'casebook_factory', 'client', 'admin_user', 'user_factory']]
        >>> user = casebook.collaborators.first()
        >>> non_collaborating_user = user_factory()
        >>> private_casebook = casebook_factory(contentcollaborator_set__user=user, public=False)
        >>> draft_casebook = casebook_factory(contentcollaborator_set__user=user, public=False, draft_mode_of_published_casebook=True, copy_of=casebook)
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
        >>> check_response(client.get(url, as_user=user), content_includes="This casebook has unpublished changes.")
        >>> check_response(client.get(url, as_user=admin_user), content_includes="This casebook has unpublished changes.")

        Drafts of published books are not apparent to other users:
        >>> check_response(client.get(url), content_excludes="This casebook has unpublished changes.")
        >>> check_response(client.get(url, as_user=non_collaborating_user), content_excludes="This casebook has unpublished changes.")
    """
    user = get_object_or_404(User, pk=user_id)
    return render(request, 'dashboard.html', {'user': user})


@require_POST
def logout(request, id=None):
    fix_after_rails("id isn't used; just kept for rails compat")
    response = HttpResponseRedirect(reverse('index'))
    response.delete_cookie('_h2o_session')
    response.delete_cookie('user_credentials')
    response.delete_cookie('csrftoken')
    return response


class CasebookView(View):

    @method_decorator(hydrate_params)
    @method_decorator(user_has_casebook_perm('viewable_by'))
    def get(self, request, casebook):
        """
            Show a casebook's front page.

            Given:
            >>> casebook, casebook_factory, client, admin_user, user_factory = [getfixture(f) for f in ['casebook', 'casebook_factory', 'client', 'admin_user', 'user_factory']]
            >>> user = casebook.collaborators.first()
            >>> non_collaborating_user = user_factory()
            >>> private_casebook = casebook_factory(contentcollaborator_set__user=user, public=False)
            >>> draft_casebook = casebook_factory(contentcollaborator_set__user=user, public=False, draft_mode_of_published_casebook=True, copy_of=casebook)

            All users can see public casebooks:
            >>> check_response(client.get(casebook.get_absolute_url(), content_includes=casebook.title))

            Other users cannot see non-public casebooks:
            >>> check_response(client.get(private_casebook.get_absolute_url()), status_code=302)
            >>> check_response(client.get(private_casebook.get_absolute_url(), as_user=non_collaborating_user), status_code=403)

            Users can see their own non-public casebooks in preview mode:
            >>> check_response(
            ...     client.get(private_casebook.get_absolute_url(), as_user=user),
            ...     content_includes=[private_casebook.title, "You are viewing a preview"],
            ... )

            Owners and admins see the "preview mode" of draft casebooks:
            >>> check_response(client.get(draft_casebook.get_absolute_url(), as_user=user), content_includes="You are viewing a preview")

            Other users cannot see draft casebooks:
            >>> check_response(client.get(draft_casebook.get_absolute_url()), status_code=302)
            >>> check_response(client.get(draft_casebook.get_absolute_url(), as_user=non_collaborating_user), status_code=403)
        """
        # canonical redirect
        canonical = casebook.get_absolute_url()
        if request.path != canonical:
            return HttpResponseRedirect(canonical)

        contents = casebook.contents.prefetch_resources()
        return render_with_actions(request, 'casebook.html', {
            'casebook': casebook,
            'contents': contents
        })

    @method_decorator(hydrate_params)
    @method_decorator(user_has_casebook_perm('editable_by'))
    def patch(self, request, casebook):
        """
            Publish a casebook.

            Given:
            >>> casebook, casebook_factory, client, admin_user, user_factory = [getfixture(f) for f in ['casebook', 'casebook_factory', 'client', 'admin_user', 'user_factory']]
            >>> user = casebook.collaborators.first()
            >>> non_collaborating_user = user_factory()
            >>> private_casebook = casebook_factory(contentcollaborator_set__user=user, public=False)
            >>> draft_casebook = casebook_factory(contentcollaborator_set__user=user, public=False, draft_mode_of_published_casebook=True, copy_of=casebook)

            Only authors (admins, etc.) may publish casebooks.
            >>> check_response(client.patch(draft_casebook.get_absolute_url()), status_code=302)
            >>> check_response(client.patch(draft_casebook.get_absolute_url(), as_user=non_collaborating_user), status_code=403)

            Already-published casebooks cannot be re-published.
            >>> check_response(client.patch(casebook.get_absolute_url(), as_user=user), status_code=403)

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
            >>> with assert_raises(Casebook.DoesNotExist):
            ...     draft_casebook.refresh_from_db()
            >>> casebook.refresh_from_db()
            >>> assert_url_equal(response, casebook.get_absolute_url())
            >>> assert casebook.is_public
        """
        # TODO: let's consider moving this functionality to a /publish route, as with /export.
        # I don't think it's particularly helpful for this logic to live in this view.
        # Since other kinds of Casebook edits aren't handled here, it isn't particularly RESTful.

        # check permissions
        if casebook.is_public:
            raise PermissionDenied("Only private casebooks may be published.")

        if casebook.draft_mode_of_published_casebook:
            casebook = casebook.merge_draft()
        else:
            casebook.public = True
            casebook.save()

        # The javascript that makes these PATCH requests expects a redirect
        # to the published casebook.
        return HttpResponseRedirect(reverse('casebook', args=[casebook]))


@require_POST
@login_required
@hydrate_params
def clone_casebook(request, casebook):
    """
        Clone a casebook and redirect to edit page for clone.

        Given:
        >>> client, user, owner_of_cloneable_casebook, owner_of_uncloneable_casebook = [getfixture(f) for f in [
        ...     'client', 'user', 'user_with_cloneable_casebook', 'user_with_uncloneable_casebook']
        ... ]

        If the casebook can be cloned, do so, then redirect to new clone:
        >>> casebook = owner_of_cloneable_casebook.casebooks.first()
        >>> check_response(client.post(reverse('clone', args=[casebook]), as_user=user), status_code=302)
        >>> check_response(client.post(reverse('clone', args=[casebook]), as_user=owner_of_cloneable_casebook), status_code=302)

        Otherwise, return Permission Denied:
        >>> casebook = owner_of_uncloneable_casebook.casebooks.first()
        >>> check_response(client.post(reverse('clone', args=[casebook]), as_user=user), status_code=403)
        >>> check_response(client.post(reverse('clone', args=[casebook]), as_user=owner_of_uncloneable_casebook), status_code=403)
    """
    if casebook.permits_cloning:
        clone = casebook.clone(request.user)
        return HttpResponseRedirect(reverse('edit_casebook', args=[clone]))
    raise PermissionDenied


@require_POST
@hydrate_params
@user_has_casebook_perm('allows_draft_creation_by')
def create_draft(request, casebook):
    """
        Create a draft of a casebook and redirect to its edit page.

        Given:
        >>> client, user, owner_of_undraftable_casebooks, owner_of_draftable_casebook = [
        ...     getfixture(f) for f in ['client', 'user', 'user_with_undraftable_casebooks', 'user_with_draftable_casebook']
        ... ]

        Only some casebooks can be edited via this draft mechanism.
        >>> for casebook in owner_of_undraftable_casebooks.casebooks.all():
        ...     check_response(client.post(reverse('create_draft', args=[casebook]), as_user=owner_of_undraftable_casebooks), status_code=403)

        And, drafts can only be created by authorized users.
        >>> casebook = owner_of_draftable_casebook.casebooks.first()
        >>> check_response(client.post(reverse('create_draft', args=[casebook]), as_user=user), status_code=403)

        When draft creation is permitted, create one, and redirect to it:
        >>> check_response(client.post(reverse('create_draft', args=[casebook]), as_user=owner_of_draftable_casebook), status_code=302)
    """
    # NB: in the Rails app, drafts are created via GET rather than POST
    # Started GET "/casebooks/128853-constitutional-law/resources/1.2.1-marbury-v-madison/create_draft" for 172.18.0.1 at 2019-10-22 18:00:49 +0000
    # Processing by Content::ResourcesController#create_draft as HTML
    # Let's not recreate that.
    # TODO: figure out if this complicates our roll out strategy.
    clone = casebook.make_draft()
    return HttpResponseRedirect(reverse('edit_casebook', args=[clone]))


@require_http_methods(["GET", "POST"])
@hydrate_params
@user_has_casebook_perm('directly_editable_by')
def edit_casebook(request, casebook):
    """
        Given:
        >>> private, with_draft, client = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client']]
        >>> draft = with_draft.drafts()

        Users can edit their unpublished and draft casebooks:
        >>> for book in [private, draft]:
        ...     new_title = 'owner-edited title'
        ...     check_response(
        ...         client.get(book.get_edit_url(), as_user=book.owner),
        ...         content_includes=[book.title, "This casebook is a draft"],
        ...     )
        ...     check_response(
        ...         client.post(book.get_edit_url(), {'title': new_title}, as_user=book.owner),
        ...         content_includes=new_title,
        ...         content_excludes=book.title
        ...     )
    """
    # NB: The Rails app does NOT redirect here to a canonical URL; it silently accepts any slug.
    # Duplicating that here.
    form = CasebookForm(request.POST or None, instance=casebook)
    if request.method == 'POST' and form.is_valid():
        form.save()
    contents = casebook.contents.prefetch_resources()
    return render_with_actions(request, 'casebook_edit.html', {
        'casebook': casebook,
        'contents': contents,
        'editing': True,
        'form': form
    })


@hydrate_params
@user_has_casebook_perm('viewable_by')
def section(request, casebook, section):
    """
        Show a section within a casebook.

        Given:
        >>> published, private, with_draft, client = [getfixture(f) for f in ['full_casebook', 'full_private_casebook', 'full_casebook_with_draft', 'client']]
        >>> published_section = published.sections.first()
        >>> private_section = private.sections.first()
        >>> draft_section = with_draft.drafts().sections.first()

        All users can see sections in public casebooks:
        >>> check_response(client.get(published_section.get_absolute_url(), content_includes=published_section.title))

        Users can see sections in their own non-public casebooks in preview mode:
        >>> check_response(
        ...     client.get(private_section.get_absolute_url(), as_user=private_section.owner),
        ...     content_includes=[private_section.title, "You are viewing a preview"],
        ... )

        Owners see the "preview mode" of sections in draft casebooks:
        >>> check_response(client.get(draft_section.get_absolute_url(), as_user=private_section.owner), content_includes="You are viewing a preview")
    """
    # canonical redirect
    canonical = section.get_absolute_url()
    if request.path != canonical:
        return HttpResponseRedirect(canonical)

    contents = section.contents.prefetch_resources()
    return render_with_actions(request, 'section.html', {
        'section': section,
        'contents': contents
    })


@require_http_methods(["GET", "POST"])
@hydrate_params
@user_has_casebook_perm('directly_editable_by')
def edit_section(request, casebook, section):
    """
        Let authorized users update Section metadata.

        Given:
        >>> private, with_draft, client = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client']]
        >>> private_section = private.sections.first()
        >>> draft_section = with_draft.drafts().sections.first()

        Users can edit sections in their unpublished and draft casebooks:
        >>> for section in [private_section, draft_section]:
        ...     new_title = 'owner-edited title'
        ...     check_response(
        ...         client.get(section.get_edit_url(), as_user=section.owner),
        ...         content_includes=[section.title, "This casebook is a draft"],
        ...     )
        ...     check_response(
        ...         client.post(section.get_edit_url(), {'title': new_title}, as_user=section.owner),
        ...         content_includes=new_title,
        ...         content_excludes=section.title
        ...     )
    """
    # NB: The Rails app does NOT redirect here to a canonical URL; it silently accepts any slug.
    # Duplicating that here.
    form = SectionForm(request.POST or None, instance=section)
    if request.method == 'POST' and form.is_valid():
        form.save()
    contents = section.contents.prefetch_resources()
    return render_with_actions(request, 'section_edit.html', {
        'section': section,
        'contents': contents,
        'editing': True,
        'form': form
    })


@hydrate_params
@user_has_casebook_perm('viewable_by')
def resource(request, casebook, resource):
    """
        Show a resource within a casebook.

        Given:
        >>> published, private, with_draft, client = [getfixture(f) for f in ['full_casebook', 'full_private_casebook', 'full_casebook_with_draft', 'client']]
        >>> published_resource = published.resources.first()
        >>> private_resource = private.resources.first()
        >>> draft_resource = with_draft.drafts().resources.first()

        All users can see resources in public casebooks:
        >>> check_response(client.get(published_resource.get_absolute_url(), content_includes=published_resource.title))

        Users can see resources in their own non-public casebooks in preview mode:
        >>> check_response(
        ...     client.get(private_resource.get_absolute_url(), as_user=private_resource.owner),
        ...     content_includes=[private_resource.get_title(), "You are viewing a preview"],
        ... )

        Owners see the "preview mode" of resources in draft casebooks:
        >>> check_response(client.get(draft_resource.get_absolute_url(), as_user=private_resource.owner), content_includes="You are viewing a preview")
    """
    # canonical redirect
    canonical = resource.get_absolute_url()
    if request.path != canonical:
        return HttpResponseRedirect(canonical)

    if resource.resource_type == 'Case':
        resource.json = json.dumps(CaseSerializer(resource.resource).data)
    elif resource.resource_type == 'TextBlock':
        resource.json = json.dumps(TextBlockSerializer(resource.resource).data)

    return render_with_actions(request, 'resource.html', {
        'resource': resource,
        'include_vuejs': resource.annotatable
    })


@require_http_methods(["GET", "POST"])
@hydrate_params
@user_has_casebook_perm('directly_editable_by')
def edit_resource(request, casebook, resource):
    """
        Let authorized users update Resource metadata.

        Given:
        >>> private, with_draft, client = [getfixture(f) for f in ['full_private_casebook', 'full_casebook_with_draft', 'client']]
        >>> draft = with_draft.drafts()
        >>> private_resources = {'TextBlock': private.contents.all()[1], 'Case': private.contents.all()[2], 'Default': private.contents.all()[3]}
        >>> draft_resources = {'TextBlock': draft.contents.all()[1], 'Case': draft.contents.all()[2], 'Default': draft.contents.all()[3]}

        Users can edit resources in their unpublished and draft casebooks:
        >>> for resource in [*private_resources.values(), *draft_resources.values()]:
        ...     original_title = resource.get_title()
        ...     new_title = 'owner-edited title'
        ...     check_response(
        ...         client.get(resource.get_edit_url(), as_user=resource.owner),
        ...         content_includes=[resource.get_title(), "This casebook is a draft"],
        ...     )
        ...     check_response(
        ...         client.post(resource.get_edit_url(), {'title': new_title}, as_user=resource.owner),
        ...         content_includes=new_title,
        ...         content_excludes=original_title
        ...     )

        You can edit the URL associated with a 'Default/Link' resource, from its edit page:
        >>> for resource in [private_resources['Default'], draft_resources['Default']]:
        ...     original_url = resource.resource.url
        ...     new_url = "http://new-test-url.com"
        ...     check_response(
        ...         client.post(resource.get_edit_url(), {'url': new_url}, as_user=resource.owner),
        ...         content_includes=new_url,
        ...         content_excludes=original_url
        ...     )

        You CANNOT presently edit the text associated with a 'TextBlock' resource, from its edit page,
        but you can see it (editing is not safe yet):
        >>> for resource in [private_resources['TextBlock'], draft_resources['TextBlock']]:
        ...     original_text = resource.resource.content
        ...     new_text = "<p>I'm new text</p>"
        ...     check_response(
        ...         client.post(resource.get_edit_url(), {'content': new_text}, as_user=resource.owner),
        ...         content_includes=original_text,
        ...         content_excludes=new_text
        ...     )
    """
    # NB: The Rails app does NOT redirect here to a canonical URL; it silently accepts any slug.
    # Duplicating that here.
    # TBD: The appearance, validation, and "flash" behavior of this route is not identical
    # to the Rails app, but the functionality is equivalent; I'm hoping we're content with it.

    # Name calculation for Resources is particularly complex right now.
    # We need the "title" field of the form to display the return value of
    # resource.get_title(). If a user submits the edit form, this will cause
    # resource.title to be populated with the value of resource.get_title()
    # While this does not, I believe, reproduce the behavior of the Rails
    # application, I think it is a step in the right direction, a world where
    # the names of ContentNodes are reliably represented in a DB field, not
    # calculated on the fly.
    if not resource.title:
        resource.title = resource.get_title()
    form = ResourceForm(request.POST or None, instance=resource)

    # Let users edit Link and TextBlock resources directly from this page
    embedded_resource_form = None
    if resource.resource_type == 'Default':
        embedded_resource_form = LinkForm(request.POST or None, instance=resource.resource)
    elif resource.resource_type == 'TextBlock':
        embedded_resource_form = TextBlockForm(request.POST or None, instance=resource.resource)

    # Save changes, if appropriate
    if request.method == 'POST':
        if embedded_resource_form:
            if form.is_valid() and embedded_resource_form.is_valid():
                form.save()
                embedded_resource_form.save()
        else:
            if form.is_valid():
                form.save()

    return render_with_actions(request, 'resource_edit.html', {
        'resource': resource,
        'editing': True,
        'form': form,
        'embedded_resource_form': embedded_resource_form
    })


@hydrate_params
@user_has_casebook_perm('directly_editable_by')
def annotate_resource(request, casebook, resource):
    # NB: The Rails app does NOT redirect here to a canonical URL; it silently accepts any slug.
    # Duplicating that here.
    if resource.resource_type == 'Case':
        resource.json = json.dumps(CaseSerializer(resource.resource).data)
    elif resource.resource_type == 'TextBlock':
        resource.json = json.dumps(TextBlockSerializer(resource.resource).data)
    else:
        # Only Cases and TextBlocks can be annotated.
        # Rails serves the "edit" page contents at both "edit" and "annotate" when resources can't be annotated;
        # let's redirect instead.
        return HttpResponseRedirect(reverse('edit_resource', args=[resource.casebook, resource]))

    return render_with_actions(request, 'resource_annotate.html', {
        'resource': resource,
        'include_vuejs': resource.resource_type in ['Case', 'TextBlock'],
        'editing': True
    })


@require_http_methods(["PATCH"])
@hydrate_params
@user_has_casebook_perm('directly_editable_by')
def reorder_node(request, casebook, section=None, node=None):
    """
        Given:
        >>> client, *_ = [getfixture(f) for f in ['client']]
        >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
        >>> casebook.public = False
        >>> casebook.save()
        >>> payload = json.dumps({'child': {'ordinals': [1, 4, 3]}})

        Can reorder nodes on the casebook page:
        >>> url = reverse('reorder_node', args=[casebook, r_1_4_1])
        >>> response = client.patch(url, payload, content_type="application/json", as_user=casebook.owner, follow=True)
        >>> check_response(response)
        >>> assert dump_content_tree_children(s_1_4) == [r_1_4_2, r_1_4_3, r_1_4_1]
        >>> assert_url_equal(response, casebook.get_edit_url())

        Can reorder nodes on the section page:
        >>> r_1_4_2.refresh_from_db()
        >>> url = reverse('reorder_node', args=[casebook, s_1, r_1_4_2])
        >>> response = client.patch(url, payload, content_type="application/json", as_user=casebook.owner, follow=True)
        >>> check_response(response)
        >>> assert dump_content_tree_children(s_1_4) == [r_1_4_3, r_1_4_1, r_1_4_2]
        >>> assert_url_equal(response, s_1.get_edit_url())
    """
    # TODO: having separate endpoints for casebook and section pages is only necessary to enable the change-and-redirect
    # behavior of the current javascript. When the casebook edit page is rendered with Vue, this endpoint can just
    # return success or failure, and the same endpoint will work for both casebook and section pages.

    # parse request:
    try:
        data = json.loads(request.body.decode("utf-8"))
        new_ordinals = [int(i) for i in data['child']['ordinals']]
    except Exception:
        return HttpResponseBadRequest(b"Request body should match data['child']['ordinals'] == [<list of ints>]")

    # update ordinals
    try:
        node.content_tree__move_to(new_ordinals)
    except ValueError as e:
        return HttpResponseBadRequest(b"Invalid ordinals: %s" % e.args[0].encode('utf8'))

    # redirect back where we came from
    if section:
        return HttpResponseRedirect(reverse('edit_section', args=[casebook, section]))
    else:
        return HttpResponseRedirect(reverse('edit_casebook', args=[casebook]))


def case(request, case_id):
    case = get_object_or_404(Case, id=case_id)
    if not case.public:
        raise PermissionDenied

    case.json = json.dumps(CaseSerializer(case).data)
    return render(request, 'case.html', {
        'case': case,
        'include_vuejs': True
    })


@require_POST
@login_required
def from_capapi(request):
    """
        Given a posted CAP ID, return the internal ID for the same case, first ingesting the case from CAP if necessary.

        Given:
        >>> capapi_mock, client, user, case_factory = [getfixture(i) for i in ['capapi_mock', 'client', 'user', 'case_factory']]
        >>> url = reverse('from_capapi')
        >>> existing_case = case_factory(capapi_id=9999)

        Existing cases will be returned without hitting the CAP API:
        >>> response = client.post(url, json.dumps({'id': 9999}), content_type="application/json", as_user=user)
        >>> check_response(response, content_includes='{"id": %s}' % existing_case.id, content_type='application/json')

        Non-existing cases will be fetched and created:
        >>> response = client.post(url, json.dumps({'id': 12345}), content_type="application/json", as_user=user)
        >>> check_response(response, content_type='application/json')
        >>> case = Case.objects.get(id=json.loads(response.content.decode())['id'])
        >>> assert case.name_abbreviation == "1-800 Contacts, Inc. v. Lens.Com, Inc."
        >>> assert case.opinions == {"majority": "HARTZ, Circuit Judge."}
    """
    # parse ID from request:
    try:
        data = json.loads(request.body.decode("utf-8"))
        cap_id = int(data['id'])
    except Exception:
        return HttpResponseBadRequest("Request body should match {'id': <int>}")

    # try to fetch existing case:
    case = Case.objects.filter(capapi_id=cap_id, public=True).first()

    if not case:
        # fetch from CAP:
        response = requests.get(
            settings.CAPAPI_BASE_URL+"cases/%s/" % cap_id,
            {"full_case": "true", "body_format": "html"},
            headers={'Authorization': 'Token %s' % settings.CAPAPI_API_KEY},
        )
        cap_case = response.json()

        # get or create local CaseCourt object:
        # (don't use get_or_create() because current data may have duplicates; we get the first one by id)
        court_args = {
            "capapi_id": cap_case['court']['id'],
            "name": cap_case['court']['name'],
            "name_abbreviation": cap_case['court']['name_abbreviation'],
        }
        court = CaseCourt.objects.filter(**court_args).order_by('id').first()
        if not court:
            court = CaseCourt(**court_args)
            court.save()

        # parse html:
        parsed = PyQuery(cap_case['casebody']['data'])

        # create case:
        case = Case(
            # our db metadata
            created_via_import=True,
            public=True,
            capapi_id=cap_id,

            # cap case metadata
            case_court=court,
            name_abbreviation=cap_case['name_abbreviation'],
            name=cap_case['name'],
            docket_number=cap_case['docket_number'],
            citations=cap_case['citations'],
            decision_date=parse_cap_decision_date(cap_case['decision_date']),

            # cap case html
            content=cap_case['casebody']['data'],
            attorneys=[el.text() for el in parsed('.attorneys').items()],
            # TODO: copying a Rails bug. Using a dict here is incorrect, as the same data-type can appear more than once:
            opinions={el.attr('data-type'): el('.author').text() for el in parsed('.opinion').items()},
        )
        case.save()

    return JsonResponse({'id': case.id})


def not_implemented_yet(request):
    """ Used for routes we want to be able to reverse(), but that aren't implemented yet. """
    raise Http404
