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

class RecursiveField(serializers.Serializer):
    def to_representation(self, value):
        serializer = self.parent.parent.__class__(value, context=self.context)
        return serializer.data

class SectionOutlineSerializer(serializers.ModelSerializer):
    resource_type = serializers.CharField(allow_null=True, default='Section', initial='Section')
    edit_url = serializers.URLField(source='get_preferred_url')
    url = serializers.URLField(source='get_absolute_url')
    citation = serializers.SerializerMethodField()
    decision_date = serializers.DateField(source='resource.decision_date', default=None)
    children = RecursiveField(many=True, allow_null=True, default=[])
    is_transmutable = serializers.BooleanField()

    def get_citation(self, node):
        if node.resource_type == 'Case':
            if node.resource and node.resource.citations and len(node.resource.citations) > 0:
                return node.resource.citations[0]['cite']
        return None

    class Meta:
        model = models.ContentNode
        fields = ('title', 'id', 'resource_type', 'edit_url', 'url', 'citation', 'decision_date', 'children', 'is_transmutable')
