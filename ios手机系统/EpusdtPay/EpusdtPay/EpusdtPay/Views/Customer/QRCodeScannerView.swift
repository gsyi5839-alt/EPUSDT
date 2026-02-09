//
//  QRCodeScannerView.swift
//  EpusdtPay
//
//  QR Code scanner for customer authorization
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - QR Code 解析结果类型
enum QRScanResult {
    case authorizationUrl(String)        // 我方授权链接 (包含 auth/password)
    case walletAddress(String, String)   // (地址, 链类型: "EVM"/"TRON")
    case eip681Uri(String)               // EIP-681 标准URI (ethereum:0x...)
    case unknown(String)                 // 未识别的内容

    /// 从扫描到的原始字符串解析
    static func parse(_ code: String) -> QRScanResult {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 我方授权链接 (最高优先级)
        if trimmed.contains("auth") || trimmed.contains("password") {
            return .authorizationUrl(trimmed)
        }

        // 2. EIP-681 URI (ethereum:0x...)
        if trimmed.lowercased().hasPrefix("ethereum:") {
            return .eip681Uri(trimmed)
        }

        // 3. EVM 钱包地址 (0x + 40位hex = 42字符)
        if trimmed.hasPrefix("0x") && trimmed.count == 42 && isHexString(String(trimmed.dropFirst(2))) {
            return .walletAddress(trimmed, "EVM")
        }

        // 4. TRON 钱包地址 (T开头, 34字符, Base58)
        if trimmed.hasPrefix("T") && trimmed.count == 34 && isBase58String(trimmed) {
            return .walletAddress(trimmed, "TRON")
        }

        // 5. 带协议前缀的地址格式 (如 tron:T..., bitcoin:...)
        //    提取冒号后的地址
        if let colonIndex = trimmed.firstIndex(of: ":") {
            let afterColon = String(trimmed[trimmed.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // 去掉可能的 // 前缀
            let address = afterColon.hasPrefix("//") ? String(afterColon.dropFirst(2)) : afterColon
            // 检查提取出的是否为有效地址
            if address.hasPrefix("0x") && address.count == 42 && isHexString(String(address.dropFirst(2))) {
                return .walletAddress(address, "EVM")
            }
            if address.hasPrefix("T") && address.count == 34 && isBase58String(address) {
                return .walletAddress(address, "TRON")
            }
        }

        return .unknown(trimmed)
    }

    private static func isHexString(_ str: String) -> Bool {
        let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return str.unicodeScalars.allSatisfy { hexChars.contains($0) }
    }

    private static func isBase58String(_ str: String) -> Bool {
        let base58Chars = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        return str.unicodeScalars.allSatisfy { base58Chars.contains($0) }
    }
}

struct QRCodeScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var scannerViewModel = QRScannerViewModel()
    @Binding var scannedAuthUrl: String?
    /// 新增: 扫描到的客户钱包地址回调
    var onWalletScanned: ((String, String) -> Void)?

    var body: some View {
        ZStack {
            if scannerViewModel.cameraUnavailable {
                // Camera unavailable (simulator or no camera)
                Color.bgPrimary.ignoresSafeArea()
                VStack(spacing: 20) {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.textPrimary)
                                .padding(12)
                                .background(Color.bgCard)
                                .clipShape(Circle())
                        }
                        .padding()
                        Spacer()
                    }

                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.textSecondary)

                        Text("相机不可用")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)

                        Text("当前设备不支持相机功能，\n请使用真机进行扫码操作")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)

                        // Manual input option
                        VStack(spacing: 12) {
                            Text("手动输入授权码或钱包地址")
                                .font(.caption)
                                .foregroundColor(.textSecondary)

                            HStack {
                                TextField("授权链接 / 钱包地址...", text: $scannerViewModel.manualInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)

                                Button("确认") {
                                    if !scannerViewModel.manualInput.isEmpty {
                                        handleScannedCode(scannerViewModel.manualInput)
                                    }
                                }
                                .foregroundColor(.gold)
                                .fontWeight(.medium)
                            }
                            .padding(.horizontal, 30)
                        }
                        .padding(.top, 10)
                    }

                    Spacer()
                }
            } else {
                // Camera Preview
                QRScannerRepresentable(
                    isScanning: $scannerViewModel.isScanning,
                    scannedCode: $scannerViewModel.scannedCode
                )
                .ignoresSafeArea()

                // Overlay
                VStack {
                    // Header
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()

                        Spacer()
                    }

                    Spacer()

                    // Scanning Frame
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gold, lineWidth: 3)
                        .frame(width: 250, height: 250)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gold)

                                Text("扫描二维码")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("支持授权码和钱包地址")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )

                    Spacer()

                    // Instructions - 显示支持的格式
                    VStack(spacing: 10) {
                        Text("扫码识别")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("支持商户授权码、MetaMask、Trust Wallet、\nTokenPocket、TronLink 等钱包二维码")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    .padding(.bottom, 40)
                }
            }

            // 识别结果提示
            if let resultMsg = scannerViewModel.scanResultMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: scannerViewModel.scanResultIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(scannerViewModel.scanResultIsSuccess ? .statusSuccess : .statusWarning)
                        Text(resultMsg)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(14)
                    .background(Color.bgCard.opacity(0.95))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom))
            }

            // Error Banner
            if let error = scannerViewModel.errorMessage {
                VStack {
                    ErrorBanner(message: error, onDismiss: {
                        scannerViewModel.errorMessage = nil
                    })
                    .padding()
                    Spacer()
                }
            }
        }
        .onChange(of: scannerViewModel.scannedCode) {
            if let code = scannerViewModel.scannedCode {
                handleScannedCode(code)
            }
        }
        .onAppear {
            scannerViewModel.checkCameraPermission()
        }
    }

    private func handleScannedCode(_ code: String) {
        let result = QRScanResult.parse(code)

        switch result {
        case .authorizationUrl(let url):
            // 我方授权链接 → 跳转授权确认
            scannedAuthUrl = url
            presentationMode.wrappedValue.dismiss()

        case .walletAddress(let address, let chain):
            // 第三方钱包地址 → 回调给调用方
            scannerViewModel.showScanResult("识别到 \(chain) 钱包地址: \(address.prefix(8))...\(address.suffix(6))", isSuccess: true)
            if let callback = onWalletScanned {
                callback(address, chain)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    presentationMode.wrappedValue.dismiss()
                }
            } else {
                // 没有钱包回调时，作为授权URL传出
                scannedAuthUrl = address
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    presentationMode.wrappedValue.dismiss()
                }
            }

        case .eip681Uri(let uri):
            // EIP-681 格式 → 回调
            scannerViewModel.showScanResult("识别到 EIP-681 授权请求", isSuccess: true)
            scannedAuthUrl = uri
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                presentationMode.wrappedValue.dismiss()
            }

        case .unknown:
            scannerViewModel.showScanResult("无法识别的二维码格式", isSuccess: false)
            // Reset scanner after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                scannerViewModel.isScanning = true
                scannerViewModel.scannedCode = nil
                scannerViewModel.scanResultMessage = nil
            }
        }
    }
}

// MARK: - QR Scanner ViewModel
class QRScannerViewModel: ObservableObject {
    @Published var isScanning = true
    @Published var scannedCode: String?
    @Published var errorMessage: String?
    @Published var cameraUnavailable = false
    @Published var manualInput = ""
    @Published var scanResultMessage: String?
    @Published var scanResultIsSuccess = false

    func showScanResult(_ message: String, isSuccess: Bool) {
        scanResultMessage = message
        scanResultIsSuccess = isSuccess
    }

    func checkCameraPermission() {
        // Check if camera hardware is available
        guard AVCaptureDevice.default(for: .video) != nil else {
            cameraUnavailable = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.errorMessage = "相机权限被拒绝，请在设置中开启"
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "相机权限被拒绝，请在设置中开启"
        @unknown default:
            errorMessage = "未知的相机权限状态"
        }
    }
}

// MARK: - QR Scanner Representable (UIKit Integration)
struct QRScannerRepresentable: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    @Binding var scannedCode: String?

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isScanning: $isScanning, scannedCode: $scannedCode)
    }

    class Coordinator: NSObject, QRScannerDelegate {
        @Binding var isScanning: Bool
        @Binding var scannedCode: String?

        init(isScanning: Binding<Bool>, scannedCode: Binding<String?>) {
            _isScanning = isScanning
            _scannedCode = scannedCode
        }

        func didScanCode(_ code: String) {
            isScanning = false
            scannedCode = code
        }
    }
}

// MARK: - QR Scanner Delegate
protocol QRScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

// MARK: - QR Scanner View Controller
class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if captureSession?.canAddInput(videoInput) == true {
            captureSession?.addInput(videoInput)
        } else {
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession?.canAddOutput(metadataOutput) == true {
            captureSession?.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)
    }

    func startScanning() {
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
    }

    func stopScanning() {
        if captureSession?.isRunning == true {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.stopRunning()
            }
        }
    }
}

// MARK: - Metadata Output Delegate
extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didScanCode(stringValue)
        }
    }
}
