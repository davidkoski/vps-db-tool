from dataclasses import dataclass
from dataclasses_json import dataclass_json
from dataclasses_json import Undefined
import typing as t
import pathlib
import json


@dataclass_json
@dataclass
class Resource:
    url: str
    broken: bool = False


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class GameRef:
    id: str
    name: str


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class Table:
    id: str
    createdAt: int
    updatedAt: int
    urls: t.Optional[t.List[Resource]]
    authors: t.List[str]
    features: t.Optional[t.Set[str]]
    theme: t.Optional[t.Set[str]] # wrong level
    tableFormat: str
    version: t.Optional[str]
    edition: t.Optional[str]
    comment: t.Optional[str]
    imgUrl: t.Optional[str]
    game: t.Optional[GameRef]
    gameFileName: t.Optional[str] # extra - delete


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class B2S:
    id: t.Optional[str]
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    features: t.Optional[t.Set[str]]
    version: t.Optional[str]
    comment: t.Optional[str]
    imgUrl: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class Topper:
    id: t.Optional[str]
    name: t.Optional[str] # obsolete?
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    comment: t.Optional[str]
    version: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class Tutorial:
    id: t.Optional[str]
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    authors: t.Optional[t.List[str]]
    youtubeId: str
    title: str
    ttile: t.Optional[str] # bug
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class Rules:
    id: t.Optional[str]
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    version: t.Optional[str]
    comment: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class ROM:
    id: t.Optional[str]
    name: t.Optional[str]
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    comment: t.Optional[str]
    version: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class WheelArt:
    id: t.Optional[str]
    name: t.Optional[str] # obsolete?
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    version: t.Optional[str]
    comment: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class POV:
    id: t.Optional[str]
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    comment: t.Optional[str]
    version: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class MediaPack:
    id: t.Optional[str]
    name: t.Optional[str] # obsolete?
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    comment: t.Optional[str]
    version: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class AltSound:
    id: t.Optional[str]
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    name: t.Optional[str] # obsolete?
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    comment: t.Optional[str]
    version: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class AltColors:
    id: t.Optional[str]
    name: t.Optional[str] # obsolete?
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    version: t.Optional[str]
    type: t.Optional[str]
    folder: t.Optional[str]
    fileName: t.Optional[str]
    comment: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class PupPack:
    id: t.Optional[str]
    name: t.Optional[str] # obsolete?
    createdAt: t.Optional[int]
    updatedAt: t.Optional[int]
    urls: t.Optional[t.List[Resource]]
    authors: t.Optional[t.List[str]]
    comment: t.Optional[str]
    version: t.Optional[str]
    game: t.Optional[GameRef]


@dataclass_json(undefined=Undefined.RAISE)
@dataclass
class Game:
    id: str
    updatedAt: int
    manufacturer: str
    name: str
    broken: t.Optional[bool]
    imageUrl: t.Optional[str]
    category: t.Optional[str] # obsolete
    imgUrl: t.Optional[str] # which is it?
    mpu: t.Optional[str]
    MPU: t.Optional[str] # which is it?
    year: t.Optional[int]
    theme: t.Optional[t.Set[str]]
    designers: t.Optional[t.Set[str]]
    features: t.Optional[t.Set[str]] # not used, inconsistent
    type: t.Optional[str]
    players: t.Optional[int]
    ipdbUrl: t.Optional[str]
    lastCreatedAt: int
    tableFiles: t.List[Table]
    b2sFiles: t.Optional[t.List[B2S]]
    topperFiles: t.Optional[t.List[Topper]]
    tutorialFiles: t.Optional[t.List[Tutorial]]
    ruleFiles: t.Optional[t.List[Rules]]
    romFiles: t.Optional[t.List[ROM]]
    wheelArtFiles: t.Optional[t.List[WheelArt]]
    povFiles: t.Optional[t.List[POV]]
    mediaPackFiles: t.Optional[t.List[MediaPack]]
    altColorFiles: t.Optional[t.List[AltColors]]
    pupPackFiles: t.Optional[t.List[PupPack]]
    altSoundFiles: t.Optional[t.List[AltSound]]
    soundFiles: t.Optional[t.List[AltSound]] # obsolete


@dataclass_json
@dataclass
class Database:
    games: t.List[Game]

    @staticmethod
    def load(path: pathlib.Path) -> "Database":
        with open(path, "r") as fp:
            data = json.load(fp)
        db = Database.from_dict({'games': data}, infer_missing=True)
        return db

    def save(self, path: pathlib.Path) -> None:
        temp_path = path.with_suffix(".tmp")
        try:
            with open(temp_path, 'w') as fp:
                json.dump(self.to_dict(), fp)
            temp_path.rename(path)
        except Exception as e:
            print(f"Error when saving file, removing temp file: {e}")
            if temp_path.exists():
                temp_path.unlink()
