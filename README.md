# Aptos Passport KYC

一个基于 Aptos 区块链的去中心化身份验证和 KYC（Know Your Customer）解决方案，通过 iOS App Attest 技术确保设备完整性，结合护照 NFC 读取和人脸识别技术提供安全可靠的身份验证服务。

## 项目描述

Aptos Passport KYC 解决了传统 KYC 流程中的信任问题和隐私泄露风险。通过将硬件级安全认证、生物识别技术与区块链技术相结合，为用户提供：

- **去中心化身份验证**：用户控制自己的身份数据，无需依赖中心化机构
- **硬件级安全保障**：利用 iOS Secure Enclave 确保认证过程的安全性
- **隐私保护**：敏感信息在本地处理，只有验证结果上链
- **防伪造能力**：通过 NFC 护照读取和人脸识别双重验证确保真实性

主要功能：

- 设备完整性验证（App Attest & App Assert）
- 护照 NFC 芯片读取和 MRZ 解析
- 实时人脸识别和对比
- 区块链身份凭证存储

## Aptos 区块链集成

本项目深度集成 Aptos 区块链技术：

### Move 智能合约（TruePassContract/）

- **身份验证合约**：存储和验证用户的 KYC 状态
- **凭证管理**：管理身份验证凭证的生命周期
- **权限控制**：基于智能合约的访问控制机制

### 区块链交互

- 使用 Aptos SDK 与链上合约交互
- 通过硬件签名确保交易安全性
- 支持 Aptos 钱包集成

### 数据上链策略

- 验证结果哈希上链，原始数据本地加密存储
- 利用 Aptos 的低延迟和高吞吐特性
- 支持批量验证和状态更新

## 技术栈

### 前端 (iOS App)

- **SwiftUI**：现代化 iOS 用户界面
- **AVFoundation**：摄像头管理和视频处理
- **Vision Framework**：人脸检测和特征提取
- **Core NFC**：护照芯片 NFC 通信
- **CryptoKit**：加密算法和密钥管理

### 安全与认证

- **App Attest**：硬件级设备完整性验证
- **Secure Enclave**：安全密钥存储和签名
- **BAC (Basic Access Control)**：护照芯片安全访问

### 区块链

- **Move 语言**：Aptos 智能合约开发
- **Aptos SDK**：区块链交互
- **CBOR**：证书数据编码格式

### 密码学

- **ECDSA**：椭圆曲线数字签名
- **SHA-256**：数据完整性验证
- **3DES-CBC**：护照数据加密
- **ICAO 9303**：国际护照标准实现

## 安装与运行指南

### 环境要求

- **iOS 设备**：iPhone (iOS 14.0+)，支持 NFC 和 Face ID
- **Xcode**：15.0 或更高版本
- **macOS**：13.0 (Ventura) 或更高版本
- **Apple Developer Account**：用于 App Attest 功能

### 安装步骤

1. **克隆仓库**

```bash
git clone https://github.com/your-username/Aptos-Passport-KYC.git
cd Aptos-Passport-KYC
```

2. **配置 Xcode 项目**

```bash
# 打开 Xcode 项目
open "Aptos Passport KYC.xcodeproj"
```

3. **配置开发者账户**

- 在 Xcode 中登录你的 Apple Developer 账户
- 设置正确的 Bundle Identifier
- 启用以下 Capabilities：
  - App Attest
  - Near Field Communication Tag Reading
  - Personal VPN (如果需要)

4. **配置证书和权限**

- 确保 `Aptos Passport KYC.entitlements` 文件包含正确的权限
- 在 Apple Developer Console 中启用 App Attest 功能

5. **部署智能合约**

```bash
cd TruePassContract
# 安装 Aptos CLI
curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3
# 部署合约（需要配置 Aptos 账户）
aptos move publish
```

6. **运行应用**

- 连接 iOS 设备到 Mac
- 在 Xcode 中选择目标设备
- 点击 Run (⌘+R) 编译并安装应用

### 测试指南

1. **设备认证测试**

   - 打开应用后点击"管理认证"
   - 执行"开始设备认证"
   - 验证 App Attest 证书生成

2. **护照读取测试**

   - 确保设备已认证
   - 点击"扫描护照"
   - 输入护照信息并将设备靠近护照芯片

3. **人脸识别测试**
   - 选择参考图像
   - 点击"人脸对比"
   - 对准摄像头进行实时对比

## 项目亮点/创新点

### 🔐 硬件级安全保障

- 首创将 iOS App Attest 技术应用于区块链 KYC 场景
- 利用 Secure Enclave 确保私钥永不离开设备
- 实现端到端的可信计算链路

### 🎯 多模态生物识别

- 集成护照 NFC 芯片读取与人脸识别
- 符合 ICAO 9303 国际标准的护照数据解析
- 实时人脸特征提取和相似度计算

### ⛓️ 区块链身份主权

- 用户完全控制自己的身份数据
- 零知识证明友好的验证机制
- 支持跨链身份认证扩展

### 🛡️ 隐私保护设计

- 敏感数据本地处理，只有哈希上链
- 支持选择性信息披露
- 符合 GDPR 等隐私法规要求

### 📱 优秀的用户体验

- 直观的 SwiftUI 界面设计
- 实时状态反馈和错误处理
- 支持多语言和无障碍访问

## 未来发展计划

### 短期目标 (3-6个月)

- [ ] 添加更多国家护照支持
- [ ] 实现批量身份验证功能
- [ ] 集成 Aptos Wallet 标准
- [ ] 添加身份凭证分享功能

### 中期目标 (6-12个月)

- [ ] 支持企业级 KYC 服务
- [ ] 实现跨链身份互操作
- [ ] 添加信用评分系统
- [ ] 构建开发者 API 生态

### 长期愿景 (1-2年)

- [ ] 建立去中心化身份联盟
- [ ] 支持更多生物识别技术
- [ ] 实现全球身份护照系统
- [ ] 推动标准化和监管合规

## 贡献指南

我们欢迎社区贡献！请阅读 CONTRIBUTING.md 了解如何参与项目开发。

## 许可证

本项目采用 MIT 许可证 - 详见 LICENSE 文件。

## 联系方式

---

_构建更安全、更私密的数字身份未来_ 🚀
