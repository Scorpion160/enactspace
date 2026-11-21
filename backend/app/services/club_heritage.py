"""Public club heritage, checked against official sources on 2026-10-03.

Bundled images preserve the club's photographs offline and avoid social-CDN
expiry. Published project objectives are not counted as achieved impact.
"""
SITE = "https://www.enactusesp.com"
POLYTECH = SITE + "/stories/concours-polytech-innovation-2025"
WORLD_2018 = "https://esp.sn/enactus-world-cup-2018-lequipe-de-lesp-demi-finaliste-dresse-un-bilan-satisfaisant-de-sa-participation/"
WORLD_2022 = "https://www.linkedin.com/posts/cheikh-mbengue-albounama_engagement-sdgs-puertorico-activity-6997943456241176576-9BIj"
DIMBALI = "https://esp.sn/%F0%9D%97%97%F0%9D%97%B6%F0%9D%97%BA%F0%9D%97%AF%F0%9D%97%AE%F0%9D%97%B9%F0%9D%97%B6-%F0%9D%97%B9%F0%9D%97%B2-%F0%9D%97%BD%F0%9D%97%BF%F0%9D%97%BC%F0%9D%97%B7%F0%9D%97%B2%F0%9D%98%81-de/"
LINKTREE = "https://linktr.ee/Enactus.esp"
OFFICIAL_SOURCE = "Site officiel Enactus ESP"
TROPHY_SOURCE = "Photothèque Enactus ESP"

def _media(key, title, description, *, asset=None, source=None, year=None,
           project=None, media_type="photo", label=OFFICIAL_SOURCE):
    return {
        "id": key, "title": title, "description": description,
        "media_type": media_type, "year": year, "project_id": project,
        "file_id": None, "external_url": source, "source_url": source,
        "source_label": label, "image_asset": asset, "is_featured": True,
    }

PUBLIC_HERITAGE_MEDIA = [
    _media("trophees-national-2016", "Trophées Enactus Sénégal 2016",
           "Deux distinctions marquent 2016 : Vice Champion National et Premier Prix de la Fondation Sonatel.",
           asset="assets/img/prix_enactus_national_2016.png", year=2016, label=TROPHY_SOURCE),
    _media("trophee-uhodari-2016", "Trophée UHODARI 2016",
           "Enactus ESP remporte l’édition 2016 du concours UHODARI.",
           asset="assets/img/prix_uhodari_2016.png", year=2016, label=TROPHY_SOURCE),
    _media("polytech-innovation-2025-photo", "Double victoire à Polytech’Innovation 2025",
           "Le 25 avril 2025, Terrasen décroche le premier prix et Aquatus le deuxième parmi les dix projets sélectionnés à Polytech’Innovation.",
           asset="assets/heritage/polytech-innovation-2025.jpg", source=POLYTECH, year=2025),
    _media("salon-polytechnicien-2025-photo", "Salon Polytechnicien 2025",
           "Un stand tenu pendant trois jours présente les produits et projets du club aux étudiants, enseignants et visiteurs.",
           asset="assets/heritage/salon-polytechnicien-2025.jpg",
           source=SITE+"/stories/salon-polytechnicien-2025", year=2025),
    _media("immersion-mars-2025-photo", "Voyage d’immersion — mars 2025",
           "À Ndiédieng, Haafe, Passi, Niaguiss et Yeumbeul, l’équipe mène des immersions, des transferts de technologies et des formations, puis recueille l’impact des solutions.",
           asset="assets/heritage/immersion-mars-2025.jpg",
           source=SITE+"/stories/voyage-d-immersion-de-mars-2025", year=2025),
    _media("shery-official-photo", "SHERY — photo officielle",
           "Serviettes hygiéniques réutilisables, tisanes naturelles et sensibilisation à l’hygiène menstruelle. Le projet vise à élargir l’accès aux protections et à développer ses ventes.",
           asset="assets/heritage/shery.jpg", source=SITE+"/projects/shery", project="shery"),
    _media("aquatus-official-photo", "AQUATUS — photo officielle",
           "L’aquaponie associe élevage de poissons et cultures : les déchets des poissons nourrissent les plantes, qui contribuent à filtrer l’eau.",
           asset="assets/heritage/aquatus.jpg", source=SITE+"/projects/aquatus", project="aquatus"),
    _media("terrasen-official-photo", "TERRASEN — photo officielle",
           "Micro-jardinage sur table, arrosage automatique et transfert de fabrication aux GIE ; un volet d’alimentation de la volaille complète cette démarche.",
           asset="assets/heritage/terrasen.jpg", source=SITE+"/projects/terrasen", project="terrasen"),
    _media("men-nan-official-photo", "MËN NAÑ — photo officielle",
           "Mën Nañ accompagne plus de 500 femmes formées, 97 emplois, 4 218 375 FCFA de chiffre d’affaires, plus d’une tonne de fruits et 1 351 litres de lait transformés.",
           asset="assets/heritage/men-nan.jpg", source=SITE+"/projects/men-nan", project="meune-nagn"),
    _media("world-cup-2018-esp-article", "World Cup 2018 — bilan officiel de l’ESP",
           "L’article du 22 octobre 2018 confirme la demi-finale et le Top 12 à San José, après la compétition des 9, 10 et 11 octobre. Dimbali et Deconaane représentent le Sénégal.",
           source=WORLD_2018, year=2018, media_type="article_presse", label="École Supérieure Polytechnique de Dakar"),
    _media("dimbali-esp-2021-article", "Dimbali à Ngayène Sabakh — reportage de l’ESP",
           "Le reportage du 25 mars 2021 décrit les formations et séchoirs solaires. Pour cette localité et cette période, le maire rapporte 112 emplois, une malnutrition passant de 15,78 % à 0 % et une hausse de revenus de 98 % pour 30 femmes du GIE-FAVEC.",
           source=DIMBALI, year=2021, project="dimbali", media_type="article_presse", label="École Supérieure Polytechnique de Dakar"),
    _media("world-cup-2022-official-post", "World Cup 2022 — demi-finale à Porto Rico",
           "Une publication Enactus ESP relayée sur LinkedIn rapporte la demi-finale à Porto Rico, lors de la compétition du 30 octobre au 2 novembre 2022.",
           source=WORLD_2022, year=2022, media_type="article_presse", label="Publication Enactus ESP relayée sur LinkedIn"),
]
for _index in range(1, 9):
    PUBLIC_HERITAGE_MEDIA.append(_media(
        f"official-gallery-{_index}", f"Galerie officielle — moment {_index}",
        "Les générations se rencontrent autour des projets, des préparations et des moments partagés. Ces souvenirs donnent un visage au collectif Enactus ESP.",
        asset=f"assets/heritage/galerie-{_index}.jpg", source=SITE+"/#galerie",
    ))
for _key, _title, _url in [
    ("instagram", "Instagram Enactus ESP", "https://www.instagram.com/enact.us_polytech/"),
    ("tiktok", "TikTok Enactus ESP", "https://www.tiktok.com/@enactus.esp"),
    ("linkedin", "LinkedIn Enactus ESP", "https://www.linkedin.com/in/enactus-esp-59899819b/"),
    ("site", "Site officiel Enactus ESP", SITE+"/"),
]:
    PUBLIC_HERITAGE_MEDIA.append(_media(
        "club-source-"+_key, _title,
        "Retrouvez les publications du club sur cette page officielle.",
        source=_url, media_type="lien", label="Enactus ESP — liens officiels" if _key=="site" else "Linktree Enactus ESP",
    ))

from app.services.club_voices import MINUTES, HOMMAGE, MEETING_HIGHLIGHTS
PUBLIC_HERITAGE_MEDIA.extend(MINUTES + MEETING_HIGHLIGHTS)
from app.services.club_photo_stories import PHOTO_STORIES, PHOTO_AWARDS, enrich_photo_stories
for key, title, body, year, project in PHOTO_STORIES:
    PUBLIC_HERITAGE_MEDIA.append(_media('phototheque-'+key,title,body,
        asset='assets/heritage/'+key+'.jpg',year=year,project=project,label=TROPHY_SOURCE))
for key, title, body, image, project in PHOTO_AWARDS:
    PUBLIC_HERITAGE_MEDIA.append(_media('phototheque-'+key,title,body,
        asset='assets/heritage/'+image+'.jpg',year=2020,project=project,label=TROPHY_SOURCE))


def enrich_public_heritage(projects, awards, competitions, hall):
    if not any(row['id'] == HOMMAGE['id'] for row in hall):
        hall.insert(0, dict(HOMMAGE))
    project_images = {
        "sukhalii-gokh": "assets/img/logo_soukhalii_gokh.png",
        "kong-serve": "assets/img/logo_kongserve.png",
        "javelisel": "assets/img/logo_javelisel.png",
        "deconaane": "assets/img/logo_deconaane.png",
        "dimbali": "assets/img/logo_dimbali.png",
        "meune-nagn": "assets/heritage/men-nan.jpg",
        "mobigel": "assets/img/logo_mobigel.png",
        "shery": "assets/heritage/shery.jpg",
        "aquatus": "assets/heritage/aquatus.jpg",
        "terrasen": "assets/heritage/terrasen.jpg",
    }
    project_sources = {
        "shery": SITE+"/projects/shery", "aquatus": SITE+"/projects/aquatus",
        "terrasen": SITE+"/projects/terrasen", "meune-nagn": SITE+"/projects/men-nan",
        "dimbali": DIMBALI,
    }
    for row in projects:
        row["image_asset"] = project_images.get(row["id"])
        if row["id"] in project_sources:
            row["source_url"] = project_sources[row["id"]]
            row["source_label"] = "Archives Enactus ESP"
    for row in awards:
        if row["id"] in {"prix-excellence-sonatel", "deuxieme-national-2016"}:
            row["image_asset"] = "assets/img/prix_enactus_national_2016.png"
            if row["id"] == "prix-excellence-sonatel": row["year"] = 2016
        elif row["id"] == "uhodari-2016":
            row["image_asset"] = "assets/img/prix_uhodari_2016.png"
        elif row["id"] in {"terrasen-polytech-innovation-2025", "aquatus-polytech-innovation-2025"}:
            row["image_asset"] = "assets/heritage/polytech-innovation-2025.jpg"
            row["source_url"] = POLYTECH
        elif row["id"] in {"champion-national-2018", "demi-finaliste-international-2018"}:
            row["source_url"] = WORLD_2018
    for row in competitions:
        if row["id"] in {"competition-nationale-2018", "world-cup-2018"}:
            row["source_url"] = WORLD_2018
        elif row["id"] == "world-cup-2022":
            row.update(result="Demi-finaliste", location="Porto Rico",
                       source_url=WORLD_2022,
                       description="Dimbali et Mën Nañ représentent Enactus ESP à Porto Rico. L’équipe atteint la demi-finale.")
    if not any(row["id"] == "polytech-innovation-2025" for row in competitions):
        competitions.append({
            "id": "polytech-innovation-2025", "archive_item_id": None,
            "name": "Polytech’Innovation 2025", "year": 2025,
            "stage": "Innovation", "result": "Premier et deuxième prix",
            "location": "École Supérieure Polytechnique de Dakar",
            "description": "Terrasen remporte le premier prix et Aquatus le deuxième prix, parmi dix projets sélectionnés.",
            "project_ids": ["terrasen", "aquatus"],
            "award_ids": ["terrasen-polytech-innovation-2025", "aquatus-polytech-innovation-2025"],
            "file_id": None, "is_featured": True,
            "image_asset": "assets/heritage/polytech-innovation-2025.jpg",
            "source_url": POLYTECH,
        })
    for row in hall:
        if row["id"] == "demi-finaliste-world-cup-2018-hall":
            row["external_url"] = WORLD_2018
        elif row["id"] == "world-cup-2022-hall":
            row.update(title="Demi-finaliste Enactus World Cup 2022",
                       subtitle="Dimbali et Mën Nañ à Porto Rico",
                       description="Dimbali et Mën Nañ portent le retour du club sur la scène mondiale, jusqu’à la demi-finale à Porto Rico.",
                       external_url=WORLD_2022)
        elif row["id"] == "innovations-2025-hall":
            row["external_url"] = POLYTECH
            row["image_asset"] = "assets/heritage/polytech-innovation-2025.jpg"

    from app.services.club_story import enrich_club_story
    enrich_club_story(projects, awards, competitions, hall)
    enrich_photo_stories(projects, awards, competitions, hall)
