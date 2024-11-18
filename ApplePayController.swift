//
//  ApplePayController.swift
//  Runner
//
//  Created by Edthin Chung on 23/8/2023.
//

import Foundation
import UIKit
import PassKit

class ApplePayController: UIViewController {
    var flutterresult: FlutterResult!
    var cardNumber: String = ""
    var last4: String = ""
    var name: String = ""
    var dpan: String = ""
    var tokenUniqueReference: String = ""
    var primaryAccountUniqueRef: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        onEnroll()
    }
    
    private func onEnroll() {
        
        guard isPassKitAvailable() else {
            showPassKitUnavailable(message: "InApp enrollment not available for this device")
            return
        }
        
        initEnrollProcess()
    }
    
    
    private func initEnrollProcess() {
        
        let card = cardInformation()
        
        NSLog("DEBUG:card holder %@", card.holder)
        NSLog("DEBUG:card panTokenSuffix %@", card.panTokenSuffix)
        
        guard let configuration = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2) else {
            showPassKitUnavailable(message: "InApp Enrollment Configuraton fail")
            return
        }
        configuration.cardholderName = card.holder
        configuration.primaryAccountSuffix = card.panTokenSuffix
        configuration.paymentNetwork = PKPaymentNetwork.masterCard
        configuration.primaryAccountIdentifier = card.primaryAccountUniqueRef
        print("[configuration] \(card)")
        guard let enrollViewController = PKAddPaymentPassViewController(requestConfiguration: configuration, delegate: self) else {
            showPassKitUnavailable(message: "InApp Enrollment Controller Configuration fail")
            return
        }
        
        present(enrollViewController, animated: true, completion: nil)
    }
    
    private func isPassKitAvailable() -> Bool {
        return PKAddPaymentPassViewController.canAddPaymentPass()
    }
    
    private func showPassKitUnavailable(message: String) {
        let alert = UIAlertController(title: "InApp Error",
                                      message: message,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
        self.flutterresult!("InApp Error");
    }
    
    private func cardInformation() -> Card {
        return Card(panTokenSuffix: last4, holder: name, dpan: dpan, tokenUniqueReference: tokenUniqueReference, primaryAccountUniqueRef: primaryAccountUniqueRef)
    }
}

private struct Card {
    /// Last four digits of the `pan token` numeration for the card (****-****-****-0000)
    let panTokenSuffix: String
    /// Holder for the card
    let holder: String
    let dpan: String
    let tokenUniqueReference: String
    let primaryAccountUniqueRef: String
}

struct Test: Codable {
    var devicePassIdentifier: String
    var deviceAccountIdentifier: String
    var primaryAccountIdentifier: String
    var serialNumber: String
    var secureElementPass_primaryAccountIdentifier: String
    var secureElementPass_devicePassIdentifier: String
}

extension ApplePayController: PKAddPaymentPassViewControllerDelegate {
    func addPaymentPassViewController(
        _ controller: PKAddPaymentPassViewController,
        generateRequestWithCertificateChain certificates: [Data],
        nonce: Data, nonceSignature: Data,
        completionHandler handler: @escaping (PKAddPaymentPassRequest) -> Void) {
            
            let request = IssuerRequest(certificates: certificates, nonce: nonce, nonceSignature: nonceSignature, productType: "DEFAULT_MASTERCARD", networkName: "MasterCard")
            
            let interactor = GetPassKitDataIssuerHostInteractor()
            interactor.getE6Data(request: request, cardNumber: cardNumber) { response in
                
                let request = PKAddPaymentPassRequest()
                request.activationData = Data(base64Encoded: response.activationData, options: [])
                request.ephemeralPublicKey = Data(base64Encoded: response.ephemeralPublicKey, options: [])
                request.encryptedPassData = Data(base64Encoded: response.encryptedPassData, options: [])
                print("activationData \(response.activationData) ")
                print("ephemeralPublicKey \(response.ephemeralPublicKey) ")
                print("encryptedPassData \(response.encryptedPassData) ")
                handler(request)
            }
        }
    
    func addPaymentPassViewController(
        _ controller: PKAddPaymentPassViewController,
        didFinishAdding pass: PKPaymentPass?,
        error: Error?) {
            if let _ = pass {
//                let interactor = GetPassKitDataIssuerHostInteractor()
//                interactor.testWebhook(request: Test(
//                    devicePassIdentifier: (pass?.devicePassIdentifier ?? "-"),
//                    deviceAccountIdentifier: (pass?.deviceAccountIdentifier ?? "-"),
//                    primaryAccountIdentifier: (pass?.primaryAccountIdentifier ?? "-"),
//                    serialNumber: (pass?.serialNumber ?? "-"),
//                    secureElementPass_primaryAccountIdentifier: (pass?.secureElementPass?.primaryAccountIdentifier ?? "-"),
//                    secureElementPass_devicePassIdentifier:(pass?.secureElementPass?.deviceAccountIdentifier ?? "-"))) { response in
//                        print("Done")
//                    }
                
                if let navigationController = self.navigationController {
                    for controller in navigationController.viewControllers {
                        if controller.isKind(of: type(of: self)) {
                            controller.dismiss(animated: false, completion: nil)
                            navigationController.setNavigationBarHidden(true, animated: false)
                            navigationController.popToRootViewController(animated: false)
                            break
                        }
                    }
                }
                print("addPaymentPassViewController -> No error")
                self.flutterresult!("success");
            } else {
                if let navigationController = self.navigationController {
                    for controller in navigationController.viewControllers {
                        if controller.isKind(of: type(of: self)) {
                            controller.dismiss(animated: false, completion: nil)
                            navigationController.setNavigationBarHidden(true, animated: false)
                            navigationController.popToRootViewController(animated: false)
                            break
                        }
                    }
                }
                print("addPaymentPassViewController -> error  \(error)")
                self.flutterresult!("backed from Apple Pay Controller");
            }
        }
}

extension Bundle {
    static func infoPlistValue(forKey key: String) -> Any? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else {
            return nil
        }
        return value
    }
}

struct IssuerRequest: Codable{
    let certificates: [Data]
    let nonce: Data
    let nonceSignature: Data
    let productType: String
    let networkName: String
}

private class GetPassKitDataIssuerHostInteractor {
    
    struct IssuerResponse: Codable {
        let statusCode: String
        let statusMessage: String
        let data: IssuerResponseData
    }
    
    struct IssuerResponseData: Codable {
        let encryptedPassData: String
        let ephemeralPublicKey: String
        let activationData: String
    }
    
    func getE6Data(request: IssuerRequest, cardNumber: String, onFinish:@escaping (IssuerResponseData) -> ()){
        guard let uafDomin = Bundle.infoPlistValue(forKey:"UAF_DOMAIN") as? String else { return }
        let url = URL(string: uafDomin + "/api/v1/card-ops/credit-cards/" + cardNumber + "/tokenization")!
        print(url)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            print("req json data: \(request)")
        }catch let jsonError{
            print(jsonError)
        }
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }
            guard let data = data, let response = response as? HTTPURLResponse else{
                print ("Error: No Response Object")
                return
            }
            guard response.statusCode == 200 else {
                print("Error: Server response status \(response.statusCode)")
                return
            }
            
            do {
                print("response json data: \(data)")
                let issuerResponse = try JSONDecoder().decode(IssuerResponse.self, from: data)
                let issuerResponseData = issuerResponse.data
                print("issuerResponseData: \(issuerResponseData)")
                onFinish(issuerResponseData)
            } catch let jsonError {
                print(jsonError)
            }
        }
        task.resume()
    }
    
    @available(iOS 14.0, *)
    final class ApplePayNonUIExtensionHandler: PKIssuerProvisioningExtensionHandler {
        
        override func status(completion: @escaping (PKIssuerProvisioningExtensionStatus) -> Void) {
            let status = PKIssuerProvisioningExtensionStatus()
            status.requiresAuthentication = true
            status.passEntriesAvailable = true
            status.remotePassEntriesAvailable = true
            completion(status)
        }
    }
}
