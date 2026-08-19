# Compile the Build Registry atomically

Every listing, resolution, validation, and setup operation will compile and validate the complete Build Registry, including adapters that no target currently selects. Any malformed record, duplicate selector, invalid ownership relationship, or cross-Baseline Integration Source claim will make the registry unavailable for all targets; this accepts reduced partial availability so every caller observes one internally consistent registry rather than a target-dependent subset of repository truth.
