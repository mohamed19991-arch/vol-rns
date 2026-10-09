"""Initialisation des donnees de base VOL-RNS.

Cree :
  * les 5 destinations (RNS, ORAN, ADRAR, BISKRA, BEJAIA) ;
  * un compte administrateur ;
  * optionnellement le programme hebdomadaire initial (trajets uniquement),
    UNIQUEMENT si des horaires sont explicitement fournis en ligne de commande.

Les horaires ne sont jamais inventes : ils doivent etre fournis par un
utilisateur autorise (ici via les options --registration-time, etc.).
"""
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

from apps.flights.constants import DayOfWeek
from apps.flights.models import Destination, WeeklySchedule

User = get_user_model()

DESTINATIONS = [
    {"code": "RNS", "name": "RENNES", "city": "Rennes", "airport_name": "Aeroport de Rennes"},
    {"code": "ORAN", "name": "ORAN", "city": "Oran", "airport_name": "Aeroport d'Oran"},
    {"code": "ADRAR", "name": "ADRAR", "city": "Adrar", "airport_name": "Aeroport d'Adrar"},
    {"code": "BISKRA", "name": "BISKRA", "city": "Biskra", "airport_name": "Aeroport de Biskra"},
    {"code": "BEJAIA", "name": "BEJAIA", "city": "Bejaia", "airport_name": "Aeroport de Bejaia"},
]

# Programme initial : trajets par jour (horaires a fournir par l'administrateur).
INITIAL_ROUTES = {
    DayOfWeek.SATURDAY: [("RNS", "ORAN"), ("ORAN", "RNS")],
    DayOfWeek.SUNDAY: [("RNS", "ADRAR"), ("ADRAR", "RNS")],
    DayOfWeek.MONDAY: [
        ("RNS", "BISKRA"),
        ("RNS", "BEJAIA"),
        ("BISKRA", "RNS"),
        ("BEJAIA", "RNS"),
    ],
}


class Command(BaseCommand):
    help = "Cree les destinations, un administrateur et (optionnellement) le programme initial."

    def add_arguments(self, parser):
        parser.add_argument("--admin-email", default="admin@vol-rns.local")
        parser.add_argument("--admin-password", default="")
        parser.add_argument(
            "--with-initial-schedule",
            action="store_true",
            help="Cree le programme hebdomadaire initial (necessite les horaires).",
        )
        parser.add_argument("--registration-time", help="Heure d'enregistrement (HH:MM).")
        parser.add_argument("--departure-time", help="Heure de decollage (HH:MM).")
        parser.add_argument("--arrival-time", help="Heure d'arrivee (HH:MM), facultative.")

    def handle(self, *args, **options):
        self._create_destinations()
        self._create_admin(options["admin_email"], options["admin_password"])
        if options["with_initial_schedule"]:
            self._create_initial_schedule(options)
        else:
            self.stdout.write(
                self.style.WARNING(
                    "Programme initial non cree : les horaires doivent etre "
                    "renseignes par un utilisateur autorise (option --with-initial-schedule)."
                )
            )
        self.stdout.write(self.style.SUCCESS("Initialisation terminee."))

    # ------------------------------------------------------------------
    def _create_destinations(self):
        for data in DESTINATIONS:
            destination, created = Destination.objects.update_or_create(
                code=data["code"], defaults={**data, "is_active": True}
            )
            state = "creee" if created else "mise a jour"
            self.stdout.write(f"Destination {destination.code} {state}.")

    def _create_admin(self, email, password):
        email = email.lower().strip()
        if User.objects.filter(email=email).exists():
            self.stdout.write(f"Administrateur {email} deja present.")
            return
        if not password:
            raise CommandError(
                "Fournissez --admin-password pour creer le compte administrateur."
            )
        User.objects.create_superuser(email=email, password=password, role=User.Role.ADMIN)
        self.stdout.write(self.style.SUCCESS(f"Administrateur {email} cree."))

    def _create_initial_schedule(self, options):
        registration = options.get("registration_time")
        departure = options.get("departure_time")
        arrival = options.get("arrival_time")
        if not registration or not departure:
            raise CommandError(
                "--registration-time et --departure-time sont obligatoires pour creer "
                "le programme initial (les horaires ne sont jamais inventes)."
            )
        created_count = 0
        for day, routes in INITIAL_ROUTES.items():
            for origin_code, destination_code in routes:
                origin = Destination.objects.get(code=origin_code)
                destination = Destination.objects.get(code=destination_code)
                _, created = WeeklySchedule.objects.update_or_create(
                    day_of_week=day.value,
                    origin=origin,
                    destination=destination,
                    departure_time=departure,
                    defaults={
                        "registration_time": registration,
                        "arrival_time": arrival,
                        "is_active": True,
                    },
                )
                created_count += int(created)
        self.stdout.write(
            self.style.SUCCESS(f"Programme initial : {created_count} trajet(s) cree(s).")
        )
