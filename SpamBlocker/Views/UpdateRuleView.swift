import SwiftUI

struct UpdateRuleView: View {
    @Environment(\.dismiss) var dismiss
    
    enum Field { case part1, part2, part3 }
    @FocusState private var focusedField: Field?
    
    @State private var part1: String
    @State private var part2: String
    @State private var part3: String
    @State private var isPrefixBlock: Bool
    @State private var memo: String
    
    let existingRule: SpamRule
    var onSave: () -> Void
    
    // 생성자: 화면이 열릴 때 기존 번호를 쪼개서 각 칸에 넣어줍니다.
    init(rule: SpamRule, onSave: @escaping () -> Void) {
        self.existingRule = rule
        self.onSave = onSave
        
        let parts = rule.phoneNumber.components(separatedBy: "-")
        _part1 = State(initialValue: parts.count > 0 ? parts[0] : "")
        _part2 = State(initialValue: parts.count > 1 ? parts[1] : "")
        _part3 = State(initialValue: parts.count > 2 ? parts[2] : "")
        _isPrefixBlock = State(initialValue: rule.matchType == "PREFIX")
        _memo = State(initialValue: rule.memo ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                // UI는 AddRuleView와 동일하게 구성
                Section(header: Text("차단할 번호 수정")) {
                    HStack {
                        TextField("010", text: $part1)
                            .keyboardType(.numberPad).multilineTextAlignment(.center)
                            .focused($focusedField, equals: .part1)
                            .onChange(of: part1) { oldValue, newValue in
                                if newValue.count == 3 {
                                    focusedField = .part2
                                }
                            }
                        Text("-")
                        TextField("1234", text: $part2)
                            .keyboardType(.numberPad).multilineTextAlignment(.center)
                            .focused($focusedField, equals: .part2)
                            .onChange(of: part2) { oldValue, newValue in
                                if newValue.count == 4 {
                                    focusedField = .part3
                                }
                            }
                        Text("-")
                        TextField("선택", text: $part3)
                            .keyboardType(.numberPad).multilineTextAlignment(.center)
                            .focused($focusedField, equals: .part3)
                            .onChange(of: part3) { oldValue, newValue in
                                if newValue.isEmpty {
                                    isPrefixBlock = true
                                } else {
                                    isPrefixBlock = false
                                }
                            }
                    }
                    
                    if (!part1.isEmpty && part1.count < 2) || (!part2.isEmpty && part2.count < 3) || (!part3.isEmpty && part3.count < 4) {
                        VStack(alignment: .leading, spacing: 5) {
                            if !part1.isEmpty && part1.count < 2 { Text("• 최소 2자리 이상 입력하세요").font(.caption).foregroundColor(.red) }
                            if !part2.isEmpty && part2.count < 3 { Text("• 최소 3자리 이상 입력하세요").font(.caption).foregroundColor(.red) }
                            if !part3.isEmpty && part3.count < 4 { Text("• 4자리 모두 입력해주세요").font(.caption).foregroundColor(.red) }
                        }
                    }
                    
                    Toggle("이 번호로 시작하는 모든 번호 차단", isOn: $isPrefixBlock)
                        .tint(.red)
                        .onChange(of: isPrefixBlock) { oldValue, newValue in
                            if newValue == true {
                                part3 = ""
                            }
                        }
                }
                
                Section(header: Text("메모 (선택)")) { TextField("차단 사유", text: $memo) }
                
                Section {
                    Button(action: saveUpdatedRule) {
                        HStack { Spacer(); Text("수정 완료").fontWeight(.bold); Spacer() }
                    }
                    .disabled(part1.count < 2 || part2.count < 3 || (part3.count > 0 && part3.count < 4))
                }
            }
            .navigationTitle("규칙 수정")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("취소") { dismiss() } } }
        }
    }
    
    // updateRule API를 호출
    func saveUpdatedRule() {
        let fullNumber = [part1, part2, part3].filter { !$0.isEmpty }.joined(separator: "-")
        let finalMatchType = isPrefixBlock ? "PREFIX" : "EXACT"
        let updateRequest = SpamRuleRequest(phoneNumber: fullNumber, matchType: finalMatchType, memo: memo.isEmpty ? nil : memo)
        
        Task {
            do {
                try await APIService.updateRule(id: existingRule.id, updateRequest)
                APIService.reloadCallDirectory()
                onSave()
                dismiss()
            } catch { print("수정 실패: \(error)") }
        }
    }
}
