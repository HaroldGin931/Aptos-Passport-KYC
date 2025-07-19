//
//  ChinesePassportScannerView.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import SwiftUI

struct ChinesePassportScannerView: View {
    @StateObject private var passportReader = ChinesePassportReader()
    @Environment(\.dismiss) private var dismiss
    
    // MRZ信息输入
    @State private var passportNumber = "E12341234"
    @State private var dateOfBirth = "900101"
    @State private var dateOfExpiry = "300101"
    
    // BAC计算相关
    @State private var bacKeyInfo: BACKeyInfo?
    @State private var bacValidationResult: BACValidationResult?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 始终显示输入界面
                mrzInputView
                
                // 护照信息显示
                if let passport = passportReader.passportData {
                    passportInfoSection(passport)
                }
                
                Spacer()
                
                // 操作按钮
                actionButtons
            }
            .padding()
            .navigationTitle("护照读取")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        passportReader.stopReading()
                        dismiss()
                    }
                }
            }
            .alert("错误", isPresented: .constant(passportReader.errorMessage != nil)) {
                Button("确定") {
                    passportReader.errorMessage = nil
                }
            } message: {
                if let errorMessage = passportReader.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - MRZ信息输入界面
    private var mrzInputView: some View {
        VStack(spacing: 25) {
            // 标题
            VStack(spacing: 10) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("护照信息输入")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("请输入护照上的基本信息，用于计算BAC密钥")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 输入表单
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("护照号")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    SecureField("例如: EA1234567", text: $passportNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("出生日期 (YYMMDD)")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    SecureField("例如: 900115", text: $dateOfBirth)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: dateOfBirth) { oldValue, newValue in
                            if newValue.count > 6 {
                                dateOfBirth = String(newValue.prefix(6))
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("到期日期 (YYMMDD)")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    SecureField("例如: 300115", text: $dateOfExpiry)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: dateOfExpiry) { oldValue, newValue in
                            if newValue.count > 6 {
                                dateOfExpiry = String(newValue.prefix(6))
                            }
                        }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
            
            // 说明
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 信息说明:")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text("• 护照号: 护照封面上的9位字母数字组合")
                Text("• 出生日期: 年月日格式，如1990年1月15日 = 900115")
                Text("• 到期日期: 年月日格式，如2030年1月15日 = 300115")
                Text("• 这些信息用于计算BAC密钥，确保护照读取安全")
                
                // 显示验证错误（如果有的话）
                if let validationResult = bacValidationResult, !validationResult.isValid {
                    Divider()
                    Text("⚠️ 输入验证错误:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    ForEach(validationResult.errors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                // 首先验证并计算BAC信息
                updateBACInfo()
                if bacValidationResult?.isValid == true {
                    // 直接开始NFC扫描，不切换页面
                    let mrzInfo = MRZInfo(
                        documentNumber: passportNumber,
                        dateOfBirth: dateOfBirth,
                        dateOfExpiry: dateOfExpiry,
                        checkDigits: "" // 这里可以为空，主要用于显示
                    )
                    
                    passportReader.readPassport(with: mrzInfo)
                }
            }) {
                HStack {
                    Image(systemName: "wave.3.right")
                    Text("开始NFC扫描")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidMRZInput() ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
            }
            .disabled(!isValidMRZInput())
        }
    }
    
    // MARK: - 辅助函数
    private func isValidMRZInput() -> Bool {
        let validation = PassportBACCalculator.validateBACInputs(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        return validation.isValid
    }
    
    /// 更新BAC密钥信息
    private func updateBACInfo() {
        // 验证输入
        bacValidationResult = PassportBACCalculator.validateBACInputs(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        
        // 如果验证通过，计算BAC密钥
        if bacValidationResult?.isValid == true {
            bacKeyInfo = BACKeyInfo(
                passportNumber: passportNumber,
                dateOfBirth: dateOfBirth,
                dateOfExpiry: dateOfExpiry
            )
        } else {
            bacKeyInfo = nil
        }
    }
    
    /// 获取BAC密钥摘要信息（用于调试）
    private func getBACKeySummary() -> String {
        return bacKeyInfo?.summary ?? "BAC密钥未计算"
    }
    
    /// 遮盖敏感信息显示
    private func maskSensitiveInfo(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        
        if text.count <= 2 {
            return String(repeating: "●", count: text.count)
        } else if text.count <= 4 {
            // 显示前1位和后1位，中间用圆点
            return String(text.prefix(1)) + String(repeating: "●", count: text.count - 2) + String(text.suffix(1))
        } else {
            // 显示前2位和后2位，中间用圆点
            return String(text.prefix(2)) + String(repeating: "●", count: text.count - 4) + String(text.suffix(2))
        }
    }
    
    // MARK: - 护照信息显示
    private func passportInfoSection(_ passport: ChinesePassportData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("读取成功")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Group {
                InfoRow(title: "姓名", value: "\(passport.lastName) \(passport.firstName)")
                InfoRow(title: "护照号", value: maskSensitiveInfo(passport.documentNumber))
                InfoRow(title: "国籍", value: passport.nationality)
                InfoRow(title: "签发国", value: passport.issuingAuthority)
                InfoRow(title: "性别", value: passport.gender)
                
                if let birthDate = passport.dateOfBirth {
                    InfoRow(title: "出生日期", value: formatDate(birthDate))
                }
                
                if let expiryDate = passport.dateOfExpiry {
                    InfoRow(title: "到期日期", value: formatDate(expiryDate))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.green, lineWidth: 2)
        )
    }
    
    // MARK: - 辅助方法
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 信息行组件
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}
