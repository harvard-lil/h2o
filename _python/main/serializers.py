from rest_framework import serializers

from . import models


class ContentAnnotationSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.ContentAnnotation
        fields = ('id', 'resource', 'start_paragraph', 'end_paragraph', 'start_offset', 'end_offset', 'kind', 'content', 'created_at', 'updated_at')


class CaseSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Case
        fields = ('id', 'content', 'name')


class TextBlockSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.TextBlock
        fields = ('id', 'content', 'name')
