//
//  ViewController.swift
//  Hello
//
//  Created by bluefish on 2019/7/5.
//  Copyright © 2019 systec. All rights reserved.
//

import UIKit
//import HandyJSON

enum Logger {
    case info
    case success
    case error
    case warning
}

func currentTime() -> String {
    let dateformatter = DateFormatter()
    dateformatter.dateFormat = "YYYY-MM-dd HH:mm:ss.SSS"
    return dateformatter.string(from: Date())
}

extension Logger {
    static func cat<T>(_ message: T, time: String = currentTime(), file: String = #file, method: String = #function, line: Int = #line) {
        self.info.cat(message)
    }
    
    func cat<T>(_ message: T, time: String = currentTime(), file: String = #file, method: String = #function, line: Int = #line) {
        
        #if DEBUG
        var log: String
        switch self {
        case .info:
            log = " ☕️ " + "\(message)"
        case .success:
            log = " 🍺 " + "\(message)"
        case .error:
            log = " ❌ " + "\(message)"
        case .warning:
            log = " ⚠️ " + "\(message)"
        }
        print("\(time) \((file as NSString).lastPathComponent)[\(line)]\(log)")
        #endif
    }
}

class ViewController: UIViewController, UITextFieldDelegate, VoipHandler, VideoPlayerHandler {

    @IBOutlet weak var domain: UITextField!
    @IBOutlet weak var sipId: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var callee: UITextField!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var videoUrl: UITextView!
    @IBOutlet weak var video: UIImageView!
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var videoStatus: UILabel!
    @IBOutlet weak var tcpClientData: UITextView!
    @IBOutlet weak var tcpClientHost: UITextField!
    
    var videoPlaying:Bool = false
    
    var player:UnsafeMutableRawPointer? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        VoipManager.addCallback(callback: self)
        self.view.layer.contents = UIImage(named: "bg")?.cgImage
        self.view.layer.contentsGravity = CALayerContentsGravity.resizeAspectFill
//        self.tcpClientHost.clearButtonMode = .whileEditing
//        self.view.endEditing(true)
//        UIApplication.shared.keyWindow?.endEditing(true)
//        self.contentView.endEditing(true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        VoipManager.removeCallback(callback: self)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        self.view.endEditing(true)
//        UIApplication.shared.keyWindow?.endEditing(true)
//        print("+++++++++++")
    }
    
    func voipHandler(action: Int, data: String) {
        if 0 == action {
            status.text = data
        } else if 1 == action {
            info.text = data
        }
    }
    
    func videoPlayerHandler(image: UIImage) {
        video.image = image
    }
    
    func videoPlayerMessageHandler(data: String) {
        videoStatus.text = data
    }
    
    @IBAction func onRegister(_ sender: Any) {
        let domain = self.domain.text
        let sipId = self.sipId.text
        let password = self.password.text
        voip_account_update(domain, sipId, password)
    }
    
    @IBAction func onUnregister(_ sender: Any) {
        voip_account_unregister()
    }
    
    @IBAction func onHangup(_ sender: Any) {
        voip_hangup()
    }
    
    @IBAction func onAnswer(_ sender: Any) {
        voip_answer()
    }
    
    @IBAction func onCall(_ sender: Any) {
        voip_call(callee.text)
    }
    
    @IBAction func onPlay(_ sender: Any) {
        if(videoPlaying) {
            videoplayer_stop(player)
        }
        videoPlaying = true
        video.image = nil
        player = videoplayer_play(self, videoUrl.text)
    }
    
    @IBAction func onStop(_ sender: Any) {
        if(videoPlaying) {
            videoplayer_stop(player)
        }
        video.image = nil
        videoPlaying = false
    }
    
    @IBAction func onTcpClient(_ sender: Any) {

        struct Message: Codable {
            var code: Int
            var message: String
            var device_code: String
        }
        
        let host: String = self.tcpClientHost.text ?? "10.19.11.144"
        let queue = DispatchQueue(label: "com.systec.tcpclient")
        queue.async {
            discovery_test(0, nil)
            let data: String = tcpclient_hello(
                "\(host)",
                "/api/code",
                "{\"user_id\":\"0000000000000001\",\"server\":\"sg.systec-pbx.net\"}"
                ) ?? ""
            DispatchQueue.main.async {
                do {
                    let decoder = JSONDecoder()
                    let a_data = try decoder.decode(Message.self, from: data.data(using: .utf8)!)
                    Logger.info.cat("\(a_data.code ), \(a_data.message ), \(a_data.device_code )")
                        self.tcpClientData.text.append("\(data)\n")
                        self.tcpClientData.scrollRangeToVisible(NSRange.init(location: self.tcpClientData.text.count, length: 1))
                } catch {
                    print(error)
                }
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

