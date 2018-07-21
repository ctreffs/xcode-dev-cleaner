//
//  DonationViewController.swift
//  DevCleaner
//
//  Created by Konrad Kołakowski on 19.05.2018.
//  Copyright © 2018 One Minute Games. All rights reserved.
//
//  DevCleaner is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 3 of the License, or
//  (at your option) any later version.
//
//  DevCleaner is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with DevCleaner.  If not, see <http://www.gnu.org/licenses/>.

import Cocoa
import StoreKit

internal final class DonationViewController: NSViewController {
    // MARK: Properties & outlets
    @IBOutlet weak var xcodeCleanerBenefitsTextField: NSTextField!
    @IBOutlet weak var closeButton: NSButton!
    
    @IBOutlet weak var smallDonationButton: NSButton!
    @IBOutlet weak var mediumDonationButton: NSButton!
    @IBOutlet weak var bigDonationButton: NSButton!
    
    @IBOutlet weak var donationsInterfaceView: NSView!
    
    private var loadingView: LoadingView! = nil

    private var donationProducts: [Donations.Product] = []
    
    // MARK: Initialization & overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make loading view
        self.loadingView = LoadingView(frame: self.view.frame)
        self.startLoading()
        
        // update benefits label
        self.xcodeCleanerBenefitsTextField.attributedStringValue = self.benefitsAttributedString(totalBytesCleaned: Preferences.shared.totalBytesCleaned)
        
        // update donation products
        Donations.shared.delegate = self
        Donations.shared.fetchProductsInfo()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.styleMask.remove(.resizable)
    }
    
    // MARK: Loading
    private func startLoading() {
        if self.loadingView.superview == nil {
            self.donationsInterfaceView.isHidden = true
            self.view.addSubview(self.loadingView)
        }
    }
    
    private func stopLoading() {
        self.donationsInterfaceView.isHidden = false
        self.loadingView.removeFromSuperview()
    }
    
    // MARK: Helpers
    private func benefitsAttributedString(totalBytesCleaned: Int64) -> NSAttributedString {
        let totalBytesString = ByteCountFormatter.string(fromByteCount: totalBytesCleaned, countStyle: .file)
        
        let fontSize: CGFloat = 13.0
        let result = NSMutableAttributedString()
        
        let partOne = NSAttributedString(string: "You saved total of ",
                                           attributes: [.font : NSFont.systemFont(ofSize: fontSize)])
        result.append(partOne)
        
        let partTwo = NSAttributedString(string: "\(totalBytesString)",
                                            attributes: [.font : NSFont.boldSystemFont(ofSize: fontSize)])
        result.append(partTwo)
        
        let partThree = NSAttributedString(string: " thanks to DevCleaner!",
                                           attributes: [.font : NSFont.systemFont(ofSize: fontSize)])
        result.append(partThree)
        
        return result
    }

    private func productKindForTag(_ tag: Int) -> Donations.Product.Kind? {
        switch tag {
            case 1: return .smallCoffee
            case 2: return .bigCoffee
            case 3: return .lunch
            default: return nil
        }
    }
    
    private func productForProductKind(_ productKind: Donations.Product.Kind) -> Donations.Product? {
        return self.donationProducts.filter { $0.kind == productKind }.first
    }

    // MARK: Updating price & titles labels
    private func adjustPriceFontSize(for attributedString: NSAttributedString, initialFont: NSFont, buttonWidth: CGFloat) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: attributedString)
        var fontSize = initialFont.pointSize
        var stringSize = attributedString.size()
        
        while ceil(stringSize.width) >= (buttonWidth - 10) { // including some margins
            if fontSize <= 1.0 { // we can't go any further
                break
            }
    
            let newFontSize = fontSize - 1.5
            if let newFont = NSFont(descriptor: initialFont.fontDescriptor, size: newFontSize) {
                attributedString.addAttribute(.font, value: newFont, range: NSMakeRange(0, attributedString.length))
                
                fontSize = newFontSize
                stringSize = attributedString.size()
            } else {
                continue
            }
        }
        
        return attributedString
    }
    
    private func updateDonationButton(button: NSButton, price: String, info: String) {
        let priceFontSize: CGFloat = 24.0
        let infoFontSize: CGFloat = 13.0
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.allowsDefaultTighteningForTruncation = true
        style.lineBreakMode = .byWordWrapping
        
        let title = NSMutableAttributedString()
        
        // price part
        let priceFont = NSFont.boldSystemFont(ofSize: priceFontSize)
        let pricePart = NSAttributedString(string: price + "\n",
                                           attributes: [.font : priceFont])
        title.append(self.adjustPriceFontSize(for: pricePart, initialFont: priceFont, buttonWidth: button.frame.size.width))
        
        // info part
        let infoPart = NSAttributedString(string: info,
                                          attributes: [.font : NSFont.systemFont(ofSize: infoFontSize)])
        title.append(infoPart)
        
        title.addAttribute(.paragraphStyle, value: style, range: NSMakeRange(0, title.length))
        
        button.attributedTitle = title
    }
    
    // MARK: Actions
    @IBAction func buyProduct(_ sender: NSButton) {
        guard let productKind = self.productKindForTag(sender.tag) else {
            log.warning("SupportViewController: Product kind for given sender tag not found: \(sender.tag)")
            return
        }
        
        guard let product = self.productForProductKind(productKind) else {
            log.warning("SupportViewController: Product of given kind not found: \(productKind)")
            return
        }
        
        Donations.shared.buy(product: product)
    }
    
    @IBAction func share(_ sender: Any) {
        guard let shareUrl = URL(string: "https://itunes.apple.com/app/devcleaner/id1388020431") else {
            return
        }
        
        guard let shareView = sender as? NSView else {
            return
        }
        
        let sharingService = NSSharingServicePicker(items: [shareUrl])
        sharingService.show(relativeTo: .zero, of: shareView, preferredEdge: .minX)
    }
}

extension DonationViewController: DonationsDelegate {
    public func donations(_ donations: Donations, didReceive products: [Donations.Product]) {
        DispatchQueue.main.async {
            self.donationProducts = products
            
            // update UI
            for product in self.donationProducts {
                switch product.kind {
                    case .smallCoffee:
                        self.updateDonationButton(button: self.smallDonationButton,
                                                  price: product.price,
                                                  info: product.info)
                    case .bigCoffee:
                        self.updateDonationButton(button: self.mediumDonationButton,
                                                  price: product.price,
                                                  info: product.info)
                    case .lunch:
                        self.updateDonationButton(button: self.bigDonationButton,
                                                  price: product.price,
                                                  info: product.info)

                }
            }
            
            self.stopLoading()
        }
    }
    
    public func transactionDidStart(for product: Donations.Product) {
        DispatchQueue.main.async {
            self.startLoading()
        }
    }
    
    public func transactionIsBeingProcessed(for product: Donations.Product) {
        DispatchQueue.main.async {
            self.startLoading()
        }
    }
    
    public func transactionDidFinish(for product: Donations.Product, error: Error?) {
        DispatchQueue.main.async {
            self.stopLoading()
            
            // hide donations interface
            self.donationsInterfaceView.isHidden = true
            
            // add a message view
            let messageView = MessageView(frame: self.view.frame)
            messageView.backgroundColor = .clear
            self.view.addSubview(messageView)
            
            // check for error or dismiss our donation sheet
            if error == nil {
                messageView.message = "🎉 Thank you for your donation!"
            } else {
                messageView.message = "😔 Donation failed! Try again later..."
            }
        }
    }
}
