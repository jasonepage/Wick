//
//  OfflineKeeper.swift
//  Hunch
//
//  Lets Wick answer typed questions on phones WITHOUT Apple Intelligence.
//
//  When the on-device Foundation Model is unavailable, we still want the Keeper
//  to work. The app already answers tapped starter chips deterministically from
//  each word's category tag (see WordAttributes). This extends the same idea to
//  FREE-TEXT questions: we map the player's sentence onto one of the known
//  StarterProperty axes by keyword, then reuse WordAttributes.deterministicVerdict.
//
//  Fully offline, fully private — no network, no model. When a question doesn't
//  map to an axis we can decide (or the word is untagged), Wick honestly shrugs
//  and points the player at questions it CAN answer, and no question is spent.
//

import Foundation

enum OfflineKeeper {

    // MARK: - Question → property mapping

    /// Ordered most-specific-first so narrow phrases win over broad ones
    /// (e.g. "ever alive" before "alive", "moving parts" before "move").
    /// Every trigger is a plain substring tested against the lowercased question;
    /// phrases (not bare words) are used wherever a bare word would false-match
    /// (e.g. "is it hot" not "hot", which hides inside "photo"/"shot").
    private static let map: [(StarterProperty, [String])] = [
        (.everAlive,   ["ever alive", "was it alive", "once alive", "used to be alive",
                        "ever living", "once living", "was it living"]),
        (.alive,       ["alive", "still living", "is it living", "a living thing"]),
        (.animal,      ["an animal", "is it animal", "a creature", "a beast", "a mammal",
                        "a bird", "an insect", "a fish"]),
        (.plant,       ["a plant", "is it plant", "vegetation", "a flower or"]),
        (.bodyPart,    ["body part", "part of the body", "part of your body",
                        "part of a body", "anatomy", "body-part"]),
        (.emotion,     ["an emotion", "is it emotion", "a feeling", "emotional", "how you feel"]),
        (.abstractIdea,["abstract", "an idea", "a concept", "concept", "a notion",
                        "intangible", "in your mind", "just an idea"]),
        (.action,      ["an action", "something you do", "an activity", "a verb",
                        "is it an action", "an act"]),
        (.manMade,     ["man-made", "manmade", "man made", "manufactured", "made by people",
                        "made by humans", "made by man", "artificial", "human-made",
                        "human made", "built by", "made in a factory"]),
        (.inNature,    ["in nature", "in the wild", "in the wilderness", "out in nature",
                        "in the wild?", "found in the wild"]),
        (.natural,     ["occur naturally", "occurs naturally", "found in nature",
                        "naturally occurring", "made by nature", "natural", "naturally"]),
        (.place,       ["a place", "is it a place", "a location", "somewhere you can",
                        "geographic", "a spot you can go"]),
        (.biggerThanCar,["bigger than a car", "bigger than car", "larger than a car",
                        "bigger than a house", "huge", "enormous", "gigantic",
                        "very big", "very large", "massive"]),
        (.smallerThanShoe,["smaller than a shoe", "smaller than shoe", "tiny",
                        "very small", "smaller than your hand"]),
        (.fitsInHand,  ["fit in your hand", "fit in a hand", "fit in hand", "fits in your hand",
                        "fits in a hand", "fits in hand", "handheld", "hold it in your hand",
                        "fit in the palm", "fit in your palm"]),
        (.inKitchen,   ["kitchen"]),
        (.nearWater,   ["near water", "in water", "underwater", "by water", "around water",
                        "in or near water"]),
        (.indoors,     ["indoors", "indoor", "inside a house", "inside a building", "found inside"]),
        (.outdoors,    ["outdoors", "outdoor", "outside"]),
        (.transport,   ["transport", "a vehicle", "get around", "used to travel", "for travel",
                        "ride in", "ride on", "for getting around"]),
        (.communication,["communicat", "send a message", "for talking", "used to talk",
                        "used for talking"]),
        (.entertainment,["entertain", "for fun", "play with", "for playing", "a hobby",
                        "a game you play"]),
        (.tool,        ["a tool", "is it a tool", "a device", "an instrument", "a utensil",
                        "a gadget", "tool or device", "a piece of equipment"]),
        (.edible,      ["can you eat", "edible", "can you drink", "do you eat", "good to eat",
                        "safe to eat", "eat it", "drink it", "taste it", "eat or drink"]),
        (.wearable,    ["wearable", "do you wear", "can you wear", "is it clothing", "clothes",
                        "put it on", "worn on", "worn by"]),
        (.canHold,     ["hold it", "can you hold", "pick it up", "carry it", "hold in your hands",
                        "held in", "can you carry"]),
        (.metal,       ["metal", "metallic", "made of metal", "made of iron", "made of steel"]),
        (.wood,        ["wood", "wooden", "made of wood"]),
        (.soft,        ["soft", "fluffy", "squishy", "soft to the touch"]),
        (.liquid,      ["a liquid", "is it liquid", "a fluid", "is it fluid"]),
        (.givesLight,  ["give off light", "gives off light", "give light", "gives light",
                        "glow", "glows", "shine", "shines", "luminous", "light up",
                        "lights up", "emit light", "emits light"]),
        (.makesSound,  ["make a sound", "makes a sound", "make sound", "makes noise",
                        "make noise", "a noise", "can you hear it", "audible", "is it loud"]),
        (.hasSmell,    ["a smell", "smell", "a scent", "scent", "odor", "odour", "aroma",
                        "fragran"]),
        (.color,       ["a color", "a colour", "specific color", "specific colour",
                        "colorful", "colourful", "what color", "what colour"]),
        (.movingParts, ["moving parts", "parts that move", "mechanical parts", "has parts"]),
        (.movesItself, ["move on its own", "move by itself", "moves itself", "move itself",
                        "self-propelled", "moves on its own", "moves by itself"]),
        (.food,        ["a food", "a kind of food", "is it food", "foodstuff", "a dish",
                        "a meal", "edible food"]),
        (.hot,         ["is it hot", "usually hot", "very hot", "warm to the touch",
                        "gives off heat", "hot to the touch", "is it warm"]),
        (.cold,        ["is it cold", "usually cold", "very cold", "freezing", "icy", "chilly",
                        "cold to the touch"]),
        (.tech,        ["technolog", "electronic", "digital", "a computer", "high-tech",
                        "is it tech", "tech?"]),
        (.job,         ["a job", "a profession", "an occupation", "a career", "kind of work",
                        "for work", "a trade"]),
        (.season,      ["a season", "time of year", "associated with a season"]),
        (.centuriesOld,["centuries", "hundreds of years", "ancient", "very old",
                        "thousands of years", "from long ago", "old invention"]),
        (.modern,      ["modern", "recent invention", "invented recently", "a new invention",
                        "recently invented", "a recent invention"]),
        (.physical,    ["physical", "can you touch", "tangible", "a real object",
                        "a solid object", "an object", "touch it", "is it an object",
                        "a thing you can touch"]),
    ]

    /// Spanish trigger phrases, mirroring `map`. Kept in a separate table so
    /// English and Spanish substrings can never cross-match. Most-specific-first.
    private static let mapES: [(StarterProperty, [String])] = [
        (.everAlive,   ["alguna vez estuvo vivo", "estuvo vivo", "estuvo viva",
                        "alguna vez vivió", "fue un ser vivo"]),
        (.alive,       ["está vivo", "está viva", "es un ser vivo", "sigue vivo", "algo vivo"]),
        (.animal,      ["es un animal", "un animal", "una criatura", "un mamífero",
                        "un ave", "un pájaro", "un insecto", "un pez"]),
        (.plant,       ["una planta", "es una planta", "vegetal", "una flor"]),
        (.bodyPart,    ["parte del cuerpo", "una parte del cuerpo"]),
        (.emotion,     ["una emoción", "un sentimiento", "es emocional"]),
        (.abstractIdea,["abstracto", "abstracta", "una idea", "un concepto",
                        "intangible", "en tu mente"]),
        (.action,      ["una acción", "algo que haces", "una actividad", "un verbo"]),
        (.manMade,     ["hecho por el hombre", "hecho por humanos", "hecho por el ser humano",
                        "fabricado", "artificial", "hecho a mano", "manufacturado",
                        "hecho en una fábrica"]),
        (.inNature,    ["en la naturaleza", "en estado salvaje", "en lo salvaje",
                        "en el medio natural"]),
        (.natural,     ["ocurre naturalmente", "de forma natural", "se encuentra en la naturaleza",
                        "es natural", "naturalmente"]),
        (.place,       ["un lugar", "es un lugar", "una ubicación", "un sitio"]),
        (.biggerThanCar,["más grande que un coche", "más grande que un carro",
                        "más grande que un auto", "más grande que una casa",
                        "enorme", "gigante", "gigantesco", "muy grande", "descomunal"]),
        (.smallerThanShoe,["más pequeño que un zapato", "más chico que un zapato",
                        "diminuto", "muy pequeño", "muy chico", "más pequeño que tu mano"]),
        (.fitsInHand,  ["cabe en la mano", "cabe en tu mano", "sostener en la mano",
                        "de mano", "cabe en la palma"]),
        (.inKitchen,   ["cocina"]),
        (.nearWater,   ["cerca del agua", "en el agua", "bajo el agua", "junto al agua",
                        "alrededor del agua"]),
        (.indoors,     ["en interiores", "dentro de casa", "dentro de un edificio",
                        "bajo techo", "en el interior", "adentro"]),
        (.outdoors,    ["al aire libre", "en exteriores", "afuera", "al exterior",
                        "en el exterior"]),
        (.transport,   ["transporte", "un vehículo", "para viajar", "para desplazarse",
                        "montar en", "para moverse", "sirve para transportar"]),
        (.communication,["comunica", "enviar un mensaje", "para hablar", "para comunicarse"]),
        (.entertainment,["entreten", "para divertir", "jugar con", "un pasatiempo",
                        "para jugar", "es un juego"]),
        (.tool,        ["una herramienta", "un dispositivo", "un instrumento",
                        "un utensilio", "un aparato"]),
        (.edible,      ["puedes comer", "comestible", "puedes beber", "se come",
                        "se bebe", "comerlo", "beberlo", "probarlo"]),
        (.wearable,    ["puedes usar", "puedes vestir", "es ropa", "se lleva puesto",
                        "ponértelo", "se pone"]),
        (.canHold,     ["puedes sostener", "sostenerlo", "recogerlo", "cargarlo",
                        "sostener en las manos", "tomarlo con la mano"]),
        (.metal,       ["metálico", "de metal", "de hierro", "de acero", "metal"]),
        (.wood,        ["de madera", "madera"]),
        (.soft,        ["suave", "blando", "esponjoso"]),
        (.liquid,      ["un líquido", "es líquido", "un fluido"]),
        (.givesLight,  ["da luz", "emite luz", "brilla", "ilumina", "luminoso", "resplandece"]),
        (.makesSound,  ["hace un sonido", "hace ruido", "un ruido", "puedes oírlo",
                        "audible", "es ruidoso", "suena"]),
        (.hasSmell,    ["un olor", "huele", "un aroma", "una fragancia"]),
        (.color,       ["un color", "de color", "colorido", "qué color", "de colores"]),
        (.movingParts, ["partes móviles", "partes que se mueven", "partes mecánicas"]),
        (.movesItself, ["moverse solo", "se mueve solo", "se mueve por sí mismo",
                        "por sí mismo", "autopropulsado"]),
        (.food,        ["una comida", "un alimento", "es comida", "un plato", "un manjar"]),
        (.hot,         ["es caliente", "está caliente", "muy caliente", "da calor",
                        "caliente al tacto"]),
        (.cold,        ["es frío", "está frío", "muy frío", "congelado", "helado",
                        "frío al tacto"]),
        (.tech,        ["tecnología", "tecnológic", "electrónico", "digital",
                        "una computadora", "un ordenador", "alta tecnología"]),
        (.job,         ["un trabajo", "una profesión", "un oficio", "una carrera"]),
        (.season,      ["una estación", "época del año", "una temporada del año"]),
        (.centuriesOld,["siglos", "cientos de años", "antiguo", "muy viejo",
                        "miles de años", "de hace mucho", "milenaria"]),
        (.modern,      ["moderno", "invención reciente", "inventado recientemente",
                        "un invento nuevo", "reciente"]),
        (.physical,    ["físico", "puedes tocar", "tangible", "un objeto real",
                        "un objeto sólido", "tocarlo", "es un objeto", "una cosa que puedes tocar"]),
    ]

    /// French trigger phrases, mirroring `map`. Most-specific-first.
    private static let mapFR: [(StarterProperty, [String])] = [
        (.everAlive,   ["déjà été vivant", "autrefois vivant", "était vivant", "était vivante",
                        "a été vivant", "a déjà vécu"]),
        (.alive,       ["vivant", "vivante", "en vie", "un être vivant"]),
        (.animal,      ["un animal", "une bête", "une créature", "un mammifère",
                        "un oiseau", "un insecte", "un poisson"]),
        (.plant,       ["une plante", "un végétal", "une fleur"]),
        (.bodyPart,    ["partie du corps", "une partie du corps"]),
        (.emotion,     ["une émotion", "un sentiment"]),
        (.abstractIdea,["abstrait", "abstraite", "une idée", "un concept", "intangible",
                        "dans la tête", "dans l'esprit"]),
        (.action,      ["une action", "quelque chose que l'on fait", "quelque chose qu'on fait",
                        "une activité", "un verbe"]),
        (.manMade,     ["fabriqué par l'homme", "fait par l'homme", "fabriqué par les humains",
                        "fabriqué", "artificiel", "artificielle", "fait à la main",
                        "fait en usine", "construit par"]),
        (.inNature,    ["dans la nature", "à l'état sauvage", "en pleine nature",
                        "dans le milieu naturel"]),
        (.natural,     ["à l'état naturel", "de façon naturelle", "naturellement",
                        "est naturel", "est naturelle"]),
        (.place,       ["un lieu", "un endroit", "est un lieu", "un emplacement"]),
        (.biggerThanCar,["plus grand qu'une voiture", "plus grande qu'une voiture",
                        "plus gros qu'une voiture", "plus grand qu'une maison",
                        "énorme", "gigantesque", "très grand", "très gros", "immense"]),
        (.smallerThanShoe,["plus petit qu'une chaussure", "plus petite qu'une chaussure",
                        "minuscule", "très petit", "très petite", "plus petit que ta main"]),
        (.fitsInHand,  ["tient dans la main", "tient dans ta main", "tenir dans la main",
                        "dans la paume", "tient dans une main"]),
        (.inKitchen,   ["cuisine"]),
        (.nearWater,   ["près de l'eau", "dans l'eau", "sous l'eau", "au bord de l'eau",
                        "autour de l'eau"]),
        (.indoors,     ["à l'intérieur", "en intérieur", "dans une maison",
                        "dans un bâtiment", "dedans"]),
        (.outdoors,    ["dehors", "à l'extérieur", "en plein air", "en extérieur"]),
        (.transport,   ["transport", "un véhicule", "pour voyager", "se déplacer",
                        "pour se déplacer", "rouler avec", "monter dedans", "monter dessus"]),
        (.communication,["communiqu", "envoyer un message", "pour parler", "pour discuter"]),
        (.entertainment,["divertissement", "divertir", "pour s'amuser", "jouer avec",
                        "pour jouer", "un passe-temps", "un jeu"]),
        (.tool,        ["un outil", "un appareil", "un instrument", "un ustensile",
                        "un dispositif", "un équipement"]),
        (.edible,      ["peut manger", "se mange", "comestible", "peut boire", "se boit",
                        "le manger", "le boire", "le goûter", "manger ou boire"]),
        (.wearable,    ["se porte", "peut porter", "un vêtement", "des vêtements",
                        "l'enfiler", "se met sur", "porté sur"]),
        (.canHold,     ["le tenir", "peut tenir", "le ramasser", "le porter dans",
                        "tenir dans les mains", "le prendre dans la main", "l'attraper"]),
        (.metal,       ["métal", "métallique", "en fer", "en acier"]),
        (.wood,        ["en bois", "bois"]),
        (.soft,        ["doux", "douce", "mou", "molle", "moelleux", "doux au toucher"]),
        (.liquid,      ["un liquide", "est liquide", "un fluide"]),
        (.givesLight,  ["de la lumière", "émet de la lumière", "donne de la lumière",
                        "brille", "lumineux", "lumineuse", "éclaire", "s'illumine"]),
        (.makesSound,  ["fait du bruit", "fait un son", "un bruit", "peut l'entendre",
                        "audible", "est bruyant", "ça sonne"]),
        (.hasSmell,    ["une odeur", "ça sent", "un parfum", "une fragrance", "un arôme"]),
        (.color,       ["une couleur", "de couleur", "coloré", "colorée", "quelle couleur",
                        "de quelle couleur"]),
        (.movingParts, ["pièces mobiles", "pièces qui bougent", "parties mobiles",
                        "pièces mécaniques"]),
        (.movesItself, ["bouger tout seul", "bouge tout seul", "se déplace tout seul",
                        "se déplacer tout seul", "par lui-même", "se déplace seul",
                        "autopropulsé"]),
        (.food,        ["un aliment", "de la nourriture", "est de la nourriture",
                        "un plat", "un repas", "un mets"]),
        (.hot,         ["est chaud", "est chaude", "très chaud", "généralement chaud",
                        "dégage de la chaleur", "chaud au toucher"]),
        (.cold,        ["est froid", "est froide", "très froid", "glacé", "glacial",
                        "congelé", "froid au toucher"]),
        (.tech,        ["technolog", "électronique", "numérique", "un ordinateur",
                        "high-tech", "informatique"]),
        (.job,         ["un métier", "une profession", "un emploi", "une carrière",
                        "un travail", "un boulot"]),
        (.season,      ["une saison", "époque de l'année", "période de l'année",
                        "saisonnier"]),
        (.centuriesOld,["des siècles", "des centaines d'années", "ancien", "ancienne",
                        "très vieux", "très vieille", "des milliers d'années",
                        "depuis longtemps", "millénaire"]),
        (.modern,      ["moderne", "invention récente", "inventé récemment",
                        "une invention nouvelle", "récent", "récente"]),
        (.physical,    ["physique", "peux toucher", "peut toucher", "tangible",
                        "un objet réel", "un objet solide", "le toucher", "un objet",
                        "une chose que tu peux toucher"]),
    ]

    /// Italian trigger phrases, mirroring `map`. Most-specific-first.
    private static let mapIT: [(StarterProperty, [String])] = [
        (.everAlive,   ["mai stato vivo", "è stato vivo", "era vivo", "una volta vivo",
                        "è mai vissuto"]),
        (.alive,       ["è vivo", "è viva", "un essere vivente", "ancora vivo", "qualcosa di vivo"]),
        (.animal,      ["un animale", "una bestia", "una creatura", "un mammifero",
                        "un uccello", "un insetto", "un pesce"]),
        (.plant,       ["una pianta", "un vegetale", "un fiore"]),
        (.bodyPart,    ["parte del corpo", "una parte del corpo"]),
        (.emotion,     ["un'emozione", "una emozione", "un sentimento"]),
        (.abstractIdea,["astratto", "astratta", "un'idea", "una idea", "un concetto",
                        "intangibile", "nella mente"]),
        (.action,      ["un'azione", "una azione", "qualcosa che si fa", "qualcosa che fai",
                        "un'attività", "un verbo"]),
        (.manMade,     ["fatto dall'uomo", "fatto dagli umani", "fabbricato", "artificiale",
                        "fatto a mano", "fatto in fabbrica", "costruito da"]),
        (.inNature,    ["in natura", "allo stato selvatico", "in piena natura",
                        "nell'ambiente naturale"]),
        (.natural,     ["allo stato naturale", "in modo naturale", "naturalmente",
                        "è naturale"]),
        (.place,       ["un luogo", "un posto", "è un luogo", "una località"]),
        (.biggerThanCar,["più grande di una macchina", "più grande di un'auto",
                        "più grande di una casa", "enorme", "gigantesco",
                        "molto grande", "molto grosso", "immenso"]),
        (.smallerThanShoe,["più piccolo di una scarpa", "più piccola di una scarpa",
                        "minuscolo", "molto piccolo", "molto piccola", "più piccolo della mano"]),
        (.fitsInHand,  ["sta in una mano", "sta nella mano", "tenere in mano",
                        "nel palmo", "sta in mano"]),
        (.inKitchen,   ["cucina"]),
        (.nearWater,   ["vicino all'acqua", "nell'acqua", "sott'acqua", "in riva",
                        "intorno all'acqua"]),
        (.indoors,     ["al chiuso", "in casa", "dentro casa", "in un edificio", "all'interno"]),
        (.outdoors,    ["all'aperto", "fuori", "all'esterno"]),
        (.transport,   ["trasporto", "un veicolo", "per viaggiare", "per spostarsi",
                        "spostarsi", "salirci sopra", "salirci dentro"]),
        (.communication,["comunic", "mandare un messaggio", "per parlare", "per chattare"]),
        (.entertainment,["divertimento", "divertirsi", "per giocare", "giocarci",
                        "un passatempo", "un gioco"]),
        (.tool,        ["un attrezzo", "uno strumento", "un dispositivo", "un utensile",
                        "un apparecchio", "un'attrezzatura"]),
        (.edible,      ["si mangia", "si può mangiare", "commestibile", "si beve",
                        "si può bere", "mangiarlo", "berlo", "assaggiarlo",
                        "mangiare o bere"]),
        (.wearable,    ["si indossa", "si può indossare", "un vestito", "un indumento",
                        "un capo", "metterselo", "si porta addosso"]),
        (.canHold,     ["tenerlo", "puoi tenere", "raccoglierlo", "portarlo in",
                        "tenere in mano", "prenderlo in mano", "afferrarlo"]),
        (.metal,       ["metallo", "metallico", "di ferro", "di acciaio"]),
        (.wood,        ["di legno", "legno"]),
        (.soft,        ["morbido", "morbida", "soffice", "molle"]),
        (.liquid,      ["un liquido", "è liquido", "un fluido"]),
        (.givesLight,  ["emette luce", "fa luce", "dà luce", "brilla", "luminoso",
                        "luminosa", "illumina", "si illumina"]),
        (.makesSound,  ["fa rumore", "fa un suono", "un rumore", "puoi sentirlo",
                        "udibile", "è rumoroso", "suona"]),
        (.hasSmell,    ["un odore", "un profumo", "una fragranza", "un aroma", "puzza"]),
        (.color,       ["un colore", "di colore", "colorato", "colorata", "che colore",
                        "di che colore"]),
        (.movingParts, ["parti mobili", "parti che si muovono", "parti meccaniche"]),
        (.movesItself, ["muoversi da solo", "si muove da solo", "si muove da sé",
                        "da solo", "semovente"]),
        (.food,        ["un cibo", "un alimento", "è cibo", "un piatto", "un pasto",
                        "una pietanza"]),
        (.hot,         ["è caldo", "è calda", "molto caldo", "di solito caldo",
                        "emana calore", "caldo al tatto"]),
        (.cold,        ["è freddo", "è fredda", "molto freddo", "gelato", "gelida",
                        "ghiacciato", "freddo al tatto"]),
        (.tech,        ["tecnolog", "elettronico", "digitale", "un computer",
                        "informatica", "high-tech"]),
        (.job,         ["un lavoro", "una professione", "un mestiere", "una carriera",
                        "un impiego"]),
        (.season,      ["una stagione", "periodo dell'anno", "stagionale"]),
        (.centuriesOld,["secoli", "centinaia di anni", "antico", "antica",
                        "molto vecchio", "molto vecchia", "migliaia di anni",
                        "da tanto tempo", "millenario"]),
        (.modern,      ["moderno", "moderna", "invenzione recente", "inventato di recente",
                        "una nuova invenzione", "recente"]),
        (.physical,    ["fisico", "puoi toccare", "può toccare", "tangibile",
                        "un oggetto reale", "un oggetto solido", "toccarlo", "un oggetto",
                        "una cosa che puoi toccare"]),
    ]

    /// German trigger phrases, mirroring `map`. Most-specific-first.
    private static let mapDE: [(StarterProperty, [String])] = [
        (.everAlive,   ["jemals gelebt", "mal gelebt", "hat es gelebt", "früher gelebt",
                        "einmal lebendig", "war es lebendig"]),
        (.alive,       ["lebt es", "lebendig", "am leben", "ein lebewesen"]),
        (.animal,      ["ein tier", "eine kreatur", "ein säugetier", "ein vogel",
                        "ein insekt", "ein fisch"]),
        (.plant,       ["eine pflanze", "ein gewächs", "eine blume"]),
        (.bodyPart,    ["körperteil", "teil des körpers", "ein teil deines körpers"]),
        (.emotion,     ["eine emotion", "ein gefühl"]),
        (.abstractIdea,["abstrakt", "eine idee", "ein konzept", "ein begriff",
                        "nicht greifbar", "im kopf"]),
        (.action,      ["eine handlung", "etwas das man tut", "etwas, das man tut",
                        "eine tätigkeit", "eine aktivität", "ein verb"]),
        (.manMade,     ["von menschen gemacht", "menschengemacht", "vom menschen",
                        "hergestellt", "künstlich", "handgemacht", "in einer fabrik",
                        "gebaut von"]),
        (.inNature,    ["in der natur", "in freier wildbahn", "in der wildnis"]),
        (.natural,     ["natürlich vor", "natürlichen ursprungs", "von natur aus",
                        "ist es natürlich", "natürlicherweise"]),
        (.place,       ["ein ort", "ein platz", "eine gegend", "ein standort"]),
        (.biggerThanCar,["größer als ein auto", "größer als ein haus", "riesig",
                        "gigantisch", "sehr groß", "enorm", "gewaltig"]),
        (.smallerThanShoe,["kleiner als ein schuh", "winzig", "sehr klein",
                        "kleiner als deine hand"]),
        (.fitsInHand,  ["passt in eine hand", "passt in die hand", "in der hand halten",
                        "in die handfläche", "handlich"]),
        (.inKitchen,   ["küche"]),
        (.nearWater,   ["am wasser", "im wasser", "unter wasser", "nahe am wasser",
                        "in der nähe von wasser"]),
        (.indoors,     ["drinnen", "im haus", "in einem gebäude", "in innenräumen"]),
        (.outdoors,    ["draußen", "im freien", "unter freiem himmel"]),
        (.transport,   ["transport", "ein fahrzeug", "zum reisen", "fortbewegung",
                        "sich fortbewegen", "damit fahren", "zum fahren"]),
        (.communication,["kommuni", "eine nachricht senden", "zum reden", "zum sprechen"]),
        (.entertainment,["unterhaltung", "zum spaß", "damit spielen", "zum spielen",
                        "ein hobby", "ein spiel"]),
        (.tool,        ["ein werkzeug", "ein gerät", "ein instrument", "ein utensil",
                        "ein apparat", "eine ausrüstung"]),
        (.edible,      ["kann man essen", "essbar", "kann man trinken", "isst man",
                        "trinkt man", "es essen", "es trinken", "probieren",
                        "essen oder trinken"]),
        (.wearable,    ["kann man tragen", "trägt man", "ein kleidungsstück", "kleidung",
                        "anziehen", "am körper tragen"]),
        (.canHold,     ["halten", "hochheben", "aufheben", "in den händen",
                        "in die hand nehmen", "damit herumtragen"]),
        (.metal,       ["metall", "metallisch", "aus eisen", "aus stahl"]),
        (.wood,        ["aus holz", "holz", "hölzern"]),
        (.soft,        ["weich", "flauschig", "kuschelig"]),
        (.liquid,      ["eine flüssigkeit", "ist es flüssig", "ein fluid"]),
        (.givesLight,  ["licht ab", "gibt licht", "leuchtet", "glüht", "strahlt",
                        "beleuchtet", "leuchtend"]),
        (.makesSound,  ["ein geräusch", "macht lärm", "einen ton", "kann man es hören",
                        "hörbar", "ist es laut", "klingt"]),
        (.hasSmell,    ["einen geruch", "riecht", "ein duft", "einen duft", "aroma"]),
        (.color,       ["eine farbe", "farbig", "bunt", "welche farbe"]),
        (.movingParts, ["bewegliche teile", "teile die sich bewegen", "mechanische teile"]),
        (.movesItself, ["von selbst bewegen", "bewegt sich selbst", "von allein bewegen",
                        "aus eigener kraft", "selbstfahrend"]),
        (.food,        ["ein essen", "ein lebensmittel", "eine speise", "ein gericht",
                        "eine mahlzeit", "art essen"]),
        (.hot,         ["ist es heiß", "meist heiß", "sehr heiß", "gibt wärme ab",
                        "heiß anfühlt", "ist es warm"]),
        (.cold,        ["ist es kalt", "meist kalt", "sehr kalt", "eisig", "gefroren",
                        "kalt anfühlt"]),
        (.tech,        ["technolog", "technik", "elektronisch", "digital", "ein computer",
                        "hightech"]),
        (.job,         ["ein beruf", "ein job", "eine arbeit", "eine karriere",
                        "ein handwerk"]),
        (.season,      ["eine jahreszeit", "zeit des jahres", "saisonal"]),
        (.centuriesOld,["jahrhunderte", "hunderte von jahren", "uralt", "sehr alt",
                        "tausende von jahren", "seit langem", "jahrtausende"]),
        (.modern,      ["modern", "neue erfindung", "kürzlich erfunden",
                        "eine moderne erfindung", "neuartig"]),
        (.physical,    ["physisch", "anfassen", "berühren", "greifbar", "ein echtes objekt",
                        "ein fester gegenstand", "ein gegenstand", "ein objekt",
                        "etwas zum anfassen"]),
    ]

    /// Per-language trigger tables. Kept separate so one language's substrings
    /// can never cross-match another's. Add a language's table here when its
    /// Keeper data ships; a missing language falls back to English triggers.
    private static let maps: [GameLanguage: [(StarterProperty, [String])]] = [
        .english: map,
        .spanish: mapES,
        .french: mapFR,
        .italian: mapIT,
        .german: mapDE,
    ]

    /// Best-matching property for a free-text question in the given language,
    /// or nil if none fits.
    static func property(for question: String, language: GameLanguage) -> StarterProperty? {
        let q = question.lowercased()
        let table = maps[language] ?? map
        for (prop, triggers) in table where triggers.contains(where: { q.contains($0) }) {
            return prop
        }
        return nil
    }

    // MARK: - Replies (coy, never revealing)

    /// A short in-character flavor line that complements the verdict badge
    /// without leaking. Localized, and stable per question (same seed → same line)
    /// so a repeated question never flickers to a different reply.
    static func reply(verdict: String, seed: String, language: GameLanguage = .english) -> String {
        let bank: [String]
        switch (verdict, language) {
        case ("Yes", .spanish):     bank = ["Así es.", "En efecto.", "Correcto.", "Sí, de verdad."]
        case ("Yes", .french):      bank = ["C'est ça.", "En effet.", "Tout à fait.", "Oui, vraiment."]
        case ("Yes", .italian):     bank = ["Esatto.", "Proprio così.", "Certo.", "Sì, davvero."]
        case ("Yes", .german):      bank = ["Genau.", "In der Tat.", "Ganz recht.", "Ja, wirklich."]
        case ("Yes", _):            bank = ["That's right.", "Indeed.", "Quite so.", "Yes, truly."]

        case ("No", .spanish):      bank = ["Eso no.", "Me temo que no.", "No, no lo es.", "Para nada."]
        case ("No", .french):       bank = ["Pas ça.", "Hélas non.", "Non, ce n'est pas ça.", "Loin de là."]
        case ("No", .italian):      bank = ["Non quello.", "Temo di no.", "No, non lo è.", "Tutt'altro."]
        case ("No", .german):       bank = ["Nicht das.", "Leider nein.", "Nein, ist es nicht.", "Weit gefehlt."]
        case ("No", _):             bank = ["Not that.", "Afraid not.", "No, it isn't.", "Far from it."]

        case ("Sort of", .spanish): bank = ["Depende.", "En parte.", "En cierto modo.", "Más o menos."]
        case ("Sort of", .french):  bank = ["Ça dépend.", "En partie.", "D'une certaine façon.", "Plus ou moins."]
        case ("Sort of", .italian): bank = ["Dipende.", "In parte.", "In un certo senso.", "Più o meno."]
        case ("Sort of", .german):  bank = ["Kommt drauf an.", "Teilweise.", "In gewisser Weise.", "Mehr oder weniger."]
        case ("Sort of", _):        bank = ["It depends.", "Partly.", "In a way.", "Sort of, yes."]

        case (_, .spanish):         bank = ["Hmm.", "Quizá."]
        case (_, .french):          bank = ["Hmm.", "Peut-être."]
        case (_, .italian):         bank = ["Hmm.", "Forse."]
        case (_, .german):          bank = ["Hmm.", "Vielleicht."]
        case (_, _):                bank = ["Hmm.", "Perhaps."]
        }
        return bank[stableIndex(seed, bank.count)]
    }

    /// A generic, word-independent opening line for offline rounds. Reveals
    /// nothing about the secret (so it can't leak via selection).
    static func openingLine(seed: String) -> String {
        let lines = [
            "I've locked in today's word. Start closing in.",
            "A word is hidden — ask yes/no questions to warm up.",
            "Guess by meaning; I'll tell you hot or cold.",
            "One secret word. Ask about it, then take your shot.",
        ]
        return lines[stableIndex(seed, lines.count)]
    }

    /// Honest shrug when offline Wick can't decide a question, in the round's
    /// language. Shown without spending a question.
    private static let shrugs: [GameLanguage: String] = [
        .english: "Offline, I only know the essentials — try asking what kind of thing it is, its size, or whether it's alive.",
        .spanish: "Sin conexión solo sé lo básico. Prueba a preguntar qué tipo de cosa es, su tamaño o si está vivo.",
        .french: "Hors ligne, je ne sais que l'essentiel — demande quel genre de chose c'est, sa taille, ou si c'est vivant.",
        .italian: "Offline conosco solo l'essenziale — chiedi che tipo di cosa è, la sua dimensione, o se è vivo.",
        .german: "Offline kenne ich nur das Wichtigste – frag, was für ein Ding es ist, wie groß es ist oder ob es lebt.",
    ]

    static func shrug(_ language: GameLanguage) -> String {
        shrugs[language] ?? shrugs[.english]!
    }

    // MARK: - Helpers

    /// Deterministic, portable index from a string so replies are stable per
    /// question (no Foundation Hasher seed variance across launches).
    private static func stableIndex(_ s: String, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        var h: UInt64 = 1469598103934665603          // FNV-1a
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Int(h % UInt64(count))
    }
}
