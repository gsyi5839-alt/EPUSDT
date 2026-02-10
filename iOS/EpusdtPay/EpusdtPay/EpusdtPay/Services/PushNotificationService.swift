//
//  PushNotificationService.swift
//  EpusdtPay
//
//  Manages push notification device token registration with server
//

import Foundation

class PushNotificationService {
    static let shared = PushNotificationService()
    
    private let baseURL = "https://bocail.com"
    private var currentDeviceToken: String?
    
    private init() {}
    
    // MARK: - Register Device Token
    func registerDeviceToken(_ token: String) async {
        currentDeviceToken = token
        
        guard let url = URL(string: "\(baseURL)/api/v1/push/register") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let authToken = APIService.shared.currentToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "device_token": token,
            "platform": "ios",
            "app_version": AppConfig.version,
            "bundle_id": AppConfig.bundleIdentifier
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("[Push] Device token registered successfully")
            } else {
                print("[Push] Device token registration failed")
            }
        } catch {
            print("[Push] Device token registration error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Unregister Device
    func unregisterDevice() async {
        guard let token = currentDeviceToken else { return }
        guard let url = URL(string: "\(baseURL)/api/v1/push/unregister") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["device_token": token]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let _ = try await URLSession.shared.data(for: request)
            currentDeviceToken = nil
            print("[Push] Device unregistered")
        } catch {
            print("[Push] Unregister error: \(error.localizedDescription)")
        }
    }
}
