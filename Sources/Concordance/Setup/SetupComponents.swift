import AppKit
import ConcordanceCore
import SwiftUI

// MARK: - Background

/// Out-of-focus light in Everpaper's hues drifting behind the glass, over a thin warm wash. The window behind it is
/// itself a behind-window blur, so the desktop shows through, softened.
struct GlassBackdrop: View {
    var glow: Color = Paper.tint

    private struct Orb {
        let color: Color
        let size: CGFloat
        let x: Double, y: Double         // resting position, 0…1
        let dx: Double, dy: Double       // drift amplitude, 0…1
        let speed: Double, phase: Double
    }

    private var orbs: [Orb] {
        [
            Orb(color: glow, size: 520, x: 0.30, y: 0.30, dx: 0.10, dy: 0.08, speed: 0.11, phase: 0),
            Orb(color: Paper.ochre, size: 440, x: 0.80, y: 0.75, dx: 0.08, dy: 0.10, speed: 0.09, phase: 1.7),
            Orb(color: Paper.rose, size: 380, x: 0.85, y: 0.15, dx: 0.07, dy: 0.06, speed: 0.13, phase: 3.1),
            Orb(color: Paper.clay, size: 420, x: 0.10, y: 0.90, dx: 0.09, dy: 0.05, speed: 0.08, phase: 4.4),
            Orb(color: Paper.plum, size: 300, x: 0.55, y: 0.95, dx: 0.12, dy: 0.04, speed: 0.15, phase: 2.2),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(Array(orbs.enumerated()), id: \.offset) { _, orb in
                        Circle()
                            .fill(orb.color)
                            .frame(width: orb.size, height: orb.size)
                            .position(x: geo.size.width * (orb.x + orb.dx * sin(t * orb.speed + orb.phase)),
                                      y: geo.size.height * (orb.y + orb.dy * cos(t * orb.speed * 1.3 + orb.phase)))
                    }
                }
                .opacity(0.55)
                .blur(radius: 90)
            }
            .animation(.easeInOut(duration: 1.4), value: glow)
        }
        .background(Paper.canvas.opacity(0.45))
        .ignoresSafeArea()
    }
}

// MARK: - Keycaps

/// A glass keycap: interactive Liquid Glass, tinted when it glows, sinking a little when pressed.
struct KeyCap: View {
    let label: String
    var size: CGFloat = 64
    var pressed = false
    var glow: Color?

    var body: some View {
        let isWord = label.count > 1
        Text(label)
            .font(.system(size: isWord ? size * 0.28 : size * 0.42, weight: .medium, design: .rounded))
            .foregroundStyle(Paper.inkPrimary)
            .frame(minWidth: isWord ? size * 2.4 : size, minHeight: size)
            .glassEffect(.regular.tint(glow?.opacity(0.45) ?? Paper.glassTint).interactive(),
                         in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .shadow(color: (glow ?? .black).opacity(glow == nil ? 0.12 : 0.45), radius: glow == nil ? 10 : 22,
                    y: pressed ? 1 : 6)
            .scaleEffect(pressed ? 0.93 : 1)
            .offset(y: pressed ? 3 : 0)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: pressed)
    }
}

struct KeyCapRow: View {
    let combo: HotKeyCombo
    var size: CGFloat = 64
    var pressed = false
    var glow: Color?

    var body: some View {
        GlassEffectContainer(spacing: size * 0.18) {
            HStack(spacing: size * 0.18) {
                ForEach(Array(combo.symbols.enumerated()), id: \.offset) { offset, symbol in
                    KeyCap(label: symbol, size: size, pressed: pressed, glow: glow)
                        .animation(.spring(duration: 0.3, bounce: 0.5).delay(Double(offset) * 0.04), value: pressed)
                }
            }
        }
    }
}

// MARK: - Neural Engine field

/// A grid of "neurons" inked in rubric and ochre: a faint shimmer at rest, travelling waves while the model is
/// prepared, a steady success-green glow once it is ready.
struct NeuralField: View {
    var activity: Double   // 0 … 1
    var done: Bool

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { g, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let cols = 20, rows = 11
                let dx = size.width / Double(cols), dy = size.height / Double(rows)
                var levels = Array(repeating: Array(repeating: 0.0, count: rows), count: cols)
                for i in 0..<cols {
                    for j in 0..<rows {
                        let wave = sin(Double(i) * 0.55 - t * 2.6 + sin(Double(j) * 0.7 + t * 0.8) * 1.3) * 0.5 + 0.5
                        let shimmer = sin(t * 1.3 + Double(i * 7 + j * 13)) * 0.5 + 0.5
                        levels[i][j] = done
                            ? 0.45 + 0.25 * (sin(t * 1.6 + Double(i + j) * 0.35) * 0.5 + 0.5)
                            : 0.08 + 0.1 * shimmer + activity * pow(wave, 4) * 0.82
                    }
                }
                func point(_ i: Int, _ j: Int) -> CGPoint {
                    CGPoint(x: (Double(i) + 0.5) * dx, y: (Double(j) + 0.5) * dy)
                }
                func color(_ i: Int) -> Color {
                    done ? Paper.success : (i * 2 < cols ? Paper.tint : Paper.ochre)
                }
                for i in 0..<cols {
                    for j in 0..<rows {
                        for (ni, nj) in [(i + 1, j), (i, j + 1)] where ni < cols && nj < rows {
                            let strength = min(levels[i][j], levels[ni][nj])
                            guard strength > 0.3 else { continue }
                            var line = Path()
                            line.move(to: point(i, j))
                            line.addLine(to: point(ni, nj))
                            g.stroke(line, with: .color(color(i).opacity(strength * 0.35)), lineWidth: 1)
                        }
                    }
                }
                for i in 0..<cols {
                    for j in 0..<rows {
                        let level = levels[i][j]
                        let p = point(i, j)
                        let r = 1.6 + level * 3.2
                        if level > 0.5 {
                            let halo = r * 3
                            g.fill(Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)),
                                   with: .color(color(i).opacity((level - 0.5) * 0.22)))
                        }
                        g.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                               with: .color(color(i).opacity(0.2 + level * 0.8)))
                    }
                }
            }
        }
    }
}

// MARK: - Hero mark

/// The Concordance mark on a disc of glass, a slow ring of Everpaper's warm hues turning behind it.
struct HeroOrb: View {
    var size: CGFloat = 150

    var body: some View {
        TimelineView(.animation) { context in
            let angle = Angle.degrees(context.date.timeIntervalSinceReferenceDate * 30)
            let ring = AngularGradient(colors: [Paper.tint, Paper.ochre, Paper.rose, Paper.clay, Paper.tint],
                                       center: .center, angle: angle)
            ZStack {
                Circle().fill(ring).frame(width: size * 1.05, height: size * 1.05).blur(radius: size * 0.16)
                    .opacity(0.85)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: size * 0.38, weight: .regular))
                    .foregroundStyle(Paper.inkPrimary)
                    .symbolEffect(.breathe)
                    .frame(width: size, height: size)
                    .glassEffect(.regular.tint(Paper.glassTint).interactive(), in: Circle())
            }
        }
        .frame(width: size * 1.3, height: size * 1.3)
    }
}

// MARK: - Welcome demo

/// A search well that types example queries and shows what Concordance finds for them.
struct DemoSearchBar: View {
    private struct Example {
        let query: String
        let title: String
        let kind: String
        let app: String?
        let symbol: String?
    }

    private let examples = [
        Example(query: "turn off the sound", title: "Toggle Mute", kind: "Command", app: nil, symbol: "speaker.slash.fill"),
        Example(query: "write an email", title: "Mail", kind: "Application", app: "/System/Applications/Mail.app", symbol: nil),
        Example(query: "the wifi isn't working", title: "Wi-Fi", kind: "System Settings",
                app: "/System/Applications/System Settings.app", symbol: nil),
        Example(query: "edit my pictures", title: "Photos", kind: "Application", app: "/System/Applications/Photos.app", symbol: nil),
        Example(query: "free up disk space", title: "Storage", kind: "System Settings",
                app: "/System/Applications/System Settings.app", symbol: nil),
    ]

    @State private var typed = ""
    @State private var shown: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Paper.inkTertiary)
                HStack(spacing: 1) {
                    Text(typed.isEmpty ? " " : typed).font(Paper.serif(18)).foregroundStyle(Paper.inkPrimary)
                    Rectangle().fill(Paper.tint).frame(width: 1.5, height: 19)
                        .phaseAnimator([1.0, 0.0]) { $0.opacity($1) } animation: { _ in .easeInOut(duration: 0.5) }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)

            if let shown {
                let example = examples[shown]
                HStack(spacing: 12) {
                    icon(for: example).frame(width: 28, height: 28)
                    Text(example.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Paper.inkPrimary)
                    Spacer()
                    Image(systemName: "sparkle").font(.system(size: 11)).foregroundStyle(Paper.tint)
                    Text(example.kind).font(.system(size: 12)).foregroundStyle(Paper.inkTertiary)
                }
                .padding(.horizontal, 10)
                .frame(height: 44)
                .glassEffect(.regular.tint(Paper.selectionGlass), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(8)
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(width: 460)
        .glassPane(radius: 22, padding: 0)
        .task { await loop() }
    }

    @ViewBuilder private func icon(for example: Example) -> some View {
        if let app = example.app {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app)).resizable()
        } else {
            Image(systemName: example.symbol ?? "sparkle")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Paper.panelRaised)
                .frame(width: 28, height: 28)
                .background(Paper.slate, in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private func loop() async {
        var index = 0
        while !Task.isCancelled {
            let example = examples[index % examples.count]
            for ch in example.query {
                typed.append(ch)
                try? await Task.sleep(for: .milliseconds(Int.random(in: 45...85)))
            }
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.spring(duration: 0.45, bounce: 0.25)) { shown = index % examples.count }
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.25)) { shown = nil }
            while !typed.isEmpty {
                typed.removeLast()
                try? await Task.sleep(for: .milliseconds(18))
            }
            try? await Task.sleep(for: .milliseconds(350))
            index += 1
        }
    }
}

// MARK: - Shortcut recording

@MainActor @Observable
final class ShortcutRecorder {
    private(set) var isRecording = false
    @ObservationIgnored var onRecord: ((HotKeyCombo) -> Void)?
    @ObservationIgnored private var monitor: Any?

    func toggle() { isRecording ? stop() : start() }

    func start() {
        guard !isRecording else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { self.stop(); return nil }   // esc cancels
            if let combo = HotKeyCombo(event: event) {
                self.onRecord?(combo)
                self.stop()
            }
            return nil
        }
    }

    func stop() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// Status line under a shortcut: conflicts (always glyph + words, never hue alone), or that it is free.
struct ShortcutStatus: View {
    let conflicts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if conflicts.isEmpty {
                Label("Free on this Mac", systemImage: "checkmark.circle.fill").foregroundStyle(Paper.success)
            } else {
                ForEach(conflicts, id: \.self) { conflict in
                    Label(conflict.prefix(1).uppercased() + conflict.dropFirst(), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Paper.warning)
                }
            }
        }
        .font(.system(size: 13))
    }
}
