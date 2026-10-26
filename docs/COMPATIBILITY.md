# Compatibility and performance validation

No physical iPhone 17, SideStore, or LiveContainer test has been completed in the initial cloud workspace. Passing simulator tests does not establish these results.

| Scenario | Status | Evidence to record |
| --- | --- | --- |
| iPhone 17 normal signed launch | Pending device test | iOS/app/tool versions and launch log |
| SideStore install, refresh, upgrade | Pending device test | Signing method and retained watchlist |
| LiveContainer launch and guest switch/return | Pending device test | Host version, container mode, memory |
| LiveContainer browser cookies/navigation restoration | Pending device test | Login/session persistence and reload |
| Native fullscreen and PiP | Pending device test | Stream codec, PiP return, audio routing |
| Audio interruption and scene backgrounding | Pending device test | Call/headphone changes and resume policy |
| LiveContainer window resizing | Pending where host supports it | Device, host mode, smallest dimensions |
| Low memory and termination restoration | Pending device test | History and progress survival |
| VoiceOver, large text, Reduce Motion | Pending accessibility review | Focus order, clipping, contrast |
| ProMotion scrolling | Pending Instruments measurement | Hitches, frame pacing, memory/energy |

Use Instruments Time Profiler, Animation Hitches, Allocations, and Energy Log on release builds. Scroll long rows, switch tabs, open large artwork, run browser video, and switch guest apps. Record cold/warm launch and memory under pressure. Check Low Power Mode and thermal pressure. The app permits the OS to schedule higher refresh rates and does not force a constant 120 FPS. Video remains governed by AVPlayer and system frame pacing.

Persistent browser state and playback progress are best-effort checkpoints, not a guarantee that LiveContainer keeps a guest process alive. Website playback progress is not inferred. Multiwindow host behavior and PiP may be constrained by LiveContainer or the provider. No minimum frame-rate guarantee is made.
