from rest_framework import serializers
from django.urls import reverse
from rest_framework.exceptions import ValidationError
from main.models import Casebook, CommonTitle

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


class CasebookListAuthorSerializer(serializers.RelatedField):
    def to_representation(self, collaborator):
        return {'can_edit': collaborator.can_edit,
                'has_attribution': collaborator.has_attribution,
                'attribution': collaborator.user.attribution,
                'public_url': collaborator.user.public_url,
                'verified_professor': collaborator.user.verified_professor,
                'titles': [x.common_title.public_url for x in  collaborator.user.casebooks.all() if x.common_title]
        }

class CasebookListSerializer(serializers.ModelSerializer):
    authors = CasebookListAuthorSerializer(many=True, read_only=True, source='tempcollaborator_set')
    url = serializers.SerializerMethodField()
    settings_url = serializers.SerializerMethodField()
    edit_url = serializers.SerializerMethodField()
    id = serializers.IntegerField()
    draft_url = serializers.SerializerMethodField()
    user_editable = serializers.SerializerMethodField()

    def get_url(self, casebook):
        return casebook.get_absolute_url()

    def get_edit_url(self, casebook):
        return casebook.get_edit_url()

    def get_settings_url(self, casebook):
        return reverse('casebook_settings', args=[casebook])

    def get_draft_url(self, casebook):
        return casebook.draft and casebook.draft.get_edit_url()

    def get_user_editable(self, casebook):
        request = self.context.get("request")
        if request and hasattr(request, "user"):
            user = request.user
            return casebook.editable_by(user)
        return False


    class Meta:
        model = models.Casebook
        fields = ['id', 'title', 'subtitle', 'is_public', 'is_archived', 'has_draft', 'authors', 'url', 'settings_url', 'edit_url', 'draft_url', 'updated_at', 'can_archive', 'user_editable']

class CommonTitleSerializer(serializers.ModelSerializer):
    casebooks = CasebookListSerializer(many=True, default=[])
    current = CasebookListSerializer()

    def update(self, instance, validated_data):
        casebook_ids = [c['id'] for c in validated_data.pop('casebooks')]
        new_casebooks = Casebook.objects.filter(id__in=casebook_ids).all()
        if len(new_casebooks) != len(casebook_ids):
            raise ValidationError
        old_casebooks = set(instance.casebooks.all())
        cbs_to_update = []
        for cb in new_casebooks:
            if cb not in old_casebooks:
                cb.common_title = instance
                cbs_to_update.append(cb)
            else:
                old_casebooks.remove(cb)
        for cb in old_casebooks:
            cb.common_title = None
            cbs_to_update.append(cb)

        Casebook.objects.bulk_update(cbs_to_update, ['common_title'])
        instance.name = validated_data.get('name', instance.name)
        instance.public_url = validated_data.get('public_url', instance.public_url)
        current_dict = validated_data.get('current', None)
        if current_dict:
            current = next((cb for cb in new_casebooks if cb.id == current_dict['id']), None)
            if not current:
                raise ValidationError
            instance.current = current
        instance.save()
        return instance

    class Meta:
        model = models.CommonTitle
        fields = ['id', 'name', 'public_url', 'current', 'casebooks']

class NewCommonTitleSerializer(serializers.ModelSerializer):
    casebooks = CasebookListSerializer(many=True)

    def create(self, validated_data):
        casebook_ids = [c['id'] for c in validated_data.pop('casebooks')]
        casebooks = Casebook.objects.filter(id__in=casebook_ids).all()
        if len(casebooks) != len(casebook_ids):
            raise ValidationError
        instance = CommonTitle(**validated_data)
        instance.save()
        for casebook in casebooks:
            casebook.common_title = instance
        Casebook.objects.bulk_update(casebooks, ['common_title'])
        return instance

    class Meta:
        model = models.CommonTitle
        fields = ['name', 'public_url', 'current', 'casebooks']
