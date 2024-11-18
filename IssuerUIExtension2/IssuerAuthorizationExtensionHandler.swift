//
//  IssuerAuthorizationExtensionHandler.swift
//  Runner
//
//  Created by Edthin Chung on 27/9/2023.
//

import PassKit
import UIKit

@available(iOS 14.0, *)
class IssuerAuthorizationExtensionHandler: UIViewController, PKIssuerProvisioningExtensionAuthorizationProviding {
    var completionHandler: ((PKIssuerProvisioningExtensionAuthorizationResult) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func authenticateUser() {
        let userAuthenticated = true
        
        let authorizationResult: PKIssuerProvisioningExtensionAuthorizationResult = userAuthenticated ? .authorized : .canceled

        self.completionHandler?(authorizationResult)
    }
}
