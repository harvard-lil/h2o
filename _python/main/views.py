from django.shortcuts import render, get_object_or_404
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .serializers import ContentAnnotationSerializer
from .models import ContentNode


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