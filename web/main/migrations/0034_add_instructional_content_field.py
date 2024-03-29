# Generated by Django 3.2.14 on 2022-08-10 13:47

import django.contrib.postgres.fields
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0033_improve_commontitle_docs'),
    ]

    operations = [
        migrations.AddField(
            model_name='contentnode',
            name='is_instructional_material',
            field=models.BooleanField(default=False, help_text='This content should only be made available on the frontend to verified professors or users with editing privilege'),
        ),
        migrations.AddField(
            model_name='historicalcontentnode',
            name='is_instructional_material',
            field=models.BooleanField(default=False, help_text='This content should only be made available on the frontend to verified professors or users with editing privilege'),
        ),
        migrations.AlterField(
            model_name='contentnode',
            name='display_ordinals',
            field=django.contrib.postgres.fields.ArrayField(base_field=models.IntegerField(), default=list, help_text='The external representation of this node in the tree, accounting for unnumbered nodes', size=None),
        ),
        migrations.AlterField(
            model_name='contentnode',
            name='does_display_ordinals',
            field=models.BooleanField(default=True, help_text='Whether this node will display its section number'),
        ),
        migrations.AlterField(
            model_name='contentnode',
            name='ordinals',
            field=django.contrib.postgres.fields.ArrayField(base_field=models.IntegerField(), default=list, help_text='The internal representation of the position of this node in the tree', size=None),
        ),
        migrations.AlterField(
            model_name='historicalcontentnode',
            name='display_ordinals',
            field=django.contrib.postgres.fields.ArrayField(base_field=models.IntegerField(), default=list, help_text='The external representation of this node in the tree, accounting for unnumbered nodes', size=None),
        ),
        migrations.AlterField(
            model_name='historicalcontentnode',
            name='does_display_ordinals',
            field=models.BooleanField(default=True, help_text='Whether this node will display its section number'),
        ),
        migrations.AlterField(
            model_name='historicalcontentnode',
            name='ordinals',
            field=django.contrib.postgres.fields.ArrayField(base_field=models.IntegerField(), default=list, help_text='The internal representation of the position of this node in the tree', size=None),
        ),
    ]
