# Generated by Django 3.2.15 on 2022-09-26 16:53

from django.db import migrations

from django.utils.text import slugify


def insert_institutions(apps, schema_editor):

    Institution = apps.get_model("main", "Institution")
    EmailWhitelist = apps.get_model("main", "EmailWhitelist")

    # Add institutions populated from the EmailWhitelist model
    for ew in EmailWhitelist.objects.all():
        inst, _ = Institution.objects.get_or_create(name=ew.university_name)
        inst.url = ew.university_url
        inst.email_domains.append(ew.email_domain)
        inst.save()

    # Add institutions generated from an out-of-band spreadsheet
    Institution.objects.create(name="Harvard Law School", slug=slugify("Harvard Law School"))
    Institution.objects.create(name="Temple University", slug=slugify("Temple University"))
    Institution.objects.create(
        name="University of Houston Law Center", slug=slugify("University of Houston Law Center")
    )
    Institution.objects.create(
        name="Quinnipiac School of Law", slug=slugify("Quinnipiac School of Law")
    )
    Institution.objects.create(
        name="Howard University School of Law", slug=slugify("Howard University School of Law")
    )
    Institution.objects.create(name="Indiana University", slug=slugify("Indiana University"))
    Institution.objects.create(
        name="Northeastern University School of Law",
        slug=slugify("Northeastern University School of Law"),
    )
    Institution.objects.create(name="University of Alabama", slug=slugify("University of Alabama"))
    Institution.objects.create(name="Tufts University", slug=slugify("Tufts University"))
    Institution.objects.create(
        name="University of North Texas", slug=slugify("University of North Texas")
    )
    Institution.objects.create(name="Richmond Law", slug=slugify("Richmond Law"))
    Institution.objects.create(name="Santa Clara Law", slug=slugify("Santa Clara Law"))
    Institution.objects.create(
        name="University of South Carolina School of Law",
        slug=slugify("University of South Carolina School of Law"),
    )
    Institution.objects.create(name="CUNY School of Law", slug=slugify("CUNY School of Law"))
    Institution.objects.create(
        name="University of Denver College of Law",
        slug=slugify("University of Denver College of Law"),
    )
    Institution.objects.create(name="GW Law", slug=slugify("GW Law"))
    Institution.objects.create(
        name="Drexel University School of Law", slug=slugify("Drexel University School of Law")
    )
    Institution.objects.create(
        name="Wayne State University", slug=slugify("Wayne State University")
    )
    Institution.objects.create(
        name="University of Delaware", slug=slugify("University of Delaware")
    )
    Institution.objects.create(name="Georgetown Law", slug=slugify("Georgetown Law"))
    Institution.objects.create(
        name="Florida State University College of Law",
        slug=slugify("Florida State University College of Law"),
    )
    Institution.objects.create(name="St. John's Law", slug=slugify("St. John's Law"))
    Institution.objects.create(
        name="University of Ottowa Faculty of Law",
        slug=slugify("University of Ottowa Faculty of Law"),
    )
    Institution.objects.create(name="Virginia Tech", slug=slugify("Virginia Tech"))
    Institution.objects.create(
        name="Universidad de Navarra", slug=slugify("Universidad de Navarra")
    )
    Institution.objects.create(name="MIT", slug=slugify("MIT"))
    Institution.objects.create(
        name="Peking University School of Transnational Law",
        slug=slugify("Peking University School of Transnational Law"),
    )
    Institution.objects.create(
        name="Thompson Rivers University Faculty of Law",
        slug=slugify("Thompson Rivers University Faculty of Law"),
    )
    Institution.objects.create(name="FIU Law", slug=slugify("FIU Law"))
    Institution.objects.create(name="Columbia Law School", slug=slugify("Columbia Law School"))
    Institution.objects.create(
        name="American University College of Law",
        slug=slugify("American University College of Law"),
    )
    Institution.objects.create(
        name="University of Iowa College of Law", slug=slugify("University of Iowa College of Law")
    )
    Institution.objects.create(name="Stanford Law School", slug=slugify("Stanford Law School"))
    Institution.objects.create(name="University of Turin", slug=slugify("University of Turin"))
    Institution.objects.create(
        name="National Law University, Delhi", slug=slugify("National Law University, Delhi")
    )
    Institution.objects.create(
        name="University of British Columbia School of Law",
        slug=slugify("University of British Columbia School of Law"),
    )
    Institution.objects.create(
        name="Concordia University Wisconsin School of Business",
        slug=slugify("Concordia University Wisconsin School of Business"),
    )
    Institution.objects.create(name="Villanova Law", slug=slugify("Villanova Law"))
    Institution.objects.create(
        name="University of Toronto Faculty of Law",
        slug=slugify("University of Toronto Faculty of Law"),
    )
    Institution.objects.create(
        name="Universidad de Puerto Rico Escuela de Derecho",
        slug=slugify("Universidad de Puerto Rico Escuela de Derecho"),
    )
    Institution.objects.create(name="UConn School of Law", slug=slugify("UConn School of Law"))
    Institution.objects.create(
        name="Loyola University Chicago School of Law",
        slug=slugify("Loyola University Chicago School of Law"),
    )
    Institution.objects.create(
        name="Boston College Law School", slug=slugify("Boston College Law School")
    )
    Institution.objects.create(name="Fordham Law", slug=slugify("Fordham Law"))
    Institution.objects.create(
        name="University of Washington School of Law",
        slug=slugify("University of Washington School of Law"),
    )
    Institution.objects.create(name="New England Law", slug=slugify("New England Law"))
    Institution.objects.create(
        name="Raoul Wallenberg Institute of Human Rights and Humanitarian Law",
        slug=slugify("Raoul Wallenberg Institute of Human Rights and Humanitarian Law"),
    )
    Institution.objects.create(
        name="Western New England School of Law", slug=slugify("Western New England School of Law")
    )
    Institution.objects.create(
        name="University of Maine School of Law", slug=slugify("University of Maine School of Law")
    )
    Institution.objects.create(name="Pitt Law", slug=slugify("Pitt Law"))
    Institution.objects.create(
        name="Central Carolina Community College",
        slug=slugify("Central Carolina Community College"),
    )
    Institution.objects.create(
        name="Northern Illinois University College of Law",
        slug=slugify("Northern Illinois University College of Law"),
    )
    Institution.objects.create(
        name="University of Minnesota Law School",
        slug=slugify("University of Minnesota Law School"),
    )
    Institution.objects.create(
        name="University of Wisconsin Law School",
        slug=slugify("University of Wisconsin Law School"),
    )
    Institution.objects.create(
        name="Boston University School of Law", slug=slugify("Boston University School of Law")
    )
    Institution.objects.create(name="Syracuse University", slug=slugify("Syracuse University"))
    Institution.objects.create(
        name="University of Louisiana at Lafayette",
        slug=slugify("University of Louisiana at Lafayette"),
    )
    Institution.objects.create(name="UC Hastings Law", slug=slugify("UC Hastings Law"))
    Institution.objects.create(
        name="Duquesne University School of Law", slug=slugify("Duquesne University School of Law")
    )
    Institution.objects.create(name="Barry University", slug=slugify("Barry University"))
    Institution.objects.create(
        name="Texas A&M University School of Law",
        slug=slugify("Texas A&M University School of Law"),
    )
    Institution.objects.create(name="South Texas College", slug=slugify("South Texas College"))
    Institution.objects.create(
        name="Case Western Reserve University School of Law",
        slug=slugify("Case Western Reserve University School of Law"),
    )
    Institution.objects.create(
        name="University of Oregon School of Law",
        slug=slugify("University of Oregon School of Law"),
    )
    Institution.objects.create(
        name="University of Cincinnati College of Law",
        slug=slugify("University of Cincinnati College of Law"),
    )
    Institution.objects.create(
        name="University of Hawaii at Manoa School of Law",
        slug=slugify("University of Hawaii at Manoa School of Law"),
    )
    Institution.objects.create(
        name="Nova Southeastern University College of Law",
        slug=slugify("Nova Southeastern University College of Law"),
    )
    Institution.objects.create(
        name="University of Hong Kong", slug=slugify("University of Hong Kong")
    )
    Institution.objects.create(
        name="University of Florida College of Law",
        slug=slugify("University of Florida College of Law"),
    )
    Institution.objects.create(name="Vermont Law School", slug=slugify("Vermont Law School"))
    Institution.objects.create(
        name="Southern Methodist University School of Law",
        slug=slugify("Southern Methodist University School of Law"),
    )
    Institution.objects.create(
        name="Indiana University School of Law", slug=slugify("Indiana University School of Law")
    )
    Institution.objects.create(
        name="University of Chicago Law School", slug=slugify("University of Chicago Law School")
    )
    Institution.objects.create(
        name="William & Mary Law School", slug=slugify("William & Mary Law School")
    )
    Institution.objects.create(
        name="Brigham Young University Law School",
        slug=slugify("Brigham Young University Law School"),
    )
    Institution.objects.create(
        name="Creighton University School of Law",
        slug=slugify("Creighton University School of Law"),
    )
    Institution.objects.create(name="Brooklyn Law School", slug=slugify("Brooklyn Law School"))
    Institution.objects.create(name="Elon Law", slug=slugify("Elon Law"))
    Institution.objects.create(
        name="University of Idaho College of Law",
        slug=slugify("University of Idaho College of Law"),
    )
    Institution.objects.create(
        name="Arizona State University College of Law",
        slug=slugify("Arizona State University College of Law"),
    )
    Institution.objects.create(
        name="Bristol Community College", slug=slugify("Bristol Community College")
    )


def revert_institutions(apps, schema_editor):
    Institution = apps.get_model("main", "Institution")
    Institution.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ("main", "0037_add_institution_model"),
    ]

    operations = [
        migrations.RunPython(insert_institutions, revert_institutions),
    ]