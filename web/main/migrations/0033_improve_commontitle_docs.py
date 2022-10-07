# Generated by Django 3.2.14 on 2022-08-08 21:51

import django.core.validators
from django.db import migrations, models
import django.db.models.deletion
import re


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0032_setting_for_html_export'),
    ]

    operations = [
        migrations.AlterModelOptions(
            name='commontitle',
            options={'managed': True, 'ordering': ('name',), 'verbose_name_plural': 'Series'},
        ),
        migrations.AlterField(
            model_name='commontitle',
            name='current',
            field=models.ForeignKey(help_text='The casebook designated as the most-recent edition in the Series', on_delete=django.db.models.deletion.DO_NOTHING, related_name='title_name', to='main.casebook'),
        ),
        migrations.AlterField(
            model_name='commontitle',
            name='name',
            field=models.CharField(help_text='A value assigned by the user at the time the series is created', max_length=300),
        ),
        migrations.AlterField(
            model_name='commontitle',
            name='public_url',
            field=models.CharField(help_text="A string derived from `name` which is appended to the user's public_url,\n        if they have one, which becomes a direct link to the current title in the series", max_length=300, validators=[django.core.validators.RegexValidator(re.compile('^[-\\w]+\\Z'), 'Enter a valid “slug” consisting of Unicode letters, numbers, underscores, or hyphens.', 'invalid')]),
        ),
    ]