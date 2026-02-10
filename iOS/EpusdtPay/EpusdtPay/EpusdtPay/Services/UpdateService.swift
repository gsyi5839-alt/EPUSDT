//
//  UpdateService.swift
//  EpusdtPay
//
//  App version update checking service
//

import Foundation
import SwiftUI

struct UpdateInfo {
    var updateAvailable = false
    var latestVersion = ""
    var updateURL = ""
    var updateNotes = ""
    var forceUpdate = false
}

enum UpdateService {
    private static let baseURL = "https://bocail.com"
    
    // MARK: - Check for Updates
    static func checkForUpdate() async -> UpdateInfo {
        guard let url = URL(string: "\(baseURL)/api/v1/app/version?platform=ios") else {
            return UpdateInfo()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[Update] Server returned non-200 status")
                return UpdateInfo()
            }
            
            let versionInfo = try JSONDecoder().decode(VersionResponse.self, from: data)
            
            let currentVersion = AppConfig.version
            if compareVersions(versionInfo.data.latestVersion, isGreaterThan: currentVersion) {
                print("[Update] New version available: \(versionInfo.data.latestVersion)")
                return UpdateInfo(
                    updateAvailable: true,
                    latestVersion: versionInfo.data.latestVersion,
                    updateURL: versionInfo.data.downloadUrl,
                    updateNotes: versionInfo.data.releaseNotes,
                    forceUpdate: versionInfo.data.forceUpdate
                )
            } else {
                print("[Update] App is up to date (v\(currentVersion))")
            }
        } catch {
            print("[Update] Check failed: \(error.localizedDescription)")
        }
        return UpdateInfo()
    }
    
    // MARK: - Version Comparison
    private static func compareVersions(_ v1: String, isGreaterThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }
}

// MARK: - Version Response Model
struct VersionResponse: Decodable {
    let statusCode: Int
    let message: String
    let data: VersionData
    
    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case message
        case data
    }
}

struct VersionData: Decodable {
    let latestVersion: String
    let downloadUrl: String
    let releaseNotes: String
    let forceUpdate: Bool
    
    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case downloadUrl = "download_url"
        case releaseNotes = "release_notes"
        case forceUpdate = "force_update"
    }
}

// MARK: - Update Alert View
struct UpdateAlertModifier: ViewModifier {
    @Binding var updateInfo: UpdateInfo
    
    func body(content: Content) -> some View {
        content
            .alert("发现新版本", isPresented: $updateInfo.updateAvailable) {
                Button("立即更新") {
                    if let url = URL(string: updateInfo.updateURL) {
                        UIApplication.shared.open(url)
                    }
                }
                if !updateInfo.forceUpdate {
                    Button("稍后再说", role: .cancel) {}
                }
            } message: {
                Text("最新版本: v\(updateInfo.latestVersion)\n\n\(updateInfo.updateNotes)")
            }
    }
}

extension View {
    func checkForUpdates(updateInfo: Binding<UpdateInfo>) -> some View {
        modifier(UpdateAlertModifier(updateInfo: updateInfo))
    }
}
