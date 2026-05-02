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
                
                // 2. 전화번호 생성 및 전개 (PREFIX 처리 추가)
                var phoneNumbersToBlock: [Int64] = []

                for rule in rules {
                    // 번호에서 하이픈 제거 (예: 010-1234-5678 -> 01012345678)
                    var cleanNumber = rule.phoneNumber.replacingOccurrences(of: "-", with: "")
                    
                    // 한국 국가코드(+82) 적용 (0으로 시작하면 82로 치환)
                    if cleanNumber.hasPrefix("0") {
                        cleanNumber.removeFirst()
                        cleanNumber = "82" + cleanNumber
                    }
                    
                    // Int64(숫자)로 변환
                    guard let baseIntNumber = Int64(cleanNumber) else { continue }
                    
                    // PREFIX 인 경우 뒤에 4자리(0000~9999)를 붙여서 1만 개 번호 생성
                    if rule.matchType == "PREFIX" {
                        // 하이픈(-) 기준으로 분리하여 3번째 파트(마지막 번호 부분)의 길이를 확인
                        let components = rule.phoneNumber.components(separatedBy: "-")
                        var missingDigits = 4 // 기본적으로 4자리가 빠졌다고 가정
                        
                        // 마지막 칸(part3)이 일부라도 입력되어 있는 경우 (예: "010-1234-56" -> 2자리 입력됨)
                        if components.count == 3 {
                            missingDigits = 4 - components[2].count
                        }
                        
                        // 빠진 자릿수만큼 10을 곱해서 배수 계산 (2자리 누락이면 100)
                        var multiplier = 1
                        for _ in 0..<missingDigits {
                            multiplier *= 10
                        }
                        
                        let expandedBase = baseIntNumber * Int64(multiplier)
                        for i in 0..<multiplier {
                            phoneNumbersToBlock.append(expandedBase + Int64(i))
                        }
                    } else {
                        // EXACT 인 경우 정확한 번호 그대로 추가
                        phoneNumbersToBlock.append(baseIntNumber)
                    }
                }

                // 3. 중복 제거 및 반드시 '오름차순'으로 정렬해야 앱이 크래시나지 않음
                let uniqueSortedNumbers = Array(Set(phoneNumbersToBlock)).sorted()

                // 4. CallKit에 차단/식별 번호 순차적으로 등록
                for phoneNumber in uniqueSortedNumbers {
                    // 많은 번호(수만 개 이상)를 등록할 때 메모리가 누적되어 튕기는 것을 방지
                    autoreleasepool {
                        // (현재 스팸 전화 식별 라벨 추가) 완전 차단을 원하시면 addBlockingEntry 로 바꾸시면 됩니다.
//                        context.addIdentificationEntry(withNextSequentialPhoneNumber: phoneNumber, label: "스팸 전화")
                        // 스팸전화 차단
                        context.addBlockingEntry(withNextSequentialPhoneNumber: phoneNumber)
                    }
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
        let url = URL(string: "http://168.107.43.174:8080/api/spam-rules")!

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
