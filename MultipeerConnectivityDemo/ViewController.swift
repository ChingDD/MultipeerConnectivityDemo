//
//  ViewController.swift
//  MultipeerConnectivityDemo
//
//  Created by Aco on 2024/7/11.
//

import UIKit
import MultipeerConnectivity
import Security

class ViewController: UIViewController {

    @IBOutlet weak var msgLabel: UILabel!
    @IBOutlet weak var msgTextField: UITextField!
    @IBOutlet weak var connectedDeviceLabel: UILabel!

    var connectedPeers: [MCPeerID]? = nil {
        didSet {
            DispatchQueue.main.async {
                guard let connectedPeers = self.connectedPeers else {
                    self.connectedDeviceLabel.text = "尚未連接"
                    print("connected Peers：\(self.connectedPeers)")
                    return
                }
                self.connectedDeviceLabel.text = connectedPeers.map { $0.displayName }.joined(separator: " ")
                print("connected Peers：\(self.connectedPeers)")
            }
        }
    }
    // 這個session的serviceType，可以取任何喜歡的字串，但要獨一無二
    let serviceType = "item-peer"

    // 這部裝置的識別，可以取任何喜歡的，但通常用UIDevice的name
    let peerId = MCPeerID(displayName: UIDevice.current.name)

    // 建立advertiser，用來發出request
    var peerAdvertiser: MCNearbyServiceAdvertiser?

    // The current peer session.
    var peerSession: MCSession?

    // 建立 browser 來搜尋周圍的advertiser，並對他們送出invitation
    var peerBrowser: MCNearbyServiceBrowser?
    var peerBrowserAssistant: MCAdvertiserAssistant?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        connectedDeviceLabel.text = "No Connected"
        peerSession = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .none)
        peerSession?.delegate = self

    }

    @IBAction func tapShareBtn(_ sender: Any) {
        guard let connectedPeers else { return }
        let msg = msgTextField.text ?? "No Input Msg"
        if let data = msg.data(using: .utf8) {
            do {
                try peerSession?.send(data, toPeers: connectedPeers, with: .reliable)
            } catch {
                print(error)
            }
        }
    }


    @IBAction func search(_ sender: Any) {
        let alertController = UIAlertController(title: nil, message: "Session", preferredStyle: .alert)
        let start = UIAlertAction(title: "join a session", style: .default, handler: sendRequest)
        let join = UIAlertAction(title: "invite user", style: .default, handler: seekUser)
        let cancel = UIAlertAction(title: "cencel", style: .cancel)
        alertController.addAction(start)
        alertController.addAction(join)
        alertController.addAction(cancel)
        present(alertController, animated: true)
    }

    @IBAction func leave(_ sender: Any) {
        peerAdvertiser?.stopAdvertisingPeer()
        peerBrowser?.stopBrowsingForPeers()
    }
    

    @objc func sendRequest(action: UIAlertAction) {
//        guard let peerSession else { return }
//        peerBrowserAssistant = MCAdvertiserAssistant(serviceType: serviceType, discoveryInfo: nil, session: peerSession)
//        peerBrowserAssistant?.delegate = self
//        self.peerBrowserAssistant?.start()
        let discoveryInfo = [
            "appVersion": "1.0.0",
            "userName": "Jeff Lin"
        ]
        peerAdvertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: discoveryInfo, serviceType: serviceType)
        peerAdvertiser?.delegate = self
        peerAdvertiser?.startAdvertisingPeer()
        let ac = UIAlertController(title: nil, message: "已發出請求", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "確認", style: .default)
        ac.addAction(okAction)
        present(ac, animated: true)
    }

    @objc func seekUser(action: UIAlertAction) {
        guard let peerSession else { return }
        let peerBrowserVC = MCBrowserViewController(serviceType: serviceType, session: peerSession)
        peerBrowserVC.delegate = self
        present(peerBrowserVC, animated: true)
//        peerBrowser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
//        peerBrowser?.delegate = self
//        peerBrowser?.startBrowsingForPeers()
    }
}


extension ViewController: MCSessionDelegate {

    // 當連線狀態有發生改變
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("連線狀態有發生改變:\(session.connectedPeers)")
        switch state {
        case .connected:
            print("Connected：\(peerID.displayName)")
        case .connecting:
            print("Connecting：\(peerID.displayName)")
        case .notConnected:
            print("Not Connected：\(peerID.displayName)")
        @unknown default:
            print("Unknown state：\(peerID.displayName)")
        }
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
        }
    }

    // 收到訊息
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            if let string = String(data: data, encoding: .utf8) {
                self?.msgLabel.text = string
            } else {
                self?.msgLabel.text = "No recieve msg"
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {

    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {

    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {

    }
}

extension ViewController: MCNearbyServiceAdvertiserDelegate {
    // 當收到邀請後想做些什麼
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("did Receive Invitation From Peer:\(peerID.displayName)")
        print("按下邀請了")
        var ac = UIAlertController(title: "Request", message: "\(peerID.displayName) wants to join", preferredStyle: .alert)
        if let msg = String(data: context ?? Data(), encoding: .utf8) {
            ac = UIAlertController(title: "Request", message: msg, preferredStyle: .alert)
        }
        let okAction = UIAlertAction(title: "Accept", style: .default) { _ in
            invitationHandler(true, self.peerSession)
        }
        let cancelAction = UIAlertAction(title: "Decline", style: .cancel) { _ in
            invitationHandler(false, nil)
        }
        ac.addAction(okAction)
        ac.addAction(cancelAction)
        present(ac, animated: true)
    }
}

extension ViewController: MCBrowserViewControllerDelegate {
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        print("browser ViewController Did Finish")
        browserViewController.dismiss(animated: true)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        print("browser ViewController Was Cancelled")
        browserViewController.dismiss(animated: true)
    }
}

//extension ViewController: MCAdvertiserAssistantDelegate {
//    func advertiserAssistantDidDismissInvitation(_ advertiserAssistant: MCAdvertiserAssistant) {
//        print("advertiser Assistant Did Dismiss Invitation")
//    }
//
//    func advertiserAssistantWillPresentInvitation(_ advertiserAssistant: MCAdvertiserAssistant) {
//
//        print("advertiser Assistant Will Present Invitation")
//    }
//}

extension ViewController: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("Found peer: \(peerID.displayName)")
        guard let peerSession else { return }
        let invitationStr = "\(peerId.displayName) would like to join the session"
        let data = invitationStr.data(using: .utf8)
        browser.invitePeer(peerID, to: peerSession, withContext: data, timeout: 60)
        print("====\(info)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost peer: \(peerID.displayName)")
    }
}
