//
//  WordBankES.swift
//  Hunch
//
//  Spanish secret words, tiered by "nicheness" (1 = everyday … 4 = tricky),
//  frequency-vetted against the wordfreq Spanish corpus and kept concrete and
//  image-rich in the daily tiers (1–2). Mirrors WordBank (English). Words missing
//  from Apple's Spanish embedding are filtered out at selection time, so an
//  out-of-vocabulary word can never be picked.
//
//  Reuses WordBank.Entry and WordBank's language-agnostic daily-selection helpers.
//

import Foundation

enum WordBankES {

    // Everyday, concrete, high-frequency — the shared daily pool draws from tiers 1–2.
    static let tier1 = [
        "océano", "mar", "río", "lago", "playa", "montaña", "bosque", "isla", "valle", "desierto",
        "sol", "luna", "estrella", "nube", "lluvia", "nieve", "fuego", "árbol", "flor", "piedra",
        "perro", "gato", "caballo", "conejo", "animal",
        "familia", "escuela", "ciudad", "pueblo", "mercado", "iglesia", "hospital", "cocina", "jardín", "puente",
        "calle", "puerta", "ventana", "mesa", "silla", "espejo", "reloj", "teléfono", "libro", "llave",
        "pan", "queso", "leche", "huevo", "manzana", "naranja", "café", "miel", "azúcar",
        "invierno", "verano", "noche", "tren", "coche", "barco", "avión", "doctor", "maestro",
    ]

    // Evocative but familiar — still daily-eligible.
    static let tier2 = [
        "castillo", "palacio", "templo", "biblioteca", "fábrica", "faro", "molino", "fuente", "puerto", "estadio",
        "guitarra", "piano", "violín", "tambor", "cohete", "telescopio", "submarino", "helicóptero", "cámara", "bicicleta",
        "tigre", "elefante", "mono", "ballena", "delfín", "águila", "búho", "serpiente", "tortuga", "rana",
        "araña", "mariposa", "otoño", "primavera", "amanecer", "atardecer", "horizonte",
        "limón", "uva", "zanahoria", "calabaza", "cereza", "ensalada", "pastel", "helado",
        "volcán", "cascada", "cueva", "colina", "selva", "arcoíris", "tesoro", "reino", "soldado",
        "diamante", "cristal", "globo", "sombrero", "zapato", "paraguas",
    ]

    // Practice only — less common but still concrete.
    static let tier3 = [
        "brújula", "linterna", "ancla", "vela", "martillo", "escalera", "almohada", "manta", "toalla", "cuchara",
        "plato", "cuaderno", "lápiz", "botella", "cesta", "guante", "chaqueta", "mantequilla", "cometa", "eclipse",
        "brisa", "niebla", "marea", "acantilado", "arrecife", "laguna", "meseta", "pradera", "cañón", "glaciar",
        "catedral", "fortaleza", "monumento", "mansión", "orquesta", "pirámide",
    ]

    // Practice only — tricky, technical, or niche by design.
    static let tier4 = [
        "entropía", "paradoja", "sintaxis", "dialecto", "metáfora", "teorema", "ecuación", "algoritmo", "molécula",
        "electrón", "protón", "neurona", "plasma", "magma", "obsidiana", "granito", "mármol", "filamento", "turbina",
        "pistón", "péndulo", "hélice", "polímero", "fósil", "néctar", "polen", "capullo", "pergamino", "daga",
        "mosaico", "tapiz", "amuleto", "reliquia", "viñedo", "santuario",
    ]

    static let all: [WordBank.Entry] =
        tier1.map { WordBank.Entry(word: $0, tier: 1) } +
        tier2.map { WordBank.Entry(word: $0, tier: 2) } +
        tier3.map { WordBank.Entry(word: $0, tier: 3) } +
        tier4.map { WordBank.Entry(word: $0, tier: 4) }
}
