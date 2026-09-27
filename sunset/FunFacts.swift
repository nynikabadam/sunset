//
//  FunFacts.swift
//  sunset
//
//  One fact a day. DRAFTS by Claude — cut, rewrite and fact-check before shipping.
//  The app shows one per day and keeps it all day.
//

import Foundation

enum FunFacts {
    static let all: [String] = [
        // Why sunsets look the way they do
        "Sunsets turn red and orange because the light crosses much more air near the horizon, and the air scatters away most of the blue on the way.",
        "The sky is blue for the same reason sunsets are red: air scatters short blue wavelengths far more than long red ones.",
        "High, thin clouds often glow brightest after the sun has set for you, because they're still catching sunlight from below the horizon.",
        "The best color often comes 10 to 20 minutes after sunset. It's worth staying a little longer.",
        "The deep blue of blue hour comes partly from ozone high in the atmosphere, which soaks up orange and red light.",
        "Golden hour light is soft and warm because it travels through so much atmosphere that it's diffused and filtered on the way.",
        "Hazy, humid air mutes sunset colors. Some of the most saturated sunsets come after rain has washed dust out of the air.",
        "Wildfire smoke can turn the setting sun a deep red, because smoke particles block and scatter so much of its light.",

        // Tricks of the eye and the air
        "When the sun looks like it's touching the horizon, it has actually already set. The atmosphere bends its light up so you still see it.",
        "The setting sun often looks squashed, because the air bends light from its bottom edge more than its top.",
        "The sun looks bigger near the horizon, but it isn't. It's the same size as at noon; the difference is in your brain.",
        "The sun you see setting is about 8 minutes old: that's how long its light takes to reach Earth.",
        "Crepuscular rays, the beams fanning out through gaps in clouds, are actually parallel. Perspective makes them spread out.",
        "Sometimes the beams reappear in the opposite part of the sky, converging on the horizon. These are called anticrepuscular rays.",
        "Right at the last moment of sunset, you can sometimes catch a green flash. A clear, flat horizon like the ocean gives the best chance.",

        // Look the other way
        "After sunset, look east: the dark blue band rising from the horizon is Earth's own shadow.",
        "The pink glow just above Earth's shadow has a name: the Belt of Venus.",
        "Alpenglow is the rosy light on mountains facing away from the sun, just after it sets.",

        // Where and when
        "The sun only sets due west around the equinoxes in March and September.",
        "In the Northern Hemisphere, summer sunsets drift toward the northwest and winter sunsets toward the southwest.",
        "The earliest sunset of the year isn't on the shortest day. At mid-northern latitudes it comes in early December.",
        "Likewise, the latest sunsets of the year come in late June, just after the longest day.",
        "Near the equator, the sun drops almost straight down and disappears in about two minutes. Farther from it, the sun sets at a slant and lingers.",
        "The sun moves across the sky by about its own width every two minutes.",
        "Civil twilight ends when the sun is 6° below the horizon, roughly when you'd need a light to read outside.",
        "In Tromsø, Norway, the sun doesn't set at all from about late May to late July.",

        // History and elsewhere
        "\"Red sky at night, sailor's delight\": weather usually moves west to east in mid-latitudes, so a red western sky hints at clear air on the way.",
        "After Krakatoa erupted in 1883, its ash made sunsets vivid around the world for months.",
        "Sunsets on Mars are blue. Fine dust there scatters blue light toward the sun.",
        "On the Moon there's no air to scatter light, so the sun simply drops out of a black sky.",
        "Astronauts on the International Space Station see about 16 sunsets a day.",
    ]

    /// Today's fact: the same all day, a different one each day.
    static func fact(for date: Date = .now) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
