import Foundation

struct SpamRule: Codable, Identifiable {
    let id: Int
    let phoneNumber: String
    let matchType: String       // "EXACT" 또는 "PREFIX"
    let memo: String?
    let createdAt: String?
}

// POST 요청 시 사용할 구조체 (id, createdAt 없이)
struct SpamRuleRequest: Codable {
    let phoneNumber: String
    let matchType: String
    let memo: String?
}
