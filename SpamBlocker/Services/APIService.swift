import Foundation
import CallKit

class APIService {
    // 시뮬레이터에서는 localhost를 쓰면 됨
    // 실제 기기 테스트 시에는 Mac의 IP 주소로 변경 (ex: "http://192.168.0.10:8080")
//    static let baseURL = "http://localhost:8080/api"
    static let baseURL = "http://192.168.35.152:8080/api"
    
    // MARK: - 전체 조회
    static func fetchRules() async throws -> [SpamRule] {
        guard let url = URL(string: "\(baseURL)/spam-rules") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([SpamRule].self, from: data)
    }
    
    // MARK: - 타입별 조회
    static func fetchRules(byType type: String) async throws -> [SpamRule] {
        guard let url = URL(string: "\(baseURL)/spam-rules?type=\(type)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([SpamRule].self, from: data)
    }
    
    // MARK: - 등록
    static func addRule(_ rule: SpamRuleRequest) async throws {
        guard let url = URL(string: "\(baseURL)/spam-rules") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(rule)
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - 삭제
    static func deleteRule(id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/spam-rules/\(id)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Call Directory 갱신
    static func reloadCallDirectory() {
        // 본인의 Extension Bundle Identifier 입력 (주의: 소문자 등 본인 설정 확인)
        let extensionIdentifier = "com.aidnkim.SpamBlocker.CallDirectoryExtension"
        
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionIdentifier) { error in
            if let error = error {
                print("Extension 갱신 실패: \(error.localizedDescription)")
            } else {
                print("Extension 갱신 성공!")
            }
        }
    }
}

