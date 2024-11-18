import UIKit
import Flutter
import GoogleMaps
import WatchConnectivity
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate ,UINavigationControllerDelegate,WCSessionDelegate{
    
    var navigationController: UINavigationController?
    var result: FlutterResult?
    
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?) {
            
            switch session.activationState {
                
            case .notActivated:
                print("Session no activated")
            case .inactive:
                print("Session inactive")
            case .activated:
                print("Session activated")
            @unknown default:
                break
            }
            
            if let err = error {
                print("ERROR: \\(err.localizedDescription)")
            }
            
            if session.isPaired {
                print("Current phone is paired to an apple watch!")
            }
            
            print("reachable: \\(session.isReachable)")
        }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Session just became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("session did deactivate")
    }
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GMSServices.provideAPIKey("AIzaSyB721xoCqQD2s6By2ZGehNJwRT9y3KO2gI")
        GeneratedPluginRegistrant.register(with: self)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        self.navigationController = UINavigationController.init(rootViewController: controller)
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = self.navigationController
        self.navigationController!.delegate=self //设置代理 ，配置导航栏的显示与否
        window?.makeKeyAndVisible()
        NotificationCenter.default.addObserver(self, selector: #selector(video), name: NSNotification.Name(rawValue:"HKIDSelected"), object: nil)
        
        let jumpIosChannel = FlutterMethodChannel(name: "com.uaf.cc/channels",binaryMessenger: controller.binaryMessenger)
        
        //处理-----跳转到iOS页面
        jumpIosChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            // Note: this method is invoked on the UI thread.
            if(call.method == "startHKIDVActivity"){
                
                //                   self?.result = result
                self?.jumpToIosPageMethod(result: result) //跳转页面
                //                   result("openVideo")
            }
            else if(call.method == "startSSIDVActivity"){
                self?.jumpToIosPageMethod2(result: result) //跳转页面
            }
            //视频播放完毕通信此方法
            else if(call.method == "videoFinish0"){
                print("接收videoFinish");
                //播放视频时关闭了页面重新跳转
                self?.jumpToIosOCRPageMethod(result: result) //跳转页面
                //通知HKViewController 的 MP4finsh 监听 调用扫描卡页面
                
            }
            //视频播放完毕通信此方法
            else if(call.method == "videoFinish1"){
                print("接收videoFinish");
                self?.jumpToIosOCR2PageMethod(result: result) //跳转页面
                //                   //通知HKViewController 的 MP4finsh 监听 调用扫描卡页面
                //                   NotificationCenter.default.post(name: NSNotification.Name("MP4finsh"), object: nil, userInfo: ["rectype":"1"])
            }
            else if(call.method == "pushSSID"){
                print("接收pushSSID");
                //                   result("videoFinish");
                self?.jumpToIosSSIDPageMethod(result: result) //跳转页面
                
                //                   //通知HKViewController 的 MP4finsh 监听 调用扫描卡页面
                //                   NotificationCenter.default.post(name: NSNotification.Name("MP4finsh"), object: nil, userInfo: ["rectype":"1"])
            }
            else if(call.method == "applepay"){
                print("push to apple pay page");
                if let args = call.arguments as? [String: Any]
                {
                    let cardNumber = args["cardNumber"] as? String
                    let last4 = args["last4"] as? String
                    let name = args["name"] as? String
                    let dpan = args["dpan"] as? String
                    let tokenUniqueReference = args["tokenUniqueReference"] as? String
                    let primaryAccountUniqueRef = args["primaryAccountUniqueRef"] as? String
                    self?.jumptoApplePay(cardNumber: cardNumber!,last4: last4!,name: name!,dpan: dpan!, tokenUniqueReference: tokenUniqueReference ?? "", primaryAccountUniqueRef: primaryAccountUniqueRef ?? "", result: result) //跳转页面
                }
            }
            else if(call.method == "checkApplePayIsAdded"){
                if let args = call.arguments as? [String: Any]
                {
                    let last4 = args["last4"] as? String
                    self?.checkApplePayIsAdded(last4: last4!,result: result)
                }
            }
            else if(call.method == "checkPendingActivateToken"){
                self?.checkPendingActivateToken(result: result)
            }
            //  //!!! Remove this after testing
            //  else if(call.method == "testing"){
            //      self?.testing(result: result)
            //  }
            else {
                result(FlutterMethodNotImplemented)
                return
            }
            
        })
        
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    @objc func video(nofi : Notification){
        //        self.result!("openVideo")
    }
    //跳转到HKIDCard页面
    private func jumpToIosPageMethod(result: @escaping FlutterResult) {
        
        let vc: HKViewController = HKViewController()
        vc.flutterreuslt = result;
        
        //                   vc.navigationItem.title = "原生页面"
        self.navigationController?.pushViewController(vc, animated: false)
        
        //             result("跳转")
        
        
        
    }
    //跳转到HKIDCard页面
    private func jumpToIosOCRPageMethod(result: @escaping FlutterResult) {
        
        let vc: OCRViewController = OCRViewController()
        vc.flutterreuslt = result;
        
        //                   vc.navigationItem.title = "原生页面"
        self.navigationController?.pushViewController(vc, animated: false)
        vc.pushOCR("0")
        //             result("跳转")
        
        
        
    }
    
    
    //跳转到HKIDCard页面
    private func jumpToIosOCR2PageMethod(result: @escaping FlutterResult) {
        
        let vc: OCRViewController = OCRViewController()
        vc.flutterreuslt = result;
        
        //                   vc.navigationItem.title = "原生页面"
        self.navigationController?.pushViewController(vc, animated: false)
        vc.pushOCR("1")
        //             result("跳转")
        
        
        
    }
    //跳转到SSID页面
    private func jumpToIosSSIDPageMethod(result: @escaping FlutterResult) {
        
        let vc: OCRViewController = OCRViewController()
        
        vc.flutterreuslt = result;
        
        //                   vc.navigationItem.title = "原生页面"
        self.navigationController?.pushViewController(vc, animated: false)
        vc.pushpage2()
        //             result("跳转")
    }
    
    
    //Go to apple pay page
    private func jumptoApplePay(cardNumber: String, last4: String, name:String, dpan:String, tokenUniqueReference:String, primaryAccountUniqueRef:String, result: @escaping FlutterResult) {
        
        let vc: ApplePayController = ApplePayController()
        
        vc.cardNumber = cardNumber
        
        vc.last4 = last4
        
        vc.name = name
        
        vc.dpan = dpan
        
        vc.tokenUniqueReference = tokenUniqueReference
        
        vc.primaryAccountUniqueRef = primaryAccountUniqueRef
        
        vc.flutterresult = result;
        
        self.navigationController?.pushViewController(vc, animated: false)
    }
    
    //check Apple Pay is added
    private func checkApplePayIsAdded(last4: String, result: @escaping FlutterResult) {
        let interactor = RegisterAtApplePayInteractorImpl(pairedDeviceRepository: PairedDeviceRepositoryImpl(), passKitRepository: PassKitRepositoryImpl())
        let card = CreditCard(panTokenSuffix: last4)
        let executeResult = interactor.execute(card: card)
        result(executeResult)
    }
    
    // //check Apple Pay pending activate token
    private func checkPendingActivateToken(result: @escaping FlutterResult) {
        let a = CheckPendingActivateTokenImpl(pairedDeviceRepository: CheckPendingActivateTokenPairedDeviceRepositoryImpl(), passKitRepository: CheckPendingActivateTokenPassKitRepositoryImpl())
        let executeResult = a.execute() as [CheckPendingActivateTokenPassKitItem]
        print("[Debug] \(executeResult)")
//        var cardList = [CheckPendingActivateTokenPassKitItem]()
//        for card in executeResult {
//            cardList.append(CheckPendingActivateTokenPassKitItem(cardSuffix: card.cardSuffix, deviceAccountIdentifier: card.deviceAccountIdentifier))
//        }
        let itemDictionaries = executeResult.map { $0.toDictionary() }

        print("[Debug] cardList \(itemDictionaries)")
        result(itemDictionaries)
    }
    
    // //!!! Remove this after testing
    // private func testing(result: @escaping FlutterResult) {
    //     let a = CheckPendingActivateTokenImpl(pairedDeviceRepository: PairedDeviceRepositoryImpl(), passKitRepository: PassKitRepositoryImpl())
    //     let executeResult = a.testing()
    //     result(executeResult)
    // }
    
    
    private func jumpToIosPageMethod2(result: FlutterResult) {
        
        let vc: UIViewController = STIneracitveViewController()
        //                   vc.navigationItem.title = "原生页面"
        self.navigationController?.pushViewController(vc, animated: false)
        
        
        //          result("跳转")
    }
    
    
    //实现UINavigationControllerDelegate代理
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        //如果是Flutter页面，导航栏就隐藏
        navigationController.navigationBar.isHidden = viewController.isKind(of: FlutterViewController.self)
    }
    
    override func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        if(url != nil && url.isFileURL){
            if(url.pathExtension=="lic"){
                let tmpLicenseUrl:URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("SSID_LIVENESS_INTERACTIVE.lic")
                
                if(FileManager.default.fileExists(atPath: tmpLicenseUrl.path)){
                    do{
                        let _: () = try FileManager.default.removeItem(atPath: tmpLicenseUrl.path)
                    }catch{
                        
                    }
                    
                }
                do{
                    let _:() = try FileManager.default.copyItem(at: url, to: tmpLicenseUrl)
                }catch{
                    
                }
                
            }
        }
        return true
    }
}
