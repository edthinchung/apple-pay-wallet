//
//  CheckPendingActivateToken.swift
//  Runner
//
//  Created by Edthin Chung on 15/11/2023.
//

import Foundation
import WatchConnectivity
import PassKit


struct CheckPendingActivateTokenPassKitItem : Codable{
    let cardSuffix: String
    let deviceAccountIdentifier: String
    let localizedDescription: String
    let passTypeIdentifier: String
    let organizationName: String
    
    func toDictionary() -> [String: Any] {
        return [
            "cardSuffix": cardSuffix,
            "deviceAccountIdentifier": deviceAccountIdentifier,
            "localizedDescription": localizedDescription,
            "passTypeIdentifier": passTypeIdentifier,
            "organizationName": organizationName
        ]
    }
}

protocol CheckPendingActivateToken {
    func execute() -> [CheckPendingActivateTokenPassKitItem]
}

class CheckPendingActivateTokenImpl: CheckPendingActivateToken {
    private let pairedDeviceRepository: CheckPendingActivateTokenPairedDeviceRepository
    private let passKitRepository: CheckPendingActivateTokenPassKitRepository
    
    init(pairedDeviceRepository: CheckPendingActivateTokenPairedDeviceRepository,
         passKitRepository: CheckPendingActivateTokenPassKitRepository) {
        self.pairedDeviceRepository = pairedDeviceRepository
        self.passKitRepository = passKitRepository
    }
    
    func execute() -> [CheckPendingActivateTokenPassKitItem] {
        print("CheckPendingActivateTokenImpl execute")
        let passes = passKitRepository.passes()
        var remotePasses: [CheckPendingActivateTokenPassKitItem] = []
        if pairedDeviceRepository.hasPairedWatchDevices() {
            remotePasses = remotePasses + passKitRepository.remotePasses()
        }
        for pass in passes + remotePasses {
            
            print("cardSuffix:\(pass.cardSuffix) deviceAccountIdentifier:\(pass.deviceAccountIdentifier)");
        }
        return passes + remotePasses
    }
}

protocol CheckPendingActivateTokenPassKitRepository {
    func isPassKitAvailable() -> Bool
    func passes() -> [CheckPendingActivateTokenPassKitItem]
    func remotePasses() -> [CheckPendingActivateTokenPassKitItem]
}

class CheckPendingActivateTokenPassKitRepositoryImpl: CheckPendingActivateTokenPassKitRepository {
    
    func isPassKitAvailable() -> Bool {
        return PKPassLibrary.isPassLibraryAvailable()
    }
    
    func passes() -> [CheckPendingActivateTokenPassKitItem] {
        guard PKPassLibrary.isPassLibraryAvailable() else {
            return []
        }
        
        return passes().compactMap(map(pkpass:))
    }
    
    func remotePasses() -> [CheckPendingActivateTokenPassKitItem] {
        guard PKPassLibrary.isPassLibraryAvailable() else {
            return []
        }
        
        return remotePasses().compactMap(map(pkpass:))
    }
    
    
    private func passes() -> [PKPass] {
        let passLibrary = PKPassLibrary()
        if #available(iOS 13.4, *) {
            print("passLibrary secureElement: \(passLibrary.passes(of: .secureElement)) ")
            return passLibrary.passes(of: .secureElement)
        } else {
            print("passLibrary payment: \(passLibrary.passes(of: .payment)) ")
            return passLibrary.passes(of: .payment)
        }
    }
    
    private func remotePasses() -> [PKPass] {
        if #available(iOS 13.4, *) {
            return PKPassLibrary().remoteSecureElementPasses
        } else {
            return PKPassLibrary().remotePaymentPasses()
        }
    }
    
    private func deviceCardSuffix(for pass: PKPass) -> String? {
        if #available(iOS 13.4, *) {
            return pass.secureElementPass?.primaryAccountNumberSuffix
        } else {
            return pass.paymentPass?.primaryAccountNumberSuffix
        }
    }
    
    private func deviceAccountIdentifier(for pass: PKPass) -> String? {
        if #available(iOS 13.4, *) {
            return pass.secureElementPass?.deviceAccountIdentifier
        } else {
            return pass.paymentPass?.deviceAccountIdentifier
        }
    }
    
    private func map(pkpass: PKPass) -> CheckPendingActivateTokenPassKitItem? {
        guard let dai = self.deviceAccountIdentifier(for: pkpass) else { return nil }
        guard let cardSuffix = self.deviceCardSuffix(for: pkpass) else { return nil }
        // Accessing properties directly from pkpass
        let localizedDescription = pkpass.localizedDescription // Descriptive text from the pass
        let passTypeIdentifier = pkpass.passTypeIdentifier // Identifier for the pass type
        let organizationName = pkpass.organizationName // Name of the organization that issued the pass
        return CheckPendingActivateTokenPassKitItem(cardSuffix: cardSuffix,
                                                        deviceAccountIdentifier: dai,
                                                        localizedDescription: localizedDescription,
                                                        passTypeIdentifier: passTypeIdentifier,
                                                        organizationName: organizationName)
    }
}

protocol CheckPendingActivateTokenPairedDeviceRepository {
    func hasPairedWatchDevices() -> Bool
}

class CheckPendingActivateTokenPairedDeviceRepositoryImpl: NSObject, CheckPendingActivateTokenPairedDeviceRepository, WCSessionDelegate {
    var isWatchConnected = false
    
    func hasPairedWatchDevices() -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        session.delegate = self
        print("Watch isPaired: \(session.isPaired) ")
        return session.isPaired
    }
    
    // WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch Session Error ->  \(error)")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
}
