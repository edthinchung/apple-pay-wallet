//
//  IssuerExtensionHandler.swift
//  Runner
//
//  Created by Edthin Chung on 27/9/2023.
//

import PassKit
import os.log

@available(iOS 14.0, *)
class IssuerExtensionHandler: PKIssuerProvisioningExtensionHandler {
    let logger = Logger()
    
    struct UserDetailsResponse: Codable {
        let statusCode: String
        let statusMessage: String
        let data: UserDetails
    }
    
    struct UserDetails: Codable {
        let creationTime: Int64
        let modifiedTime: Int64
        let id: String
        let cardNumber: String
        let panFirst6: String
        let panLast4: String
        let type: String
        let state: String
        let cardProfileName: String
        let pinFailCount: Int
        let reissue: Bool
        let expiry: String
        let customerNumber: String
        let embossedName: String
        let programName: String
        let shipAddress: Address?
        let homeAddress: Address
        let countryCode: String
        let mobileNumber: String
        let tokenDTOList: [Token]
    }
    
    struct Address: Codable {
        let creationTime: Int64
        let modifiedTime: Int64
        let id: String
        let type: String?
        let line1: String?
        let line2: String?
        let line3: String?
        let neighborhood: String?
        let postalCode: String?
        let city: String?
        let state: String?
        let country: String?
    }
    
    struct Token: Codable {
        let id: Int
        let cardNumber: String
        let dpan: String
        let walletId: String
        let tokenUniqueReference: String
        let status: String
        let primaryAccountUniqueRef: String
        let seid: String
    }
    
    override func status(completion: @escaping (PKIssuerProvisioningExtensionStatus) -> Void) {
        let status = PKIssuerProvisioningExtensionStatus()
        status.requiresAuthentication = false
        status.passEntriesAvailable = true
        status.remotePassEntriesAvailable = true
        completion(status)
    }
    
    func getUserInfo(cardNumber: String, onFinish:@escaping (UserDetails) -> ()){
        print("getUserInfo start \(cardNumber)")
        guard let uafDomin = Bundle.infoPlistValue(forKey:"UAF_DOMAIN") as? String else { return }
        let url = URL(string: uafDomin + "/api/v1/card-ops/credit-cards/" + cardNumber + "/tokenization/metadata")!
        print("getUserInfo start \(url)")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
                let response = try JSONDecoder().decode(UserDetailsResponse.self, from: data)
                let userDetails = response.data
                print("userDetails: \(userDetails)")
                onFinish(userDetails)
            } catch let jsonError {
                print(jsonError)
            }
        }
        task.resume()
    }
    
    override func passEntries(completion: @escaping ([PKIssuerProvisioningExtensionPassEntry]) -> Void) {
        //Get all cards by local storage cardNumber
        var entries: [PKIssuerProvisioningExtensionPassEntry] = []
        print("[Hit] passEntries()")
        let cardNumbers = UserDefaults(suiteName: "group.walletextension")?.object(forKey: "card") as? [String]
        print("passEntries() cardNumber stored \(cardNumbers)")
        
        let group = DispatchGroup()
        cardNumbers?.forEach { cardNumber in
            group.enter()
            
            var response: UserDetails? = nil
            getUserInfo(cardNumber: cardNumber) { userInfoResponse in
                response = userInfoResponse
                group.leave()
            }
            
            group.wait()
            if let response = response {
                //Reports the list of passes available to add to an iPhone.
                print("getUserInfo with cardNumber: \(cardNumber)")
                var transparentImage: CGImage {
                    let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
                    return context!.makeImage()!
                }
                let requestConfig = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2)!
                
                requestConfig.style = .payment
                requestConfig.primaryAccountIdentifier = response.tokenDTOList.first?.primaryAccountUniqueRef ?? ""
                requestConfig.cardholderName = response.embossedName
                requestConfig.primaryAccountSuffix = response.panLast4
                requestConfig.paymentNetwork = .masterCard
                let passEntry = PKIssuerProvisioningExtensionPaymentPassEntry(identifier: cardNumber,
                                                                              title: response.programName,
                                                                              art: transparentImage,
                                                                              addRequestConfiguration: requestConfig)
                entries.append(passEntry!)
            }
        }
        print("passEntries count: \(entries.count)")
        completion(entries)
    }
    
    override func generateAddPaymentPassRequestForPassEntryWithIdentifier(_ identifier: String, configuration: PKAddPaymentPassRequestConfiguration,
                                                                          certificateChain certificates: [Data], nonce: Data, nonceSignature: Data,
                                                                          completionHandler completion: @escaping (PKAddPaymentPassRequest?) ->
                                                                          Void) {
        let request = IssuerRequest(certificates: certificates, nonce: nonce, nonceSignature: nonceSignature, productType: "DEFAULT_MASTERCARD", networkName: "MasterCard")
        let interactor = GetPassKitDataIssuerHostInteractor()
        interactor.getE6Data(request: request, cardNumber: identifier) { response in
            
            let request = PKAddPaymentPassRequest()
            request.activationData = Data(base64Encoded: response.activationData, options: [])
            request.ephemeralPublicKey = Data(base64Encoded: response.ephemeralPublicKey, options: [])
            request.encryptedPassData = Data(base64Encoded: response.encryptedPassData, options: [])
            print("activationData \(response.activationData) ")
            print("ephemeralPublicKey \(response.ephemeralPublicKey) ")
            print("encryptedPassData \(response.encryptedPassData) ")
            completion(request)
            
        }
    }
    
    //    for Apple Watch
    //    override func remotePassEntries(completion: @escaping ([PKIssuerProvisioningExtensionPassEntry]) -> Void) {
    //        //Reports the list of passes available to add to an Apple Watch.
    //        var entries: [PKIssuerProvisioningExtensionPassEntry] = []
    //
    //        var transparentImage: CGImage {
    //            let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    //            return context!.makeImage()!
    //        }
    //
    //        let passEntry2 = PKIssuerProvisioningExtensionPaymentPassEntry(identifier: "SIM credit card",
    //                                                                        title: "SIM",
    //                                                                        art: transparentImage,
    //                                                               addRequestConfiguration: PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2)!)
    //     entries.append(passEntry2!)
    //
    //        completion(entries)
    //    }
}
    
    /**
     Converts a UIImage to a CGImage.
     */
    private func getEntryArt(image: UIImage) -> CGImage {
        let ciImage = CIImage(image: image)
        let ciContext = CIContext(options: nil)
        return ciContext.createCGImage(ciImage!, from: ciImage!.extent)!
    }
    
    
    struct IssuerRequest: Codable{
        let certificates: [Data]
        let nonce: Data
        let nonceSignature: Data
        let productType: String
        let networkName: String
    }
    
    extension Bundle {
        static func infoPlistValue(forKey key: String) -> Any? {
            guard let value = Bundle.main.object(forInfoDictionaryKey: key) else {
                return nil
            }
            return value
        }
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
            let url = URL(string: "https://api-cc-xapi.uaf.com.hk/api/v1/card-ops/credit-cards/" + cardNumber + "/tokenization")!
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
    }
    
    

