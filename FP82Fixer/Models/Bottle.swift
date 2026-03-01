import Foundation

struct Bottle: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let path: URL
}
