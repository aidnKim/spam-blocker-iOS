import Foundation
import CallKit

struct ExtensionSpamRule: Codable {
    let phoneNumber: String
    let matchType: String
    let memo: String?
}

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self
        
        // 1. 비동기로 백엔드 데이터 가져오기
        Task {
            do {
                let rules = try await fetchRules()
                
                // 2. 전화번호 생성 (PREFIX인 경우 0000~9999 등 확장 필요하지만,
                // 지금은 심플하게 정확한 번호만 '스팸' 라벨링 처리하는 로직으로 구성합니다)
                // * PREFIX의 완벽한 처리를 위해서는 차단 번호 대역폭을 모두 생성해야 하나,
                // 여기서는 EXACT 매칭과 단순 전화번호 포맷 변환에 집중
                
                var phoneNumbersToBlock: [CXCallDirectoryPhoneNumber] = []
                
                for rule in rules {
                    // 번호에서 하이픈 제거 (예: 010-1234-5678 -> 01012345678)
                    var cleanNumber = rule.phoneNumber.replacingOccurrences(of: "-", with: "")
                    
                    // 한국 국가코드(+82) 적용 (0으로 시작하면 82로 치환)
                    if cleanNumber.hasPrefix("0") {
                        cleanNumber.removeFirst()
                        cleanNumber = "82" + cleanNumber
                    }
                    
                    if let intNumber = CXCallDirectoryPhoneNumber(cleanNumber) {
                        phoneNumbersToBlock.append(intNumber)
                    }
                }
                
                // 3. 반드시 '오름차순'으로 정렬해야 앱이 크래시나지 않음
                phoneNumbersToBlock.sort()
                
                // 4. CallKit에 차단/식별 번호 등록 (여기서는 '스팸 전화'로 식별 라벨 추가)
                for phoneNumber in phoneNumbersToBlock {
                    context.addIdentificationEntry(withNextSequentialPhoneNumber: phoneNumber, label: "스팸 전화")
                }
                
                // 5. 완료 알림
                await context.completeRequest()
                
            } catch {
                print("Failed to fetch rules: \(error)")
                context.cancelRequest(withError: error)
            }
        }
    }
    
    // 백엔드 API 통신 함수
    private func fetchRules() async throws -> [ExtensionSpamRule] {
        // 실제 테스트할 때는 Mac의 IP주소를 넣어야 실기기에서 접속 가능합니다! (예: 192.168.0.x)
//        let url = URL(string: "http://localhost:8080/api/spam-rules")!
        let url = URL(string: "http://192.168.35.152:8080/api/spam-rules")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([ExtensionSpamRule].self, from: data)
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        print("Call Directory Extension error: \(error.localizedDescription)")
    }
}
