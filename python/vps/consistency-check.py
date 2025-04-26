import db
import pathlib


path = pathlib.Path("../db/vpsdb.json")
db = db.Database.load(path)


def tables_missing_version(db):
    for game in db.games:
        for t in game.tableFiles:
            if t.version is None and "Zen Studios" not in t.authors:
                print(t)

def bs2_missing_version(db):
    for game in db.games:
        for t in game.b2sFiles or []:
            if t.version is None and "Zen Studios" not in (t.authors or []) and t.urls is not None and len(t.urls) > 0:
                print(t)

def automatic_parent():
    for game in db.games:
        for t in game.tableFiles:
            if t.features is not None:
                if "incl. B2S" in t.features:
                    t.features.remove("incl. B2S")

                if "incl. Art" in t.features:
                    t.features.remove("incl. Art")

    for game in db.games:
        for t in game.tableFiles:
            authors = list(t.authors)
            while len(authors) > 0:
                del authors[0]
                for t2 in game.tableFiles:
                    if authors == t2.authors:
                        print(f"{game.name}: {t.authors[0]} -> {t2.authors[0]}")
                        if t.features is not None and t2.features is not None and len(t.features) < len(t2.features):
                            print("    MISSING")

# for game in db.games:
#     for t in game.tableFiles:
#         if t.urls is not None and len(t.urls) > 0:
#             print(t.urls[0].url)

# i = { }
# for game in db.games:
#     for t in game.tableFiles:
#         if t.urls is not None and len(t.urls) > 0:
#             url = t.urls[0].url
#             if url in i:
#                 print(f"{game.name} {i[url]} -> {url}")
#             else:
#                 i[url] = game.name

for game in db.games:
    for b in game.pupPackFiles or []:
        if b.id is None:
            print(game.name)
