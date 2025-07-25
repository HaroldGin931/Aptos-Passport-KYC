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
        print("📦 ParserDataManager: Setting assertion information")
        print("   - Key ID: \(info.keyId)")
        assertionInfo = info
        print("   - Setting complete, assertionInfo != nil: \(assertionInfo != nil)")
    }
    
    func clearAssertionInfo() {
        assertionInfo = nil
    }
    
    func clearResults() {
        print("🧹 ParserDataManager: Clearing all parsing results")
        assertionInfo = nil
        certificateInfo = nil
        print("✅ ParserDataManager: Clearing complete")
    }
}

struct IntegrityView: View {
    @StateObject private var attestService = AppAttestService.shared
    @StateObject private var assertService = AppAssertService.shared
    @StateObject private var authStateManager = AuthenticationStateManager.shared
    @StateObject private var parserManager = ParserDataManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSaveDialog = false
    @State private var certificateToSave = ""
    @State private var testRequestData = "This is a test for sensitive data request"
    @State private var showCertificateParser = false
    @State private var showAssertionParser = false
    @State private var isAttestationCompleted = false // New: Track authentication completion status
    
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
                    
                    // Save Section - Only show if authentication is not completed and certificate exists
                    if attestService.lastAttestation != nil && !isAttestationCompleted {
                        saveSection
                    }
                }
                .padding()
            }
            .navigationTitle("Integrity Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Refresh authentication status every time IntegrityView opens
            print("🔄 IntegrityView onAppear: Refreshing authentication status")
            authStateManager.refreshAuthenticationState()
        }
        .alert("Message", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showCertificateParser) {
            if let info = parserManager.certificateInfo {
                CertificateParserView(info: info)
            } else {
                Text("Certificate data not found")
            }
        }
        .sheet(isPresented: $showAssertionParser) {
            if let info = parserManager.assertionInfo {
                AssertionParserView(info: info)
            } else {
                VStack(spacing: 16) {
                    Text("⚠️ Assertion data not found")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text("Status debug information:")
                        .font(.subheadline)
                    
                    Text("parserManager.assertionInfo: \(parserManager.assertionInfo == nil ? "nil" : "exists")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Close") {
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
                alertMessage = "Certificate saved to: \(url.path)"
                showAlert = true
            case .failure(let error):
                alertMessage = "Save failed: \(error.localizedDescription)"
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
            
            Text("POC Demo - App Attest & Assert")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Verify application and device integrity")
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
                Text("Device Authentication")
                    .font(.headline)
                Spacer()
                // Check authStateManager status first, then check attestService
                statusIndicator(isActive: authStateManager.isAuthenticated || attestService.lastAttestation != nil)
            }
            
            Text("Generate device key and obtain Apple authentication certificate")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if attestService.isLoading {
                ProgressView("Verifying...")
                    .frame(maxWidth: .infinity)
            } else if authStateManager.isAuthenticated || isAttestationCompleted {
                // Authenticated state: Either restored from saved state or just completed authentication
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Device authentication completed")
                            .font(.headline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    
                    if let keyId = attestService.lastKeyId {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Authentication information:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Text("Key ID:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(keyId.prefix(20) + "...")
                                    .font(.system(.caption, design: .monospaced))
                            }
                            
                            if let attestation = attestService.lastAttestation {
                                HStack {
                                    Text("Certificate size:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(attestation.count) bytes")
                                        .font(.caption)
                                }
                                
                                Button("View Certificate Details") {
                                    parseCertificate(attestation: attestation)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Text("Status:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Restored from saved state")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                Text("💡 Certificate details need to be regenerated for viewing")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button("Re-authenticate") {
                                resetAttestation()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            
                            Button("Clear Authentication State") {
                                clearAuthenticationState()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            } else {
                // Only show "Start Device Authentication" button when truly not authenticated
                Button("Start Device Authentication") {
                    Task {
                        await performAttestation()
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!attestService.checkAppAttestSupport())
            }
            
            if !attestService.checkAppAttestSupport() {
                Text("⚠️ Current device does not support App Attest")
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
                Text("Sensitive Data Verification")
                    .font(.headline)
                Spacer()
                statusIndicator(isActive: assertService.lastAssertion != nil)
            }
            
            Text("Use authenticated key to verify sensitive data requests")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Test request input
            VStack(alignment: .leading, spacing: 8) {
                Text("Test request data:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Enter test data", text: $testRequestData)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.caption)
            }
            
            if assertService.isLoading {
                ProgressView("Generating assertion...")
                    .frame(maxWidth: .infinity)
            } else {
                Button("Generate Sensitive Data Assertion") {
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
                    Text("Assertion size: \(assertion.count) bytes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button("Save Assertion to File") {
                            saveAssertionToFile()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("Parse Assertion") {
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
                Text("Attest Certificate")
                    .font(.headline)
                Spacer()
            }
            
            Text("Save the obtained authentication certificate to your chosen location")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let keyId = attestService.lastKeyId,
               let attestation = attestService.lastAttestation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key ID: \(keyId.prefix(16))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Certificate size: \(attestation.count) bytes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Button("Save Certificate to File") {
                        saveCertificateToFile(attestation: attestation, keyId: keyId)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Parse Certificate") {
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
            isAttestationCompleted = true // Set authentication completion status
            alertMessage = "Device authentication successful！\nKey ID: \(result.keyId.prefix(16))...\nCertificate size: \(result.attestation.count) bytes"
            showAlert = true
        } catch {
            alertMessage = "Authentication failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func performAssertion() async {
        guard let keyId = attestService.lastKeyId else {
            alertMessage = "Please complete device authentication first"
            showAlert = true
            return
        }
        
        do {
            let assertion = try await assertService.assertStringRequest(keyId: keyId, requestString: testRequestData)
            alertMessage = "Sensitive data assertion generated successfully！\nAssertion size: \(assertion.count) bytes"
            showAlert = true
        } catch {
            alertMessage = "Assertion generation failed: \(error.localizedDescription)"
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
            alertMessage = "No assertion data to save"
            showAlert = true
            return
        }
        
        let requestData = testRequestData.data(using: .utf8) ?? Data()
        certificateToSave = assertService.saveAssertionToFile(assertion: assertion, keyId: keyId, requestData: requestData)
        showSaveDialog = true
    }
    
    private func resetAttestation() {
        print("🔄 IntegrityView: Resetting authentication status...")
        isAttestationCompleted = false
        parserManager.clearResults()
        
        // Clear data in services
        attestService.errorMessage = nil
        attestService.lastAttestation = nil
        attestService.lastKeyId = nil
        
        // Clear assertion service data
        assertService.errorMessage = nil
        assertService.lastAssertion = nil
        
        print("✅ IntegrityView: Authentication status has been reset")
    }
    
    private func clearAuthenticationState() {
        print("🔄 IntegrityView: Clearing authentication status...")
        
        // Clear authentication state manager status
        authStateManager.clearAuthenticationState()
        
        // Also reset current session authentication status
        resetAttestation()
        
        // Show confirmation message
        alertMessage = "Authentication status has been cleared, device authentication needs to be performed again."
        showAlert = true
        
        print("✅ IntegrityView: Authentication status has been cleared")
    }
    
    private func parseCertificate(attestation: Data) {
        print("🔄 IntegrityView: Starting certificate parsing...")
        print("   - Certificate data size: \(attestation.count) bytes")
        print("💡 Will extract Key ID, public key, Bundle ID and other information from certificate itself")
        
        // Call updated parser, which will extract all information from certificate itself
        let result = AttestationParser.parseCertificate(attestation: attestation)
        parserManager.certificateInfo = result
        print("   - Parsing complete, extracted Key ID: \(result.keyId)")
        print("   - Parsing complete, extracted Bundle ID: \(result.bundleId)")
        showCertificateParser = true
    }
    
    private func parseAssertion() {
        print("🔄 IntegrityView: Starting assertion parsing...")
        
        guard let keyId = attestService.lastKeyId,
              let assertion = assertService.lastAssertion else {
            print("❌ IntegrityView: Missing assertion data")
            print("   - keyId exists: \(attestService.lastKeyId != nil)")
            print("   - assertion exists: \(assertService.lastAssertion != nil)")
            alertMessage = "No assertion data to parse"
            showAlert = true
            return
        }
        
        let requestData = testRequestData.data(using: .utf8) ?? Data()
        print("✅ IntegrityView: Parameters preparation complete")
        print("   - Key ID: \(keyId)")
        print("   - Assertion size: \(assertion.count) bytes")
        print("   - Request data: \(testRequestData)")
        print("   - Request data size: \(requestData.count) bytes")
        
        let result = AttestationParser.parseAssertion(assertion: assertion, keyId: keyId, originalData: requestData)
        print("🔍 IntegrityView: Parsing result verification")
        print("   - Result object creation: Success")
        print("   - Key ID setting: \(result.keyId)")
        print("   - Signature verification status: \(result.signatureVerification)")
        print("   - Assertion size: \(result.assertionSize)")
        
        // Ensure UI state is updated on main thread
        DispatchQueue.main.async {
            // Use StateObject manager to set data
            self.parserManager.setAssertionInfo(result)
            print("   - Status variable setting: Complete (main thread)")
            print("   - parserManager.assertionInfo != nil: \(self.parserManager.assertionInfo != nil)")
            print("   - parserManager.assertionInfo.keyId: \(self.parserManager.assertionInfo?.keyId ?? "nil")")
            
            // Add brief delay to ensure state update completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("   - Preparing to trigger Sheet display...")
                print("   - Final check parserManager.assertionInfo != nil: \(self.parserManager.assertionInfo != nil)")
                if let info = self.parserManager.assertionInfo {
                    print("   - Final check Key ID: \(info.keyId)")
                }
                self.showAssertionParser = true
                print("   - Display parser: Triggered (main thread)")
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
                        Text("Parsing failed")
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Certificate Parsing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func certificateBasicInfo(_ info: AttestationInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📜 Certificate Parsing Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            parseItem("Key ID", info.keyId)
            parseItem("Certificate size", info.rawSize, "bytes")
            parseItem("Format", info.format)
            parseItem("CBOR type", info.cborType)
            parseItem("Base64 preview", info.base64Preview)
        }
    }
    
    @ViewBuilder
    private func certificateVerificationResults(_ info: AttestationInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            Text("🔍 Verification Results")
                .font(.headline)
            
            parseItem("1. Signature verification", info.signatureStatus)
            parseItem("2. Bundle ID", info.bundleId)
            parseItem("3. Challenge verification", info.challengeVerification)
            parseItem("4. Public key extraction", info.publicKeyExtracted)
            parseItem("5. Device attestation", info.deviceAttestation)
        }
    }
    
    @ViewBuilder
    private func certificateAppleKeys(_ info: AttestationInfo) -> some View {
        if !info.applePublicKeys.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                
                Text("🔐 Apple Certificate Public Key Details")
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
                            Text("🔐 Assertion Parsing Results")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            parseItem("Key ID", info.keyId)
                            parseItem("Assertion size", info.assertionSize, "bytes")
                            parseItem("Original data size", info.originalDataSize, "bytes")
                            parseItem("Original data preview", info.originalDataPreview)
                            parseItem("Data hash", info.dataHash)
                            
                            Divider()
                            
                            Text("🔍 Verification Results")
                                .font(.headline)
                            
                            parseItem("Signature verification", info.signatureVerification)
                            parseItem("Counter check", info.counterCheck)
                            parseItem("Timestamp check", info.timestampCheck)
                            parseItem("Signature algorithm", info.signatureAlgorithm)
                            parseItem("Key usage", info.keyUsage)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Text("⚠️ Parsing data not received")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("Possible reasons:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Problem occurred during data transfer process")
                                Text("• SwiftUI state update delay")
                                Text("• Parser returned empty object")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Text("Please check Xcode console for detailed logs")
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
            .navigationTitle("Assertion Parsing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if let info = info {
                print("✅ AssertionParserView: Received valid parsing results")
                print("   - Key ID: \(info.keyId)")
                print("   - Signature verification: \(info.signatureVerification)")
            } else {
                print("❌ AssertionParserView: Received empty parsing results")
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
            Text("Certificate #\(index + 1)")
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
            parseItem("Public key type", keyInfo.keyType)
            parseItem("Certificate size", "\(keyInfo.certificateSize) bytes")
            parseItem("Public key size", "\(keyInfo.keySize) bytes")
        }
    }
    
    @ViewBuilder
    private var hexRepresentationView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hexadecimal representation (for comparison)")
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
            Text("Complete public key (Base64) - Can be used for verification comparison")
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
