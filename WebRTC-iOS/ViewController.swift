//
//  ViewController.swift
//  WebRTC-iOS
//
//  Created by Hamza El Yousfi on 1/14/19.
//  Copyright © 2019 Hamza El Yousfi. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let signalClient = SignalClient()
    let webRTCClient = WebRTCClient()
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var hangupButton: UIButton!
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var startButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.webRTCClient.delegate = self
        self.signalClient.delegate = self
    }
    
    func initChatComponents(){
//        initAudio()
        initVideo()
    }
    
    func initVideo(){
        #if arch(arm64)
        // Using metal (arm64 only)
        let localRenderer = RTCMTLVideoView(frame: videoView.frame)
        localRenderer.videoContentMode = .scaleAspectFill
        
        #else
        // Using OpenGLES for the rest
        let localRenderer = RTCEAGLVideoView(frame: videoView.frame)
        #endif
        
        self.webRTCClient.startCaptureLocalVideo(renderer: localRenderer)
        self.embedView(localRenderer, into: self.videoView)
    }
    
    func initAudio(){
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord, mode: .videoChat, options: [])
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true)
        }
        catch let error {
            print("Couldn't set audio to speaker: \(error)")
        }
    }
    
    @IBAction func startDidTap(_ sender: Any) {
        startButton.isEnabled = false
        callButton.isEnabled = true
        hangupButton.isEnabled = false
        self.signalClient.connect(){ error in
            if(error != nil){
                return
            }
            self.webRTCClient.initPeerConnection()
        }
        
    }
    @IBAction func callDidTap(_ sender: Any) {
        startButton.isEnabled = false
        callButton.isEnabled = false
        hangupButton.isEnabled = true
        self.webRTCClient.offer { (sdp) in
            self.signalClient.send(sdp: sdp)
        }
    }
    @IBAction func hangupDidTap(_ sender: Any) {
        startButton.isEnabled = true
        callButton.isEnabled = false
        hangupButton.isEnabled = false
    }
    
    func embedView(_ view: UIView, into containerView: UIView) {
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|",
                                                                    options: [],
                                                                    metrics: nil,
                                                                    views: ["view":view]))
        
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|",
                                                                    options: [],
                                                                    metrics: nil,
                                                                    views: ["view":view]))
        containerView.layoutIfNeeded()
    }
}

extension ViewController: SignalClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalClient) {
        print("Signaling client connected")
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalClient) {
        print("Signaling client disconnected")
    }
    
    func signalClient(_ signalClient: SignalClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        self.webRTCClient.set(remoteSdp: sdp) { (error) in
            print("Received remote sdp")
        }
    }
    
    func signalClient(_ signalClient: SignalClient, didReceiveCandidate candidate: RTCIceCandidate) {
        print("Received remote candidate")
        self.webRTCClient.add(remoteCandidate: candidate)
    }
}

extension ViewController: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        print("discovered local candidate")
        self.signalClient.send(candidate: candidate)
        
    }
}

