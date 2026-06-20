import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var openAIKey = APIConfig.openAIKey
    @State private var anthropicKey = APIConfig.anthropicKey
    @State private var model = APIConfig.claudeModel
    @State private var language = APIConfig.sttLanguage

    var body: some View {
        NavigationStack {
            Form {
                Section("API 키") {
                    SecureField("OpenAI API Key (Whisper)", text: $openAIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Anthropic API Key (Claude)", text: $anthropicKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("옵션") {
                    TextField("Claude 모델", text: $model)
                        .autocorrectionDisabled()
                    Picker("받아쓰기 언어", selection: $language) {
                        Text("한국어").tag("ko")
                        Text("English").tag("en")
                        Text("日本語").tag("ja")
                    }
                }

                Section {
                    Text("⚠️ 키는 기기에만 저장됩니다. 더 안전하게 쓰려면 본인 서버를 프록시로 두는 방식을 권장합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("설정")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        APIConfig.openAIKey = openAIKey.trimmingCharacters(in: .whitespaces)
                        APIConfig.anthropicKey = anthropicKey.trimmingCharacters(in: .whitespaces)
                        APIConfig.claudeModel = model.trimmingCharacters(in: .whitespaces)
                        APIConfig.sttLanguage = language
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
