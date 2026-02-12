import SwiftUI

// MARK: - Preference Keys

struct ItemFramePreferenceKey<ID: Hashable>: PreferenceKey {
    static var defaultValue: [ID: CGRect] { [:] }

    static func reduce(value: inout [ID: CGRect], nextValue: () -> [ID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Propagates drag/long-press state up to the ScrollView so it can
/// disable scrolling during reorder drags.
struct ReorderDragActiveKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

// MARK: - Reorderable Grid

/// A LazyVGrid wrapper that supports drag-to-reorder functionality.
///
/// **Key design decisions**:
/// 1. The drag gesture is on the grid container (not ForEach items)
///    so it survives SwiftUI re-renders when the array mutates mid-drag.
/// 2. Uses `.highPriorityGesture` so the long-press+drag wins over
///    the parent ScrollView's pan gesture recognizer.
/// 3. Propagates `longPressActive` via PreferenceKey so the ScrollView
///    can disable scrolling once long press recognizes.
struct ReorderableGrid<Item: Identifiable, Content: View>: View where Item.ID: Hashable {
    @Binding var items: [Item]
    let columns: [GridItem]
    let spacing: CGFloat
    let canReorder: (Item) -> Bool
    let onReorder: (Item, Int) -> Void
    let onDragEnd: (() -> Void)?
    @ViewBuilder let content: (Item, Bool) -> Content

    @State private var draggingItemID: Item.ID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartFrame: CGRect?
    @State private var itemFrames: [Item.ID: CGRect] = [:]
    @State private var lastReorderDate: Date?
    @State private var longPressActive = false

    private let debugLogger = DebugLogger.shared
    private var isDragging: Bool { draggingItemID != nil }

    init(
        items: Binding<[Item]>,
        columns: [GridItem],
        spacing: CGFloat,
        canReorder: @escaping (Item) -> Bool = { _ in true },
        onReorder: @escaping (Item, Int) -> Void,
        onDragEnd: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item, Bool) -> Content
    ) {
        self._items = items
        self.columns = columns
        self.spacing = spacing
        self.canReorder = canReorder
        self.onReorder = onReorder
        self.onDragEnd = onDragEnd
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { item in
                let isItemDragging = draggingItemID == item.id

                content(item, isItemDragging)
                    .opacity(isItemDragging ? 0.001 : 1)
                    .zIndex(isItemDragging ? 1 : 0)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ItemFramePreferenceKey<Item.ID>.self,
                                value: [item.id: geo.frame(in: .named("reorderableGrid"))]
                            )
                        }
                    )
            }
        }
        .coordinateSpace(name: "reorderableGrid")
        .onPreferenceChange(ItemFramePreferenceKey<Item.ID>.self) { frames in
            let oldCount = itemFrames.count
            itemFrames = frames
            if oldCount != frames.count {
                debugLogger.debug("ReorderableGrid itemFrames updated: \(frames.count) items tracked", category: "Reorder")
            }
        }
        .onAppear {
            debugLogger.debug("ReorderableGrid appeared with \(items.count) items", category: "Reorder")
        }
        // highPriorityGesture so this wins over ScrollView's pan gesture
        .highPriorityGesture(reorderGesture)
        .overlay(alignment: .topLeading) {
            dragPreview
        }
        // Tell the ancestor ScrollView to disable scrolling during drag
        .preference(key: ReorderDragActiveKey.self, value: longPressActive)
    }

    // MARK: - Drag Preview

    @ViewBuilder
    private var dragPreview: some View {
        if let draggingId = draggingItemID,
           let draggingItem = items.first(where: { $0.id == draggingId }),
           let startFrame = dragStartFrame {
            content(draggingItem, true)
                .frame(width: startFrame.width, height: startFrame.height)
                .scaleEffect(1.05)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                .offset(
                    x: startFrame.minX + dragOffset.width,
                    y: startFrame.minY + dragOffset.height
                )
                .allowsHitTesting(false)
                .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Gesture

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.15)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("reorderableGrid")))
            .onChanged { value in
                switch value {
                case .first(true):
                    debugLogger.debug("ReorderableGrid: LongPress RECOGNIZED. Setting longPressActive=true", category: "Reorder")
                    longPressActive = true
                    HapticManager.impact(.medium)
                case .second(true, let drag):
                    if let drag = drag {
                        debugLogger.debug("ReorderableGrid: DRAG event at (\(Int(drag.location.x)), \(Int(drag.location.y))) translation=(\(Int(drag.translation.width)), \(Int(drag.translation.height)))", category: "Reorder")
                        if draggingItemID == nil {
                            let startLoc = drag.startLocation
                            debugLogger.debug("ReorderableGrid: Drag START at (\(Int(startLoc.x)), \(Int(startLoc.y)))", category: "Reorder")
                            if let itemID = itemAt(point: startLoc) {
                                debugLogger.debug("ReorderableGrid: Found item \(itemID) under finger. Starting drag.", category: "Reorder")
                                dragStartFrame = itemFrames[itemID]
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    draggingItemID = itemID
                                }
                            } else {
                                let frameDescriptions = itemFrames.map { id, rect in
                                    "\(id): (\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height)))"
                                }.joined(separator: ", ")
                                debugLogger.debug("ReorderableGrid: NO item found at (\(Int(startLoc.x)), \(Int(startLoc.y))). Frames: \(frameDescriptions)", category: "Reorder")
                            }
                        }
                        if draggingItemID != nil {
                            dragOffset = drag.translation
                            checkForReorder()
                        }
                    }
                default:
                    debugLogger.debug("ReorderableGrid: Gesture default case hit", category: "Reorder")
                    break
                }
            }
            .onEnded { _ in
                debugLogger.debug("ReorderableGrid: Gesture ENDED. wasDragging=\(isDragging) longPressActive=\(longPressActive)", category: "Reorder")
                let wasActive = isDragging
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    draggingItemID = nil
                    dragOffset = .zero
                    dragStartFrame = nil
                }
                longPressActive = false
                lastReorderDate = nil
                if wasActive {
                    onDragEnd?()
                    debugLogger.debug("ReorderableGrid: Called onDragEnd for persistence", category: "Reorder")
                }
            }
    }

    // MARK: - Hit Testing & Reorder

    private func itemAt(point: CGPoint) -> Item.ID? {
        for (id, frame) in itemFrames {
            if frame.contains(point) {
                return id
            }
        }
        return nil
    }

    private func checkForReorder() {
        guard let draggingID = draggingItemID,
              let startFrame = dragStartFrame else { return }

        // Debounce: prevent reorder oscillation
        if let lastReorder = lastReorderDate,
           Date().timeIntervalSince(lastReorder) < 0.2 {
            return
        }

        let dragCenter = CGPoint(
            x: startFrame.midX + dragOffset.width,
            y: startFrame.midY + dragOffset.height
        )

        for (id, frame) in itemFrames {
            guard id != draggingID else { continue }

            if frame.contains(dragCenter) {
                if let draggingItem = items.first(where: { $0.id == draggingID }),
                   let targetIndex = items.firstIndex(where: { $0.id == id }) {
                    debugLogger.debug("ReorderableGrid: REORDER \(draggingItem.id) → index \(targetIndex)", category: "Reorder")
                    lastReorderDate = Date()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        onReorder(draggingItem, targetIndex)
                    }
                    HapticManager.selection()
                }
                break
            }
        }
    }
}
