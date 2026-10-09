"""Export des donnees de l'application (sauvegarde portable).

Neon PostgreSQL ne garantit pas de sauvegardes illimitees sur l'offre
gratuite : cette commande fournit un export complet et reproductible.

  python manage.py backup_data
  python manage.py backup_data --output backups/vol-rns.json

Restauration :  python manage.py loaddata backups/vol-rns.json
"""
import datetime as dt
from pathlib import Path

from django.conf import settings
from django.core.management import call_command
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Exporte toutes les donnees dans un fichier JSON horodate."

    def add_arguments(self, parser):
        parser.add_argument(
            "--output",
            help="Chemin du fichier de sortie (defaut: backups/vol-rns-<horodatage>.json).",
        )
        parser.add_argument(
            "--exclude",
            action="append",
            default=["contenttypes", "auth.permission", "sessions"],
            help="Application a exclure (repetable).",
        )

    def handle(self, *args, **options):
        if options.get("output"):
            output_path = Path(options["output"])
        else:
            timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
            output_path = Path(settings.BASE_DIR) / "backups" / f"vol-rns-{timestamp}.json"
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with output_path.open("w", encoding="utf-8") as handle:
            call_command(
                "dumpdata",
                exclude=options["exclude"],
                indent=2,
                stdout=handle,
            )
        self.stdout.write(self.style.SUCCESS(f"Sauvegarde ecrite : {output_path}"))
        self.stdout.write(
            f"Restauration : python manage.py loaddata {output_path}"
        )
