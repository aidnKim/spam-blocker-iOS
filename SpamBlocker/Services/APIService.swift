import Foundation
import CallKit

enum APIError: Error, LocalizedError {
    case duplicateNumber
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .duplicateNumber:
            return "이미 등록된 번호입니다."
        case .serverError(let statusCode):
            return "서버 오류가 발생했습니다. (코드: \(statusCode))"
        }
    }
}

class APIService {
    // 시뮬레이터에서는 localhost를 쓰면 됨
    // 실제 기기 테스트 시에는 Mac의 IP 주소로 변경 (ex: "http://192.168.0.10:8080")
//    static let baseURL = "http://localhost:8080/api"
    static let baseURL = "http://168.107.43.174:8080/api"
    
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
        
        let (_, response) = try await URLSession.shared.data(for: request)
                
        if let httpResponse = response as? HTTPURLResponse {
            // 백엔드 에러 코드에 맞게 수정 (기본 500, 혹은 예외처리 시 409)
            if httpResponse.statusCode == 500 || httpResponse.statusCode == 409 {
                throw APIError.duplicateNumber
            } else if !(200...299).contains(httpResponse.statusCode) {
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        }

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
    
    // MARK: - 수정
    static func updateRule(id: Int, _ rule: SpamRuleRequest) async throws {
        guard let url = URL(string: "\(baseURL)/spam-rules/\(id)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(rule)
        
        let (_, response) = try await URLSession.shared.data(for: request)
                
        if let httpResponse = response as? HTTPURLResponse {
            // 백엔드 에러 코드에 맞게 수정 (기본 500, 혹은 예외처리 시 409)
            if httpResponse.statusCode == 500 || httpResponse.statusCode == 409 {
                throw APIError.duplicateNumber
            } else if !(200...299).contains(httpResponse.statusCode) {
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        }

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

