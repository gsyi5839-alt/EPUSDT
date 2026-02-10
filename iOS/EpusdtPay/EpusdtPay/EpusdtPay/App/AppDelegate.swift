//
//  AppDelegate.swift
//  EpusdtPay
//
//  Handles push notification registration and lifecycle events
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // MARK: - App Lifecycle
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        // Request push notification permission
        requestPushNotificationPermission(application)
        return true
    }
    
    // MARK: - Push Notification Permission
    private func requestPushNotificationPermission(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error = error {
                print("[Push] Authorization error: \(error.localizedDescription)")
                return
            }
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
                print("[Push] Notification permission granted")
            } else {
                print("[Push] Notification permission denied")
            }
        }
    }
    
    // MARK: - Device Token Registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] Device token: \(token)")
        // Send token to server
        Task {
            await PushNotificationService.shared.registerDeviceToken(token)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] Failed to register: \(error.localizedDescription)")
    }
    
    // MARK: - Foreground Notification Handling
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    // MARK: - Notification Tap Handling
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationAction(userInfo: userInfo)
        completionHandler()
    }
    
    private func handleNotificationAction(userInfo: [AnyHashable: Any]) {
        // Handle different notification types
        if let type = userInfo["type"] as? String {
            switch type {
            case "payment":
                NotificationCenter.default.post(name: .pushPaymentReceived, object: nil, userInfo: userInfo)
            case "update":
                NotificationCenter.default.post(name: .pushUpdateAvailable, object: nil, userInfo: userInfo)
            case "authorization":
                NotificationCenter.default.post(name: .pushAuthorizationUpdate, object: nil, userInfo: userInfo)
            default:
                print("[Push] Unknown notification type: \(type)")
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let pushPaymentReceived = Notification.Name("pushPaymentReceived")
    static let pushUpdateAvailable = Notification.Name("pushUpdateAvailable")
    static let pushAuthorizationUpdate = Notification.Name("pushAuthorizationUpdate")
}
