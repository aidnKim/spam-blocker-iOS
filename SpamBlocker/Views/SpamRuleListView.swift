import SwiftUI

struct SpamRuleListView: View {
    @State private var rules: [SpamRule] = []
    @State private var showAddSheet = false
    @State private var selectedFilter = "ALL"  // ALL, EXACT, PREFIX
    
    let filters = ["ALL", "EXACT", "PREFIX"]
    
    var body: some View {
        NavigationView {
            VStack {
                // 필터 Picker
                Picker("필터", selection: $selectedFilter) {
                    ForEach(filters, id: \.self) { filter in
                        Text(filter).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedFilter) {
                    Task { await loadRules() }
                }
                
                // 목록
                List {
                    ForEach(rules) { rule in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(rule.phoneNumber)
                                    .font(.headline)
                                Spacer()
                                Text(rule.matchType)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(rule.matchType == "PREFIX" ? Color.orange : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            if let memo = rule.memo, !memo.isEmpty {
                                Text(memo)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteRules)
                }
            }
            .navigationTitle("스팸 차단 목록")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddRuleView(onSave: {
                    Task { await loadRules() }
                })
            }
            .task {
                await loadRules()
            }
        }
    }
    
    func loadRules() async {
        do {
            if selectedFilter == "ALL" {
                rules = try await APIService.fetchRules()
            } else {
                rules = try await APIService.fetchRules(byType: selectedFilter)
            }
        } catch {
            print("로딩 실패: \(error)")
        }
    }
    
    func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            let rule = rules[index]
            Task {
                do {
                    // 1. 서버에서 규칙 삭제 성공
                    try await APIService.deleteRule(id: rule.id)
                    
                    // 2. iOS 시스템에 "규칙 삭제" 알려주기
                    APIService.reloadCallDirectory()
                    
                    // 3. 목록 새로고침
                    await loadRules()
                } catch {
                    print("삭제 실패: \(error)")
                }
            }
        }
    }
}

