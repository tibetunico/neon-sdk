//
//  File.swift
//
//
//  Created by Tuna Öztürk on 14.07.2024.
//


import Foundation
import Adapty
import UIKit
import AdaptyUI


public class AdaptyBuilderManager : NSObject, AdaptyPaywallControllerDelegate{
    
    public static let shared = AdaptyBuilderManager()
    
    var purchased: ((_ product : AdaptyPaywallProduct?) -> ())? = nil
    var dismissed: (() -> ())? = nil
    var restored: (() -> ())? = nil
    var customButtonHandlers = [String: () -> Void]()
    @available(iOS 15.0, *)
    public func present(
        paywall : AdaptyPaywall,
        from controller : UIViewController,
        purchased: @escaping (_ product : AdaptyPaywallProduct?) -> (),
        dismissed: @escaping () -> (),
        restored: @escaping () -> (),
        failedToPresent: @escaping () -> ()
    ){
        
        self.purchased = purchased
        self.dismissed = dismissed
        self.restored = restored
        
        if !AdaptyManager.adaptyBuilderPaywalls.contains(where: {$0.paywall.placementId == paywall.placementId}){
            failedToPresent()
            return
        }
        for adaptyBuilderPaywall in AdaptyManager.adaptyBuilderPaywalls {
            if adaptyBuilderPaywall.paywall.placementId == paywall.placementId{
                
                guard paywall.hasViewConfiguration else {
                    //  use your custom logic
                    print("This paywall does not contain viewConfiguration")
                    failedToPresent()
                    return
                }
                
                let visualPaywall = try! AdaptyUI.paywallController(with: adaptyBuilderPaywall.configuration, delegate: self)
                controller.present(visualPaywall, animated: true)
                
            }
        }
        
    }
    
    @available(iOS 15.0, *)
    public func presentUncache(
        placementId: String,
        from controller: UIViewController,
        purchased: @escaping (_ product: AdaptyPaywallProduct?) -> (),
        dismissed: @escaping () -> (),
        restored: @escaping () -> (),
        failedToPresent: @escaping () -> ()
    ) {
        self.purchased = purchased
        self.dismissed = dismissed
        self.restored = restored

        Task {
            do {
                let paywall = try await Adapty.getPaywall(placementId: placementId, locale: nil, fetchPolicy: .reloadRevalidatingCacheData, loadTimeout: nil)
                
                guard paywall.hasViewConfiguration else {
                    print("This paywall does not contain viewConfiguration")
                    failedToPresent()
                    return
                }

                // Konfigürasyon çek
                let config = try await AdaptyUI.getPaywallConfiguration(forPaywall: paywall)

                let visualPaywall = try AdaptyUI.paywallController(with: config, delegate: self)

                await MainActor.run {
                    controller.present(visualPaywall, animated: true)
                }
            } catch {
                print("Failed to load paywall: \(error)")
                failedToPresent()
            }
        }
    }

    
    
}
@available(iOS 15.0, *)
extension AdaptyBuilderManager{
    public func paywallControllerDidStartRestore(_ controller: AdaptyPaywallController) {
        
    }
    public func paywallController(_ controller: AdaptyPaywallController, didFailPurchase product: AdaptyPaywallProduct, error: AdaptyError) {
        
    }
    
    public func paywallController(_ controller: AdaptyPaywallController, didSelectProduct product: AdaptyPaywallProduct) {
        
    }
    
    public func paywallController(_ controller: AdaptyPaywallController, didStartPurchase product: AdaptyPaywallProduct) {
        
    }
    
    public func paywallController(_ controller: AdaptyPaywallController, didCancelPurchase product: AdaptyPaywallProduct) {
        
    }
    
    public func paywallController(_ controller: AdaptyPaywallController, didFailRestoreWith error: AdaptyError) {
        
    }
    
    public func paywallController(_ controller: AdaptyPaywallController, didFailRenderingWith error: AdaptyError) {
        
    }
    
    public func paywallController(_ controller: AdaptyPaywallController, didFailLoadingProductsWith error: AdaptyError) -> Bool {
        return true
    }
    public func paywallController(_ controller: AdaptyPaywallController,
                                  didPerform action: AdaptyUI.Action) {
        
        switch action {
        case .close:
            controller.dismiss(animated: true)
            if let dismissed{
                dismissed()
            }
        case let .openURL(url):
            // handle URL opens (incl. terms and privacy links)
            UIApplication.shared.open(url, options: [:])
        case let .custom(id):
            if let action = customButtonHandlers[id]{
                action()
            }
            break
        }
    }
    
    public func paywallController(_ controller: AdaptyPaywallController, didFinishPurchase product: any AdaptyPaywallProduct, purchaseResult: AdaptyPurchaseResult) {
        
        switch purchaseResult {
        case .userCancelled:
            break
        case .pending:
            break
        case .success(let profile, let transaction):
            Neon.isUserPremium = true
            controller.dismiss(animated: true)
            if let purchased{
                purchased(product)
            }
        }
    }
    
    public func paywallController(_ controller: AdaptyPaywallController,
                                  didFinishRestoreWith profile: AdaptyProfile) {
        
        if profile.accessLevels[AdaptyManager.accessLevel]?.isActive ?? false {
            Neon.isUserPremium = true
            NeonAlertManager.default.present(title: "Restored Succesfully!", message: "Welcome back! We restored your subscription succesfully. Now you can use all of the premium features again.", style: .alert, buttons: [
                AlertButton(completion: {
                    controller.dismiss(animated: true)
                    
                })
            ], viewController: controller)
            if let restored{
                restored()
            }
            
            
        }else{
            NeonAlertManager.default.present(title: "Oops!", message: "We couldn’t find any active subscription in your account.", style: .alert, buttons: [
                AlertButton(completion: {
                    
                })
            ], viewController: controller)
        }
        
    }
    public func addCustomButtonHandler(buttonId : String, action : @escaping () -> Void){
        customButtonHandlers[buttonId] = action
    }
    
}

public class AdaptyBuilderPaywall{
    var paywall : AdaptyPaywall
    var configuration : AdaptyUI.PaywallConfiguration
    var packages : [AdaptyPaywallProduct]
    
    init(paywall: AdaptyPaywall, configuration: AdaptyUI.PaywallConfiguration, packages: [AdaptyPaywallProduct]) {
        self.paywall = paywall
        self.configuration = configuration
        self.packages = packages
    }
    
    
}
