from django.shortcuts import render, get_object_or_404
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .serializers import ContentAnnotationSerializer
from .models import ContentNode, Casebook

@api_view(['GET'])
def annotations(request, resource_id, format=None):
    """
        /resources/:resource_id/annotations view.
    """
    resource = get_object_or_404(ContentNode, pk=resource_id)
    if request.method == 'GET':
        return Response(ContentAnnotationSerializer(resource.annotations.all(), many=True).data)

def index(request):
    return render(request, 'index.html')

def casebook(request, casebook_id):
    casebook = get_object_or_404(Casebook, id=casebook_id)
    contents = casebook.contents.all().order_by('ordinals')

    # TODO: find out about the resources that appear in this TOC, but not on prod.
    return render(request, 'casebook.html', {
        'casebook': casebook,
        'contents': contents
    })

