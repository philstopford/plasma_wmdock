// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMViz – Audio spectrum visualizer backed by CAVA (via AudioSpectrum).
 *
 * Eighteen MilkDrop-inspired effects driven by real spectral data:
 *
 *   bars      – classic spectrum analyser with per-bar peak markers
 *   wave      – radial scope: 16 bands plotted as a rotating petal blob
 *   circles   – starfield: per-band particles fired in radial directions
 *   plasma    – tunnel:    concentric circles zooming from centre
 *   terrain   – pseudo-3D spectral landscape flyover scrolling toward viewer
 *   vortex    – wormhole fly-through: first-person tunnel with perspective rings
 *   warp      – 16 glowing radial beams (one per band) shooting from centre
 *   ripple    – concentric ripples fired on beats and bass transients
 *   kaleid    – 6-fold kaleidoscope of radial spectrum wedges
 *   nova      – afterglow bloom: persistence-of-vision comet trails
 *   galaxy    – rotating logarithmic spiral galaxy
 *   aurora    – 8 flowing northern-lights curtains
 *   mandala   – 12/8/6-fold geometric mandala with counter-rotating petal layers
 *   led       – retro LED segment VU meter: stacked dot columns, green→red
 *   discharge – plasma discharge tubes: glowing branching arcs between nodes
 *   lightning – branching storm bolts from the top, recursive fractal tree
 *   concert   – sweeping spotlight beams from the floor, coloured by band
 *   pyro      – fireworks: shells rise then burst into radial particle sprays
 *
 * Effects can be cycled with the mouse wheel or selected from a right-click
 * context menu.  All effects react to beat transients (white flash).
 */
Item {
    id: root

    // ----- configuration ---------------------------------------------------
    readonly property string effect:           Plasmoid.configuration.effect      || "bars"
    readonly property string colorScheme:      Plasmoid.configuration.colorScheme || "green"
    readonly property bool   terrainRotate:    Plasmoid.configuration.terrainRotate    || false
    readonly property bool   terrainWireframe: Plasmoid.configuration.terrainWireframe || false

    // ----- colour helpers (CSS strings – required for Canvas fillStyle) -----
    function schemeColorCss(t) {
        switch (root.colorScheme) {
        case "blue":
            return "hsl(" + Math.round((0.58 + t * 0.05) * 360) + ",90%,"
                          + Math.round((0.3  + t * 0.4)  * 100) + "%)"
        case "amber":
            return "hsl(" + Math.round((0.10 + t * 0.03) * 360) + ",100%,"
                          + Math.round((0.2  + t * 0.45) * 100) + "%)"
        case "rainbow":
            return "hsl(" + Math.round(t * 0.75 * 360) + ",100%,"
                          + Math.round((0.35 + t * 0.2)  * 100) + "%)"
        default: // green
            return "hsl(" + Math.round((0.33 - t * 0.08) * 360) + ",100%,"
                          + Math.round((0.15 + t * 0.4)  * 100) + "%)"
        }
    }

    // Convert "hsl(...)" to "hsla(..., alpha)"
    function withAlpha(hslStr, alpha) {
        if (hslStr.length > 4 && hslStr.startsWith("hsl("))
            return "hsla(" + hslStr.slice(4, -1) + "," + alpha.toFixed(2) + ")"
        return hslStr
    }

    // ----- shared per-frame state ------------------------------------------
    property var  bandVals:  []         // current 16-band values 0-1
    property real rms:       0          // overall loudness 0-1
    property real bass:      0          // low-freq energy 0-1
    property real treble:    0          // high-freq energy 0-1
    property real beatFlash: 0          // decays to 0 after each beat
    property bool gotBeat:   false      // true for exactly one tick on beat
    property int  tickCount: 0

    // ----- tuning constants -------------------------------------------------
    readonly property real signalDecay:        0.88  // per-frame decay when unavailable
    readonly property real particleLifeDecay:  0.028 // life lost per tick (~35 ticks = 1.4 s)
    readonly property real particleSpawnThresh:0.08  // minimum band energy to spawn
    readonly property real particleSpawnProb:  0.4   // probability multiplier per band
    readonly property int  numBands:           16    // CAVA band count

    // ----- bars state -------------------------------------------------------
    property var peakBands: []

    // ----- scope (wave) state -----------------------------------------------
    property real wavePhase: 0

    // ----- starfield (circles) state ----------------------------------------
    property var stars: []

    // ----- tunnel (plasma) state --------------------------------------------
    property var tunnelRings: []

    // ----- terrain state ----------------------------------------------------
    // Each entry is a snapshot of 16 band values; index 0 = newest (nearest).
    property var terrainHistory: []
    readonly property int terrainMaxRows: 24

    // ----- vortex state -----------------------------------------------------
    property real vortexAngle:   0
    property real vortexDriftX:  0   // tunnel centreline pitch/yaw fraction (−1..1)
    property real vortexDriftY:  0
    property real vortexRoll:    0   // camera banking (roll about tunnel axis)
    property real vortexTravelZ: 0   // z-travel fraction [0,1); cycles each full fly-through

    // ----- warp state -------------------------------------------------------
    // Per-band beam length in 0-1; each beam immediately jumps up when its
    // band energy rises and then decays exponentially.
    property var warpLengths: []

    // ----- terrain rotation state -------------------------------------------
    property real terrainRotAngle: 0

    // ----- ripple state -----------------------------------------------------
    property var ripples: []

    // ----- kaleidoscope state -----------------------------------------------
    property real kaleidPhase: 0

    // ----- nova (afterglow bloom) state -------------------------------------
    property var  novaParticles: []

    // ----- galaxy (rotating spiral) state -----------------------------------
    property real galaxyAngle: 0
    property var  galaxyStars: []

    // ----- aurora (northern lights) state -----------------------------------
    property real auroraTime: 0

    // ----- mandala (multi-layer geometric) state ----------------------------
    property real mandalaPhase: 0

    // ----- LED meter state --------------------------------------------------
    // (reuses peakBands from bars effect — no extra state needed)

    // ----- discharge state --------------------------------------------------
    // Each arc: { x1,y1, x2,y2, jitter:[], energy, hue }
    property var dischargeArcs: []
    property real dischargeTime: 0

    // ----- lightning state --------------------------------------------------
    // Each bolt: { segs:[{x1,y1,x2,y2}], flash, hue }
    property var lightningBolts: []
    property real lightningCooldown: 0

    // ----- concert state ----------------------------------------------------
    // Each beam: { angle, speed, hue, width, energy }
    property var concertBeams: []
    property real concertTime: 0

    // ----- pyro state -------------------------------------------------------
    // Shells: { x, y, vy, hue, phase } — rise until vy>0 (gravity)
    // Particles: { x, y, vx, vy, life, hue, size }
    property var pyroShells: []
    property var pyroParticles: []

    // ----- ordered effects list (for wheel cycling) -------------------------
    readonly property var effectOrder: [
        "bars","wave","circles","plasma","terrain","vortex","warp",
        "ripple","kaleid","nova","galaxy","aurora","mandala",
        "led","discharge","lightning","concert","pyro"
    ]

    Component.onCompleted: {
        peakBands   = new Array(numBands).fill(0)
        bandVals    = new Array(numBands).fill(0)
        warpLengths = new Array(numBands).fill(0)

        // Build the galaxy star field once at startup so positions are fixed
        // and per-frame rendering only needs to rotate and draw.
        const ARMS          = 2
        const STARS_PER_ARM = 280
        const HALO_STARS    = 140
        let gs = []
        for (let arm = 0; arm < ARMS; arm++) {
            for (let s = 0; s < STARS_PER_ARM; s++) {
                const t = s / STARS_PER_ARM
                const theta = t * 4.5 * Math.PI
                // Scatter: more spread toward the outer rim
                const scat = (Math.random() - 0.5) * 0.18 * Math.sqrt(t + 0.05)
                gs.push({
                    r:        Math.sqrt(t) * 0.88 + scat,
                    theta:    theta + arm * Math.PI + (Math.random() - 0.5) * 0.38,
                    hue:      t * 0.65 + Math.random() * 0.15,
                    size:     0.6 + Math.random() * 1.2 * (1.0 - t * 0.55),
                    bandBias: Math.floor(t * 16) % 16
                })
            }
        }
        // Scattered halo stars not on any arm
        for (let i = 0; i < HALO_STARS; i++) {
            gs.push({
                r:        0.20 + Math.random() * 0.80,
                theta:    Math.random() * 2 * Math.PI,
                hue:      Math.random(),
                size:     0.5,
                bandBias: Math.floor(Math.random() * 16)
            })
        }
        galaxyStars = gs
    }

    // ----- beat → flash ------------------------------------------------------
    Connections {
        target: AudioSpectrum
        function onBeatChanged() {
            if (AudioSpectrum.beat) {
                root.gotBeat   = true
                root.beatFlash = 1.0
            }
        }
    }

    // ----- animation ticker --------------------------------------------------
    Timer {
        interval: 40     // ~25 fps
        repeat:   true
        running:  true
        onTriggered: {
            root.tickCount++

            // Refresh spectrum snapshot
            if (AudioSpectrum.available) {
                root.bandVals = Array.from(AudioSpectrum.bands)
                root.rms    = AudioSpectrum.rms
                root.bass   = AudioSpectrum.bass
                root.treble = AudioSpectrum.treble
            } else {
                root.bandVals = root.bandVals.map(v => v * root.signalDecay)
                root.rms    = root.rms    * root.signalDecay
                root.bass   = root.bass   * root.signalDecay
                root.treble = root.treble * root.signalDecay
            }

            root.beatFlash = Math.max(0, root.beatFlash - 0.12)

            switch (root.effect) {
            case "wave":      tickScope();      break
            case "circles":   tickStars();      break
            case "plasma":    tickTunnel();     break
            case "terrain":   tickTerrain();    break
            case "vortex":    tickVortex();     break
            case "warp":      tickWarp();       break
            case "ripple":    tickRipple();     break
            case "kaleid":    tickKaleid();     break
            case "nova":      tickNova();       break
            case "galaxy":    tickGalaxy();     break
            case "aurora":    tickAurora();     break
            case "mandala":   tickMandala();    break
            case "led":       tickBars();       break  // LED meter uses same peak-hold logic as bars
            case "discharge": tickDischarge();  break
            case "lightning": tickLightning();  break
            case "concert":   tickConcert();    break
            case "pyro":      tickPyro();       break
            default:          tickBars();       break
            }

            root.gotBeat = false   // consumed by tick functions above

            canvas.requestPaint()
        }
    }

    // ----- bars tick ---------------------------------------------------------
    function tickBars() {
        const bands = root.bandVals
        const N = 16
        if (!bands || bands.length < N) return
        let peaks = root.peakBands.length === N ? root.peakBands.slice() : new Array(N).fill(0)
        for (let i = 0; i < N; i++) {
            const v = bands[i] || 0
            if (v > peaks[i]) peaks[i] = v
            else              peaks[i] = Math.max(0, peaks[i] - 0.007)
        }
        root.peakBands = peaks
    }

    // ----- scope (wave) tick -------------------------------------------------
    function tickScope() {
        root.wavePhase = (root.wavePhase + 0.025) % (2 * Math.PI)
    }

    // ----- starfield (circles) tick ------------------------------------------
    function tickStars() {
        const cx       = canvas.width  / 2
        const cy       = canvas.height / 2
        const maxSpeed = Math.min(cx, cy) * 0.09
        const bands    = root.bandVals

        // Advance existing particles
        let active = []
        for (let i = 0; i < root.stars.length; i++) {
            const s  = root.stars[i]
            const nl = s.life - root.particleLifeDecay
            if (nl > 0)
                active.push({ x: s.x + s.vx, y: s.y + s.vy,
                             vx: s.vx, vy: s.vy, life: nl, hue: s.hue })
        }

        // Spawn per-band particles (each band fires in its own radial direction)
        if (active.length < 80) {
            for (let i = 0; i < 16; i++) {
                const v = bands[i] || 0
                if (v > root.particleSpawnThresh && Math.random() < v * root.particleSpawnProb) {
                    const angle = 2 * Math.PI * i / 16
                    const speed = v * maxSpeed
                    active.push({ x: cx, y: cy,
                                 vx: Math.cos(angle) * speed,
                                 vy: Math.sin(angle) * speed,
                                 life: 1.0, hue: i / 16 })
                }
            }
        }

        // Beat burst – random spray with bass-scaled velocity
        if (root.gotBeat && active.length < 70) {
            for (let j = 0; j < 10; j++) {
                const angle = Math.random() * 2 * Math.PI
                const speed = (root.bass * 0.6 + 0.2) * maxSpeed * 1.5
                active.push({ x: cx, y: cy,
                             vx: Math.cos(angle) * speed,
                             vy: Math.sin(angle) * speed,
                             life: 1.0, hue: root.treble })
            }
        }

        root.stars = active
    }

    // ----- tunnel (plasma) tick ----------------------------------------------
    function tickTunnel() {
        const speed = root.bass * 0.08 + 0.012

        let rings = root.tunnelRings
                .map(r => ({ scale: r.scale + speed, hue: r.hue }))
                .filter(r => r.scale < 1.8)

        // Spawn a new ring at the centre whenever the gap is large enough
        const frontScale = rings.length > 0 ? rings[0].scale : 9
        if (frontScale > speed * 5)
            rings.unshift({ scale: 0, hue: root.treble })

        root.tunnelRings = rings
    }

    // ----- terrain tick -------------------------------------------------------
    function tickTerrain() {
        const snap = (root.bandVals && root.bandVals.length === root.numBands)
                     ? root.bandVals.slice() : new Array(root.numBands).fill(0)
        // Mutate in place to avoid creating a new array every frame.
        let hist = root.terrainHistory
        hist.unshift(snap)
        if (hist.length > root.terrainMaxRows)
            hist.pop()
        root.terrainHistory = hist

        // Optional rotating viewpoint: speed proportional to treble + beat kick
        if (root.terrainRotate) {
            const rotSpeed = 0.003 + root.treble * 0.012 + (root.gotBeat ? 0.08 : 0)
            root.terrainRotAngle = (root.terrainRotAngle + rotSpeed) % (2 * Math.PI)
        }
    }

    // ----- vortex tick --------------------------------------------------------
    function tickVortex() {
        // Primary tunnel spin speed (drives twist / helix accumulation)
        const rotSpeed = 0.018 + root.rms * 0.045 + (root.gotBeat ? 0.14 : 0)
        root.vortexAngle = root.vortexAngle + rotSpeed

        // Banking (camera roll): continuous slow roll, kicked by bass transients
        const rollSpeed = 0.003 + root.bass * 0.018 + (root.gotBeat ? 0.09 : 0)
        root.vortexRoll = root.vortexRoll + rollSpeed

        // Forward travel through tunnel: advances all ring depths toward viewer
        const travelSpeed = 0.009 + root.rms * 0.014
        root.vortexTravelZ = (root.vortexTravelZ + travelSpeed) % 1.0

        // Pitch / yaw Lissajous drives tunnel centreline curvature (turning/winding)
        const driftAmp = Math.min(0.35, root.treble * 0.32 + root.bass * 0.10)
        root.vortexDriftX = root.vortexDriftX * 0.94
                            + Math.sin(root.vortexAngle * 1.7) * driftAmp
        root.vortexDriftY = root.vortexDriftY * 0.94
                            + Math.cos(root.vortexAngle * 2.3) * driftAmp * 0.65
    }

    // ----- warp tick ----------------------------------------------------------
    function tickWarp() {
        const bands     = root.bandVals
        const decayRate = 0.90
        const boom      = root.gotBeat ? 1.5 : 1.0
        // Reuse the existing array when possible; only allocate on first call.
        let lens = root.warpLengths
        if (lens.length !== root.numBands)
            lens = new Array(root.numBands).fill(0)
        for (let i = 0; i < root.numBands; i++) {
            const target = Math.min(1, (bands[i] || 0) * (1 + root.bass * 0.8) * boom)
            lens[i] = Math.max(target, lens[i] * decayRate)
        }
        root.warpLengths = lens
    }

    // ----- ripple tick --------------------------------------------------------
    function tickRipple() {
        const maxR = Math.min(canvas.width, canvas.height) * 0.80
        const speed = 0.9 + root.bass * 1.8

        // Advance existing ripples
        let active = []
        for (let i = 0; i < root.ripples.length; i++) {
            const rp = root.ripples[i]
            const nr = rp.radius + speed
            const ne = rp.energy * 0.96
            if (nr < maxR && ne > 0.02)
                active.push({ radius: nr, energy: ne, hue: rp.hue })
        }

        // Large ripple on beat or strong bass transient
        if ((root.gotBeat || root.bass > 0.55) && active.length < 8)
            active.push({ radius: 2, energy: 0.65 + root.bass * 0.35, hue: root.treble })

        // Steady smaller ripples driven by RMS
        if (root.rms > 0.08 && active.length < 6 && (root.tickCount % 6 === 0))
            active.push({ radius: 2, energy: root.rms * 0.45, hue: root.treble * 0.6 })

        root.ripples = active
    }

    // ----- kaleidoscope tick --------------------------------------------------
    function tickKaleid() {
        const rotSpeed = 0.007 + root.rms * 0.025 + (root.gotBeat ? 0.18 : 0)
        root.kaleidPhase = (root.kaleidPhase + rotSpeed) % (2 * Math.PI)
    }

    // ----- nova tick ----------------------------------------------------------
    function tickNova() {
        const cx       = canvas.width  / 2
        const cy       = canvas.height / 2
        const maxSpeed = Math.min(cx, cy) * 0.14
        const bands    = root.bandVals

        // Advance and decay existing particles
        let alive = []
        for (let i = 0; i < root.novaParticles.length; i++) {
            const p  = root.novaParticles[i]
            const nl = p.life - (p.tracer ? 0.009 : 0.021)
            if (nl > 0)
                alive.push({ x: p.x + p.vx, y: p.y + p.vy,
                            vx: p.vx * 0.97, vy: p.vy * 0.97,
                            life: nl, hue: p.hue, size: p.size, tracer: p.tracer })
        }

        // Continuous per-band emission in each band's radial direction
        if (alive.length < 300) {
            for (let i = 0; i < 16; i++) {
                const v = bands[i] || 0
                if (v > 0.08 && Math.random() < v * 0.55) {
                    const angle = 2 * Math.PI * i / 16 + (Math.random() - 0.5) * 0.70
                    const speed = v * maxSpeed * (0.4 + root.rms * 0.9)
                    alive.push({ x: cx, y: cy,
                                vx: Math.cos(angle) * speed,
                                vy: Math.sin(angle) * speed,
                                life: 0.6 + Math.random() * 0.4,
                                hue: i / 16, size: 1.2 + v * 2.5, tracer: false })
                }
            }
        }

        // Beat burst: 130 particles, first 24 are slow long-lived "tracers"
        if (root.gotBeat) {
            for (let j = 0; j < 130; j++) {
                const angle  = Math.random() * 2 * Math.PI
                const tracer = j < 24
                const speed  = (0.35 + root.bass * 0.75 + Math.random() * 0.30) * maxSpeed
                               * (tracer ? 0.35 : 1.0)
                alive.push({ x: cx, y: cy,
                            vx: Math.cos(angle) * speed,
                            vy: Math.sin(angle) * speed,
                            life: tracer ? 1.0 : 0.70 + Math.random() * 0.30,
                            hue:  root.treble * 0.4 + Math.random() * 0.6,
                            size: tracer ? 2.5 + Math.random() * 1.5
                                        : 1.2 + Math.random() * 2.2,
                            tracer: tracer })
            }
        }

        if (alive.length > 450)
            alive = alive.slice(alive.length - 450)

        root.novaParticles = alive
    }

    // ----- galaxy tick --------------------------------------------------------
    function tickGalaxy() {
        const speed = 0.003 + root.treble * 0.012 + (root.gotBeat ? 0.05 : 0)
        root.galaxyAngle = (root.galaxyAngle + speed) % (2 * Math.PI)
    }

    // ----- aurora tick --------------------------------------------------------
    function tickAurora() {
        const speed = 0.010 + root.rms * 0.022 + (root.gotBeat ? 0.07 : 0)
        root.auroraTime  = root.auroraTime + speed
    }

    // ----- mandala tick -------------------------------------------------------
    function tickMandala() {
        const speed = 0.006 + root.rms * 0.022 + (root.gotBeat ? 0.14 : 0)
        root.mandalaPhase = (root.mandalaPhase + speed) % (2 * Math.PI)
    }

    // ----- LED meter tick ---------------------------------------------------
    // LED meter reuses tickBars for peak-hold state — see switch statement.

    // ----- discharge tick ---------------------------------------------------
    function tickDischarge() {
        const w = canvas.width  > 4 ? canvas.width  : 64
        const h = canvas.height > 4 ? canvas.height : 64
        root.dischargeTime += 0.07 + root.rms * 0.12
        const N = 6  // simultaneous arcs
        let arcs = root.dischargeArcs.length === N ? root.dischargeArcs.slice() : []

        // Fixed anchor points: top/bottom nodes spaced across canvas
        const nodes = []
        for (let i = 0; i < 3; i++) {
            nodes.push({ x: (i + 0.5) * w / 3, y: h * 0.05 })  // top row
            nodes.push({ x: (i + 0.5) * w / 3, y: h * 0.95 })  // bottom row
        }

        while (arcs.length < N) {
            const n1 = Math.floor(Math.random() * nodes.length)
            let   n2 = Math.floor(Math.random() * nodes.length)
            if (n2 === n1) n2 = (n1 + 1) % nodes.length
            const SEGS = 8 + Math.floor(Math.random() * 6)
            const jitter = []
            for (let s = 0; s <= SEGS; s++) jitter.push((Math.random() - 0.5) * w * 0.22)
            const bandIdx = Math.floor(Math.random() * 16)
            arcs.push({ x1: nodes[n1].x, y1: nodes[n1].y,
                        x2: nodes[n2].x, y2: nodes[n2].y,
                        jitter: jitter, segs: SEGS,
                        energy: 0.4 + (root.bandVals[bandIdx] || 0) * 0.6,
                        hue: 0.55 + Math.random() * 0.25,
                        life: 0.6 + Math.random() * 0.8 })
        }

        // Age arcs; rejitter active ones on every tick for the flickering look
        let live = []
        for (let i = 0; i < arcs.length; i++) {
            const a = Object.assign({}, arcs[i])
            a.life -= 0.055 + root.rms * 0.04
            if (a.life <= 0) continue
            const bandIdx = Math.floor(Math.random() * 16)
            a.energy = Math.max(0.2, 0.4 + (root.bandVals[bandIdx] || 0) * 0.6)
            // Re-jitter the mid-points each tick
            for (let s = 1; s < a.segs; s++)
                a.jitter[s] += (Math.random() - 0.5) * w * 0.08
            live.push(a)
        }
        root.dischargeArcs = live
    }

    // ----- lightning tick ---------------------------------------------------
    // Spawns a new fractal bolt on strong bass beats; bolts decay quickly.
    function tickLightning() {
        const w = canvas.width  > 4 ? canvas.width  : 64
        const h = canvas.height > 4 ? canvas.height : 64
        root.lightningCooldown = Math.max(0, root.lightningCooldown - 1)

        // Decay existing bolts
        let bolts = root.lightningBolts.map(b => Object.assign({}, b))
        bolts = bolts.filter(b => { b.flash -= 0.08; return b.flash > 0 })

        // Spawn on bass beat
        if (root.gotBeat && root.bass > 0.4 && root.lightningCooldown === 0) {
            root.lightningCooldown = 6
            const startX = w * (0.25 + Math.random() * 0.5)
            const segs = []
            // Build the bolt via recursive subdivision
            function subdivide(x1, y1, x2, y2, depth, maxOffset) {
                if (depth === 0) { segs.push({ x1, y1, x2, y2 }); return }
                const mx = (x1 + x2) / 2 + (Math.random() - 0.5) * maxOffset
                const my = (y1 + y2) / 2 + (Math.random() - 0.5) * maxOffset * 0.4
                subdivide(x1, y1, mx, my, depth - 1, maxOffset * 0.55)
                subdivide(mx, my, x2, y2, depth - 1, maxOffset * 0.55)
                // Branch
                if (depth >= 2 && Math.random() < 0.45) {
                    const bx = mx + (Math.random() - 0.5) * w * 0.3
                    const by = my + h * (0.15 + Math.random() * 0.15)
                    subdivide(mx, my, bx, by, depth - 2, maxOffset * 0.4)
                }
            }
            subdivide(startX, 0, startX + (Math.random() - 0.5) * w * 0.5, h, 4, w * 0.28)
            bolts.push({ segs: segs, flash: 1.0 + root.bass * 0.5,
                         hue: 0.60 + root.treble * 0.15 })
        }

        root.lightningBolts = bolts
    }

    // ----- concert tick -----------------------------------------------------
    function tickConcert() {
        root.concertTime += 0.025 + root.rms * 0.06
        const N = 8  // number of spotlight beams
        let beams = root.concertBeams

        // Initialise beams
        if (beams.length !== N) {
            beams = []
            for (let i = 0; i < N; i++) {
                beams.push({ angle: -1.2 + (i / (N - 1)) * 2.4,
                             speed: (Math.random() < 0.5 ? 1 : -1) * (0.008 + Math.random() * 0.016),
                             hue:   i / N,
                             width: 0.10 + Math.random() * 0.08,
                             energy: 0 })
            }
        }

        beams = beams.map((b, i) => {
            const bb = Object.assign({}, b)
            const bandIdx = (i * 2) % 16
            bb.energy = (root.bandVals[bandIdx] || 0) * 0.6 + bb.energy * 0.4
            bb.angle  += bb.speed * (1 + root.bass * 1.5)
            if (bb.angle > 1.5 || bb.angle < -1.5) bb.speed = -bb.speed
            return bb
        })

        root.concertBeams = beams
    }

    // ----- pyro tick --------------------------------------------------------
    function tickPyro() {
        const w = canvas.width  > 4 ? canvas.width  : 64
        const h = canvas.height > 4 ? canvas.height : 64
        const GRAVITY = 0.045

        // Age particles
        let parts = root.pyroParticles.map(p => {
            const pp = Object.assign({}, p)
            pp.x    += pp.vx
            pp.y    += pp.vy
            pp.vy   += GRAVITY
            pp.life -= 0.022 + Math.random() * 0.008
            return pp
        }).filter(p => p.life > 0)

        // Age shells; burst when rising velocity reverses (apex)
        let shells = root.pyroShells.map(s => {
            const ss = Object.assign({}, s)
            ss.x  += ss.vx
            ss.y  += ss.vy
            ss.vy += GRAVITY
            return ss
        }).filter(s => {
            if (s.vy >= 0) {
                // Burst at apex
                const N = 28 + Math.floor(Math.random() * 20)
                for (let i = 0; i < N; i++) {
                    const ang   = (i / N) * 2 * Math.PI + (Math.random() - 0.5) * 0.3
                    const speed = 0.8 + Math.random() * 0.8
                    parts.push({ x: s.x, y: s.y,
                                 vx: Math.cos(ang) * speed,
                                 vy: Math.sin(ang) * speed - 0.5,
                                 life: 0.7 + Math.random() * 0.5,
                                 hue: s.hue + (Math.random() - 0.5) * 0.08,
                                 size: 1.0 + Math.random() })
                }
                return false
            }
            return s.y > -h * 0.1 // discard off-canvas
        })

        // Spawn new shells
        const launchProb = 0.05 + root.bass * 0.25 + (root.gotBeat ? 0.5 : 0)
        if (Math.random() < launchProb && shells.length < 8) {
            shells.push({ x: w * (0.15 + Math.random() * 0.70),
                          y: h,
                          vx: (Math.random() - 0.5) * 0.8,
                          vy: -(2.2 + Math.random() * 1.8 + root.bass * 1.5),
                          hue: Math.random() })
        }

        if (parts.length  > 500) parts  = parts.slice(parts.length  - 500)
        root.pyroShells    = shells
        root.pyroParticles = parts
    }

    // ----- background -------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#1a1a1a"
        border.width: 1
    }

    // ----- main canvas ------------------------------------------------------
    Canvas {
        id: canvas
        anchors { fill: parent; margins: 3 }
        renderTarget: Canvas.Image

        onWidthChanged:  Qt.callLater(requestPaint)
        onHeightChanged: Qt.callLater(requestPaint)

        Component.onCompleted: Qt.callLater(requestPaint)

        onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return
            // Nova uses a persistence-fade overlay for comet trails; it clears itself.
            // All other effects need a clean canvas each frame.
            if (root.effect !== "nova")
                ctx.clearRect(0, 0, width, height)

            switch (root.effect) {
            case "wave":      paintScope(ctx);      break
            case "circles":   paintStars(ctx);      break
            case "plasma":    paintTunnel(ctx);     break
            case "terrain":   paintTerrain(ctx);    break
            case "vortex":    paintVortex(ctx);     break
            case "warp":      paintWarp(ctx);       break
            case "ripple":    paintRipple(ctx);     break
            case "kaleid":    paintKaleid(ctx);     break
            case "nova":      paintNova(ctx);       break
            case "galaxy":    paintGalaxy(ctx);     break
            case "aurora":    paintAurora(ctx);     break
            case "mandala":   paintMandala(ctx);    break
            case "led":       paintLed(ctx);        break
            case "discharge": paintDischarge(ctx);  break
            case "lightning": paintLightning(ctx);  break
            case "concert":   paintConcert(ctx);    break
            case "pyro":      paintPyro(ctx);       break
            default:          paintBars(ctx);       break
            }

            // Beat flash overlay (all effects)
            if (root.beatFlash > 0.01) {
                ctx.fillStyle = "rgba(255,255,255," + (root.beatFlash * 0.25).toFixed(2) + ")"
                ctx.fillRect(0, 0, width, height)
            }
        }

        // ---- bars -----------------------------------------------------------
        function paintBars(ctx) {
            const w = width, h = height
            const N = 16
            const bands = root.bandVals
            const peaks = root.peakBands
            if (!bands || bands.length < N) return

            const bw = (w - N + 1) / N

            for (let i = 0; i < N; i++) {
                const frac = bands[i] || 0
                const barH = Math.max(1, frac * h)
                ctx.fillStyle = root.schemeColorCss(frac)
                ctx.fillRect(Math.round(i * (bw + 1)), h - barH,
                            Math.max(1, Math.floor(bw)), barH)

                // Per-bar peak marker
                if (peaks && i < peaks.length) {
                    const peakH = peaks[i] * h
                    if (peakH > 2) {
                        ctx.fillStyle = "#ffffff"
                        ctx.fillRect(Math.round(i * (bw + 1)), h - peakH,
                                    Math.max(1, Math.floor(bw)), 1)
                    }
                }
            }
        }

        // ---- scope (radial waveform) -----------------------------------------
        function paintScope(ctx) {
            const w = width, h = height
            const cx = w / 2, cy = h / 2
            const N  = 16
            const bands = root.bandVals
            if (!bands || bands.length < N) return

            const innerR = Math.min(cx, cy) * 0.18
            const outerR = Math.min(cx, cy) * 0.82
            const rangeR = outerR - innerR

            // Draw closed polygon through band points arranged radially
            ctx.beginPath()
            for (let i = 0; i <= N; i++) {
                const idx   = i % N
                const angle = (2 * Math.PI * idx / N) + root.wavePhase
                const r     = innerR + (bands[idx] || 0) * rangeR
                const x     = cx + Math.cos(angle) * r
                const y     = cy + Math.sin(angle) * r
                if (i === 0) ctx.moveTo(x, y)
                else         ctx.lineTo(x, y)
            }
            ctx.closePath()

            ctx.fillStyle   = root.withAlpha(root.schemeColorCss(root.rms * 0.8), 0.18)
            ctx.fill()
            ctx.strokeStyle = root.schemeColorCss(Math.max(0.3, root.rms))
            ctx.lineWidth   = 1.5
            ctx.stroke()

            // Pulsing centre dot scaled by RMS
            const dotR = Math.max(1.5, root.rms * 4)
            ctx.fillStyle = root.schemeColorCss(0.9)
            ctx.beginPath()
            ctx.arc(cx, cy, dotR, 0, 2 * Math.PI)
            ctx.fill()
        }

        // ---- starfield (per-band particles) ----------------------------------
        function paintStars(ctx) {
            const stars = root.stars
            for (let i = 0; i < stars.length; i++) {
                const s  = stars[i]
                const a  = s.life * s.life     // quadratic fade
                const sz = Math.max(1, s.life * 2.5)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(s.hue), a)
                ctx.fillRect(s.x - sz * 0.5, s.y - sz * 0.5, sz, sz)
            }
        }

        // ---- tunnel (zooming concentric rings) --------------------------------
        function paintTunnel(ctx) {
            const w    = width,  h  = height
            const cx   = w / 2, cy = h / 2
            const maxR = Math.min(cx, cy)
            const rings = root.tunnelRings

            for (let i = 0; i < rings.length; i++) {
                const r      = rings[i]
                const radius = r.scale * maxR
                if (radius < 0.5) continue

                // Rings near edge are brighter; rings at centre are dim (depth cue)
                const alpha = Math.min(1.0, r.scale * 1.5)
                ctx.strokeStyle = root.withAlpha(root.schemeColorCss(r.hue), alpha)
                ctx.lineWidth   = Math.max(0.8, (1.0 - r.scale) * 3 + 0.5)
                ctx.beginPath()
                ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
                ctx.stroke()
            }
        }

        // ---- terrain (pseudo-3D spectral landscape flyover) ------------------
        function paintTerrain(ctx) {
            const w        = width,  h = height
            const history  = root.terrainHistory
            const numRows  = history.length
            if (numRows === 0) return

            ctx.fillStyle = "#000"
            ctx.fillRect(0, 0, w, h)

            const horizonY = h * 0.30

            // Optional rotation: spin the whole viewport around the canvas centre
            if (root.terrainRotate && root.terrainRotAngle !== 0) {
                ctx.save()
                ctx.translate(w * 0.5, h * 0.5)
                ctx.rotate(root.terrainRotAngle)
                ctx.translate(-w * 0.5, -h * 0.5)
            }

            // Draw from farthest row (near horizon) to nearest (bottom canvas).
            // In terrainHistory index 0 is NEWEST (nearest), numRows-1 is OLDEST.
            for (let r = numRows - 1; r >= 0; r--) {
                const t     = r / Math.max(1, numRows - 1) // 0=nearest, 1=farthest
                const baseY = h - t * (h - horizonY)       // ground baseline
                const rowW  = w * (1.0 - t * 0.60)         // narrower at horizon
                const xOff  = (w - rowW) / 2
                const maxH  = (baseY - horizonY) * 0.88    // max hill height

                const row = history[r]
                ctx.beginPath()
                ctx.moveTo(xOff, baseY)
                for (let i = 0; i < root.numBands; i++) {
                    const xPos = xOff + i * rowW / Math.max(1, root.numBands - 1) // spread numBands points across [0, rowW]
                    const yPos = baseY - (row[i] || 0) * maxH
                    ctx.lineTo(xPos, yPos)
                }
                ctx.lineTo(xOff + rowW, baseY)
                ctx.closePath()

                const energy = row.reduce((s, v) => s + v, 0) / root.numBands
                const alpha  = 0.12 + (1 - t) * 0.70

                if (!root.terrainWireframe) {
                    ctx.fillStyle = root.withAlpha(
                        root.schemeColorCss((1 - t) * 0.55 + energy * 0.45), alpha)
                    ctx.fill()
                }

                // Wireframe ridge line on top of each terrain slice
                ctx.strokeStyle = root.withAlpha(root.schemeColorCss(1 - t), (1 - t) * 0.55)
                ctx.lineWidth   = root.terrainWireframe ? 1.0 : 0.6
                ctx.stroke()
            }

            // Horizon rule
            ctx.strokeStyle = root.schemeColorCss(0.65)
            ctx.lineWidth   = 0.5
            ctx.beginPath()
            ctx.moveTo(0, horizonY); ctx.lineTo(w, horizonY)
            ctx.stroke()

            if (root.terrainRotate && root.terrainRotAngle !== 0)
                ctx.restore()
        }

        // ---- vortex (wormhole: first-person fly-through tunnel) ---------------
        function paintVortex(ctx) {
            const w      = width,  h  = height
            const cx0    = w / 2,  cy0 = h / 2
            const bands  = root.bandVals
            const minDim = Math.min(w, h)

            // Geometry / perspective constants
            // RINGS × VERTS gives the ring mesh; N_RIBS longitudinal lines add
            // the lengthwise structure visible in wormhole / stargate visuals.
            const RINGS  = 30        // depth slices (cross-section rings)
            const VERTS  = 32        // polygon vertices per ring
            const N_RIBS = 8         // longitudinal rib lines along tunnel walls
            const Z_NEAR = 0.25      // depth of nearest ring (fills ~screen)
            const Z_FAR  = 7.0       // depth of farthest ring (vanishing point)
            const FOCAL  = minDim * 0.50   // focal length in screen pixels
            const TUBE_R = 0.35      // world-space tube radius (calibrated for FOV)

            // Tuning constants (separated for ease of adjustment)
            const ROLL_DAMP       = 0.45  // fraction of vortexRoll applied as canvas rotation
            const MIN_RING_RADIUS = 0.4   // cull rings smaller than this (pixels)
            const MAX_RING_MULT   = 3.0   // cull rings larger than minDim × this
            const HELIX_PHASE_T   = 0.55  // time contribution to helix phase per radian
            const HELIX_PHASE_Z   = 0.20  // depth contribution to helix phase per world unit
            const BEND_AMP        = 0.38  // helix bend amplitude (fraction of FOCAL)
            const LISSAJOUS_Y     = 0.71  // Y-axis phase ratio for Lissajous centreline
            const TWIST_T         = 2.8   // time multiplier for per-ring twist
            const TWIST_Z         = 0.42  // depth multiplier for per-ring twist

            ctx.fillStyle = "#000000"
            ctx.fillRect(0, 0, w, h)

            // Apply camera roll (banking): rotate entire scene around screen centre.
            // This creates the barrel-roll / wormhole banking sensation.
            ctx.save()
            ctx.translate(cx0, cy0)
            ctx.rotate(root.vortexRoll * ROLL_DAMP)
            ctx.translate(-cx0, -cy0)

            // Pre-compute per-ring geometry so both the ring pass and the rib pass
            // can reuse the data without redundant trigonometry.
            const ringData = []
            for (let k = 0; k < RINGS; k++) {
                // tNorm 0 = vanishing (far, small on screen)
                //        1 = right in front of viewer (large, about to clip)
                // vortexTravelZ advances 0→1 continuously, sliding all rings
                // toward the viewer; when a ring reaches tNorm=1 it wraps to 0.
                const tNorm = (k / RINGS + root.vortexTravelZ) % 1.0

                // Logarithmic depth: rings appear evenly spaced in perspective.
                const z = Z_FAR * Math.pow(Z_NEAR / Z_FAR, tNorm)

                // Perspective scale: screen pixels per world unit at depth z.
                const ps    = FOCAL / z
                const baseR = TUBE_R * ps   // screen-space ring radius

                // Cull rings that are invisible (vanishingly small or clipping).
                if (baseR < MIN_RING_RADIUS || baseR > minDim * MAX_RING_MULT) {
                    ringData.push(null)
                    continue
                }

                // Tunnel centreline curves as a smooth helix driven by pitch/yaw.
                // Bend amplitude grows with sqrt(z) so near rings hug the travel
                // axis while far rings show the curve — the "looking into a bend"
                // depth cue.
                const ph    = root.vortexAngle * HELIX_PHASE_T + z * HELIX_PHASE_Z
                const bendR = FOCAL * BEND_AMP * Math.sqrt(z / Z_FAR)
                const cx    = cx0 + root.vortexDriftX * bendR * Math.sin(ph)
                const cy    = cy0 + root.vortexDriftY * bendR * Math.cos(ph * LISSAJOUS_Y)

                // Twist angle: each ring is rotated around the tunnel axis by an
                // amount that depends on both time and depth, giving the spiral
                // corridor appearance.
                const twist = root.vortexAngle * TWIST_T + z * TWIST_Z

                ringData.push({ cx, cy, baseR, twist, tNorm })
            }

            // ---- Cross-section rings, drawn far → near (k=0 farthest) ----------
            for (let k = 0; k < RINGS; k++) {
                const rd = ringData[k]
                if (!rd) continue

                ctx.beginPath()
                for (let v = 0; v <= VERTS; v++) {
                    const idx     = v % VERTS
                    const bandIdx = idx % 16
                    const angle   = (2 * Math.PI * idx / VERTS) + rd.twist
                    // Spectral deformation: vertices pushed out by their band;
                    // effect is strongest for near rings (tNorm → 1).
                    const deform  = (bands[bandIdx] || 0) * 0.50 * rd.tNorm
                    const r = rd.baseR * (1 + deform)
                    const x = rd.cx + Math.cos(angle) * r
                    const y = rd.cy + Math.sin(angle) * r
                    if (v === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.closePath()

                const alpha = 0.06 + rd.tNorm * 0.84
                ctx.strokeStyle = root.withAlpha(
                    root.schemeColorCss(root.treble * 0.2 + rd.tNorm * 0.8), alpha)
                ctx.lineWidth = Math.max(0.3, rd.tNorm * 3.0)
                ctx.stroke()
            }

            // ---- Longitudinal ribs (tunnel structure lines) ---------------------
            // Each rib is a single path connecting one vertex index across all
            // visible rings from far to near, creating the grid-like wormhole wall.
            for (let r = 0; r < N_RIBS; r++) {
                const vIdx    = Math.floor(r * VERTS / N_RIBS)
                const bandIdx = vIdx % 16
                const bandVal = bands[bandIdx] || 0

                ctx.beginPath()
                let started = false
                for (let k = 0; k < RINGS; k++) {
                    const rd = ringData[k]
                    if (!rd) continue
                    const angle  = (2 * Math.PI * vIdx / VERTS) + rd.twist
                    const deform = bandVal * 0.50 * rd.tNorm
                    const radius = rd.baseR * (1 + deform)
                    const x = rd.cx + Math.cos(angle) * radius
                    const y = rd.cy + Math.sin(angle) * radius
                    if (!started) { ctx.moveTo(x, y); started = true }
                    else          { ctx.lineTo(x, y) }
                }

                const ribAlpha = 0.10 + bandVal * 0.42
                ctx.strokeStyle = root.withAlpha(
                    root.schemeColorCss(bandIdx / 16), ribAlpha)
                ctx.lineWidth = Math.max(0.4, bandVal * 1.8 + 0.4)
                ctx.stroke()
            }

            ctx.restore()

            // Vanishing-point glow at screen centre, pulsed by RMS
            if (root.rms > 0.04) {
                const glowR = Math.max(2, root.rms * 10)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(root.treble), 0.85)
                ctx.beginPath()
                ctx.arc(cx0, cy0, glowR, 0, 2 * Math.PI)
                ctx.fill()
            }
        }

        // ---- warp (radial beam hyperspace) -----------------------------------
        function paintWarp(ctx) {
            const w      = width,  h  = height
            const cx     = w / 2,  cy = h / 2
            const maxLen = Math.min(cx, cy) * 0.93
            const lens   = root.warpLengths
            if (!lens || lens.length < root.numBands) return

            for (let i = 0; i < root.numBands; i++) {
                const len = (lens[i] || 0) * maxLen
                if (len < 1.5) continue

                // Beams start at 12 o'clock and fan clockwise around 360°.
                const angle = 2 * Math.PI * i / root.numBands - Math.PI / 2
                const x2   = cx + Math.cos(angle) * len
                const y2   = cy + Math.sin(angle) * len
                const col  = root.schemeColorCss(i / root.numBands)

                // Triple-layer glow: wide halo → mid beam → bright core
                ctx.lineWidth   = 6
                ctx.strokeStyle = root.withAlpha(col, 0.12)
                ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(x2, y2); ctx.stroke()

                ctx.lineWidth   = 2.5
                ctx.strokeStyle = root.withAlpha(col, 0.50)
                ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(x2, y2); ctx.stroke()

                ctx.lineWidth   = 0.8
                ctx.strokeStyle = col
                ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(x2, y2); ctx.stroke()

                // Tip sparkle dot
                const ts = Math.max(1.0, lens[i] * 3)
                ctx.fillStyle = "#ffffff"
                ctx.fillRect(x2 - ts * 0.5, y2 - ts * 0.5, ts, ts)
            }

            // Pulsing core dot
            const coreR = Math.max(1.5, root.rms * 5)
            ctx.fillStyle = root.schemeColorCss(0.85)
            ctx.beginPath()
            ctx.arc(cx, cy, coreR, 0, 2 * Math.PI)
            ctx.fill()
        }

        // ---- ripple (concentric pond ripples + band bubbles) -----------------
        function paintRipple(ctx) {
            const w      = width,  h  = height
            const cx     = w / 2,  cy = h / 2
            const bands  = root.bandVals

            // Background: small per-band circles arranged radially
            if (bands && bands.length >= root.numBands) {
                for (let i = 0; i < root.numBands; i++) {
                    const v     = bands[i] || 0
                    if (v < 0.04) continue
                    const angle = 2 * Math.PI * i / root.numBands
                    const r     = Math.min(cx, cy) * (0.10 + v * 0.58)
                    const bx    = cx + Math.cos(angle) * r
                    const by    = cy + Math.sin(angle) * r
                    const bSize = Math.max(1.2, v * 4.5)
                    ctx.strokeStyle = root.withAlpha(root.schemeColorCss(i / root.numBands), v * 0.45)
                    ctx.lineWidth   = 0.8
                    ctx.beginPath()
                    ctx.arc(bx, by, bSize, 0, 2 * Math.PI)
                    ctx.stroke()
                }
            }

            // Ripple rings
            const ripples = root.ripples
            for (let i = 0; i < ripples.length; i++) {
                const rp    = ripples[i]
                const alpha = rp.energy * 0.85
                ctx.strokeStyle = root.withAlpha(root.schemeColorCss(rp.hue), alpha)
                ctx.lineWidth   = Math.max(0.5, rp.energy * 2.5)
                ctx.beginPath()
                ctx.arc(cx, cy, rp.radius, 0, 2 * Math.PI)
                ctx.stroke()
            }

            // Centre glow
            if (root.rms > 0.04) {
                const gr = Math.max(1.5, root.rms * 6)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(root.treble), root.rms * 0.85)
                ctx.beginPath()
                ctx.arc(cx, cy, gr, 0, 2 * Math.PI)
                ctx.fill()
            }
        }

        // ---- kaleidoscope (6-fold mirrored spectrum wedges) -----------------
        function paintKaleid(ctx) {
            const w      = width,  h  = height
            const cx     = w / 2,  cy = h / 2
            const maxR   = Math.min(cx, cy) * 0.90
            const bands  = root.bandVals
            const folds  = 6
            if (!bands || bands.length < root.numBands) return

            const energy = bands.reduce((s, v) => s + v, 0) / root.numBands

            for (let k = 0; k < folds; k++) {
                // Each fold rotated by 60° + slow phase driven by RMS / beats
                const foldAngle = k * 2 * Math.PI / folds + root.kaleidPhase

                // Draw the wedge twice: once normal, once mirrored (scale Y =-1)
                for (let mirror = 0; mirror < 2; mirror++) {
                    ctx.save()
                    ctx.translate(cx, cy)
                    ctx.rotate(foldAngle)
                    if (mirror === 1) ctx.scale(1, -1)  // mirror image

                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    for (let i = 0; i < root.numBands; i++) {
                        // Sweep band points through the half-wedge angle
                        const sweep = Math.PI / folds
                        const ang   = sweep * i / Math.max(1, root.numBands - 1) - sweep * 0.5
                        const r     = maxR * (0.15 + (bands[i] || 0) * 0.85)
                        ctx.lineTo(Math.cos(ang) * r, Math.sin(ang) * r)
                    }
                    ctx.closePath()

                    ctx.fillStyle = root.withAlpha(
                        root.schemeColorCss(k / folds + root.treble * 0.12),
                        0.12 + energy * 0.30)
                    ctx.fill()

                    ctx.strokeStyle = root.schemeColorCss(k / folds + root.treble * 0.12)
                    ctx.lineWidth   = 0.7 + root.rms * 1.2
                    ctx.stroke()
                    ctx.restore()
                }
            }

            // Centre dot
            if (root.rms > 0.03) {
                const cr = Math.max(1.5, root.rms * 5)
                ctx.fillStyle = root.schemeColorCss(0.9)
                ctx.beginPath()
                ctx.arc(cx, cy, cr, 0, 2 * Math.PI)
                ctx.fill()
            }
        }

        // ---- nova (afterglow bloom / comet-trail nebula) --------------------
        function paintNova(ctx) {
            const w   = width,  h  = height
            const cx  = w / 2,  cy = h / 2
            const R   = Math.min(cx, cy)

            // Persistence fade: overwrite with near-black, not clearRect
            ctx.fillStyle = "rgba(0,0,0,0.072)"
            ctx.fillRect(0, 0, w, h)

            const ps = root.novaParticles
            for (let i = 0; i < ps.length; i++) {
                const p     = ps[i]
                const alpha = p.life * (p.tracer ? 0.70 : 0.82)
                const r     = p.size * (0.5 + p.life * 0.5)

                // Inner core
                ctx.beginPath()
                ctx.arc(p.x, p.y, Math.max(0.5, r), 0, 2 * Math.PI)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(p.hue), alpha)
                ctx.fill()

                // Outer halo glow
                if (p.size > 1.5) {
                    const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r * 3.5)
                    g.addColorStop(0, root.withAlpha(root.schemeColorCss(p.hue), alpha * 0.55))
                    g.addColorStop(1, "rgba(0,0,0,0)")
                    ctx.beginPath()
                    ctx.arc(p.x, p.y, r * 3.5, 0, 2 * Math.PI)
                    ctx.fillStyle = g
                    ctx.fill()
                }
            }

            // Pulsing central star – always rendered
            const coreR = Math.max(1.5, root.rms * R * 0.22 + (root.gotBeat ? R * 0.065 : 0))
            const cg    = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreR * 3.5)
            cg.addColorStop(0, root.withAlpha(root.schemeColorCss(root.treble * 0.55), 0.95))
            cg.addColorStop(0.28, root.withAlpha(root.schemeColorCss(root.treble * 0.55 + 0.1), 0.35))
            cg.addColorStop(1, "rgba(0,0,0,0)")
            ctx.beginPath()
            ctx.arc(cx, cy, coreR * 3.5, 0, 2 * Math.PI)
            ctx.fillStyle = cg
            ctx.fill()

            // Bright inner dot
            ctx.beginPath()
            ctx.arc(cx, cy, coreR, 0, 2 * Math.PI)
            ctx.fillStyle = root.schemeColorCss(root.treble * 0.3 + 0.75)
            ctx.fill()
        }

        // ---- galaxy (rotating logarithmic spiral star field) ----------------
        function paintGalaxy(ctx) {
            const w      = width,  h  = height
            const cx     = w / 2,  cy = h / 2
            const R      = Math.min(cx, cy) * 0.90
            const bands  = root.bandVals
            const ang    = root.galaxyAngle
            if (!bands || bands.length < root.numBands) return

            ctx.fillStyle = "#000000"
            ctx.fillRect(0, 0, w, h)

            // Draw stars
            const stars = root.galaxyStars
            for (let i = 0; i < stars.length; i++) {
                const s  = stars[i]
                const a  = s.theta + ang * (1 + s.r * 0.9)
                const px = cx + Math.cos(a) * s.r * R
                const py = cy + Math.sin(a) * s.r * R * 0.52   // flatten: elliptical galaxy

                const band  = bands[s.bandBias] || 0
                const glow  = 0.55 + band * 0.85
                const alpha = (0.4 + band * 0.7) * (1.0 - s.r * 0.45)
                const sr    = s.size * glow * (1.0 + root.bass * 0.6)

                ctx.beginPath()
                ctx.arc(px, py, Math.max(0.4, sr), 0, 2 * Math.PI)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(s.hue + root.treble * 0.08), alpha)
                ctx.fill()
            }

            // Galactic core: layered radial glow
            const coreR = R * (0.065 + root.bass * 0.095 + (root.gotBeat ? 0.04 : 0))
            for (let layer = 3; layer >= 0; layer--) {
                const lr   = coreR * (layer * 1.8 + 1)
                const cg   = ctx.createRadialGradient(cx, cy, 0, cx, cy, lr)
                const alpC = 0.85 - layer * 0.18
                cg.addColorStop(0,    root.withAlpha(root.schemeColorCss(0.08), alpC))
                cg.addColorStop(0.35, root.withAlpha(root.schemeColorCss(0.12), alpC * 0.45))
                cg.addColorStop(1,    "rgba(0,0,0,0)")
                ctx.beginPath()
                ctx.arc(cx, cy, lr, 0, 2 * Math.PI)
                ctx.fillStyle = cg
                ctx.fill()
            }
        }

        // ---- aurora (northern-lights flowing curtains) -----------------------
        function paintAurora(ctx) {
            const w     = width,  h  = height
            const bands = root.bandVals
            const t     = root.auroraTime
            if (!bands || bands.length < root.numBands) return

            ctx.fillStyle = "#000009"
            ctx.fillRect(0, 0, w, h)

            const NUM_RIBBONS = 8
            for (let ri = 0; ri < NUM_RIBBONS; ri++) {
                // Pair up 2 adjacent bands per ribbon
                const b1    = bands[(ri * 2)     % 16] || 0
                const b2    = bands[(ri * 2 + 1) % 16] || 0
                const amp   = h * (0.07 + (b1 + b2) * 0.5 * 0.25)
                const baseY = h * (0.15 + ri / NUM_RIBBONS * 0.60)
                const phase = t * (0.6 + ri * 0.18) + ri * 1.4
                const hue   = ri / NUM_RIBBONS + root.treble * 0.18

                const STEPS = 80
                ctx.beginPath()
                for (let si = 0; si <= STEPS; si++) {
                    const xf  = si / STEPS
                    const px  = xf * w
                    const py  = baseY + Math.sin(xf * 3.5 + phase) * amp
                             + Math.sin(xf * 7.0 - phase * 0.7) * amp * 0.35
                    if (si === 0) ctx.moveTo(px, py)
                    else          ctx.lineTo(px, py)
                }
                // Ribbon bottom (near h)
                for (let si = STEPS; si >= 0; si--) {
                    const xf  = si / STEPS
                    const px  = xf * w
                    const py  = baseY + h * 0.085 + Math.sin(xf * 3.5 + phase + 0.5) * amp * 0.5
                    ctx.lineTo(px, py)
                }
                ctx.closePath()

                const alpha = 0.06 + (b1 + b2) * 0.5 * 0.32 + (root.gotBeat ? 0.10 : 0)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(hue), alpha)
                ctx.fill()

                // Bright upper edge stroke
                ctx.beginPath()
                for (let si = 0; si <= STEPS; si++) {
                    const xf  = si / STEPS
                    const px  = xf * w
                    const py  = baseY + Math.sin(xf * 3.5 + phase) * amp
                             + Math.sin(xf * 7.0 - phase * 0.7) * amp * 0.35
                    if (si === 0) ctx.moveTo(px, py)
                    else          ctx.lineTo(px, py)
                }
                ctx.strokeStyle = root.withAlpha(root.schemeColorCss(hue + 0.06), 0.45 + b1 * 0.55)
                ctx.lineWidth   = 0.9 + b2 * 1.8
                ctx.stroke()
            }
        }

        // ---- mandala (multi-layer geometric / jewel) ------------------------
        function paintMandala(ctx) {
            const w     = width,  h  = height
            const cx    = w / 2,  cy = h / 2
            const R     = Math.min(cx, cy) * 0.90
            const bands = root.bandVals
            const ph    = root.mandalaPhase
            if (!bands || bands.length < root.numBands) return

            ctx.fillStyle = "#000000"
            ctx.fillRect(0, 0, w, h)

            // Layer definitions: { folds, direction, hueOffset, bandRange }
            const layers = [
                { folds: 12, dir:  1, hueOff: 0.00, bands: [0,5]  },
                { folds:  8, dir: -1, hueOff: 0.33, bands: [5,10] },
                { folds:  6, dir:  1, hueOff: 0.66, bands: [10,16] }
            ]

            for (let li = 0; li < layers.length; li++) {
                const L      = layers[li]
                const folds  = L.folds
                const bSlice = bands.slice(L.bands[0], L.bands[1])
                const energy = bSlice.reduce((s, v) => s + v, 0) / bSlice.length
                const rInner = R * (0.06 + energy * 0.08)
                const rOuter = R * (0.22 + energy * 0.55 + root.rms * 0.12)
                const layPh  = ph * L.dir * (1 + li * 0.35)

                for (let k = 0; k < folds; k++) {
                    const foldAngle = k * 2 * Math.PI / folds + layPh
                    for (let mirror = 0; mirror < 2; mirror++) {
                        ctx.save()
                        ctx.translate(cx, cy)
                        ctx.rotate(foldAngle)
                        if (mirror === 1) ctx.scale(1, -1)

                        // Petal shape: arc from rInner to rOuter using band values
                        ctx.beginPath()
                        ctx.moveTo(0, rInner)
                        const SEGS = bSlice.length
                        for (let si = 0; si <= SEGS; si++) {
                            const t    = si / SEGS
                            const bv   = bSlice[Math.min(si, SEGS - 1)] || 0
                            const petalW = Math.PI * 0.72 / folds
                            const ang  = (t - 0.5) * petalW
                            const r    = rInner + (rOuter - rInner) * (0.2 + bv * 0.8)
                            ctx.lineTo(Math.sin(ang) * r, Math.cos(ang) * r)
                        }
                        ctx.lineTo(0, rInner)
                        ctx.closePath()

                        const hue   = L.hueOff + root.treble * 0.18 + k / folds * 0.1
                        const alpha = 0.08 + energy * 0.35
                        ctx.fillStyle   = root.withAlpha(root.schemeColorCss(hue), alpha)
                        ctx.strokeStyle = root.withAlpha(root.schemeColorCss(hue + 0.04), 0.55 + energy * 0.45)
                        ctx.lineWidth   = 0.6
                        ctx.fill()
                        ctx.stroke()
                        ctx.restore()
                    }
                }
            }

            // Central jewel – glowing disc
            const jewR = R * (0.04 + root.rms * 0.08 + (root.gotBeat ? 0.03 : 0))
            const jg   = ctx.createRadialGradient(cx, cy, 0, cx, cy, jewR * 3)
            jg.addColorStop(0,   root.withAlpha(root.schemeColorCss(root.treble * 0.5 + 0.8), 1.0))
            jg.addColorStop(0.4, root.withAlpha(root.schemeColorCss(root.treble * 0.5 + 0.6), 0.50))
            jg.addColorStop(1,   "rgba(0,0,0,0)")
            ctx.beginPath()
            ctx.arc(cx, cy, jewR * 3, 0, 2 * Math.PI)
            ctx.fillStyle = jg
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx, cy, jewR, 0, 2 * Math.PI)
            ctx.fillStyle = root.schemeColorCss(root.treble * 0.5 + 0.9)
            ctx.fill()
        }

        // ---- LED segment meter ----------------------------------------------
        // Stacked dot columns styled after old Hi-Fi peak meters.
        function paintLed(ctx) {
            const w = width, h = height
            const N = 16
            const bands = root.bandVals
            const peaks = root.peakBands
            if (!bands || bands.length < N) return

            const ROWS   = 14   // number of LED segments per column
            const gap    = 1    // gap between dots
            const colW   = (w - N + 1) / N
            const dotH   = (h - (ROWS - 1) * gap) / ROWS
            const dotW   = Math.max(1, Math.floor(colW) - 1)

            for (let i = 0; i < N; i++) {
                const frac   = bands[i] || 0
                const litN   = Math.round(frac * ROWS)
                const peakRow= Math.round((peaks[i] || 0) * ROWS)
                const cx     = Math.round(i * (colW + 1))

                for (let row = 0; row < ROWS; row++) {
                    const rowFromTop = ROWS - 1 - row
                    const y = rowFromTop * (dotH + gap)
                    // Colour zone: red (top 2), amber (next 3), green (rest)
                    let hue
                    if (rowFromTop < 2)      hue = 0.00   // red
                    else if (rowFromTop < 5) hue = 0.10   // amber
                    else                     hue = 0.33   // green

                    const lit = row < litN
                    const isPeak = row === peakRow && peakRow > 0
                    if (lit || isPeak) {
                        // Bright dot
                        ctx.fillStyle = isPeak && !lit
                            ? "#ffffff"
                            : "hsl(" + Math.round(hue * 360) + ",100%," + (lit ? "55%" : "25%") + ")"
                        ctx.fillRect(cx, Math.round(y), dotW, Math.max(1, Math.floor(dotH)))
                    } else {
                        // Dim unlit segment
                        ctx.fillStyle = "hsl(" + Math.round(hue * 360) + ",40%,12%)"
                        ctx.fillRect(cx, Math.round(y), dotW, Math.max(1, Math.floor(dotH)))
                    }
                }
            }
        }

        // ---- plasma discharge -----------------------------------------------
        // Simulates plasma discharge tubes and Jacob's ladder arcs.
        function paintDischarge(ctx) {
            const w = width, h = height
            const arcs = root.dischargeArcs
            if (!arcs || arcs.length === 0) return

            // Dark background with slight blue tint
            ctx.fillStyle = "rgba(0,0,12,0.55)"
            ctx.fillRect(0, 0, w, h)

            for (let ai = 0; ai < arcs.length; ai++) {
                const a = arcs[ai]
                const alpha = Math.min(1.0, a.life) * a.energy

                // Draw three passes: wide glow, mid, bright core
                const passes = [
                    { lw: 6.0, alpha: alpha * 0.12 },
                    { lw: 2.5, alpha: alpha * 0.35 },
                    { lw: 0.8, alpha: Math.min(1, alpha * 0.9) }
                ]
                for (const pass of passes) {
                    ctx.beginPath()
                    const dx = a.x2 - a.x1
                    const dy = a.y2 - a.y1
                    const len = Math.sqrt(dx * dx + dy * dy) || 1
                    const nx = -dy / len   // perpendicular
                    const ny =  dx / len

                    for (let s = 0; s <= a.segs; s++) {
                        const t  = s / a.segs
                        const bx = a.x1 + dx * t + nx * (a.jitter[s] || 0)
                        const by = a.y1 + dy * t + ny * (a.jitter[s] || 0) * 0.3
                        if (s === 0) ctx.moveTo(bx, by)
                        else         ctx.lineTo(bx, by)
                    }
                    ctx.strokeStyle = "hsla(" + Math.round(a.hue * 360) + ",100%,72%," + pass.alpha.toFixed(2) + ")"
                    ctx.lineWidth   = pass.lw
                    ctx.stroke()
                }

                // Node corona
                for (const pt of [{ x: a.x1, y: a.y1 }, { x: a.x2, y: a.y2 }]) {
                    const rg = ctx.createRadialGradient(pt.x, pt.y, 0, pt.x, pt.y, 7)
                    rg.addColorStop(0, "hsla(" + Math.round(a.hue * 360) + ",100%,90%," + (alpha * 0.8).toFixed(2) + ")")
                    rg.addColorStop(1, "rgba(0,0,0,0)")
                    ctx.beginPath()
                    ctx.arc(pt.x, pt.y, 7, 0, 2 * Math.PI)
                    ctx.fillStyle = rg
                    ctx.fill()
                }
            }
        }

        // ---- lightning ------------------------------------------------------
        // Branching storm bolt from the top, fading quickly.
        function paintLightning(ctx) {
            const w = width, h = height

            // Slow ambient glow wash
            ctx.fillStyle = "rgba(0,0,20," + (0.08 + root.rms * 0.12).toFixed(2) + ")"
            ctx.fillRect(0, 0, w, h)

            const bolts = root.lightningBolts
            for (let bi = 0; bi < bolts.length; bi++) {
                const bolt = bolts[bi]
                const f    = Math.min(1, bolt.flash)
                const hDeg = Math.round(bolt.hue * 360)

                // Wide purple glow pass
                ctx.strokeStyle = "hsla(" + hDeg + ",80%,50%," + (f * 0.20).toFixed(2) + ")"
                ctx.lineWidth   = 5.0
                for (const seg of bolt.segs) {
                    ctx.beginPath()
                    ctx.moveTo(seg.x1, seg.y1)
                    ctx.lineTo(seg.x2, seg.y2)
                    ctx.stroke()
                }
                // Bright white/blue core
                ctx.strokeStyle = "hsla(" + hDeg + ",70%,90%," + (f * 0.85).toFixed(2) + ")"
                ctx.lineWidth   = 0.9
                for (const seg of bolt.segs) {
                    ctx.beginPath()
                    ctx.moveTo(seg.x1, seg.y1)
                    ctx.lineTo(seg.x2, seg.y2)
                    ctx.stroke()
                }
            }
        }

        // ---- concert spotlight beams ----------------------------------------
        // Sweeping floor spotlights with coloured beams, beat-driven intensity.
        function paintConcert(ctx) {
            const w = width, h = height
            const beams = root.concertBeams
            if (!beams || beams.length === 0) return

            // Haze floor gradient
            const haze = ctx.createLinearGradient(0, h * 0.6, 0, h)
            haze.addColorStop(0, "rgba(0,0,0,0)")
            haze.addColorStop(1, "rgba(10,10,18,0.65)")
            ctx.fillStyle = haze
            ctx.fillRect(0, 0, w, h)

            const BEAM_LEN = Math.sqrt(w * w + h * h)

            for (let i = 0; i < beams.length; i++) {
                const b     = beams[i]
                const en    = b.energy
                const alpha = 0.06 + en * 0.28 + (root.gotBeat ? 0.10 : 0)
                const hDeg  = Math.round(b.hue * 360)

                // Each beam is a thin wedge (triangle) from source at bottom
                const srcX  = w * (0.1 + (i / (beams.length - 1)) * 0.8)
                const srcY  = h
                const ang   = -Math.PI / 2 + b.angle
                const hw    = b.width / 2 + en * 0.06

                const lx = srcX + Math.cos(ang - hw) * BEAM_LEN
                const ly = srcY + Math.sin(ang - hw) * BEAM_LEN
                const rx = srcX + Math.cos(ang + hw) * BEAM_LEN
                const ry = srcY + Math.sin(ang + hw) * BEAM_LEN

                const grad = ctx.createLinearGradient(srcX, srcY,
                    srcX + Math.cos(ang) * BEAM_LEN,
                    srcY + Math.sin(ang) * BEAM_LEN)
                grad.addColorStop(0,   "hsla(" + hDeg + ",100%,70%," + (alpha * 0.9).toFixed(2) + ")")
                grad.addColorStop(0.4, "hsla(" + hDeg + ",80%,55%,"  + (alpha * 0.5).toFixed(2) + ")")
                grad.addColorStop(1,   "hsla(" + hDeg + ",60%,40%,"  + "0)")

                ctx.beginPath()
                ctx.moveTo(srcX, srcY)
                ctx.lineTo(lx, ly)
                ctx.lineTo(rx, ry)
                ctx.closePath()
                ctx.fillStyle = grad
                ctx.fill()
            }

            // Floor reflection line
            ctx.fillStyle = "rgba(255,255,255,0.04)"
            ctx.fillRect(0, h - 2, w, 2)
        }

        // ---- pyrotechnics ---------------------------------------------------
        // Firework shells rise and burst; gravity arcs the particle sprays.
        function paintPyro(ctx) {
            const w = width, h = height

            // Faint smoke/trail fade instead of full clear
            ctx.fillStyle = "rgba(0,0,4,0.35)"
            ctx.fillRect(0, 0, w, h)

            // Rising shells
            const shells = root.pyroShells
            for (let i = 0; i < shells.length; i++) {
                const s = shells[i]
                const hDeg = Math.round(s.hue * 360)
                ctx.beginPath()
                ctx.arc(s.x, s.y, 1.5, 0, 2 * Math.PI)
                ctx.fillStyle = "hsl(" + hDeg + ",100%,90%)"
                ctx.fill()
                // Trail
                ctx.beginPath()
                ctx.moveTo(s.x, s.y)
                ctx.lineTo(s.x - s.vx * 4, s.y - s.vy * 4)
                ctx.strokeStyle = "hsla(" + hDeg + ",80%,70%,0.4)"
                ctx.lineWidth = 1.0
                ctx.stroke()
            }

            // Burst particles
            const parts = root.pyroParticles
            for (let i = 0; i < parts.length; i++) {
                const p    = parts[i]
                const hDeg = Math.round(p.hue * 360)
                const a    = p.life
                ctx.beginPath()
                ctx.arc(p.x, p.y, p.size * 0.7 * a, 0, 2 * Math.PI)
                ctx.fillStyle = "hsla(" + hDeg + ",100%,70%," + (a * 0.9).toFixed(2) + ")"
                ctx.fill()
                // Trail line
                ctx.beginPath()
                ctx.moveTo(p.x, p.y)
                ctx.lineTo(p.x - p.vx * 3, p.y - p.vy * 3)
                ctx.strokeStyle = "hsla(" + hDeg + ",80%,85%," + (a * 0.5).toFixed(2) + ")"
                ctx.lineWidth = 0.8
                ctx.stroke()
            }
        }
    }

    // ----- mouse wheel: cycle effects ----------------------------------------
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onWheel: whe => {
            const order = root.effectOrder
            const cur   = order.indexOf(root.effect)
            const next  = (cur + (whe.angleDelta.y > 0 ? -1 : 1) + order.length) % order.length
            Plasmoid.configuration.effect = order[next]
            whe.accepted = true
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                effectMenu.popup()
        }
    }

    // ----- right-click context menu ------------------------------------------
    QQC2.Menu {
        id: effectMenu
        title: i18n("Visualization")

        QQC2.MenuItem { text: i18n("Bars");          onTriggered: Plasmoid.configuration.effect = "bars"      }
        QQC2.MenuItem { text: i18n("Scope");         onTriggered: Plasmoid.configuration.effect = "wave"      }
        QQC2.MenuItem { text: i18n("Starfield");     onTriggered: Plasmoid.configuration.effect = "circles"   }
        QQC2.MenuItem { text: i18n("Tunnel");        onTriggered: Plasmoid.configuration.effect = "plasma"    }
        QQC2.MenuItem { text: i18n("Terrain");       onTriggered: Plasmoid.configuration.effect = "terrain"   }
        QQC2.MenuItem { text: i18n("Vortex");        onTriggered: Plasmoid.configuration.effect = "vortex"    }
        QQC2.MenuItem { text: i18n("Warp");          onTriggered: Plasmoid.configuration.effect = "warp"      }
        QQC2.MenuItem { text: i18n("Ripple");        onTriggered: Plasmoid.configuration.effect = "ripple"    }
        QQC2.MenuItem { text: i18n("Kaleidoscope");  onTriggered: Plasmoid.configuration.effect = "kaleid"    }
        QQC2.MenuItem { text: i18n("Nova");          onTriggered: Plasmoid.configuration.effect = "nova"      }
        QQC2.MenuItem { text: i18n("Galaxy");        onTriggered: Plasmoid.configuration.effect = "galaxy"    }
        QQC2.MenuItem { text: i18n("Aurora");        onTriggered: Plasmoid.configuration.effect = "aurora"    }
        QQC2.MenuItem { text: i18n("Mandala");       onTriggered: Plasmoid.configuration.effect = "mandala"   }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("LED Meter");     onTriggered: Plasmoid.configuration.effect = "led"       }
        QQC2.MenuItem { text: i18n("Discharge");     onTriggered: Plasmoid.configuration.effect = "discharge" }
        QQC2.MenuItem { text: i18n("Lightning");     onTriggered: Plasmoid.configuration.effect = "lightning" }
        QQC2.MenuItem { text: i18n("Concert");       onTriggered: Plasmoid.configuration.effect = "concert"   }
        QQC2.MenuItem { text: i18n("Pyrotechnics");  onTriggered: Plasmoid.configuration.effect = "pyro"      }
    }
}

