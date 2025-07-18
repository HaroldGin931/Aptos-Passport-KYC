//
//  IntegrityView.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Parser Data Manager
class ParserDataManager: ObservableObject {
    @Published var assertionInfo: AssertionInfo?
    @Published var certificateInfo: AttestationInfo?
    
    func setAssertionInfo(_ info: AssertionInfo) {
        print("📦 ParserDataManager: 设置断言信息")
        print("   - Key ID: \(info.keyId)")
        assertionInfo = info
        print("   - 设置完成, assertionInfo != nil: \(assertionInfo != nil)")
    }
    
    func clearAssertionInfo() {
        assertionInfo = nil
    }
    
    func clearResults() {
        print("🧹 ParserDataManager: 清除所有解析结果")
        assertionInfo = nil
        certificateInfo = nil
        print("✅ ParserDataManager: 清除完成")
    }
}

struct IntegrityView: View {
    @StateObject private var attestService = AppAttestService.shared
    @StateObject private var assertService = AppAssertService.shared
    @StateObject private var parserManager = ParserDataManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSaveDialog = false
    @State private var certificateToSave = ""
    @State private var testRequestData = "这是一个敏感数据请求的测试"
    @State private var showCertificateParser = false
    @State private var showAssertionParser = false
    @State private var isAttestationCompleted = false // 新增：跟踪认证完成状态
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // App Attest Section
                    attestSection
                    
                    // App Assert Section (only show if we have an attested key)
                    if attestService.lastKeyId != nil {
                        assertSection
                    }
                    
                    // Save Section - 只在认证未完成且有证书时显示
                    if attestService.lastAttestation != nil && !isAttestationCompleted {
                        saveSection
                    }
                }
                .padding()
            }
            .navigationTitle("完整性验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .alert("消息", isPresented: $showAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showCertificateParser) {
            if let info = parserManager.certificateInfo {
                CertificateParserView(info: info)
            } else {
                Text("证书数据未找到")
            }
        }
        .sheet(isPresented: $showAssertionParser) {
            if let info = parserManager.assertionInfo {
                AssertionParserView(info: info)
            } else {
                VStack(spacing: 16) {
                    Text("⚠️ 断言数据未找到")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text("状态调试信息:")
                        .font(.subheadline)
                    
                    Text("parserManager.assertionInfo: \(parserManager.assertionInfo == nil ? "nil" : "存在")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("关闭") {
                        showAssertionParser = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .fileExporter(
            isPresented: $showSaveDialog,
            document: CertificateDocument(content: certificateToSave),
            contentType: .json,
            defaultFilename: "aptos_passport_kyc_certificate.json"
        ) { result in
            switch result {
            case .success(let url):
                alertMessage = "证书已保存到: \(url.path)"
                showAlert = true
            case .failure(let error):
                alertMessage = "保存失败: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 40))
                .foregroundColor(attestService.lastAttestation != nil ? .green : .orange)
            
            Text("POC 演示 - App Attest & Assert")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("验证应用和设备的完整性")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var attestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.blue)
                Text("设备认证")
                    .font(.headline)
                Spacer()
                statusIndicator(isActive: attestService.lastAttestation != nil)
            }
            
            Text("生成设备密钥并获取 Apple 认证证书")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if attestService.isLoading {
                ProgressView("正在验证...")
                    .frame(maxWidth: .infinity)
            } else if isAttestationCompleted {
                // 认证完成后显示证书信息和解析按钮
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("设备认证已完成")
                            .font(.headline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    
                    if let attestation = attestService.lastAttestation,
                       let keyId = attestService.lastKeyId {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("认证信息:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Text("Key ID:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(keyId.prefix(20) + "...")
                                    .font(.system(.caption, design: .monospaced))
                            }
                            
                            HStack {
                                Text("证书大小:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(attestation.count) bytes")
                                    .font(.caption)
                            }
                            
                            Button("查看证书详情") {
                                parseCertificate(attestation: attestation)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                            Button("重新认证") {
                                resetAttestation()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            } else {
                Button("开始设备认证") {
                    Task {
                        await performAttestation()
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!attestService.checkAppAttestSupport())
            }
            
            if !attestService.checkAppAttestSupport() {
                Text("⚠️ 当前设备不支持 App Attest")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if let errorMessage = attestService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private var assertSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                Text("敏感数据验证")
                    .font(.headline)
                Spacer()
                statusIndicator(isActive: assertService.lastAssertion != nil)
            }
            
            Text("使用已认证的密钥对敏感数据请求进行验证")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Test request input
            VStack(alignment: .leading, spacing: 8) {
                Text("测试请求数据:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("输入测试数据", text: $testRequestData)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.caption)
            }
            
            if assertService.isLoading {
                ProgressView("正在生成断言...")
                    .frame(maxWidth: .infinity)
            } else {
                Button("生成敏感数据断言") {
                    Task {
                        await performAssertion()
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(attestService.lastKeyId == nil)
            }
            
            if let errorMessage = assertService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if let assertion = assertService.lastAssertion {
                VStack(alignment: .leading, spacing: 8) {
                    Text("断言大小: \(assertion.count) bytes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button("保存断言到文件") {
                            saveAssertionToFile()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("解析断言") {
                            parseAssertion()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                Text("Attest 证书")
                    .font(.headline)
                Spacer()
            }
            
            Text("将获取的认证证书保存到您选择的位置")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let keyId = attestService.lastKeyId,
               let attestation = attestService.lastAttestation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key ID: \(keyId.prefix(16))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("证书大小: \(attestation.count) bytes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Button("保存证书到文件") {
                        saveCertificateToFile(attestation: attestation, keyId: keyId)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("解析证书") {
                        parseCertificate(attestation: attestation)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private func statusIndicator(isActive: Bool) -> some View {
        Circle()
            .fill(isActive ? Color.green : Color.gray)
            .frame(width: 10, height: 10)
    }
    
    // MARK: - Actions
    
    private func performAttestation() async {
        do {
            let result = try await attestService.performAttestation()
            isAttestationCompleted = true // 设置认证完成状态
            alertMessage = "设备认证成功！\nKey ID: \(result.keyId.prefix(16))...\n证书大小: \(result.attestation.count) bytes"
            showAlert = true
        } catch {
            alertMessage = "认证失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func performAssertion() async {
        guard let keyId = attestService.lastKeyId else {
            alertMessage = "请先完成设备认证"
            showAlert = true
            return
        }
        
        do {
            let assertion = try await assertService.assertStringRequest(keyId: keyId, requestString: testRequestData)
            alertMessage = "敏感数据断言生成成功！\n断言大小: \(assertion.count) bytes"
            showAlert = true
        } catch {
            alertMessage = "断言生成失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func saveCertificateToFile(attestation: Data, keyId: String) {
        certificateToSave = attestService.saveCertificateToFile(attestation: attestation, keyId: keyId)
        showSaveDialog = true
    }
    
    private func saveAssertionToFile() {
        guard let keyId = attestService.lastKeyId,
              let assertion = assertService.lastAssertion else {
            alertMessage = "没有可保存的断言数据"
            showAlert = true
            return
        }
        
        let requestData = testRequestData.data(using: .utf8) ?? Data()
        certificateToSave = assertService.saveAssertionToFile(assertion: assertion, keyId: keyId, requestData: requestData)
        showSaveDialog = true
    }
    
    private func resetAttestation() {
        print("🔄 IntegrityView: 重置认证状态...")
        isAttestationCompleted = false
        parserManager.clearResults()
        
        // 清除服务中的数据
        attestService.errorMessage = nil
        attestService.lastAttestation = nil
        attestService.lastKeyId = nil
        
        // 清除断言服务数据
        assertService.errorMessage = nil
        assertService.lastAssertion = nil
        
        print("✅ IntegrityView: 认证状态已重置")
    }
    
    private func parseCertificate(attestation: Data) {
        print("🔄 IntegrityView: 开始解析证书...")
        print("   - 证书数据大小: \(attestation.count) bytes")
        print("💡 将从证书本身提取Key ID, 公钥, Bundle ID等信息")
        
        // 调用更新后的解析器，它会从证书本身提取所有信息
        let result = AttestationParser.parseCertificate(attestation: attestation)
        parserManager.certificateInfo = result
        print("   - 解析完成，提取的Key ID: \(result.keyId)")
        print("   - 解析完成，提取的Bundle ID: \(result.bundleId)")
        showCertificateParser = true
    }
    
    private func parseAssertion() {
        print("🔄 IntegrityView: 开始解析断言...")
        
        guard let keyId = attestService.lastKeyId,
              let assertion = assertService.lastAssertion else {
            print("❌ IntegrityView: 缺少断言数据")
            print("   - keyId 存在: \(attestService.lastKeyId != nil)")
            print("   - assertion 存在: \(assertService.lastAssertion != nil)")
            alertMessage = "没有可解析的断言数据"
            showAlert = true
            return
        }
        
        let requestData = testRequestData.data(using: .utf8) ?? Data()
        print("✅ IntegrityView: 参数准备完成")
        print("   - Key ID: \(keyId)")
        print("   - 断言大小: \(assertion.count) bytes")
        print("   - 请求数据: \(testRequestData)")
        print("   - 请求数据大小: \(requestData.count) bytes")
        
        let result = AttestationParser.parseAssertion(assertion: assertion, keyId: keyId, originalData: requestData)
        print("🔍 IntegrityView: 解析结果验证")
        print("   - 结果对象创建: 成功")
        print("   - Key ID设置: \(result.keyId)")
        print("   - 签名验证状态: \(result.signatureVerification)")
        print("   - 断言大小: \(result.assertionSize)")
        
        // 确保在主线程上更新UI状态
        DispatchQueue.main.async {
            // 使用 StateObject 管理器设置数据
            self.parserManager.setAssertionInfo(result)
            print("   - 状态变量设置: 完成 (主线程)")
            print("   - parserManager.assertionInfo != nil: \(self.parserManager.assertionInfo != nil)")
            print("   - parserManager.assertionInfo.keyId: \(self.parserManager.assertionInfo?.keyId ?? "nil")")
            
            // 添加短暂延迟确保状态更新完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("   - 准备触发Sheet显示...")
                print("   - 最终检查 parserManager.assertionInfo != nil: \(self.parserManager.assertionInfo != nil)")
                if let info = self.parserManager.assertionInfo {
                    print("   - 最终检查 Key ID: \(info.keyId)")
                }
                self.showAssertionParser = true
                print("   - 显示解析器: 触发 (主线程)")
            }
        }
    }
}

// MARK: - Document Type

struct CertificateDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var content: String
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

// MARK: - Parser Views

struct CertificateParserView: View {
    let info: AttestationInfo?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    if let info = info {
                        certificateBasicInfo(info)
                        certificateVerificationResults(info)
                        certificateAppleKeys(info)
                    } else {
                        Text("解析失败")
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("证书解析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func certificateBasicInfo(_ info: AttestationInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📜 证书解析结果")
                .font(.title2)
                .fontWeight(.semibold)
            
            parseItem("Key ID", info.keyId)
            parseItem("证书大小", info.rawSize, "bytes")
            parseItem("格式", info.format)
            parseItem("CBOR类型", info.cborType)
            parseItem("Base64预览", info.base64Preview)
        }
    }
    
    @ViewBuilder
    private func certificateVerificationResults(_ info: AttestationInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            Text("🔍 验证结果")
                .font(.headline)
            
            parseItem("1. 签名验证", info.signatureStatus)
            parseItem("2. Bundle ID", info.bundleId)
            parseItem("3. 挑战验证", info.challengeVerification)
            parseItem("4. 公钥提取", info.publicKeyExtracted)
            parseItem("5. 设备认证", info.deviceAttestation)
        }
    }
    
    @ViewBuilder
    private func certificateAppleKeys(_ info: AttestationInfo) -> some View {
        if !info.applePublicKeys.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                
                Text("🔐 Apple证书公钥详情")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                ForEach(0..<info.applePublicKeys.count, id: \.self) { index in
                    AppleKeyInfoView(keyInfo: info.applePublicKeys[index], index: index)
                }
            }
        }
    }
    
    @ViewBuilder
    private func parseItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func parseItem(_ title: String, _ value: Int, _ unit: String) -> some View {
        parseItem(title, "\(value) \(unit)")
    }
}

struct AssertionParserView: View {
    let info: AssertionInfo?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    // 添加调试信息
                    if let info = info {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🔐 断言解析结果")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            parseItem("Key ID", info.keyId)
                            parseItem("断言大小", info.assertionSize, "bytes")
                            parseItem("原始数据大小", info.originalDataSize, "bytes")
                            parseItem("原始数据预览", info.originalDataPreview)
                            parseItem("数据哈希", info.dataHash)
                            
                            Divider()
                            
                            Text("🔍 验证结果")
                                .font(.headline)
                            
                            parseItem("签名验证", info.signatureVerification)
                            parseItem("计数器检查", info.counterCheck)
                            parseItem("时间戳检查", info.timestampCheck)
                            parseItem("签名算法", info.signatureAlgorithm)
                            parseItem("密钥使用", info.keyUsage)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Text("⚠️ 解析数据未接收")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("可能的原因：")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• 数据传递过程中出现问题")
                                Text("• SwiftUI 状态更新延迟")
                                Text("• 解析器返回了空对象")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Text("请检查 Xcode 控制台查看详细日志")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("断言解析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            if let info = info {
                print("✅ AssertionParserView: 收到有效的解析结果")
                print("   - Key ID: \(info.keyId)")
                print("   - 签名验证: \(info.signatureVerification)")
            } else {
                print("❌ AssertionParserView: 收到空的解析结果")
            }
        }
    }
    
    @ViewBuilder
    private func parseItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func parseItem(_ title: String, _ value: Int, _ unit: String) -> some View {
        parseItem(title, "\(value) \(unit)")
    }
}

// MARK: - Apple Key Info View
struct AppleKeyInfoView: View {
    let keyInfo: ApplePublicKeyInfo
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("证书 #\(index + 1)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            keyBasicInfo
            hexRepresentationView
            base64PublicKeyView
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var keyBasicInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            parseItem("公钥类型", keyInfo.keyType)
            parseItem("证书大小", "\(keyInfo.certificateSize) bytes")
            parseItem("公钥大小", "\(keyInfo.keySize) bytes")
        }
    }
    
    @ViewBuilder
    private var hexRepresentationView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("十六进制表示 (用于对比)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(keyInfo.hexRepresentation)
                .font(.system(.footnote, design: .monospaced))
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    @ViewBuilder
    private var base64PublicKeyView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("完整公钥 (Base64) - 可用于验证对比")
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(keyInfo.publicKey)
                    .font(.system(.footnote, design: .monospaced))
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
    
    @ViewBuilder
    private func parseItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    IntegrityView()
}
