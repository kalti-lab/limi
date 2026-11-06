import SwiftUI
private struct SlotFrames: PreferenceKey {
    static var defaultValue: [Int: CGRect] { [:] }
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct GroupFrames: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct MenuBarSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var groupDrag: GroupDragPreview?
    @State private var settlingGroupDrag = false
    @State private var groupFrames: [UUID: CGRect] = [:]
    private var groups: [MenuBarLayout] { store.displayConfiguration.effectiveLayouts }
    private var selected: MenuBarLayout? { groups.first { $0.id == store.selectedMenuBarGroupID } ?? groups.first }
    // Settings scrolls and pads every tab, so this is only the content.
    var body: some View {
        VStack(alignment: .leading, spacing: SettingsStyle.sectionSpacing) {
            // Guidance for a first setup; once lines exist the editor speaks for itself.
            if groups.allSatisfy({ $0.rows.isEmpty }) {
                Text("Each group is one item in the menu bar and shows up to three usage lines from any of your accounts. Select a group tab to edit it.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Titled blocks like the other tabs' sections: what the menu bar will
            // look like, then the groups that make it up, each tab one item.
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionTitle("Menu bar preview")
                MenuBarPreview(groups: groups, selectedID: selected?.id)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    SettingsSectionTitle("Groups")
                    if !store.edition.customizesMenuBar { ProBadge() }
                }
                if !store.edition.customizesMenuBar {
                    Label("Customizing the menu bar is available in AgentBar Pro.", systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.leading, SettingsStyle.rowInsets.leading)
                }
                VStack(alignment: .leading, spacing: 0) {
                    groupTabs
                    if let selected { MenuBarGroupEditor(group: selected).id(selected.id) }
                    else {
                        Text("Add a group, then add a line for each usage limit you want to see.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(SettingsStyle.sectionFill,
                                        in: RoundedRectangle(cornerRadius: SettingsStyle.cornerRadius, style: .continuous))
                    }
                }
                .disabled(!store.edition.customizesMenuBar)
            }
            if store.displayWidthWarning { Text("These groups use a large portion of the menu bar.").font(.caption).foregroundStyle(.orange) }
        }
        .onDisappear { groupDrag = nil; settlingGroupDrag = false }
    }

    // Groups are tabs sitting on the editor below, so the selected one reads as "this group".
    private var groupTabs: some View {
        HStack(spacing: 2) {
            ForEach(groups) { group in
                Button { store.selectMenuBarGroup(group.id) } label: {
                    groupLabel(group)
                }
                .buttonStyle(GroupTabStyle(selected: selected?.id == group.id))
                .help(group.enabled ? Text("\(group.name) · Drag to reorder") : Text("\(group.name) · hidden · Drag to reorder"))
                .accessibilityAddTraits(selected?.id == group.id ? .isSelected : [])
                .highPriorityGesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("group-order"))
                    .onChanged { value in
                        guard !settlingGroupDrag else { return }
                        if groupDrag == nil {
                            groupDrag = GroupDragPreview(source: group.id, order: groups.map(\.id), frames: groupFrames,
                                                         location: value.location, translation: value.translation)
                        } else {
                            groupDrag?.location = value.location
                            groupDrag?.translation = value.translation
                        }
                    }
                    .onEnded { finishGroupDrag(at: $0.location) })
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: GroupFrames.self, value: [group.id: proxy.frame(in: .named("group-order"))])
                })
                .opacity(groupDrag?.source == group.id ? 0 : 1)
                .offset(groupDrag?.offset(for: group.id) ?? .zero)
                .animation(.snappy(duration: 0.18), value: groupDrag?.target)
            }
            Button {
                let group = MenuBarLayout(name: String(localized: "Group \(groups.count + 1)"))
                store.updateDisplay { $0.editLayouts { $0.append(group) } }
                store.selectMenuBarGroup(group.id)
            } label: { Image(systemName: "plus") }
                .buttonStyle(GroupTabStyle(selected: false))
                .help("Add Group")
                .accessibilityLabel("Add Group")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .coordinateSpace(name: "group-order")
        .onPreferenceChange(GroupFrames.self) { groupFrames = $0 }
        .overlay(alignment: .topLeading) { groupDragOverlay.allowsHitTesting(false) }
        .zIndex(groupDrag == nil ? 0 : 1)
    }

    private func groupLabel(_ group: MenuBarLayout) -> some View {
        HStack(spacing: 4) {
            if !group.enabled { Image(systemName: "eye.slash") }
            if group.name.isEmpty { Text("Untitled").lineLimit(1) } else { Text(verbatim: group.name).lineLimit(1) }
        }
    }

    @ViewBuilder private var groupDragOverlay: some View {
        if let drag = groupDrag, let group = groups.first(where: { $0.id == drag.source }) {
            DragSlotPlaceholder()
                .frame(width: drag.placeholder.width, height: drag.placeholder.height)
                .offset(x: drag.placeholder.minX, y: drag.placeholder.minY)
                .animation(.snappy(duration: 0.18), value: drag.target)
            groupLabel(group)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .frame(width: drag.floatingFrame.width, height: drag.floatingFrame.height)
                .modifier(FloatingDragCard(settling: settlingGroupDrag))
                .offset(x: drag.floatingFrame.minX, y: drag.floatingFrame.minY)
                .accessibilityHidden(true)
        }
    }

    private func finishGroupDrag(at point: CGPoint) {
        guard var drag = groupDrag, !settlingGroupDrag else { return }
        drag.location = point
        let target = drag.target
        groupDrag = drag
        withAnimation(.easeOut(duration: 0.16)) {
            settlingGroupDrag = true
            groupDrag?.translation = drag.landingTranslation
        } completion: {
            guard groupDrag?.source == drag.source else { return }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let target, groups.map(\.id) == drag.order { store.moveMenuBarGroup(drag.source, to: target) }
                groupDrag = nil
                settlingGroupDrag = false
            }
        }
    }
}

private struct MenuBarGroupEditor: View {
    @EnvironmentObject private var store: UsageStore
    let group: MenuBarLayout
    @State private var deleting = false
    @State private var lineDrag: ReorderDragPreview<Int>?
    @State private var draggedLineID: String?
    @State private var originalDragRows: [MenuBarLine] = []
    @State private var settlingLineDrag = false
    @State private var slotFrames: [Int: CGRect] = [:]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // The name is also the menu bar badge, so there is one field for both.
            HStack(spacing: 8) {
                LabeledContent("Name") {
                    TextField("Name", text: Binding(get: { group.name }, set: { text in
                        store.updateDisplay { $0.editLayout(group.id) { $0.name = String(text.prefix(MenuBarLayout.nameLimit)) } }
                    })).labelsHidden()
                }
                Menu {
                    Button("Delete Group…", role: .destructive) { deleting = true }
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .help("Group options")
            }
            HStack(spacing: 16) {
                Toggle("Show in menu bar", isOn: binding(\.enabled))
                Toggle("Show name", isOn: Binding(get: { group.effectiveBadgeMode.includesCommon }, set: { on in
                    store.updateDisplay { $0.editLayout(group.id) { $0.badgeMode = on ? .common : BadgeDisplayMode.none } }
                })).help("Show the group name in front of its usage in the menu bar.")
                Spacer(minLength: 0)
            }.toggleStyle(.checkbox)
            HStack(spacing: 6) {
                ForEach(MenuBarStyle.selectableCases) { style in
                    Button {
                        store.updateDisplay { $0.editLayout(group.id) {
                            $0.style = style
                            if style == .bars { $0.showBar = true }
                            if style == .text { $0.showPercent = true }
                        } }
                    } label: {
                        VStack(spacing: 6) {
                            StyleSymbol(style: style).frame(height: 24).accessibilityHidden(true)
                            Text(style.title).font(.caption).lineLimit(1)
                        }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChoiceButtonStyle(selected: group.style.selection == style))
                    .disabled(style != .text && group.style == .text && group.rows.count > MenuBarLayout.maximumLines)
                    .help(style != .text && group.style == .text && group.rows.count > MenuBarLayout.maximumLines
                          ? String(localized: "Remove values until three remain to use this style.") : style.summary)
                    .accessibilityLabel(style.title)
                    .accessibilityAddTraits(group.style.selection == style ? .isSelected : [])
                }
            }
            if group.style == .text && group.rows.count > MenuBarLayout.maximumLines {
                Text("Remove values until three remain to switch styles.").font(.caption).foregroundStyle(.secondary)
            }
            if !group.showsAnything { Text("All components are off. This group is hidden and its refresh is paused.").font(.caption).foregroundStyle(.secondary) }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text(usageLinesTitle).font(.headline)
                if let hint = usageLinesHint {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !group.rows.isEmpty {
                // Column titles line up with each line's account and limit buttons.
                HStack(spacing: 6) {
                    if group.style != .ring { Color.clear.frame(width: 14, height: 1) }
                    Text("Account").frame(width: 150, alignment: .leading)
                    Text("Limit").frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: MenuBarLineEditor.removeWidth, height: 1)
                }
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.bottom, -8)
                .accessibilityHidden(true)
            }
            ForEach(0..<editorSlotCount, id: \.self) { slot in
                VStack(spacing: 0) {
                if let index = lineIndex(for: slot) {
                    lineEditor(at: index)
                        .frame(minHeight: 44)
                } else {
                    Button { addLine(in: slot) } label: {
                        Image(systemName: "plus").font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                        .accessibilityLabel("Add usage line \(slot + 1)")
                        .help("Add usage line \(slot + 1)")
                        .disabled(store.orderedAccounts.isEmpty)
                }
                }
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: SlotFrames.self, value: [slot: proxy.frame(in: .named(group.id))])
                })
                .opacity(lineDrag?.source == slot ? 0 : 1)
                .offset(lineDrag?.offset(for: slot) ?? .zero)
                .animation(.snappy(duration: 0.18), value: lineDrag?.target)
            }
            // The one place a group's percentage is chosen, under the lines it
            // picks from: the menu names them as they read now and follows a
            // line through edits and drags. Capsule Fill and Text Only always
            // show theirs.
            if group.style == .bars && !group.displayedRows.isEmpty {
                Picker("Percentage", selection: Binding(get: { group.shownPercentageLineID }, set: { id in
                    store.updateDisplay { $0.editLayout(group.id) { $0.showPercentage(of: id) } }
                })) {
                    Text("Hidden").tag(String?.none)
                    ForEach(percentageChoices, id: \.id) { choice in Text(choice.title).tag(Optional(choice.id)) }
                }
                .fixedSize()
                .help("The line whose percentage appears beside the bars.")
            } else if group.style == .ring && !group.rows.isEmpty {
                Toggle("Percentage", isOn: binding(\.showPercent)).toggleStyle(.checkbox)
            }
            if store.orderedAccounts.isEmpty { Text("Add an account in the Accounts tab first.").font(.caption).foregroundStyle(.secondary) }
        }.padding(14).background(SettingsStyle.sectionFill,
                                 in: RoundedRectangle(cornerRadius: SettingsStyle.cornerRadius, style: .continuous))
        .coordinateSpace(name: group.id)
        .onPreferenceChange(SlotFrames.self) { slotFrames = $0 }
        .overlay(alignment: .topLeading) { lineDragOverlay.allowsHitTesting(false) }
        .onDisappear { clearLineDrag() }
        .alert("Delete \(group.name)?", isPresented: $deleting) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { store.updateDisplay { $0.editLayouts { $0.removeAll { $0.id == group.id } } } }
        } message: { Text("Only this display group is removed. Its accounts remain available. To keep its layout for later, turn off Show in menu bar instead.") }
    }
    private var editorSlotCount: Int {
        if group.style == .ring { return 1 }
        if group.style == .text { return group.rows.count + 1 }
        return MenuBarLayout.maximumLines
    }
    private var usageLinesTitle: String {
        if group.style == .ring { return String(localized: "Usage line") }
        if group.style == .text { return String(localized: "Usage values · \(group.rows.count)") }
        return String(localized: "Usage lines · \(group.rows.count)/\(MenuBarLayout.maximumLines)")
    }
    // Shown only while there is something to learn: an empty group, or lines
    // that Ring Gauge leaves out.
    private var usageLinesHint: String? {
        if group.style == .ring && group.rows.count > 1 {
            return String(localized: "Ring Gauge shows only the first line. Choose Multi Bar or Capsule Fill for up to three lines, or Text Only for more.")
        }
        guard group.rows.isEmpty else { return nil }
        switch group.style {
        case .ring: return String(localized: "Ring Gauge shows a single line. Click + to choose it.")
        case .text: return String(localized: "Each value can come from any account. Click + to add one.")
        default: return String(localized: "Each line shows one limit of one account; lines can come from different accounts. Click + in an empty slot to add a line.")
        }
    }
    private func lineIndex(for slot: Int) -> Int? {
        if group.style == .ring, let line = group.displayedRows.first {
            return group.rows.firstIndex { $0.id == line.id }
        }
        return group.rows.indices.first { (group.rows[$0].slot ?? $0) == slot }
    }
    /// Each shown line as the Percentage menu names it: account and limit, with
    /// the line number only where two lines would read the same.
    private var percentageChoices: [(id: String, title: String)] {
        let titles = group.displayedRows.map { row -> String in
            let account = store.accounts.first { $0.id == row.accountID }
            let metric = account.flatMap { account in DisplayMetric.all(store.snapshot(for: account)).first { $0.id == row.metricID } }
            return "\(account.map { store.accountLabel(for: $0) } ?? String(localized: "Account")) · \(metric?.choiceTitle ?? row.metricID)"
        }
        return zip(group.displayedRows, titles).enumerated().map { index, pair in
            (pair.0.id, titles.filter { $0 == pair.1 }.count > 1 ? String(localized: "\(pair.1) (line \(index + 1))") : pair.1)
        }
    }
    private func lineEditor(at index: Int, preview: Bool = false) -> some View {
        let line = group.rows[index]
        return MenuBarLineEditor(groupID: group.id, line: line, index: index,
            allowsDragging: group.style != .ring,
            dragChanged: { value in
                if !preview { updateLineDrag(line.id, slot: line.slot ?? index, value: value) }
            },
            dragEnded: { point in if !preview { finishLineDrag(at: point) } })
    }

    @ViewBuilder private var lineDragOverlay: some View {
        if let drag = lineDrag, let index = group.rows.firstIndex(where: { $0.id == draggedLineID }) {
            DragSlotPlaceholder(cornerRadius: 8)
                .frame(width: drag.placeholder.width, height: drag.placeholder.height)
                .offset(x: drag.placeholder.minX, y: drag.placeholder.minY)
                .animation(.snappy(duration: 0.18), value: drag.target)
            lineEditor(at: index, preview: true)
                .frame(width: drag.floatingFrame.width, height: drag.floatingFrame.height)
                .modifier(FloatingDragCard(settling: settlingLineDrag, liftScale: 1.02))
                .offset(x: drag.floatingFrame.minX, y: drag.floatingFrame.minY)
        }
    }

    private func updateLineDrag(_ id: String, slot: Int, value: DragGesture.Value) {
        guard !settlingLineDrag else { return }
        if lineDrag == nil {
            // The trailing plus in Text Only creates a new line, not a reorder slot.
            let count = group.style == .text ? group.rows.count : editorSlotCount
            lineDrag = ReorderDragPreview(source: slot, order: Array(0..<count), frames: slotFrames,
                                          location: value.location, translation: value.translation,
                                          behavior: .swap, hitPadding: CGSize(width: 3, height: 7))
            draggedLineID = id
            originalDragRows = group.rows
        } else {
            lineDrag?.location = value.location
            lineDrag?.translation = value.translation
        }
    }

    private func finishLineDrag(at point: CGPoint) {
        guard var drag = lineDrag, let id = draggedLineID, !settlingLineDrag else { return }
        drag.location = point
        let target = drag.target
        lineDrag = drag
        withAnimation(.easeOut(duration: 0.16)) {
            settlingLineDrag = true
            lineDrag?.translation = drag.landingTranslation
        } completion: {
            guard draggedLineID == id else { return }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let target, group.rows == originalDragRows {
                    store.updateDisplay { $0.editLayout(group.id) { $0.moveLine(id, offset: target - drag.source) } }
                }
                clearLineDrag()
            }
        }
    }

    private func clearLineDrag() {
        lineDrag = nil
        draggedLineID = nil
        originalDragRows = []
        settlingLineDrag = false
    }
    private func addLine(in slot: Int) {
        let preferredID = group.rows.last?.accountID
        guard let account = store.orderedAccounts.first(where: { $0.id == preferredID }) ?? store.orderedAccounts.first else { return }
        store.updateDisplay { config in
            config.setVisible(account.id, true)
            let badge = config.display(account).badge
            config.editLayout(group.id) { layout in
                guard (layout.style == .text || layout.rows.count < MenuBarLayout.maximumLines),
                      !layout.rows.contains(where: { $0.slot == slot }) else { return }
                layout.rows.append(MenuBarLine(accountID: account.id, metricID: "weekly", slot: slot, badgeText: badge))
                layout.rows.sort { ($0.slot ?? 0) < ($1.slot ?? 0) }
            }
        }
    }
    private func binding<Value>(_ key: WritableKeyPath<MenuBarLayout, Value>) -> Binding<Value> {
        Binding(get: { group[keyPath: key] }, set: { value in
            store.updateDisplay { $0.editLayout(group.id) { $0[keyPath: key] = value } }
        })
    }
}

private struct MenuBarLineEditor: View {
    @EnvironmentObject private var store: UsageStore
    let groupID: UUID
    let line: MenuBarLine
    let index: Int
    let allowsDragging: Bool
    let dragChanged: (DragGesture.Value) -> Void
    let dragEnded: (CGPoint) -> Void
    /// Fixed so the column titles above can line up with the remove button.
    static let removeWidth: CGFloat = 18
    private var account: UsageAccount? { store.accounts.first { $0.id == line.accountID } }
    private var metrics: [DisplayMetric] {
        account.map { DisplayMetric.all(store.snapshot(for: $0)) } ?? []
    }
    var body: some View {
        HStack(spacing: 6) {
            if allowsDragging {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(width: 14, height: 22).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .named(groupID))
                        .onChanged(dragChanged)
                        .onEnded { dragEnded($0.location) })
                    .help("Drag to another slot")
                    .accessibilityLabel("Move usage line \((line.slot ?? index) + 1)")
                    .accessibilityAction(named: "Move up") { move(-1) }
                    .accessibilityAction(named: "Move down") { move(1) }
            }
            // The mark says which provider the chosen account belongs to; the
            // provider's name is added only to accounts named something else.
            HStack(spacing: 5) {
                if let account { ProviderMark(provider: account.provider, size: 16) }
                Picker("Account", selection: Binding(get: { line.accountID }, set: { id in
                    store.updateDisplay { config in
                        config.setVisible(id, true)
                        config.editLayout(groupID) { group in
                            guard let i = group.rows.firstIndex(where: { $0.id == line.id }) else { return }
                            group.rows[i].accountID = id
                            if let account = store.accounts.first(where: { $0.id == id }),
                               !DisplayMetric.all(store.snapshot(for: account)).contains(where: { $0.id == line.metricID }) {
                                group.rows[i].metricID = "weekly"
                            }
                        }
                    }
                })) {
                    ForEach(store.orderedAccounts) { Text($0.provider.accountChoiceTitle(store.accountLabel(for: $0))).tag($0.id) }
                }.labelsHidden()
            }.frame(width: 150, alignment: .leading)
                // Full names ("Fable weekly") when the row has room for all of
                // them; otherwise the shorter names in equal widths.
                ViewThatFits(in: .horizontal) {
                    FillingHStack(spacing: 4) {
                        ForEach(limitChoices) { limitButton($0, title: $0.choiceTitle, truncates: false) }
                    }
                    HStack(spacing: 4) {
                        ForEach(limitChoices) { limitButton($0, title: $0.compactChoiceTitle, truncates: true) }
                    }
                }.frame(maxWidth: .infinity)
            if !store.displayConfiguration.isVisible(line.accountID) {
                Button { store.updateDisplay { $0.setVisible(line.accountID, true) } } label: {
                    Image(systemName: "pause.circle")
                }.buttonStyle(.plain).help("Enable this account")
            }
            Button {
                store.updateDisplay { $0.editLayout(groupID) { group in
                    group.rows.removeAll { $0.id == line.id }
                    if group.percentageLineID == line.id { group.percentageLineID = nil }
                } }
            } label: { Image(systemName: "minus.circle").frame(width: Self.removeWidth) }
                .buttonStyle(.plain)
                .help("Remove this usage line")
                .accessibilityLabel("Remove Line")
        }.padding(8)

    }
    private var limitChoices: [DisplayMetric] {
        if metrics.contains(where: { $0.id == line.metricID }) { return metrics }
        return metrics + [DisplayMetric(id: line.metricID, title: line.metricID, window: nil)]
    }
    private func limitButton(_ metric: DisplayMetric, title: String, truncates: Bool) -> some View {
        Button {
            store.updateDisplay { $0.editLayout(groupID) { group in
                guard let i = group.rows.firstIndex(where: { $0.id == line.id }) else { return }
                group.rows[i].metricID = metric.id
            } }
        } label: {
            Text(title).font(.caption).lineLimit(1)
                .fixedSize(horizontal: !truncates, vertical: false)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChoiceButtonStyle(selected: line.metricID == metric.id))
        .help(metric.window?.utilization == nil ? String(localized: "\(metric.localizedTitle) · no data yet") : metric.localizedTitle)
        .accessibilityLabel(metric.localizedTitle)
        .accessibilityAddTraits(line.metricID == metric.id ? .isSelected : [])
    }
    private func move(_ offset: Int) {
        store.updateDisplay { $0.editLayout(groupID) { group in
            group.moveLine(line.id, offset: offset)
        } }
    }
}

/// Each child at least as wide as its content, sharing what is left so the row
/// stays full. Its ideal width is the content alone, which is what ViewThatFits
/// compares against the row.
struct FillingHStack: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        let content = Self.widths(ideal.map(\.width), spacing: spacing, available: 0).reduce(0, +)
            + spacing * CGFloat(max(ideal.count - 1, 0))
        return CGSize(width: max(content, proposal.width ?? content), height: ideal.map(\.height).max() ?? 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = Self.widths(subviews.map { $0.sizeThatFits(.unspecified).width }, spacing: spacing, available: bounds.width)
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }
    /// Each content width grown by an equal share of the room left over.
    static func widths(_ content: [CGFloat], spacing: CGFloat, available: CGFloat) -> [CGFloat] {
        guard !content.isEmpty else { return [] }
        let used = content.reduce(0, +) + spacing * CGFloat(content.count - 1)
        let extra = max(0, available - used) / CGFloat(content.count)
        return content.map { $0 + extra }
    }
}

struct ChoiceButtonStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8).padding(.vertical, 8)
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .background(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(configuration.isPressed ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct StyleSymbol: View {
    let style: MenuBarStyle
    var body: some View {
        switch style {
        case .badge:
            HStack(spacing: 3) {
                Text("CL").font(.system(size: 8, weight: .bold)).padding(3)
                    .background(Color.accentColor.opacity(0.25), in: RoundedRectangle(cornerRadius: 3))
                Capsule().fill(Color.accentColor).frame(width: 19, height: 4)
            }
        case .ring:
            HStack(spacing: 4) {
                Circle().stroke(Color.accentColor, lineWidth: 3).frame(width: 19, height: 19)
                Text("42%").font(.system(size: 9, weight: .bold, design: .rounded))
            }
        case .capsule:
            ZStack(alignment: .leading) {
                Capsule().fill(Color.accentColor.opacity(0.15))
                Rectangle().fill(Color.accentColor.opacity(0.65)).frame(width: 13)
                Text("42%").font(.system(size: 8, weight: .bold)).frame(width: 32)
            }.frame(width: 32, height: 18).clipShape(Capsule())
        case .bars:
            VStack(alignment: .leading, spacing: 3) {
                ForEach([32.0, 22.0, 27.0], id: \.self) { width in
                    Capsule().fill(Color.accentColor).frame(width: width, height: 3)
                }
            }.frame(width: 40)
        case .text:
            Text("42%").font(.system(size: 12, weight: .bold, design: .rounded))
        }
    }
}

private struct GroupTabStyle: ButtonStyle {
    // Shared by the selected tab and the editor below so they read as one panel.
    static let panelFill = SettingsStyle.sectionFill
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7, style: .continuous)
                .fill(selected ? Self.panelFill : Color.primary.opacity(configuration.isPressed ? 0.05 : 0)))
            .contentShape(Rectangle())
    }
}

// What the menu bar will show, drawn by the same renderer as the real status items.
private struct MenuBarPreview: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.colorScheme) private var colorScheme
    let groups: [MenuBarLayout]
    let selectedID: UUID?
    private var shown: [MenuBarLayout] {
        groups.filter { $0.enabled && $0.showsAnything && ($0.rows.isEmpty || !store.entries(for: $0).isEmpty) }
    }
    var body: some View {
        HStack(spacing: 2) {
            Spacer(minLength: 8)
            if shown.isEmpty {
                Text("No groups shown").font(.caption).foregroundStyle(.tertiary)
            }
            ForEach(shown) { group in
                Button { store.selectMenuBarGroup(group.id) } label: {
                    Image(nsImage: image(for: group))
                        .padding(.horizontal, 3).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(group.id == selectedID ? Color.primary.opacity(0.14) : .clear))
                }
                .buttonStyle(.plain)
                .help("\(group.name) · Click to edit this group")
                .accessibilityLabel("Select \(group.name)")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        // A strip like the menu bar itself rather than a field: no border, a
        // soft shadow, items on the right as macOS places them.
        .background(.bar, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 1.5, y: 0.5)
    }
    private func image(for group: MenuBarLayout) -> NSImage {
        DisplayStatusRenderer.render(entries: store.entries(for: group), config: group.renderingConfiguration(store.displayConfiguration),
            height: 20, scale: 2, explicitRows: true,
            appearance: NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua))
    }
}
