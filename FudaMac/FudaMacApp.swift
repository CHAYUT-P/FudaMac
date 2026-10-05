import SwiftUI

@main
struct FudaMacApp: App {
    // The DEBUG screenshot walkthrough keeps its own files so it never touches real progress.
    private static let shots = UserDefaults.standard.string(forKey: "FudaShots") != nil
    @State private var store = ProgressStore(filename: shots ? "shots-progress.json" : "progress.json")
    @State private var course = CourseProgress(filename: shots ? "shots-course-progress.json" : "course-progress.json")
    @State private var router = MacRouter()

    init() {
        _ = DB.shared
        _ = Course.shared
    }

    var body: some Scene {
        WindowGroup("札 Fuda") {
            MacRoot()
                .environment(store)
                .environment(course)
                .environment(router)
                .preferredColorScheme(store.settings.appearance.scheme)
                .tint(Ink.akane)
                .frame(minWidth: 1100, minHeight: 720)
                .onAppear {
                    Speech.shared.rate = Float(store.settings.speechRate)
                    #if DEBUG
                    MacShots.runIfRequested(router: router, store: store, course: course)
                    #endif
                }
                .onChange(of: store.settings.speechRate) { _, r in Speech.shared.rate = Float(r) }
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandMenu("Go") {
                ForEach(MacSection.allCases) { s in
                    Button(s.title) { router.section = s }
                        .keyboardShortcut(s.shortcut, modifiers: .command)
                }
            }
            CommandGroup(after: .textEditing) {
                Button("Search Everything") { router.section = .dictionary }
                    .keyboardShortcut("k", modifiers: .command)
            }
        }

        SwiftUI.Settings {
            MacSettingsView()
                .environment(store)
                .environment(course)
                .frame(width: 520, height: 560)
        }
    }
}

// MARK: - Navigation

enum MacSection: String, CaseIterable, Identifiable {
    case today, course, decks, practice, talk, read, essentials, dictionary, progress
    var id: String { rawValue }
    var glyph: String {
        switch self {
        case .today: "今"; case .course: "道"; case .decks: "札"; case .practice: "練"; case .talk: "話"
        case .read: "読"; case .essentials: "基"; case .dictionary: "辞"; case .progress: "績"
        }
    }
    var title: String {
        switch self {
        case .today: "Today"; case .course: "Course"; case .decks: "Decks"; case .practice: "Practice"
        case .talk: "Conversations"; case .read: "Stories"; case .essentials: "Essentials"
        case .dictionary: "Dictionary"; case .progress: "Progress"
        }
    }
    var group: String {
        switch self {
        case .today, .course, .decks, .practice: "STUDY"
        case .talk, .read: "LISTEN & READ"
        case .essentials, .dictionary, .progress: "REFERENCE"
        }
    }
    var shortcut: KeyEquivalent {
        KeyEquivalent(Character(String(MacSection.allCases.firstIndex(of: self)! + 1)))
    }
}

@Observable
final class MacRouter {
    var section: MacSection = .today
    var lessonN: Int?                    // open lesson in the Course section
    var step: LessonStep = .learn
    var learnPoint = 0                   // selected grammar point in Learn
    var learnMode: LearnMode = .lesson
    var debugBeat = 0                    // DEBUG walkthrough: open the lesson player at this beat
    var drillTab = "A"                   // 練習 A / B / C tab in textbook lessons
    var notesSection: Int?               // 文法: scroll to this grammar section when opened
    var typing = false                   // a text field is being edited: Esc / ⌘→ belong to it
    var deckCategory: Category?
    var talkID: String?
    var storyKey: String?
    var essentialID = 1
    var query = ""

    var study: StudySession?
    var quiz: QuizSession?
    var quizLesson: Int?                 // set when the quiz is a lesson test

    func openLesson(_ n: Int, step: LessonStep? = nil) {
        section = .course
        if lessonN != n { learnPoint = 0; drillTab = "A" }
        lessonN = n
        if let step { self.step = step }
    }

    func startStudy(_ title: String, cards: [Card], direction: StudyDirection = .recognition, store: ProgressStore) {
        guard !cards.isEmpty else { return }
        study = StudySession(title: title, cards: cards, direction: direction, store: store)
    }

    func startQuiz(_ title: String, cards: [Card], mode: QuizMode = .mixed, count: Int = 10, lessonTest: Int? = nil, store: ProgressStore) {
        let qs = QuizBuilder.make(from: cards, count: count, mode: mode)
        guard !qs.isEmpty else { return }
        quizLesson = lessonTest
        quiz = QuizSession(title: title, questions: qs, store: store)
    }
}

// MARK: - Root

struct MacRoot: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        HStack(spacing: 0) {
            MacSidebar()
            Rectangle().fill(Ink.ink).frame(width: 2)
            Group {
                switch router.section {
                case .today: MacTodayView()
                case .course: MacCourseView()
                case .decks: MacDecksView()
                case .practice: MacPracticeView()
                case .talk: MacTalkView()
                case .read: MacStoriesView()
                case .essentials: MacEssentialsView()
                case .dictionary: MacDictionaryView()
                case .progress: MacProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Ink.paper)
        }
        .background(Ink.paper)
        .sheet(item: $router.study) { s in
            MacStudyView(session: s).frame(minWidth: 1000, minHeight: 720)
        }
        .sheet(item: $router.quiz) { q in
            MacQuizView(session: q, lessonTest: router.quizLesson).frame(minWidth: 900, minHeight: 680)
        }
    }
}

struct MacSidebar: View {
    @Environment(ProgressStore.self) private var store
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("札").font(Typo.mincho(22)).foregroundStyle(Ink.onAkane)
                    .frame(width: 34, height: 34).background(Ink.akane)
                    .overlay(Rectangle().strokeBorder(Ink.onAkane, lineWidth: 1).padding(2))
                VStack(alignment: .leading, spacing: 1) {
                    Text("FUDA").font(.system(size: 13, weight: .heavy)).tracking(4)
                    Text("FOR MAC").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(Ink.soft)
                }
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)

            Button { router.section = .dictionary } label: {
                HStack {
                    Text("Search everything").font(Typo.ui(13)).foregroundStyle(Ink.soft)
                    Spacer()
                    Kbd("⌘K")
                }
                .padding(.horizontal, 10).frame(height: 32)
                .background(Ink.paper)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(["STUDY", "LISTEN & READ", "REFERENCE"], id: \.self) { g in
                        Text(g).font(.system(size: 10, weight: .heavy)).tracking(2.2).foregroundStyle(Ink.soft)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
                        ForEach(MacSection.allCases.filter { $0.group == g }) { s in item(s) }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TrackedLabel(text: "Level", size: 10)
                    Spacer()
                    Segmented(options: Level.allCases.map { ($0, $0.title) }, selection: $store.settings.level, height: 26)
                }
                HStack {
                    (Text("連続 ") + Text("\(store.streak)日").foregroundColor(Ink.akane)).font(Typo.ui(13, .heavy))
                    Spacer()
                    WeekDots()
                }
            }
            .padding(14)
            .overlay(alignment: .top) { Rectangle().fill(Ink.ink).frame(height: 2) }
        }
        .frame(width: 240)
        .background(Ink.chip.opacity(0.6))
        .foregroundStyle(Ink.ink)
    }

    private func badge(_ s: MacSection) -> (String, Bool)? {
        switch s {
        case .today: let d = store.dueCount(); return d > 0 ? ("\(d)", true) : nil
        case .course: return course.currentLesson.map { ("L\($0.n)", false) }
        case .talk: return ("\(Talk.scenes.count)", false)
        case .read: return ("\(Course.shared.stories.count)", false)
        case .essentials: return ("\(Essentials.chapters.count)", false)
        default: return nil
        }
    }

    private func item(_ s: MacSection) -> some View {
        let on = router.section == s
        return Button { router.section = s } label: {
            HStack(spacing: 10) {
                Text(s.glyph).font(Typo.mincho(18)).foregroundStyle(on ? Color(hex: 0xE5605B) : Ink.ink).frame(width: 22)
                Text(s.title).font(Typo.ui(14, .bold))
                Spacer()
                if let (text, hot) = badge(s) {
                    Text(text).font(.system(size: 11, weight: .heavy))
                        .padding(.horizontal, hot ? 6 : 0).padding(.vertical, 1)
                        .foregroundStyle(hot ? Ink.onAkane : on ? Ink.line : Ink.soft)
                        .background(hot ? Ink.akane : .clear)
                }
            }
            .padding(.horizontal, 10).frame(height: 34)
            .foregroundStyle(on ? Ink.onInk : Ink.ink)
            .background(on ? Ink.ink : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct WeekDots: View {
    @Environment(ProgressStore.self) private var store
    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let wd = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -wd, to: today)!
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                let d = cal.date(byAdding: .day, value: i, to: monday)!
                let did = store.stat(on: d).reviews > 0
                Rectangle().fill(did ? Ink.ink : .clear)
                    .frame(width: 12, height: 12)
                    .overlay(Rectangle().strokeBorder(d == today && !did ? Ink.akane : did ? Ink.ink : Ink.line, lineWidth: d == today ? 2 : 1.5))
            }
        }
    }
}
