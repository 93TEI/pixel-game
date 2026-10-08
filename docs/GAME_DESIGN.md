# Monster Trail — accepted design, 2026-10-06

## Product contract
Native Windows/macOS, offline single player, Korean UI. Cozy original monster RPG.
200 species INCLUDING evolutions; no palette-swap counting. 40 three-stage families,
30 two-stage families, 20 independent species. Eight regions and a final region.
15–20h campaign target is a playtest requirement, not a measured achievement.
Almost no quests: short onboarding, then explore/capture/train/defeat boss/open road.
One industrial town; other regions warm natural fantasy with ecological mysteries.

## Control and combat
WASD move trainer, LMB designate enemy, RMB recall, 1–6 switch, E interact, F capture,
Tab party/bag, J journal, M map, Escape pause. One active companion, six party slots.
Trainer takes no damage and cannot body-block enemies. All battle is real time.
Basic attack is independent of 1–4 automatic moves. Moves have windup, cooldown,
range, power and effect. One cast at a time; player controls priority and enablement.
Cooldown starts on successful activation; canceled windup deals no damage.
Switch cancels casts, has 3s global cooldown and does not reset existing cooldowns.
Bag, journal, information and settings pause simulation. Six fainted means defeat:
return to town, heal, lose 5% currency, never lose monsters.

## Capture and progression
Weaken living wild monsters and throw a consumable capture tool. Show chance.
Probability uses species catch rate, remaining HP and tool grade. Suppress companion
attacks during the capture action. Bosses and trainer-owned monsters cannot be caught.
Defeated wild boss species become obtainable in post-boss habitats.
Full party sends captures to storage. Town-only storage access, filtering/sorting.
Individuals are rolled once when spawned: persistent id, seed, IVs and move branches.
Capturing, saving, reloading, evolving never rerolls those properties.

Species rank: D/C/B/A/S, move slots 1/2/3/4/4. Base stats and skill power budgets
increase with rank. IV appraisal is a separate 0–100 score. Six stats: HP/ATK/DEF/
SPATK/SPDEF/SPD, IVs 0–31, approximately 10% maximum within-species difference.
No rank upgrades, IV training, reroll items or move reroll machines.
Evolution changes species, preserves IVs, maps existing moves along authored
branches, deterministically fills new slots; evolution never reduces slots.
Level cap 50. Active XP 100%, surviving reserves 70%. Ordinary-IV parties must be
able to finish. Perfect rolls are optional collecting goals.

## World and art
Regions: 새봄18 / 물버들20 / 솔바람22 / 적토22 / 톱니24 / 등불24 / 눈마루24 /
별마루26 / 첫숲20 = 200 distinct dex entries. Each region: town, two main fields,
one optional field, boss arena. Bosses alternate trainers and wild guardians.
Boss victories open next route and shortcuts. Final victory opens rematches.
All visual creation and review must follow [DESIGN_AGENT.md](../DESIGN_AGENT.md).
2026-10-07: All previous game artwork/studies were deleted at the user's request.
Visual specifications and production/review workflow live only in that agent file.
Existing renderer dimensions are implementation history, not an approved art target.
Each species gets ecological lore, silhouette, behavioral identity and cross-family
links; final lore target 150–300 Korean characters. Asset metadata must truthfully
distinguish missing, draft, integrated and approved artwork.

## Technical and delivery
Godot 4.7.2 stable/GDScript/Compatibility, no external runtime services.
Permanent string content IDs. Versioned three-slot saves, atomic replacement and
last-good backup. Save on capture/boss/town; manual save in safety; combat resume at
safe point. Current region/party textures only. Spatial broad phase; AI 10Hz and
combat 60Hz. Reuse effects, bounded emitters, streamed music.
Targets NOT guarantees: 60fps, <=512MiB RSS, <=300MiB compressed per-platform build.
Benchmark Intel UHD620/8GB and Apple M1/8GB before publishing minimum specs.
Titles: 30 cosmetic-only titles AFTER core content completed. Collect event counters
early to award retroactively. No farming, multiplayer, breeding, cash shop in v1.
Code MIT, original art separate retained-rights license. Credit Godot and asset sources.

## Milestones
0 accepted docs + full 200-species authored catalog + visual gate defined in DESIGN_AGENT.md.
1 movement, follow, commands, autocast, swap, capture, immutable rolls, save.
2 finished first town/18 species/boss/UI/audio; 30–45min playtest.
3 all 200 species + all regions, evolution, storage, final boss and postgame.
4 cosmetic title system after content gate. 5 exports, performance, GitHub delivery.
Never label these complete solely because scaffolding or data records exist.
