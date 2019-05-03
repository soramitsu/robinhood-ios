import Foundation

public enum SectionedListDifference<Section, Item> {
    case insert(index: Int, newSection: Section)
    case update(index: Int, itemChange: ListDifference<Item>, newSection: Section)
    case delete(index: Int, oldSection: Section)
}
