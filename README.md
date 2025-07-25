# Aptos Passport KYC

A decentralized identity verification and KYC (Know Your Customer) solution based on the Aptos blockchain, ensuring device integrity through iOS App Attest technology, combined with passport NFC reading and facial recognition technology to provide secure and reliable identity verification services.

## Project Description

Aptos Passport KYC solves the trust issues and privacy leakage risks in traditional KYC processes. By combining hardware-level security authentication, biometric technology, and blockchain technology, it provides users with:

- **Decentralized Identity Verification**: Users control their own identity data without relying on centralized institutions
- **Hardware-level Security**: Utilizes iOS Secure Enclave to ensure the security of the authentication process
- **Privacy Protection**: Sensitive information is processed locally, only verification results are stored on-chain
- **Anti-counterfeiting Capability**: Ensures authenticity through dual verification of NFC passport reading and facial recognition

Main features:

- Device integrity verification (App Attest & App Assert)
- Passport NFC chip reading and MRZ parsing
- Real-time facial recognition and comparison
- Blockchain identity credential storage

## Aptos Blockchain Integration

This project deeply integrates Aptos blockchain technology:

### Move Smart Contracts (TruePassContract/)

- **Identity Verification Contract**: Stores and verifies users' KYC status
- **Credential Management**: Manages the lifecycle of identity verification credentials
- **Access Control**: Smart contract-based access control mechanisms

### Blockchain Interaction

- Uses Aptos SDK to interact with on-chain contracts
- Ensures transaction security through hardware signatures
- Supports Aptos wallet integration

### Data On-chain Strategy

- Verification result hashes are stored on-chain, raw data is encrypted and stored locally
- Leverages Aptos' low latency and high throughput characteristics
- Supports batch verification and state updates

## Technology Stack

### Frontend (iOS App)

- **SwiftUI**: Modern iOS user interface
- **AVFoundation**: Camera management and video processing
- **Vision Framework**: Face detection and feature extraction
- **Core NFC**: Passport chip NFC communication
- **CryptoKit**: Cryptographic algorithms and key management

### Security & Authentication

- **App Attest**: Hardware-level device integrity verification
- **Secure Enclave**: Secure key storage and signing
- **BAC (Basic Access Control)**: Secure passport chip access
- **ICAO 9303**: International passport standard implementation

### Blockchain

- **Move Language**: Aptos smart contract development
- **Aptos SDK**: Blockchain interaction

## Installation and Setup Guide

### Environment Requirements

- **iOS Device**: iPhone (iOS 14.0+), supports NFC and Face ID
- **Xcode**: 15.0 or higher
- **macOS**: 13.0 (Ventura) or higher
- **Apple Developer Account**: Required for App Attest functionality

### Installation Steps

1. **Clone Repository**

```bash
git clone https://github.com/your-username/Aptos-Passport-KYC.git
cd Aptos-Passport-KYC
```

2. **Configure Xcode Project**

```bash
# Open Xcode project
open "Aptos Passport KYC.xcodeproj"
```

3. **Configure Developer Account**

- Sign in to your Apple Developer account in Xcode
- Set the correct Bundle Identifier
- Enable the following Capabilities:
  - App Attest
  - Near Field Communication Tag Reading
  - Personal VPN (if needed)

4. **Configure Certificates and Entitlements**

- Ensure `Aptos Passport KYC.entitlements` file contains correct permissions
- Enable App Attest functionality in Apple Developer Console

5. **Deploy Smart Contracts**

```bash
cd TruePassContract
# Install Aptos CLI
curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3
# Deploy contracts (requires Aptos account configuration)
aptos move publish
```

6. **Run Application**

- Connect iOS device to Mac
- Select target device in Xcode
- Click Run (⌘+R) to compile and install the app

### Testing Guide

1. **Device Authentication Test**

   - Open app and click "Manage Authentication"
   - Execute "Start Device Authentication"
   - Verify App Attest certificate generation

2. **Passport Reading Test**

   - Ensure device is authenticated
   - Click "Scan Passport"
   - Enter passport information and hold device near passport chip

3. **Face Recognition Test**
   - Select reference image
   - Click "Face Comparison"
   - Align with camera for real-time comparison

## Project Highlights/Innovations

### 🔐 Hardware-Level Security

- First to apply iOS App Attest technology to blockchain KYC scenarios
- Utilizes Secure Enclave to ensure private keys never leave the device
- Implements end-to-end trusted computing chain

### 🎯 Multi-Modal Biometric Recognition

- Integrates passport NFC chip reading with face recognition
- ICAO 9303 international standard compliant passport data parsing
- Real-time facial feature extraction and similarity computation

### ⛓️ Blockchain Identity Sovereignty

- Users have complete control over their identity data
- Zero-knowledge proof friendly verification mechanism
- Supports cross-chain identity authentication extension

### 🛡️ Privacy-by-Design

- Sensitive data processed locally, only hashes stored on-chain
- Supports selective information disclosure
- Complies with GDPR and other privacy regulations

### 📱 Excellent User Experience

- Intuitive SwiftUI interface design
- Real-time status feedback and error handling
- Supports multilingual and accessibility features

## Future Development Plans

### Short-term Goals (3-6 months)

- [ ] Add support for more countries' passports
- [ ] Implement batch identity verification functionality
- [ ] Integrate Aptos Wallet standards
- [ ] Add identity credential sharing features

### Medium-term Goals (6-12 months)

- [ ] Support enterprise-level KYC services
- [ ] Implement cross-chain identity interoperability
- [ ] Add credit scoring system
- [ ] Build developer API ecosystem

### Long-term Vision (1-2 years)

- [ ] Establish decentralized identity federation
- [ ] Support more biometric recognition technologies
- [ ] Implement global identity passport system
- [ ] Promote standardization and regulatory compliance

## Contributing

We welcome community contributions! Please read CONTRIBUTING.md to learn how to participate in project development.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

---

_Building a safer, more private digital identity future_ 🚀
