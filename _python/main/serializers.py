from rest_framework import serializers

from . import models


class AnnotationSerializer(serializers.ModelSerializer):
    start_offset = serializers.IntegerField(source='global_start_offset')
    end_offset = serializers.IntegerField(source='global_end_offset')

    class Meta:
        model = models.ContentAnnotation
        fields = ('id', 'resource_id', 'start_offset', 'end_offset', 'kind', 'content', 'created_at', 'updated_at')


class NewAnnotationSerializer(serializers.ModelSerializer):
    start_offset = serializers.IntegerField(source='global_start_offset')
    end_offset = serializers.IntegerField(source='global_end_offset')

    class Meta:
        model = models.ContentAnnotation
        fields = ('id', 'start_offset', 'end_offset', 'kind', 'content')


class UpdateAnnotationSerializer(serializers.ModelSerializer):

    class Meta:
        model = models.ContentAnnotation
        fields = ('id','content')


class CaseSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Case
        fields = ('id', 'content', 'name')


class TextBlockSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.TextBlock
        fields = ('id', 'content', 'name')
