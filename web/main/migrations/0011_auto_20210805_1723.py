# Generated by Django 2.2.24 on 2021-08-05 17:23

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('main', '0010_auto_20210512_0257'),
    ]

    operations = [
        migrations.AddField(
            model_name='contentnode',
            name='headnote_doc_class',
            field=models.CharField(blank=True, max_length=40, null=True),
        ),
        migrations.AddField(
            model_name='historicalcontentnode',
            name='headnote_doc_class',
            field=models.CharField(blank=True, max_length=40, null=True),
        ),
        migrations.AddField(
            model_name='historicaltextblock',
            name='doc_class',
            field=models.CharField(blank=True, max_length=40, null=True),
        ),
        migrations.AddField(
            model_name='textblock',
            name='doc_class',
            field=models.CharField(blank=True, max_length=40, null=True),
        ),
    ]
