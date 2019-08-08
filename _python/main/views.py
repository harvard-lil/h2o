from django.contrib.auth.decorators import login_required
from django.contrib.auth.views import redirect_to_login
from django.http import HttpResponseForbidden, HttpResponseRedirect
from django.shortcuts import render, get_object_or_404
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .serializers import ContentAnnotationSerializer
from .models import Casebook, Resource, Section


def login_required_response(request):
    if request.user.is_authenticated:
        return HttpResponseForbidden()
    else:
        return redirect_to_login(request.build_absolute_uri())

@login_required
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
    return render(request, 'index.html')


def casebook(request, casebook_param):
    casebook = get_object_or_404(Casebook, id=casebook_param['id'])

    # check permissions
    if not casebook.viewable_by(request.user):
        return login_required_response(request)

    # canonical redirect
    canonical = casebook.get_absolute_url()
    if request.path != canonical:
        return HttpResponseRedirect(canonical)

    contents = casebook.contents.all().order_by('ordinals')

    # TODO: find out about the resources that appear in this TOC, but not on prod.
    # TODO: find out about the "None"s appearing in spots in place of titles
    return render(request, 'casebook.html', {
        'casebook': casebook,
        'contents': contents
    })

def section(request, casebook_param, ordinals_param):
    section = get_object_or_404(Section, casebook=casebook_param['id'], ordinals=ordinals_param['ordinals'])

    # TODO: permissions

    # canonical redirect
    canonical = section.get_absolute_url()
    if request.path != canonical:
        return HttpResponseRedirect(canonical)

    return render(request, 'section.html', {
        'section': section
    })

