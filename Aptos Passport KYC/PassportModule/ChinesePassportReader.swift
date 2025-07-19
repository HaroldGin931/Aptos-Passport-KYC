//
//  ChinesePassportReader.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/18.
//

import Foundation
import CoreNFC
import CryptoKit
import CommonCrypto

// MARK: - 中国护照数据模型
struct ChinesePassportData {
    let documentNumber: String
    let firstName: String
    let lastName: String
    let nationality: String
    let issuingAuthority: String
    let gender: String
    let dateOfBirth: Date?
    let dateOfExpiry: Date?
    let placeOfBirth: String?
    let personalNumber: String?
    let faceImage: Data?
}

// MARK: - MRZ信息结构
struct MRZInfo {
    let documentNumber: String
    let dateOfBirth: String
    let dateOfExpiry: String
    let checkDigits: String
}

// MARK: - 中国护照读取器
class ChinesePassportReader: NSObject, ObservableObject {
    @Published var isReading = false
    @Published var statusMessage = "准备读取"
    @Published var errorMessage: String?
    @Published var passportData: ChinesePassportData?
    
    private var nfcSession: NFCTagReaderSession?
    private var mrzInfo: MRZInfo?
    
    // MRZ信息用于BAC计算
    private var mrzPassportNumber: String = ""
    private var mrzDateOfBirth: String = ""
    private var mrzDateOfExpiry: String = ""
    
    // BAC密钥存储
    private var bacKEnc: Data?
    private var bacKMac: Data?
    private var bacRndIFD: Data?
    private var bacRndIC: Data?
    private var bacKIC: Data? // 保存我们生成的KIC
    
    // 会话密钥存储
    private var sessionKEnc: Data?
    private var sessionKMac: Data?
    private var ssc: UInt64 = 0
    
    override init() {
        super.init()
    }
    
    // MARK: - 公共接口
    
    // 使用MRZ信息开始读取护照
    func readPassport(with mrzInfo: MRZInfo) {
        log("🚀 开始读取护照，护照号: \(mrzInfo.documentNumber)")
        
        self.mrzInfo = mrzInfo
        self.mrzPassportNumber = mrzInfo.documentNumber
        self.mrzDateOfBirth = mrzInfo.dateOfBirth
        self.mrzDateOfExpiry = mrzInfo.dateOfExpiry
        
        DispatchQueue.main.async {
            self.isReading = true
            self.statusMessage = "准备NFC读取"
            self.errorMessage = nil
            self.passportData = nil
        }
        
        // 计算BAC密钥
        calculateBACKeys()
        
        // 启动NFC会话
        startNFCSession()
    }
    
    // 停止读取
    func stopReading() {
        log("⏹️ 用户取消读取")
        nfcSession?.invalidate()
        
        DispatchQueue.main.async {
            self.isReading = false
            self.statusMessage = "已取消"
        }
    }
    
    // MARK: - BAC密钥计算
    
    private func calculateBACKeys() {
        log("🔑 开始计算BAC密钥")
        
        // 使用PassportBACCalculator计算BAC密钥
        let keys = PassportBACCalculator.deriveBACKeys(
            passportNumber: mrzPassportNumber,
            dateOfBirth: mrzDateOfBirth,
            dateOfExpiry: mrzDateOfExpiry
        )
        
        self.bacKEnc = keys.encryptionKey
        self.bacKMac = keys.macKey
        
        log("✅ BAC密钥计算成功")
        log("🔑 KEnc: \(keys.encryptionKey.hexString)")
        log("🔑 KMac: \(keys.macKey.hexString)")
    }
    
    // MARK: - NFC会话管理
    
    private func startNFCSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            log("❌ 此设备不支持NFC读取")
            DispatchQueue.main.async {
                self.errorMessage = "此设备不支持NFC读取"
                self.isReading = false
            }
            return
        }
        
        nfcSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        nfcSession?.alertMessage = "请将手机靠近护照的个人信息页"
        nfcSession?.begin()
        
        log("📱 NFC会话已启动")
    }
    
    // MARK: - 日志输出
    
    private func log(_ message: String) {
        print("[ChinesePassportReader] \(message)")
        
        DispatchQueue.main.async {
            self.statusMessage = message
        }
    }
    
    // MARK: - 3DES加密/解密工具
    
    private func encrypt3DESECB(data: Data, key: Data) -> Data {
        return perform3DESOperation(data: data, key: key, operation: CCOperation(kCCEncrypt), mode: CCMode(kCCModeECB))
    }
    
    private func decrypt3DESECB(data: Data, key: Data) -> Data {
        return perform3DESOperation(data: data, key: key, operation: CCOperation(kCCDecrypt), mode: CCMode(kCCModeECB))
    }
    
    private func encrypt3DESCBC(data: Data, key: Data, iv: Data? = nil) -> Data {
        return perform3DESOperation(data: data, key: key, operation: CCOperation(kCCEncrypt), mode: CCMode(kCCModeCBC), iv: iv)
    }
    
    private func decrypt3DESCBC(data: Data, key: Data, iv: Data? = nil) -> Data {
        return perform3DESOperation(data: data, key: key, operation: CCOperation(kCCDecrypt), mode: CCMode(kCCModeCBC), iv: iv)
    }
    
    private func perform3DESOperation(data: Data, key: Data, operation: CCOperation, mode: CCMode, iv: Data? = nil) -> Data {
        let keyLength = key.count
        let dataLength = data.count
        
        // 确保密钥长度正确 (24字节用于3DES)
        var keyData = key
        if keyLength == 16 {
            // 如果是16字节密钥，扩展为24字节
            keyData = key + key.prefix(8)
        } else if keyLength < 24 && keyLength != 16 {
            log("❌ 3DES密钥长度错误: \(keyLength)")
            return Data()
        }
        
        let bufferSize = dataLength + kCCBlockSize3DES
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesProcessed: size_t = 0
        
        // 根据模式设置选项
        var options: CCOptions = 0
        if mode == CCMode(kCCModeCBC) {
            // ICAO 9303 Part 11, 4.3.3 specifies NO PADDING for External Authenticate's EncS.
            // The input S is 32 bytes, which is a multiple of the 8-byte block size,
            // so no padding is needed. kCCOptionPKCS7Padding would add an extra block.
            // options = CCOptions(kCCOptionPKCS7Padding) // This was causing the issue.
        }
        
        let cryptStatus = keyData.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                if let ivData = iv {
                    return ivData.withUnsafeBytes { ivBytes in
                        return CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithm3DES),
                            options,
                            keyBytes.baseAddress, keyData.count,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress, dataLength,
                            &buffer,
                            bufferSize,
                            &numBytesProcessed
                        )
                    }
                } else {
                    return CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithm3DES),
                        options,
                        keyBytes.baseAddress, keyData.count,
                        nil,
                        dataBytes.baseAddress, dataLength,
                        &buffer,
                        bufferSize,
                        &numBytesProcessed
                    )
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else {
            log("❌ 3DES操作失败: \(cryptStatus)")
            log("❌ 密钥长度: \(keyData.count), 数据长度: \(dataLength)")
            log("❌ 操作: \(operation), 模式: \(mode)")
            return Data()
        }
        
        return Data(bytes: buffer, count: numBytesProcessed)
    }
    
    // 计算MAC (使用3DES-CBC-MAC)
    private func calculateMAC(data: Data, key: Data) -> Data {
        log("🔐 计算MAC，数据长度: \(data.count)，密钥长度: \(key.count)")
        log("🔐 MAC输入数据: \(data.hexString)")
        log("🔐 MAC密钥: \(key.hexString)")
        
        // ISO 9797-1 MAC Algorithm 3 (3DES-CBC-MAC)
        let blockSize = 8
        var paddedData = data
        
        // 添加ISO 9797-1 Padding Method 2
        paddedData.append(0x80)
        while paddedData.count % blockSize != 0 {
            paddedData.append(0x00)
        }
        
        log("🔐 填充后数据: \(paddedData.hexString)")
        
        // 确保密钥长度正确
        var macKey = key
        if key.count == 16 {
            macKey = key + key.prefix(8) // 扩展为24字节
        } else if key.count < 16 {
            log("❌ MAC密钥长度不足: \(key.count)")
            return Data()
        }
        
        // 简化的MAC计算：使用3DES-CBC加密最后一个块
        var mac = Data(repeating: 0, count: blockSize)
        
        // 逐块处理
        for i in stride(from: 0, to: paddedData.count, by: blockSize) {
            let endIndex = min(i + blockSize, paddedData.count)
            var block = paddedData.subdata(in: i..<endIndex)
            
            // 确保块大小为8字节
            while block.count < blockSize {
                block.append(0x00)
            }
            
            // XOR with previous MAC
            var xorBlock = Data()
            for j in 0..<blockSize {
                let xorByte = mac[j] ^ block[j]
                xorBlock.append(xorByte)
            }
            
            // 使用DES加密（使用前8字节密钥）
            let desKey = Data(macKey.prefix(8))
            mac = performDESOperation(data: xorBlock, key: desKey, operation: CCOperation(kCCEncrypt))
            
            if mac.isEmpty {
                log("❌ DES加密失败")
                return Data()
            }
        }
        
        // 最终3DES处理：Decrypt-Encrypt
        if macKey.count >= 24 {
            let key2 = Data(macKey.subdata(in: 8..<16)) // 第二个8字节
            let key1 = Data(macKey.prefix(8)) // 第一个8字节
            
            // Decrypt with key2
            mac = performDESOperation(data: mac, key: key2, operation: CCOperation(kCCDecrypt))
            if mac.isEmpty {
                log("❌ DES解密失败")
                return Data()
            }
            
            // Encrypt with key1
            mac = performDESOperation(data: mac, key: key1, operation: CCOperation(kCCEncrypt))
            if mac.isEmpty {
                log("❌ DES加密失败")
                return Data()
            }
        }
        
        let finalMAC = Data(mac.prefix(8))
        log("🔐 计算出的MAC: \(finalMAC.hexString)")
        return finalMAC
    }
    
    // DES操作（用于MAC计算）
    private func performDESOperation(data: Data, key: Data, operation: CCOperation) -> Data {
        guard key.count == 8 else {
            log("❌ DES密钥长度错误: \(key.count)")
            return Data()
        }
        
        guard data.count == 8 else {
            log("❌ DES数据长度错误: \(data.count)")
            return Data()
        }
        
        let bufferSize = 8
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesProcessed: size_t = 0
        
        let cryptStatus = key.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                return CCCrypt(
                    operation,
                    CCAlgorithm(kCCAlgorithmDES),
                    0, // 无选项，ECB模式无填充
                    keyBytes.baseAddress, 8,
                    nil, // 无IV
                    dataBytes.baseAddress, 8,
                    &buffer,
                    bufferSize,
                    &numBytesProcessed
                )
            }
        }
        
        guard cryptStatus == kCCSuccess else {
            log("❌ DES操作失败: \(cryptStatus)")
            return Data()
        }
        
        return Data(bytes: buffer, count: numBytesProcessed)
    }
    
    // MARK: - BAC认证流程
    
    private func performGetChallenge(iso7816Tag: NFCISO7816Tag, completion: @escaping (Data?) -> Void) {
        log("🎲 开始获取随机数挑战")
        
        let getChallengeAPDU = NFCISO7816APDU(
            instructionClass: 0x00,
            instructionCode: 0x84,
            p1Parameter: 0x00,
            p2Parameter: 0x00,
            data: Data(),
            expectedResponseLength: 8
        )
        
        iso7816Tag.sendCommand(apdu: getChallengeAPDU) { [weak self] data, sw1, sw2, error in
            if let error = error {
                self?.log("❌ 获取挑战失败: \(error)")
                completion(nil)
                return
            }
            
            if sw1 == 0x90 && sw2 == 0x00 {
                self?.log("✅ 获取挑战成功: \(data.hexString)")
                completion(data)
            } else {
                self?.log("❌ 获取挑战失败: SW1=\(String(format: "%02X", sw1)), SW2=\(String(format: "%02X", sw2))")
                completion(nil)
            }
        }
    }
    
    private func performExternalAuthenticate(
        iso7816Tag: NFCISO7816Tag,
        rndIC: Data,
        completion: @escaping (Data?) -> Void
    ) {
        log("🔐 开始外部认证")
        
        guard let bacKEnc = bacKEnc, let bacKMac = bacKMac else {
            log("❌ BAC密钥未计算")
            completion(nil)
            return
        }
        
        // 生成随机数RND.IFD
        var rndIFD = Data(count: 8)
        let result = rndIFD.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 8, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            log("❌ 生成随机数失败")
            completion(nil)
            return
        }
        
        self.bacRndIFD = rndIFD
        self.bacRndIC = rndIC
        
        log("🎲 RND.IFD: \(rndIFD.hexString)")
        log("🎲 RND.IC: \(rndIC.hexString)")
        
        // 生成密钥种子KiC
        var kIC = Data(count: 16)
        let kiCResult = kIC.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 16, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard kiCResult == errSecSuccess else {
            log("❌ 生成KiC失败")
            completion(nil)
            return
        }
        self.bacKIC = kIC // 保存kIC以供后续使用
        
        // 构建S = RND.IFD || RND.IC || KiC (32字节)
        // ICAO 9303 Part 11, 4.3.3 specifies the order RND.IFD || RND.IC
        let S = rndIFD + rndIC + kIC
        log("🔗 S (RND.IFD || RND.IC || KiC): \(S.hexString)")
        
        // 使用KEnc加密S
        let encryptedS = encrypt3DESCBC(data: S, key: bacKEnc, iv: Data(repeating: 0, count: 8))
        log("🔐 加密的S: \(encryptedS.hexString)")
        
        // 计算MAC
        let macInput = encryptedS
        let mac = calculateMAC(data: macInput, key: bacKMac)
        log("🏷️ 计算的MAC: \(mac.hexString)")
        
        // 构建外部认证命令数据: encryptedS || MAC
        let cmdData = encryptedS + mac
        log("📤 外部认证命令数据: \(cmdData.hexString)")
        
        let externalAuthAPDU = NFCISO7816APDU(
            instructionClass: 0x00,
            instructionCode: 0x82,
            p1Parameter: 0x00,
            p2Parameter: 0x00,
            data: cmdData,
            expectedResponseLength: 256 // Use a valid value for Le, e.g., 256 for max length
        )
        
        iso7816Tag.sendCommand(apdu: externalAuthAPDU) { [weak self] data, sw1, sw2, error in
            if let error = error {
                self?.log("❌ 外部认证失败: \(error)")
                completion(nil)
                return
            }
            
            self?.log("📥 外部认证响应: SW1=\(String(format: "%02X", sw1)), SW2=\(String(format: "%02X", sw2))")
            self?.log("📥 响应数据: \(data.hexString)")
            
            if sw1 == 0x90 && sw2 == 0x00 {
                self?.log("✅ 外部认证成功")
                completion(data)
            } else {
                self?.log("❌ 外部认证失败: SW1=\(String(format: "%02X", sw1)), SW2=\(String(format: "%02X", sw2))")
                completion(nil)
            }
        }
    }
    
    // 提取并保存会话密钥 (ICAO 9303标准实现)
    private func extractAndSaveSessionKeys(from authResponse: Data) {
        log("🔑 开始提取会话密钥 (ICAO 9303标准)")
        
        guard let bacKEnc = bacKEnc,
              let bacKMac = bacKMac,
              let bacRndIFD = bacRndIFD,
              let bacRndIC = bacRndIC,
              let kIC = self.bacKIC else { // 使用保存的kIC
            log("❌ BAC认证数据不完整 (KEnc, KMac, RNDs, or kIC is missing)")
            return
        }
        
        guard authResponse.count >= 40 else {
            log("❌ 认证响应数据长度不足: \(authResponse.count), 期望至少40字节")
            return
        }
        
        // 解析响应: encryptedR (32字节) + MAC (8字节)
        let encryptedR = authResponse.prefix(32)
        let receivedMAC = authResponse.suffix(8)
        
        log("🔐 加密的R: \(encryptedR.hexString)")
        log("🏷️ 接收的MAC: \(Data(receivedMAC).hexString)")
        
        // 验证MAC
        let expectedMAC = calculateMAC(data: encryptedR, key: bacKMac)
        log("🏷️ 期望的MAC: \(expectedMAC.hexString)")
        
        guard Data(receivedMAC) == expectedMAC else {
            log("❌ MAC验证失败")
            return
        }
        
        log("✅ MAC验证成功")
        
        // 解密R
        let decryptedR = decrypt3DESCBC(data: encryptedR, key: bacKEnc, iv: Data(repeating: 0, count: 8))
        log("🔓 解密的R: \(decryptedR.hexString)")
        
        guard decryptedR.count >= 32 else {
            log("❌ 解密数据长度不足: \(decryptedR.count), 期望32字节")
            return
        }
        
        // ICAO 9303 Part 11, 4.4: R = RND.IC || RND.IFD || K.ICC
        let receivedRndIC = decryptedR.prefix(8)
        let receivedRndIFD = decryptedR.subdata(in: 8..<16)
        let kICC = Data(decryptedR.suffix(16)) // Convert SubSequence to Data to reset indices
        
        log("🎲 接收的RND.IC: \(Data(receivedRndIC).hexString)")
        log("🎲 接收的RND.IFD: \(Data(receivedRndIFD).hexString)")
        log("🔑 K.ICC: \(Data(kICC).hexString)")
        
        // 验证随机数
        guard Data(receivedRndIC) == bacRndIC else {
            log("❌ RND.IC验证失败")
            log("   - 期望: \(bacRndIC.hexString)")
            log("   - 收到: \(Data(receivedRndIC).hexString)")
            return
        }
        
        guard Data(receivedRndIFD) == bacRndIFD else {
            log("❌ RND.IFD验证失败")
            log("   - 期望: \(bacRndIFD.hexString)")
            log("   - 收到: \(Data(receivedRndIFD).hexString)")
            return
        }
        
        log("✅ 随机数验证成功")
        
        // 按照ICAO 9303标准计算会话密钥
        // 会话密钥种子 KSeed = K.IC XOR K.ICC
        var sessionKeySeed = Data()
        for i in 0..<16 {
            sessionKeySeed.append(kIC[i] ^ kICC[i])
        }
        
        log("🌱 会话密钥种子 (K.IC XOR K.ICC): \(sessionKeySeed.hexString)")
        
        // 使用SHA-1派生会话密钥 (ICAO 9303-11, Appendix D.1)
        // KEnc = SHA1(KSeed || 00000001)
        let kEncSeed = sessionKeySeed + Data([0x00, 0x00, 0x00, 0x01])
        let kEncHash = calculateSHA1(data: kEncSeed)
        self.sessionKEnc = PassportBACCalculator.adjustParity(key: Data(kEncHash.prefix(16)))
        
        // KMac = SHA1(KSeed || 00000002)
        let kMacSeed = sessionKeySeed + Data([0x00, 0x00, 0x00, 0x02])
        let kMacHash = calculateSHA1(data: kMacSeed)
        self.sessionKMac = PassportBACCalculator.adjustParity(key: Data(kMacHash.prefix(16)))
        
        // 初始化SSC (Send Sequence Counter)
        // SSC = RND.IC的后4字节 + RND.IFD的后4字节
        let sscInitData = Data(bacRndIC.suffix(4)) + Data(bacRndIFD.suffix(4))
        // Manually construct the UInt64 from big-endian bytes to ensure all bytes are processed
        var tempSsc: UInt64 = 0
        for byte in sscInitData {
            tempSsc = (tempSsc << 8) | UInt64(byte)
        }
        self.ssc = tempSsc
        
        log("✅ 会话密钥派生完成")
        log("🔑 会话KEnc: \(sessionKEnc!.hexString)")
        log("🔑 会话KMac: \(sessionKMac!.hexString)")
        log("🔢 初始SSC Raw Data: \(sscInitData.hexString)")
        log("🔢 初始SSC Value: \(String(format: "%016X", ssc))")
    }
    
    // 计算SHA-1哈希
    private func calculateSHA1(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        _ = data.withUnsafeBytes { bytes in
            CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
    
    // MARK: - 安全消息传递 (Secure Messaging)
    
    // 使用安全消息传递读取文件
    private func readFileWithSecureMessaging(
        iso7816Tag: NFCISO7816Tag,
        session: NFCTagReaderSession,
        fileID: Data,
        fileName: String
    ) {
        log("📂 开始读取文件: \(fileName)")
        log("📂 文件ID: \(fileID.hexString)")
        
        // 1. 选择文件
        let selectAPDU = createSecureSelectAPDU(fileID: fileID)
        
        iso7816Tag.sendCommand(apdu: selectAPDU) { [weak self] data, sw1, sw2, error in
            guard let self = self else { return }
            
            if let error = error {
                self.log("❌ 选择\(fileName)文件失败: \(error)")
                self.handleReadError(session: session, message: "选择文件失败")
                return
            }
            
            self.log("📂 选择\(fileName)响应: SW1=\(String(format: "%02X", sw1)), SW2=\(String(format: "%02X", sw2))")
            
            // 处理特定错误码
            switch (sw1, sw2) {
            case (0x90, 0x00):
                self.log("✅ \(fileName)文件选择成功")
                
                // 2. 检测文件长度
                self.detectFileLength(iso7816Tag: iso7816Tag, session: session, fileName: fileName)
                
            case (0x69, 0x82):
                self.log("❌ 安全状态不满足 - 需要重新认证")
                self.handleReadError(session: session, message: "安全状态不满足，需要重新认证")
                
            case (0x6A, 0x82):
                self.log("❌ 文件未找到")
                self.handleReadError(session: session, message: "文件未找到")
                
            case (0x67, 0x00):
                self.log("❌ Le字段错误")
                self.handleReadError(session: session, message: "命令长度错误")
                
            case (0x69, 0x88):
                self.log("❌ 安全消息传递数据对象错误")
                self.handleReadError(session: session, message: "安全消息传递格式错误")
                
            default:
                self.log("❌ \(fileName)文件选择失败: SW1=\(String(format: "%02X", sw1)), SW2=\(String(format: "%02X", sw2))")
                self.handleReadError(session: session, message: "文件选择失败: \(String(format: "%02X%02X", sw1, sw2))")
            }
        }
    }
    
    // 检测文件长度
    private func detectFileLength(
        iso7816Tag: NFCISO7816Tag,
        session: NFCTagReaderSession,
        fileName: String
    ) {
        log("📏 检测\(fileName)文件长度")
        
        // 先尝试读取前4字节来获取文件长度信息
        let readHeaderAPDU = createSecureReadAPDU(offset: 0, length: 4)
        
        iso7816Tag.sendCommand(apdu: readHeaderAPDU) { [weak self] data, sw1, sw2, error in
            guard let self = self else { return }
            
            if let error = error {
                self.log("❌ 读取\(fileName)头部失败: \(error)")
                self.handleReadError(session: session, message: "读取文件头部失败")
                return
            }
            
            if sw1 == 0x90 && sw2 == 0x00 {
                // 解密响应数据
                let decryptedData = self.decryptSecureResponse(data)
                self.log("📏 \(fileName)头部数据: \(decryptedData.hexString)")
                
                // 解析文件长度（通常在前几个字节）
                var fileLength = 255 // 默认长度
                
                if decryptedData.count >= 4 {
                    // 尝试解析DER/TLV格式的长度
                    if decryptedData[0] == 0x60 || decryptedData[0] == 0x61 {
                        // BER/DER格式
                        if decryptedData[1] & 0x80 == 0 {
                            // 短格式
                            fileLength = Int(decryptedData[1])
                        } else {
                            // 长格式
                            let lengthBytes = Int(decryptedData[1] & 0x7F)
                            if lengthBytes <= 2 && decryptedData.count > 1 + lengthBytes {
                                fileLength = 0
                                for i in 0..<lengthBytes {
                                    fileLength = (fileLength << 8) + Int(decryptedData[2 + i])
                                }
                            }
                        }
                    }
                }
                
                fileLength = min(fileLength + 10, 1024) // 添加一些缓冲，限制最大长度
                self.log("📏 估算\(fileName)文件长度: \(fileLength)字节")
                
                // 开始分块读取文件
                self.readFileInChunks(
                    iso7816Tag: iso7816Tag,
                    session: session,
                    fileName: fileName,
                    totalLength: fileLength
                )
                
            } else {
                self.log("❌ 读取\(fileName)头部失败: SW1=\(String(format: "%02X", sw1)), SW2=\(String(format: "%02X", sw2))")
                // 回退到默认长度读取
                self.readFileInChunks(
                    iso7816Tag: iso7816Tag,
                    session: session,
                    fileName: fileName,
                    totalLength: 255
                )
            }
        }
    }
    
    // 分块读取文件
    private func readFileInChunks(
        iso7816Tag: NFCISO7816Tag,
        session: NFCTagReaderSession,
        fileName: String,
        totalLength: Int
    ) {
        log("📚 开始分块读取\(fileName)，总长度: \(totalLength)字节")
        
        var allData = Data()
        let chunkSize = 240 // 每次读取240字节
        
        func readNextChunk(offset: Int) {
            guard offset < totalLength else {
                // 读取完成
                self.log("✅ \(fileName)读取完成，总数据: \(allData.count)字节")
                self.log("📄 \(fileName)原始数据: \(allData.hexString)")
                
                // 处理读取到的数据
                self.processReadData(fileName: fileName, data: allData, session: session)
                return
            }
            
            let remainingBytes = totalLength - offset
            let currentChunkSize = min(chunkSize, remainingBytes)
            
            self.log("📖 读取\(fileName) offset=\(offset), length=\(currentChunkSize)")
            
            let readAPDU = self.createSecureReadAPDU(offset: offset, length: currentChunkSize)
            
            iso7816Tag.sendCommand(apdu: readAPDU) { [weak self] data, sw1, sw2, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.log("❌ 读取\(fileName)块失败: \(error)")
                    self.handleReadError(session: session, message: "读取文件块失败")
                    return
                }
                
                if sw1 == 0x90 && sw2 == 0x00 {
                    // 解密响应数据
                    let decryptedData = self.decryptSecureResponse(data)
                    self.log("📖 \(fileName)块数据: \(decryptedData.hexString)")
                    
                    allData.append(decryptedData)
                    
                    // 读取下一块
                    readNextChunk(offset: offset + currentChunkSize)
                    
                } else if sw1 == 0x6B && sw2 == 0x00 {
                    // 到达文件末尾
                    self.log("📄 \(fileName)已到达文件末尾")
                    self.log("✅ \(fileName)读取完成，总数据: \(allData.count)字节")
                    self.processReadData(fileName: fileName, data: allData, session: session)
                    
                } else {
                    self.log("❌ 读取\(fileName)块失败: SW1=\(String(format: "%02X", sw1)), SW2=\(String(format: "%02X", sw2))")
                    
                    // 某些错误可以尝试用已读取的数据
                    if !allData.isEmpty {
                        self.log("⚠️ 使用已读取的部分数据")
                        self.processReadData(fileName: fileName, data: allData, session: session)
                    } else {
                        self.handleReadError(session: session, message: "读取文件失败: \(String(format: "%02X%02X", sw1, sw2))")
                    }
                }
            }
        }
        
        readNextChunk(offset: 0)
    }
    
    // 创建安全选择 APDU —— C‑MAC 保护，DO87带明文 FID（方案 B）
    private func createSecureSelectAPDU(fileID: Data) -> NFCISO7816APDU {

        // 如果会话密钥尚未建立，回退到普通 APDU
        guard let sessionKMac = sessionKMac, let sessionKEnc = sessionKEnc else {
            return NFCISO7816APDU(
                instructionClass: 0x00,
                instructionCode: 0xA4,
                p1Parameter: 0x02,
                p2Parameter: 0x0C,
                data: fileID,
                expectedResponseLength: 0
            )
        }

        // 1. 递增 SSC
        ssc += 1
        let sscData = Data(withUnsafeBytes(of: ssc.bigEndian) { Data($0) })
        log("🔒 SSC: \(String(format: "%016X", ssc))")

        // 2. Protected header
        let claProtected: UInt8 = 0x00 | 0x0C      // SM, no secure‑messaging indicators set except SM bits
        let ins: UInt8 = 0xA4
        let p1: UInt8  = 0x02
        let p2: UInt8  = 0x0C
        let header     = Data([claProtected, ins, p1, p2])

        // 3. DO87 – PLAIN (未加密) 文件 ID
        //    ICAO 9303 / BSI TR‑03105: DO87 value must begin with 0x01 to indicate
        //    unencrypted bytes.  Length = 1 (indicator) + FID length (2 bytes).
        let do87Value = Data([0x01]) + fileID            // 0x01 | FID
        let do87       = Data([0x87, UInt8(do87Value.count)]) + do87Value
        log("🔒 DO87 (plain FID): \(do87.hexString)")

        // 4. 根据 ICAO 9303 标准，SELECT 命令不需要 DO97（Le）
        //    当不期望返回数据时，只包含 DO87 和 DO8E
        log("🔒 跳过 DO97 - SELECT 命令不需要 Le 字段")

        // 5. Lcʹ – length of *protected* data objects (DO87 + optional DO97).
        //    For SELECT FILE we have only DO87, so this is always 5 (0x05).
        let lcProtected = Data([UInt8(do87.count)])
        log("🔒 Lcᵖʳᵒᵗᵉᶜᵗᵉᵈ for MAC: \(lcProtected.hexString)")

        // 6. MAC 输入：SSC || header || Lcᵖʳᵒᵗᵉᶜᵗᵉᵈ || DO87  (不包含 DO97/DO8E)
        let macInput = sscData + header + lcProtected + do87
        log("🔒 MAC输入: \(macInput.hexString)")

        let mac = calculateMAC(data: macInput, key: sessionKMac)
        log("🔒 计算出的MAC: \(mac.hexString)")

        let do8e = Data([0x8E, 0x08]) + mac
        log("🔒 DO8E: \(do8e.hexString)")

        // 7. 组装完整数据域：DO87 || DO8E（不包含 DO97）
        let commandData = do87 + do8e
        log("🔒 完整安全消息数据 (Lc=\(commandData.count)): \(commandData.hexString)")

        return NFCISO7816APDU(
            instructionClass: claProtected,
            instructionCode: ins,
            p1Parameter: p1,
            p2Parameter: p2,
            data: commandData,
            expectedResponseLength: -1   // No Le for SELECT commands
        )
    }
    
    // 创建安全读取APDU
    private func createSecureReadAPDU(offset: Int, length: Int) -> NFCISO7816APDU {
        return createSecureMessageAPDU(
            cla: 0x00,
            ins: 0xB0, // READ BINARY
            p1: UInt8((offset >> 8) & 0xFF),
            p2: UInt8(offset & 0xFF),
            data: Data(),
            le: length
        )
    }
    
    // 创建安全消息传递APDU (完整实现)
    private func createSecureMessageAPDU(
        cla: UInt8,
        ins: UInt8,
        p1: UInt8,
        p2: UInt8,
        data: Data,
        le: Int?
    ) -> NFCISO7816APDU {
        log("🔒 创建安全消息传递APDU: CLA=\(String(format: "%02X", cla)), INS=\(String(format: "%02X", ins))")
        
        guard let sessionKEnc = sessionKEnc,
              let sessionKMac = sessionKMac else {
            log("❌ 会话密钥未建立，回退到普通APDU")
            return NFCISO7816APDU(
                instructionClass: 0x00,
                instructionCode: ins,
                p1Parameter: p1,
                p2Parameter: p2,
                data: data,
                expectedResponseLength: le ?? -1
            )
        }
        
        ssc += 1
        let sscData = Data(withUnsafeBytes(of: ssc.bigEndian) { Data($0) })
        log("🔒 SSC: \(String(format: "%016X", ssc))")
        
        let protectedCla: UInt8 = cla | 0x0C
        let cmdHeader = Data([protectedCla, ins, p1, p2])
        
        var do87: Data?
        if !data.isEmpty {
            let paddedData = addISO9797Method2Padding(data: data, blockSize: 8)
            let encryptedData = encrypt3DESCBC(data: paddedData, key: sessionKEnc, iv: Data(repeating: 0, count: 8))
            var tempDo87 = Data([0x87])
            // BER-TLV length encoding
            let valueLength = 1 + encryptedData.count
            if valueLength < 128 {
                tempDo87.append(UInt8(valueLength))
            } else {
                log("❌ DO'87' data too long, BER-TLV long form not implemented.")
            }
            tempDo87.append(0x01) // Padding indicator
            tempDo87.append(encryptedData)
            do87 = tempDo87
            log("🔒 DO87: \(do87!.hexString)")
        }
        
        var do97: Data?
        if let le = le {
            var tempDo97 = Data([0x97, 0x01, UInt8(le == 256 ? 0 : le)])
            do97 = tempDo97
            log("🔒 DO97: \(do97!.hexString)")
        }
        
        // Lc is the length of the data field, which is DO'87' || DO'97' || DO'8E'
        let do8eLength = 10 // Tag(1) + Length(1) + MAC(8)
        let lcValue = (do87?.count ?? 0) + (do97?.count ?? 0) + do8eLength
        
        // We assume Lc fits in a single byte for the MAC calculation.
        let lcData = Data([UInt8(lcValue)])
        log("🔒 Lc for MAC: \(lcData.hexString)")

        let mac = calculateSecureMAC(ssc: sscData, cmdHeader: cmdHeader, lc: lcData, do87: do87, do97: do97, key: sessionKMac)
        let do8e = Data([0x8E, 0x08]) + mac
        log("🔒 DO8E: \(do8e.hexString)")
        
        var commandData = Data()
        if let do87 = do87 { commandData.append(do87) }
        if let do97 = do97 { commandData.append(do97) }
        commandData.append(do8e)
        
        log("🔒 完整安全消息数据 (Lc=\(commandData.count)): \(commandData.hexString)")
        
        return NFCISO7816APDU(
            instructionClass: protectedCla,
            instructionCode: ins,
            p1Parameter: p1,
            p2Parameter: p2,
            data: commandData,
            expectedResponseLength: -1   // omit Le when using secure‑messaging
        )
    }
    
    // 计算安全消息传递的MAC
    private func calculateSecureMAC(
        ssc: Data,
        cmdHeader: Data,
        lc: Data,
        do87: Data?,
        do97: Data?,
        key: Data
    ) -> Data {
        log("🔒 计算安全消息传递MAC")
        
        // Per ICAO 9303-11, the MAC is calculated over: SSC || protected_header || Lc || DO'87' || DO'97'
        var macInput = ssc + cmdHeader + lc
        if let do87 = do87 {
            macInput.append(do87)
        }
        if let do97 = do97 {
            macInput.append(do97)
        }
        
        log("🔒 MAC输入: \(macInput.hexString)")
        
        let finalMac = calculateMAC(data: macInput, key: key)
        log("🔒 计算出的MAC: \(finalMac.hexString)")
        return finalMac
    }
    
    // 解密安全消息传递的响应
    private func decryptSecureResponse(_ data: Data) -> Data {
        log("🔒 解密安全消息传递响应")
        log("🔒 响应数据: \(data.hexString)")
        
        guard let sessionKEnc = sessionKEnc,
              let _ = sessionKMac else {
            log("⚠️ 会话密钥未建立，直接返回原数据")
            return data
        }
        
        // 简单的安全响应解析
        // 真实实现需要解析DO87, DO99, DO8E等
        
        // 如果数据很短，可能不是安全消息传递格式
        if data.count < 16 {
            log("⚠️ 响应数据太短，可能不是安全消息传递格式")
            return data
        }
        
        // 查找DO87 (加密数据)
        var offset = 0
        while offset < data.count - 2 {
            if data[offset] == 0x87 {
                let length = Int(data[offset + 1])
                if offset + 2 + length <= data.count {
                    let encryptedData = data.subdata(in: (offset + 3)..<(offset + 2 + length))
                    log("🔒 找到DO87加密数据: \(encryptedData.hexString)")
                    
                    // 解密数据
                    let decryptedData = decrypt3DESCBC(data: encryptedData, key: sessionKEnc)
                    log("🔒 解密后数据: \(decryptedData.hexString)")
                    
                    // 移除填充
                    let unpaddedData = removePKCS7Padding(data: decryptedData)
                    log("🔒 移除填充后数据: \(unpaddedData.hexString)")
                    
                    return unpaddedData
                }
            }
            offset += 1
        }
        
        log("⚠️ 未找到DO87，返回原数据")
        return data
    }
    
    // 添加PKCS7填充
    private func addPKCS7Padding(data: Data, blockSize: Int) -> Data {
        let paddingLength = blockSize - (data.count % blockSize)
        let padding = Data(repeating: UInt8(paddingLength), count: paddingLength)
        return data + padding
    }

    // 添加 ISO9797‑1 Method 2 填充 (0x80 后填 0x00)
    private func addISO9797Method2Padding(data: Data, blockSize: Int) -> Data {
        var padded = data
        padded.append(0x80)
        while padded.count % blockSize != 0 {
            padded.append(0x00)
        }
        return padded
    }
    
    // 移除PKCS7填充
    private func removePKCS7Padding(data: Data) -> Data {
        guard !data.isEmpty else { return data }
        
        let paddingLength = Int(data.last!)
        if paddingLength > 0 && paddingLength <= 16 && paddingLength <= data.count {
            return Data(data.prefix(data.count - paddingLength))
        }
        
        return data
    }
    
    // MARK: - 数据处理
    
    private func processReadData(fileName: String, data: Data, session: NFCTagReaderSession) {
        if fileName == "COM" {
            processCOMData(data, session: session)
        } else if fileName == "DG1" {
            processDG1Data(data, session: session)
        } else {
            log("⚠️ 未知文件类型: \(fileName)")
            completeReading(session: session)
        }
    }
    
    private func processCOMData(_ data: Data, session: NFCTagReaderSession) {
        log("📋 处理COM文件数据")
        log("📋 COM文件原始数据: \(data.hexString)")
        
        // COM文件包含了可用的数据组信息
        // 简化解析：查找 DG1 的存在
        var foundDG1 = false
        
        // 尝试解析 COM 文件的 TLV 结构
        let dataBytes = [UInt8](data)
        for i in 0..<dataBytes.count {
            // 寻找 DG1 标签 (0x61 或在数据组列表中)
            if i < dataBytes.count - 1 {
                if dataBytes[i] == 0x01 { // DG1 在数据组列表中的标识
                    foundDG1 = true
                    log("✅ COM文件中发现DG1数据组")
                    break
                }
            }
        }
        
        if !foundDG1 {
            log("⚠️ COM文件中未明确发现DG1，但仍尝试读取")
        }
        
        guard let iso7816Tag = session.connectedTag as? NFCISO7816Tag else {
            log("❌ 无法获取ISO7816标签")
            DispatchQueue.main.async {
                self.errorMessage = "NFC标签类型错误"
                self.isReading = false
            }
            session.invalidate(errorMessage: "NFC标签类型不支持")
            return
        }
        
        // 继续读取 DG1 文件
        readDG1File(iso7816Tag: iso7816Tag, session: session)
    }
    
    private func processDG1Data(_ data: Data, session: NFCTagReaderSession) {
        log("👤 处理DG1文件数据")
        
        // DG1包含MRZ数据，进行基本解析
        do {
            let passportData = try parseDG1Data(data)
            
            DispatchQueue.main.async {
                self.passportData = passportData
                self.statusMessage = "读取成功"
                session.alertMessage = "护照读取成功！"
            }
            
            log("✅ 护照数据解析成功")
            log("📄 姓名: \(passportData.firstName) \(passportData.lastName)")
            log("📄 护照号: \(passportData.documentNumber)")
            log("📄 国籍: \(passportData.nationality)")
            
        } catch {
            log("❌ DG1数据解析失败: \(error)")
            
            DispatchQueue.main.async {
                self.errorMessage = "数据解析失败: \(error.localizedDescription)"
            }
        }
        
        completeReading(session: session)
    }
    
    // MARK: - DG1数据解析
    
    private func parseDG1Data(_ data: Data) throws -> ChinesePassportData {
        log("🔍 解析DG1 MRZ数据")
        
        // 简化的DG1解析 - 基于TLV结构查找MRZ数据
        let dataBytes = [UInt8](data)
        
        // 查找MRZ数据块 (通常在DG1中以特定标签开始)
        var mrzData: Data?
        
        // 尝试查找包含可打印ASCII字符的MRZ区域
        for i in 0..<(dataBytes.count - 88) {
            let segment = Array(dataBytes[i..<i+88])
            
            // MRZ通常包含大写字母、数字和'<'字符
            let mrzCharSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<")
            let candidateString = String(bytes: segment, encoding: .ascii) ?? ""
            
            if candidateString.count == 88 &&
               candidateString.unicodeScalars.allSatisfy({ mrzCharSet.contains($0) }) {
                mrzData = Data(segment)
                break
            }
        }
        
        guard let validMrzData = mrzData,
              let mrzString = String(data: validMrzData, encoding: .ascii) else {
            throw NSError(domain: "DG1Parser", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法找到有效的MRZ数据"])
        }
        
        // 解析MRZ字符串 (两行各44字符)
        guard mrzString.count == 88 else {
            throw NSError(domain: "DG1Parser", code: -2, userInfo: [NSLocalizedDescriptionKey: "MRZ数据长度不正确"])
        }
        
        let line1 = String(mrzString.prefix(44))
        let line2 = String(mrzString.suffix(44))
        
        log("📋 MRZ第一行: \(line1)")
        log("📋 MRZ第二行: \(line2)")
        
        // 解析MRZ数据
        return try parseMRZLines(line1: line1, line2: line2)
    }
    
    private func parseMRZLines(line1: String, line2: String) throws -> ChinesePassportData {
        // 第一行格式: P<COUNTRY_CODE<LASTNAME<<FIRSTNAME<<<...
        // 第二行格式: PASSPORT_NUMBER<CHECK<NATIONALITY<BIRTH_DATE<SEX<EXPIRY_DATE<CHECK<PERSONAL_NUMBER<CHECK
        
        // 解析第一行
        let line1Parts = line1.replacingOccurrences(of: "<", with: " ").components(separatedBy: "  ").filter { !$0.isEmpty }
        
        guard line1Parts.count >= 2 else {
            throw NSError(domain: "MRZParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "第一行MRZ格式错误"])
        }
        
        let country = String(line1.dropFirst(2).prefix(3)).trimmingCharacters(in: CharacterSet(charactersIn: "<"))
        let nameSection = String(line1.dropFirst(5))
        let nameParts = nameSection.components(separatedBy: "<<")
        
        let lastName = nameParts.first?.replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces) ?? ""
        let firstName = nameParts.count > 1 ? nameParts[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces) : ""
        
        // 解析第二行
        let documentNumber = String(line2.prefix(9)).trimmingCharacters(in: CharacterSet(charactersIn: "<"))
        let nationality = String(line2.dropFirst(10).prefix(3))
        let birthDateStr = String(line2.dropFirst(13).prefix(6))
        let gender = String(line2.dropFirst(20).prefix(1))
        let expiryDateStr = String(line2.dropFirst(21).prefix(6))
        
        // 转换日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        
        let birthDate = dateFormatter.date(from: birthDateStr)
        let expiryDate = dateFormatter.date(from: expiryDateStr)
        
        return ChinesePassportData(
            documentNumber: documentNumber,
            firstName: firstName,
            lastName: lastName,
            nationality: nationality,
            issuingAuthority: country,
            gender: gender,
            dateOfBirth: birthDate,
            dateOfExpiry: expiryDate,
            placeOfBirth: nil,
            personalNumber: nil,
            faceImage: nil
        )
    }
    
    private func handleReadError(session: NFCTagReaderSession, message: String) {
        log("❌ 读取错误: \(message)")
        
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isReading = false
        }
        
        session.invalidate(errorMessage: message)
    }
    
    private func completeReading(session: NFCTagReaderSession) {
        log("🏁 完成护照读取")
        
        DispatchQueue.main.async {
            self.isReading = false
            if self.passportData != nil {
                self.statusMessage = "读取完成"
            }
        }
        
        session.invalidate()
    }
}

// MARK: - NFCTagReaderSessionDelegate
extension ChinesePassportReader: NFCTagReaderSessionDelegate {
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        log("✅ NFC会话已激活")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        log("❌ NFC会话失效: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            self.isReading = false
            
            // 检查错误类型，提供更具体的错误信息
            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    self.statusMessage = "用户取消"
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.errorMessage = "读取超时，请重试"
                case .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
                    self.errorMessage = "连接中断，请重试"
                case .readerSessionInvalidationErrorSystemIsBusy:
                    self.errorMessage = "系统繁忙，请稍后重试"
                default:
                    self.errorMessage = "NFC读取失败: \(error.localizedDescription)"
                }
            } else {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        log("🏷️ 检测到NFC标签: \(tags.count)个")
        
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "未检测到有效标签")
            return
        }
        
        session.connect(to: tag) { [weak self] error in
            if let error = error {
                self?.log("❌ 连接标签失败: \(error)")
                session.invalidate(errorMessage: "连接失败: \(error.localizedDescription)")
                return
            }
            
            self?.log("✅ 标签连接成功")
            
            switch tag {
            case .iso7816(let iso7816Tag):
                self?.handleISO7816Tag(iso7816Tag, session: session)
            default:
                self?.log("❌ 不支持的标签类型")
                session.invalidate(errorMessage: "不支持的标签类型")
            }
        }
    }
    
    private func handleISO7816Tag(_ iso7816Tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        log("🔍 处理ISO7816标签")
        
        // 选择护照应用程序
        let selectPassportApp = NFCISO7816APDU(
            instructionClass: 0x00,
            instructionCode: 0xA4,
            p1Parameter: 0x04,
            p2Parameter: 0x0C,
            data: Data([0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01]), // 护照应用程序AID
            expectedResponseLength: -1
        )
        
        iso7816Tag.sendCommand(apdu: selectPassportApp) { [weak self] data, sw1, sw2, error in
            if let error = error {
                self?.log("❌ 选择护照应用程序失败: \(error)")
                session.invalidate(errorMessage: "护照应用程序选择失败")
                return
            }
            
            if sw1 == 0x90 && sw2 == 0x00 {
                self?.log("✅ 护照应用程序选择成功")
                self?.performBACAuthentication(iso7816Tag: iso7816Tag, session: session)
            } else {
                self?.log("❌ 护照应用程序选择失败: SW1=\(String(format: "%02X", sw1)), SW2=\(String(format: "%02X", sw2))")
                session.invalidate(errorMessage: "护照应用程序不可用")
            }
        }
    }
    
    private func performBACAuthentication(iso7816Tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        log("🔐 开始BAC认证")
        
        guard bacKEnc != nil, bacKMac != nil else {
            log("❌ BAC密钥未准备好")
            session.invalidate(errorMessage: "认证密钥未准备好")
            return
        }
        
        // Step 1: 获取随机数挑战
        performGetChallenge(iso7816Tag: iso7816Tag) { [weak self] rndIC in
            guard let self = self, let rndIC = rndIC else {
                session.invalidate(errorMessage: "获取挑战失败")
                return
            }
            
            // Step 2: 执行外部认证
            self.performExternalAuthenticate(iso7816Tag: iso7816Tag, rndIC: rndIC) { [weak self] authResponse in
                guard let self = self, let authResponse = authResponse else {
                    session.invalidate(errorMessage: "BAC认证失败")
                    return
                }
                
                // Step 3: 提取会话密钥
                self.extractAndSaveSessionKeys(from: authResponse)
                
                // Step 4: 开始读取护照数据
                self.readPassportData(iso7816Tag: iso7816Tag, session: session)
            }
        }
    }
    
    private func readPassportData(
        iso7816Tag: NFCISO7816Tag,
        session: NFCTagReaderSession
    ) {
        log("📖 开始读取护照数据")
        
        // 首先读取COM文件（包含数据组列表）
        readCOMFile(iso7816Tag: iso7816Tag, session: session)
    }
    
    private func readCOMFile(iso7816Tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        log("📋 读取COM文件")
        
        let comFileID = Data([0x01, 0x1E]) // COM文件ID
        
        readFileWithSecureMessaging(
            iso7816Tag: iso7816Tag,
            session: session,
            fileID: comFileID,
            fileName: "COM"
        )
    }
    
    private func readDG1File(iso7816Tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        log("👤 读取DG1文件（MRZ数据）")
        
        let dg1FileID = Data([0x01, 0x01]) // DG1文件ID
        
        readFileWithSecureMessaging(
            iso7816Tag: iso7816Tag,
            session: session,
            fileID: dg1FileID,
            fileName: "DG1"
        )
    }
}

// MARK: - Data扩展
extension Data {
    var hexString: String {
        return map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
