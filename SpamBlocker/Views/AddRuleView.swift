import SwiftUI

struct AddRuleView: View {
    @Environment(\.dismiss) var dismiss
    
    // ⭐️ 1. 포커스(커서) 관리를 위한 상태 추가
    enum Field {
        case part1, part2, part3
    }
    @FocusState private var focusedField: Field?
    
    @State private var part1 = ""
    @State private var part2 = ""
    @State private var part3 = ""
    
    @State private var isPrefixBlock = true
    @State private var memo = ""
    
    var onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("차단할 번호 입력")) {
                    HStack {
                        // 첫 번째 칸
                        TextField("010", text: $part1)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .part1) // 포커스 바인딩
                            .onChange(of: part1) { newValue in
                                // ⭐️ 3글자가 채워지면 두 번째 칸으로 커서 자동 이동
                                if newValue.count == 3 {
                                    focusedField = .part2
                                }
                            }
                        
                        Text("-")
                        
                        // 두 번째 칸
                        TextField("1234", text: $part2)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .part2) // 포커스 바인딩
                            .onChange(of: part2) { oldValue, newValue in
                                // ⭐️ 4글자가 채워지면 세 번째 칸으로 커서 자동 이동
                                if newValue.count == 4 {
                                    focusedField = .part3
                                }
                            }
                        
                        Text("-")
                        
                        // 세 번째 칸
                        TextField("선택", text: $part3)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .part3) // 포커스 바인딩
                            .onChange(of: part3) { oldValue, newValue in
                                // 커서만 넘어온 상태에서는 newValue가 비어있으므로 토글이 안 꺼집니다.
                                // 사용자가 '진짜로 숫자를 타이핑했을 때만' 토글이 꺼집니다.
                                if newValue.isEmpty {
                                    isPrefixBlock = true
                                } else {
                                    isPrefixBlock = false
                                }
                            }
                    }
                    
                    // 유효성 검사 경고 메시지
                    if (!part1.isEmpty && part1.count < 2) ||
                       (!part2.isEmpty && part2.count < 3) ||
                       (!part3.isEmpty && part3.count < 4) {
                        
                        VStack(alignment: .leading, spacing: 5) {
                            if !part1.isEmpty && part1.count < 2 {
                                Text("• 첫번째 칸은 최소 2자리 이상 입력하세요")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if !part2.isEmpty && part2.count < 3 {
                                Text("• 두번째 칸은 최소 3자리 이상 입력하세요")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if !part3.isEmpty && part3.count < 4 {
                                Text("• 모든번호 차단 스위치를 켜거나 4자리 모두 입력해주세요")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Toggle("이 번호로 시작하는 모든 번호 차단", isOn: $isPrefixBlock)
                        .tint(.red)
                        .onChange(of: isPrefixBlock) { oldValue, newValue in
                            if newValue {
                                part3 = ""
                                // 토글을 다시 켰을 때 커서를 두 번째 칸으로 돌려보내기
                                focusedField = .part2
                            }
                        }
                }
                
                Section(header: Text("메모 (선택)")) {
                    TextField("차단 사유", text: $memo)
                }
                
                Section {
                    Button(action: saveRule) {
                        HStack {
                            Spacer()
                            Text("차단 등록")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(!isValid())
                }
            }
            .navigationTitle("새 규칙 추가")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            // (옵션) 화면이 켜지자마자 첫 번째 칸에 키보드를 띄우고 싶다면 아래 주석을 푸세요
            /*
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .part1
                }
            }
            */
        }
    }
    
    // 유효성 검사 및 저장 로직은 이전과 동일
    func isValid() -> Bool {
        if part1.count < 2 || part2.count < 3 { return false }
        if part3.count > 0 && part3.count < 4 { return false }
        return true
    }
    
    func saveRule() {
        let fullNumber = [part1, part2, part3].filter { !$0.isEmpty }.joined(separator: "-")
        let finalMatchType = isPrefixBlock ? "PREFIX" : "EXACT"
        let rule = SpamRuleRequest(phoneNumber: fullNumber, matchType: finalMatchType, memo: memo.isEmpty ? nil : memo)
        
        Task {
            do {
                try await APIService.addRule(rule)
                APIService.reloadCallDirectory()
                onSave()
                dismiss()
            } catch {
                print("등록 실패: \(error)")
            }
        }
    }
}
