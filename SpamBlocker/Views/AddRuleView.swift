import SwiftUI

struct AddRuleView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var phoneNumber = ""
    @State private var matchType = "EXACT"
    @State private var memo = ""
    
    var onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("차단 정보")) {
                    TextField("전화번호 또는 접두사", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    
                    Picker("차단 타입", selection: $matchType) {
                        Text("번호 일치 (EXACT)").tag("EXACT")
                        Text("접두사 일치 (PREFIX)").tag("PREFIX")
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
                    .disabled(phoneNumber.isEmpty)
                }
            }
            .navigationTitle("새 규칙 추가")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
    
    func saveRule() {
        let rule = SpamRuleRequest(
            phoneNumber: phoneNumber,
            matchType: matchType,
            memo: memo.isEmpty ? nil : memo
        )
        Task {
            do {
                try await APIService.addRule(rule)
                onSave()
                dismiss()
            } catch {
                print("등록 실패: \(error)")
            }
        }
    }
}

