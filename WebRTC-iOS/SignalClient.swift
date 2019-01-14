//
//  SignalClient.swift
//  WebRTC
//
//  Created by Stas Seldin on 20/05/2018.
//  Copyright © 2018 Stas Seldin. All rights reserved.
//

import Foundation
import FirebaseFirestore

protocol SignalClientDelegate: class {
    func signalClientDidConnect(_ signalClient: SignalClient)
    func signalClientDidDisconnect(_ signalClient: SignalClient)
    func signalClient(_ signalClient: SignalClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalClient(_ signalClient: SignalClient, didReceiveCandidate candidate: RTCIceCandidate)
}

struct Message: Codable {
    enum PayloadType: String, Codable {
        case sdp, candidate
    }
    let type: PayloadType
    let payload: String
}

class SignalClient {
    weak var delegate: SignalClientDelegate?
    let FIREBASE_COLLECTION_NAME = "dev-stream"
    var db : Firestore?
    var callId : String? = nil
    var docRef : ListenerRegistration?
    
    var remoteIceCandidates : [[String:String]] = [[String:String]]()
    var localIceCandidates : [[String:String]] = [[String:String]]()
    
    var phoneNode : [String:Any?] = [String:Any?]()

    func connect(completion: @escaping (Error?) -> ()) {
        db = Firestore.firestore()
        var ref: DocumentReference? = nil
        ref = db!.collection(FIREBASE_COLLECTION_NAME).addDocument(data: [String : Any]()){
            err in
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                self.callId = ref!.documentID
                self.setupListeners()
            }
            completion(err)
        }
    }
    
    func setupListeners(){
        let query = db!.collection(FIREBASE_COLLECTION_NAME).document(callId!)
        docRef = query.addSnapshotListener{ (snapshot, error) in
            if(error != nil){
                print("Listener failed")
                return
            }
            if snapshot != nil && snapshot!.exists && snapshot!.data() != nil{
                let data = snapshot!.data()!
                print("Current data: \(data)")
                if(data.keys.contains("phone")){
                    self.phoneNode = data["phone"] as! [String:Any?]
                }
                
                if(data.keys.contains("dispatcher")){
                    self.delegate?.signalClientDidConnect(self)
                    let dispatcher = data["dispatcher"] as! [String:Any?]
                    if(dispatcher.keys.contains("answer")){
                        let answer = dispatcher["answer"] as! [String:String]
                        self.delegate?.signalClient(self, didReceiveRemoteSdp: RTCSessionDescription(type: RTCSessionDescription.type(for: answer["type"]!), sdp: answer["sdp"]!))
                    }
                    
                    if(dispatcher.keys.contains("iceCandidates")){
                        let iceCandidates = dispatcher["iceCandidates"] as! [[String:String]]
                        let newIceCandidates = iceCandidates.filter{
                            let dict = $0
                            return !self.remoteIceCandidates.contains{ dict == $0 }
                        }
                        for iceCandidate in newIceCandidates{
                            self.delegate?.signalClient(self, didReceiveCandidate: RTCIceCandidate(sdp: iceCandidate["candidate"]!, sdpMLineIndex: Int32(iceCandidate["label"]!)!, sdpMid: iceCandidate["id"]!))
                        }
                        self.remoteIceCandidates = iceCandidates
                    }
                }
            } else {
                print("current data: null")
                self.delegate?.signalClientDidDisconnect(self)
            }
        }
    }
    
    func send(sdp: RTCSessionDescription) {
        print("emitMessage() called with: message = \(sdp.sdp)")
        var docData = [String:Any]()
        var offer = [String:String]()
        offer["type"] = RTCSessionDescription.string(for: sdp.type)
        offer["sdp"] = sdp.sdp
        
        phoneNode.merge(["offer":offer]){ (_, new) in new }
        
        docData["phone"] = phoneNode
        print("created offer \(offer)")
        db!.collection(FIREBASE_COLLECTION_NAME).document(callId!).setData(docData){ err in
            if err != nil {
                print("error creating an offer")
            } else {
                print("offer created succesfully")
            }
        }
    }
    
    func send(candidate: RTCIceCandidate) {
        print("send Candidate  called with: candidate = \(candidate.sdp)")
        var docData = [String:Any]()
        var ic = [String:String]()
        ic["label"] = "\(candidate.sdpMLineIndex)"
        ic["id"] = candidate.sdpMid == "0" ? "audio" : "video"
        ic["candidate"] = candidate.sdp
        
        localIceCandidates.append(ic)
        
        phoneNode.merge(["iceCandidates":localIceCandidates]){ (_, new) in new }
        
        docData["phone"] = phoneNode
        print("created iceCandidates \(ic)")
        db!.collection(FIREBASE_COLLECTION_NAME).document(callId!).setData(docData){ err in
            if err != nil {
                print("error creating an iceCandidate")
            } else {
                print("ice candidate created succesfully")
            }
        }
    }
}
