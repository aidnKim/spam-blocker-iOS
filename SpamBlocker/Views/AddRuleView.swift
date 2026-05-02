import SwiftUI

struct AddRuleView: View {
    @Environment(\.dismiss) var dismiss
    
    // 1. 포커스(커서) 관리를 위한 상태 추가
    enum Field {
        case part1, part2, part3
    }
    @FocusState private var focusedField: Field?
    
    @State private var part1 = ""
    @State private var part2 = ""
    @State private var part3 = ""
    
    @State private var isPrefixBlock = true
    @State private var memo = ""
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
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
                            .onChange(of: part1) { oldValue, newValue in
                                if newValue.count > 3 {
                                    part1 = String(newValue.prefix(3))
                                }
                                // 3글자가 채워지면 두 번째 칸으로 커서 자동 이동
                                if part1.count == 3 {
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
                                if newValue.count > 4 {
                                    part2 = String(newValue.prefix(4))
                                }
                                // 4글자가 채워지면 세 번째 칸으로 커서 자동 이동
                                if part2.count == 4 {
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
                                // 입력값이 4자리를 초과하면, 딱 4자리까지만 남기고 잘라냅니다.
                               if newValue.count > 4 {
                                   part3 = String(newValue.prefix(4))
                               }
                               
                               // 방금 입력한 값(또는 잘라낸 결과)이 4자리라면 모드 전환
                               if part3.count == 4 {
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
                            if !isPrefixBlock && part3.count < 4 {
                                Text("• 정확한 번호 차단을 위해 4자리를 모두 입력하거나, 시작 번호 차단 스위치를 켜주세요")
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
                                // 4자리가 꽉 차있는데 토글을 켰다면 마지막 자리를 하나 지워줌
                                if part3.count == 4 {
                                    part3.removeLast()
                                }
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .part1
                }
            }
            .alert("알림", isPresented: $showAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // 유효성 검사 및 저장 로직은 이전과 동일
    func isValid() -> Bool {
        if part1.count < 2 || part2.count < 3 { return false }
        
        if isPrefixBlock {
            // PREFIX 차단일 때는 part3가 비어있거나 1~3자리여야 함
            if part3.count >= 4 { return false }
        } else {
            // EXACT 차단일 때는 part3가 정확히 4자리여야 함
            if part3.count != 4 { return false }
        }
        return true
    }
    
    func saveRule() {
        let fullNumber = [part1, part2, part3].filter { !$0.isEmpty }.joined(separator: "-")
        let finalMatchType = isPrefixBlock ? "PREFIX" : "EXACT"
        let rule = SpamRuleRequest(phoneNumber: fullNumber, matchType: finalMatchType, memo: memo.isEmpty ? nil : memo)
        
        Task {
            do {
                try await APIService.addRule(rule) // (수정 화면은 updateRule)
                APIService.reloadCallDirectory()
                onSave()
                dismiss()
            } catch let error as APIError {
                // 우리가 정의한 에러일 경우
                alertMessage = error.localizedDescription
                showAlert = true
            } catch {
                // 그 외 네트워크 에러 등
                alertMessage = "요청에 실패했습니다. (\(error.localizedDescription))"
                showAlert = true
                print("등록 실패: \(error)")
            }
        }
    }
}
