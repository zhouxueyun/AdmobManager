//
//  AdmobManager.swift
//  AdmobManager
//
//  Created by zhouxueyun on 2018/9/29.
//  Copyright © 2018 zhouxueyun. All rights reserved.
//

import UIKit
import GoogleMobileAds

class AdmobManager: NSObject {

    // MARK: class property
    static let `default` = AdmobManager()

    /// 插页失败自动重试逻辑
    static var interstitialFailedRetryInterval: TimeInterval = 30

    static var bannerViewRefreshInterval: TimeInterval = 60
    static var bannerViewFailedRetryInterval: TimeInterval = 30
    
    
    // MARK: object property
    var interstitial: GADInterstitial?
    private var autoPresentRootVC: UIViewController? = nil
    
    var bannerViews = [GADBannerView]() // 强引用
    
    // MARK: life cycle
    deinit {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
}

extension AdmobManager {
    // MARK: class func
    
    static func register(_ appID: String) {
        AdmobManager.default.register(appID)
    }
    
    static func loadInterstitial(adUnitID: String,
                                 autoPresentIn rootViewController: UIViewController? = nil) {
        AdmobManager.default.loadInterstitial(adUnitID: adUnitID, autoPresentIn: rootViewController)
    }
    
    static func presentInterstitial(from rootViewController: UIViewController) -> Bool {
        return AdmobManager.default.presentInterstitial(from: rootViewController)
    }
    
    static func createBannerView(adUnitID: String,
                          adSize: GADAdSize = kGADAdSizeSmartBannerPortrait,
                          toView: UIView) -> GADBannerView {
        return AdmobManager.default.createBannerView(adUnitID: adUnitID, adSize: adSize, toView: toView)
    }
    
    static func loadBannerViewNextAdRequest(_ bannerView: GADBannerView) -> Bool {
        return AdmobManager.default.loadBannerViewNextAdRequest(bannerView)
    }
    
    // MARK: object func
    
    func register(_ appID: String) {
        GADMobileAds.configure(withApplicationID: appID)
    }
    
    func loadInterstitial(adUnitID: String,
                          autoPresentIn rootViewController: UIViewController? = nil) {
        self.autoPresentRootVC = rootViewController
        self.interstitial = self.createAndLoadInterstitial(adUnitID: adUnitID)
    }
    
    func presentInterstitial(from rootViewController: UIViewController) -> Bool {
        if let ad = self.interstitial, ad.isReady {
            ad.present(fromRootViewController: rootViewController)
            return true
        } else {
            return false
        }
    }
    
    func createBannerView(adUnitID: String,
                          adSize: GADAdSize = kGADAdSizeSmartBannerPortrait,
                          toView: UIView) -> GADBannerView {
        let bannerView = GADBannerView(adSize: adSize)
        bannerView.delegate = self
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = self.viewController(with: toView)
        bannerView.load(GADRequest())
        self.addBannerView(bannerView, toView: toView)
        self.bannerViews.append(bannerView)
        return bannerView
    }
    
    @objc func loadBannerViewNextAdRequest(_ bannerView: GADBannerView) -> Bool {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(loadBannerViewNextAdRequest(_:)), object: bannerView)
        if bannerView.superview != nil {
            bannerView.load(GADRequest())
            return true
        } else {
            if let index = self.bannerViews.index(of: bannerView) {
                self.bannerViews.remove(at: index)
            }
            return false
        }
    }
    
    // MARK: private func
    
    @objc private func createAndLoadInterstitial(adUnitID: String) -> GADInterstitial {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(createAndLoadInterstitial), object: nil)
        let interstitial = GADInterstitial(adUnitID: adUnitID)
        interstitial.delegate = self
        interstitial.load(GADRequest())
        return interstitial
    }
    
    private func viewController(with view: UIView) -> UIViewController? {
        var theView: UIView? = view
        while theView != nil {
            let responder = theView!.next
            if let responder = (responder as? UIViewController) {
                return responder
            }
            theView = theView!.superview
        }
        return nil
    }
    
    private func addBannerView(_ bannerView: GADBannerView, toView: UIView) {
        toView.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        [NSLayoutConstraint.init(item: bannerView, attribute: .centerX, relatedBy: .equal, toItem: toView, attribute: .centerX, multiplier: 1.0, constant: 0),
         NSLayoutConstraint.init(item: bannerView, attribute: .centerY, relatedBy: .equal, toItem: toView, attribute: .centerY, multiplier: 1.0, constant: 0)].forEach { $0.isActive = true }
    }
    
}

extension AdmobManager: GADInterstitialDelegate {
    // MARK: GADInterstitialDelegate
    
    func interstitialDidReceiveAd(_ ad: GADInterstitial) {
        print("interstitialDidReceiveAd")
        if self.autoPresentRootVC != nil {
            ad.present(fromRootViewController: self.autoPresentRootVC!)
        }
    }
    
    func interstitial(_ ad: GADInterstitial, didFailToReceiveAdWithError error: GADRequestError) {
        print("interstitial:didFailToReceiveAdWithError: \(error.localizedDescription)")
        if autoPresentRootVC != nil { // 如果选中自动弹出，则不自动加载下一次请求
            return
        }
        if let unitID = ad.adUnitID {
            DispatchQueue.main.asyncAfter(deadline: .now() + AdmobManager.interstitialFailedRetryInterval) {
                self.interstitial = self.createAndLoadInterstitial(adUnitID: unitID)
            }
        }
    }
    
    func interstitialDidDismissScreen(_ ad: GADInterstitial) {
        print("interstitialDidDismissScreen")
        if autoPresentRootVC != nil { // 如果选中自动弹出，则不自动加载下一次请求
            return
        }
        if let unitID = ad.adUnitID {
            self.interstitial = self.createAndLoadInterstitial(adUnitID: unitID)
        }
    }
    
}

extension AdmobManager: GADBannerViewDelegate {
    // MARK: GADBannerViewDelegate
    
    func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("adViewDidReceiveAd")
        self.perform(#selector(loadBannerViewNextAdRequest(_:)),
                     with: bannerView,
                     afterDelay: AdmobManager.bannerViewRefreshInterval)
    }
    
    func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
        print("adView:didFailToReceiveAdWithError: \(error.localizedDescription)")
        self.perform(#selector(loadBannerViewNextAdRequest(_:)),
                     with: bannerView,
                     afterDelay: AdmobManager.bannerViewFailedRetryInterval)
    }
    
}
