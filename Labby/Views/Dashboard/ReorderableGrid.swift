import SwiftUI

// MARK: - Preference Key for Item Frames

struct ItemFramePreferenceKey<ID: Hashable>: PreferenceKey {
    static var defaultValue: [ID: CGRect] { [:] }

    static func reduce(value: inout [ID: CGRect], nextValue: () -> [ID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Drag State

struct DragState<ID: Hashable> {
    var draggingItemId: ID?
    var dragOffset: CGSize = .zero
    var startPosition: CGPoint = .zero
    var currentPosition: CGPoint = .zero

    var isDragging: Bool { draggingItemId != nil }
}

// MARK: - Reorderable Grid

/// A LazyVGrid wrapper that supports drag-to-reorder functionality.
/// Works around SwiftUI's lack of native grid reordering by using
/// LongPressGesture + DragGesture and manual position tracking.
struct ReorderableGrid<Item: Identifiable, Content: View>: View where Item.ID: Hashable {
    @Binding var items: [Item]
    let columns: [GridItem]
    let spacing: CGFloat
    let canReorder: (Item) -> Bool
    let onReorder: (Item, Int) -> Void
    @ViewBuilder let content: (Item, Bool) -> Content

    @State private var dragState = DragState<Item.ID>()
    @State private var itemFrames: [Item.ID: CGRect] = [:]
    @State private var hapticTriggered = false

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { item in
                let isDragging = dragState.draggingItemId == item.id
                let isReorderable = canReorder(item)

                content(item, isDragging)
                    .opacity(isDragging ? 0.001 : 1) // Near-invisible when dragging (placeholder)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ItemFramePreferenceKey<Item.ID>.self,
                                value: [item.id: geo.frame(in: .named("reorderableGrid"))]
                            )
                        }
                    )
                    .gesture(
                        isReorderable ? dragGesture(for: item) : nil
                    )
                    .zIndex(isDragging ? 1 : 0)
            }
        }
        .coordinateSpace(name: "reorderableGrid")
        .onPreferenceChange(ItemFramePreferenceKey<Item.ID>.self) { frames in
            itemFrames = frames
        }
        .overlay(alignment: .topLeading) {
            // Drag preview overlay
            if let draggingId = dragState.draggingItemId,
               let draggingItem = items.first(where: { $0.id == draggingId }),
               let frame = itemFrames[draggingId] {
                content(draggingItem, true)
                    .frame(width: frame.width, height: frame.height)
                    .scaleEffect(1.05)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    .offset(
                        x: frame.minX + dragState.dragOffset.width,
                        y: frame.minY + dragState.dragOffset.height
                    )
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.interactiveSpring(), value: dragState.dragOffset)
            }
        }
    }

    private func dragGesture(for item: Item) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(coordinateSpace: .named("reorderableGrid")))
            .onChanged { value in
                switch value {
                case .first(true):
                    // Long press recognized - prepare for drag
                    if !hapticTriggered {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        hapticTriggered = true
                    }

                case .second(true, let drag?):
                    // Dragging
                    if dragState.draggingItemId == nil {
                        // Start drag
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragState.draggingItemId = item.id
                            dragState.startPosition = drag.startLocation
                        }
                    }
                    dragState.dragOffset = drag.translation
                    dragState.currentPosition = drag.location

                    // Check for reorder
                    checkForReorder(draggingItem: item)

                default:
                    break
                }
            }
            .onEnded { _ in
                // End drag
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragState = DragState()
                }
                hapticTriggered = false
            }
    }

    private func checkForReorder(draggingItem: Item) {
        guard let draggingFrame = itemFrames[draggingItem.id] else { return }

        // Calculate the center of the dragged item
        let dragCenter = CGPoint(
            x: draggingFrame.midX + dragState.dragOffset.width,
            y: draggingFrame.midY + dragState.dragOffset.height
        )

        // Find which item we're hovering over
        for (id, frame) in itemFrames {
            guard id != draggingItem.id else { continue }

            if frame.contains(dragCenter) {
                // Found a target - get its index
                if let targetIndex = items.firstIndex(where: { $0.id == id }) {
                    // Trigger reorder
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        onReorder(draggingItem, targetIndex)
                    }

                    // Haptic feedback
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                }
                break
            }
        }
    }
}

// MARK: - Convenience Extension

extension ReorderableGrid {
    /// Creates a reorderable grid with default settings
    init(
        items: Binding<[Item]>,
        columns: [GridItem] = [GridItem(.adaptive(minimum: 160), spacing: 16)],
        spacing: CGFloat = 16,
        canReorder: @escaping (Item) -> Bool = { _ in true },
        onReorder: @escaping (Item, Int) -> Void,
        @ViewBuilder content: @escaping (Item, Bool) -> Content
    ) {
        self._items = items
        self.columns = columns
        self.spacing = spacing
        self.canReorder = canReorder
        self.onReorder = onReorder
        self.content = content
    }
}
