//
//  ViewController.swift
//  ARCamera
//
//  Created by 間嶋大輔 on 2020/02/08.
//  Copyright © 2020 daisuke. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import AVFoundation
import ReplayKit
import AudioToolbox
import Speech

class ViewController: UIViewController, ARSCNViewDelegate,UIGestureRecognizerDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,RPPreviewViewControllerDelegate,ARSessionDelegate,UITextFieldDelegate, SFSpeechRecognizerDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    //MARK: - Recoder
    var isRecording = false
    let sharedRecorder = RPScreenRecorder.shared()
    
    //MARK: - State
    
    var isFront = false
    var pressed:PressedButton = .back
    enum PressedButton {
        case back
        case texture
        case material
        case occlussion
    }
    
    @objc func tapRecordButton(){
        if !isPhoto {
            moviewRecord()
        } else {
            shutter()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sharedRecorder.isMicrophoneEnabled = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        buttonSetting()
        buttonAdding()
        faceTextureButton.isHidden = true
        faceTextureLabel.isHidden = true
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        if !ARFaceTrackingConfiguration.isSupported {
            // Impossible Face Camera
            isFront = false
            //            AddButton.isHidden = true
            //            addLabel.isHidden = true
            CameraButton.isHidden = true
            cameraLabel.isHidden = true
            cameraLabel.isUserInteractionEnabled = false
            addLabel.isUserInteractionEnabled = false
            faceTextureLabel.isUserInteractionEnabled = false
            AddButton.isUserInteractionEnabled = false
            faceTextureLabel.alpha = 0
            AddButton.alpha = 0
            addLabel.alpha = 0
            cameraLabel.alpha = 0
            faceTextureLabel.alpha = 0
            faceTextureLabel.isHidden = true
            faceTextureButton.isHidden = true
            CameraButton.removeFromSuperview()
            cameraLabel.removeFromSuperview()
            faceTextureLabel.removeFromSuperview()
            faceTextureButton.removeFromSuperview()
            semanticsModeSwitchButton.removeFromSuperview()
        } else {
            if !ARFaceTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
                semanticsModeSwitchButton.removeFromSuperview()
            }
        }
        
        if !AVCaptureMultiCamSession.isMultiCamSupported{
            AddButton.removeFromSuperview()
            addLabel.removeFromSuperview()
            AddButton.isHidden = true
            AddButton.isHidden = true
        }
        if #available(iOS 13.0, *) {
            config.wantsHDREnvironmentTextures = true
        }
        sceneView.session.run(config, options: [])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        if !ARFaceTrackingConfiguration.isSupported {
            presentAlert(NSLocalizedString("この端末/OSではバックカメラのみ利用できます", comment: ""))
        } else if !ARFaceTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            presentAlert(NSLocalizedString("この端末/OSではピープルオクルージョンを利用できません", comment: ""))
        }
    }
    
    var currentOrientation:UIDeviceOrientation?
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let orientation = UIDevice.current.orientation
        if orientation != currentOrientation, orientation != .unknown {
            switch orientation {
            case .portrait:
                currentOrientation = .portrait
            case .landscapeLeft:
                currentOrientation = .landscapeLeft
            case .landscapeRight:
                currentOrientation = .landscapeRight
                //            case .unknown:
            //                currentOrientation = .unknown
            default:
                currentOrientation = .portrait
            }
            buttonSetting()
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        if audioEngine?.isRunning ?? false {
            audioEngine?.stop()
            recognitionRequest?.endAudio()
        }
    }
    
    private func initializeConfig(){
        if isFront == true {
            //Switch to Front Camera
            if ARFaceTrackingConfiguration.isSupported {
                let config = ARFaceTrackingConfiguration()
                
                if isOcclusion {
                    if ARFaceTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
                        config.frameSemantics.insert(.personSegmentation)
                    } else {
                        presentAlert(NSLocalizedString("この端末/OSではピープルオクルージョンを利用できません", comment: ""))
                    }
                } else {
                    if #available(iOS 12.0, *) {
                        config.maximumNumberOfTrackedFaces = 3
                        config.frameSemantics.remove(.personSegmentation)
                    }
                }
                sceneView.session.run(config, options: [])
                isFront = true
            } else {
                presentAlert(NSLocalizedString("Front camera is not available on this device.", comment: ""))
            }
            
        } else {
            // Switch to Back Camera
            let config = ARWorldTrackingConfiguration()
            if isOcclusion {
                if  ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
                    config.frameSemantics = .personSegmentation
                } else {
                    presentAlert(NSLocalizedString("この端末/OSではピープルオクルージョンを利用できません", comment: "") )
                }
            }
            sceneView.session.run(config, options:  [])
            isFront = false
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String {
            if mediaType == "public.movie" {
                if let videoURL = info[UIImagePickerController.InfoKey.mediaURL]  as? URL {
                    picker.dismiss(animated: true, completion: nil)
                    switch pressed {
                    case .back:
                        createVideoNode(size: 5.0, videoUrl: videoURL)
                        pinchSuggestAnimation()
                        
                    case .texture:
                        createVideoNode(size: 3.0, videoUrl: videoURL)
                    case .material:
                        createVideoNode(size: 3.0, videoUrl: videoURL)
                    case .occlussion:
                        createVideoNode(size: 3.0, videoUrl: videoURL)
                    }
                }
            }
            
            if mediaType == "public.image" {
                if let image = info[UIImagePickerController.InfoKey.originalImage]  as? UIImage {
                    picker.dismiss(animated: true, completion: nil)
                    print(image.imageOrientation.rawValue)
                    var newImage = UIImage()
                    switch image.imageOrientation.rawValue {
                    case 1:
                        newImage = imageRotatedByDegrees(oldImage: image, deg: 180)
                    case 3:
                        newImage = imageRotatedByDegrees(oldImage: image, deg: 90)
                    default:
                        newImage = image
                    }
                    switch pressed {
                    case .back:
                        createImageNode(size: 5.0, uiImage: newImage)
                        pinchSuggestAnimation()
                    case .texture :
                        createImageNode(size: 3.0, uiImage: image)
                    case .material:
                        createImageNode(size: 3.0, uiImage: newImage)
                    case .occlussion:
                        createImageNode(size: 3.0, uiImage: newImage)
                    }
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func createVideoNode(size:CGFloat, videoUrl: URL) {
        let avPlayer = AVPlayer(url: videoUrl)
        var mediaAspectRatio: Double!
        let resolution = resolutionForLocalVideo(url: videoUrl)
        let width = resolution.0?.width
        let height = resolution.0?.height
        mediaAspectRatio = Double(width! / height! )
        avPlayer.actionAtItemEnd = AVPlayer.ActionAtItemEnd.none;
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ViewController.didPlayToEnd),
                                               name: NSNotification.Name("AVPlayerItemDidPlayToEndTimeNotification"),
                                               object: avPlayer.currentItem)
        let skScene = SKScene(size: CGSize(width: 1000 * mediaAspectRatio, height: 1000))
        if resolution.1?.b != 0{
            skScene.size = CGSize(width: 1000, height: 1000 )
            skScene.zRotation = 1.5708
        } else if resolution.1?.a != 1.0 {
            skScene.zRotation = 1.5708 * 2
        }
        let skNode = SKVideoNode(avPlayer: avPlayer)
        skNode.position = CGPoint(x: skScene.size.width / 2.0, y: skScene.size.height / 2.0)
        skNode.size = skScene.size
        skNode.yScale = -1.0
        if resolution.1?.b != 0{
            skNode.zRotation = 1.5708
        } else if resolution.1?.a != 1.0 {
            skNode.zRotation = 1.5708 * 2
        }
        skNode.play()
        skScene.addChild(skNode)
        
        switch pressed{
            
        case .back :
            if backgroundNode != nil {
                backgroundNode?.removeFromParentNode()
            }
            
            let node = SCNNode()
            node.geometry = SCNPlane(width: size, height: size)
            let material = SCNMaterial()
            material.diffuse.contents = skScene
            node.geometry?.materials = [material]
            node.scale = SCNVector3(1.7  * mediaAspectRatio, 1.7, 1)
            node.position = position()
            sceneView.scene.rootNode.addChildNode(node)
            backgroundNode = node
            
        case .texture :
            for node in contentNodes {
                node.isHidden = false
                node.geometry?.firstMaterial?.transparency = 1
                node.geometry?.firstMaterial?.diffuse.contents = skScene
            }
        case .material :
            switch materialType {
            case .box:
                materialNode = SCNNode(geometry: SCNBox())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1 * mediaAspectRatio,1  , 1 * mediaAspectRatio)
                materialNode.worldPosition = frontOfCamera
            case .sphere:
                materialNode = SCNNode(geometry: SCNSphere())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1, 1, 1)
                materialNode.worldPosition = frontOfCamera
            case .text:
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(0.1, 0.1, 0.1)
                materialNode.worldPosition = frontOfCamera
            case .plane:
                materialNode = SCNNode(geometry: SCNBox())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1 * mediaAspectRatio, 1 , 0.01)
                if resolution.1?.b != 0{
                    materialNode.scale = SCNVector3(1 * Double(width! / height!), 1 , 0.01)
                }
                materialNode.worldPosition = frontOfCamera
            case .movingBox:
                materialNode = SCNNode(geometry: SCNBox())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1 * mediaAspectRatio,1  , 1 * mediaAspectRatio)
                materialNode.worldPosition = frontOfCamera
                movingNodes.append(materialNode)
            case .movingSphere:
                materialNode = SCNNode(geometry: SCNSphere())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1, 1, 1)
                materialNode.worldPosition = frontOfCamera
                movingNodes.append(materialNode)
            case .movingPlane:
                materialNode = SCNNode(geometry: SCNBox())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1 * mediaAspectRatio, 1 , 0.01)
                if resolution.1?.b != 0{
                    materialNode.scale = SCNVector3(1 * Double(width! / height!), 1 , 0.01)
                }
                materialNode.worldPosition = frontOfCamera
                movingNodes.append(materialNode)
            }
        case .occlussion:
            guard let reference = SCNReferenceNode(named: "reference").childNode(withName: creatureName, recursively: false) else {return}
            reference.enumerateChildNodes ({ (node:SCNNode, _ _:UnsafeMutablePointer<ObjCBool>) in
                if !(node.name?.contains("1"))!  {
                    node.geometry?.firstMaterial?.diffuse.contents = skScene
                }
            })
            sceneView.scene.rootNode.addChildNode(reference)
            reference.scale = SCNVector3(1, 1, 1)
            reference.worldPosition = SCNVector3(frontOfCamera.x,frontOfCamera.y,frontOfCamera.z - 2)
        }
    }
    
    func createImageNode(size:CGFloat, uiImage: UIImage) {
        
        switch pressed{
        case .back :
            if backgroundNode != nil {
                backgroundNode?.removeFromParentNode()
            }
            let width = uiImage.size.width
            let height = uiImage.size.height
            let mediaAspectRatio = Double(width / height)
            let cgImage = uiImage.cgImage
            let newUiImage = UIImage(cgImage: cgImage!, scale: 1.0, orientation: .up)
            let skScene = SKScene(size: CGSize(width: 1000  * mediaAspectRatio, height: 1000))
            let texture = SKTexture(image:newUiImage)
            let skNode = SKSpriteNode(texture:texture)
            skNode.position = CGPoint(x: skScene.size.width / 2.0, y: skScene.size.height / 2.0)
            skNode.size = skScene.size
            skNode.yScale = -1.0
            skScene.addChild(skNode)
            let node = SCNNode()
            node.geometry = SCNPlane(width: size, height: size)
            let material = SCNMaterial()
            material.diffuse.contents = skScene
            node.geometry?.materials = [material]
            node.scale = SCNVector3(1.7  * mediaAspectRatio, 1.7, 1)
            node.position = position()
            sceneView.scene.rootNode.addChildNode(node)
            backgroundNode = node
        case .texture :
            let width = uiImage.size.width
            let height = uiImage.size.height
            let mediaAspectRatio = Double(width / height)
            let cgImage = uiImage.cgImage
            let newUiImage = UIImage(cgImage: cgImage!, scale: 1.0, orientation: .up)
            let skScene = SKScene(size: CGSize(width: 1000  * mediaAspectRatio, height: 1000))
            let texture = SKTexture(image:newUiImage)
            let skNode = SKSpriteNode(texture:texture)
            skNode.position = CGPoint(x: skScene.size.width / 2.0, y: skScene.size.height / 2.0)
            skNode.size = skScene.size
            skNode.yScale = -1.0
            skScene.addChild(skNode)
            for node in contentNodes {
                node.isHidden = false
                node.geometry?.firstMaterial?.transparency = 1
                node.geometry?.firstMaterial?.diffuse.contents = skScene
            }
        case .material :
            let width = uiImage.size.width
            let height = uiImage.size.height
            let mediaAspectRatio = Double(width / height)
            let cgImage = uiImage.cgImage
            let newUiImage = UIImage(cgImage: cgImage!, scale: 1.0, orientation: .up)
            let skScene = SKScene(size: CGSize(width: 1000  * mediaAspectRatio, height: 1000))
            let texture = SKTexture(image:newUiImage)
            let skNode = SKSpriteNode(texture:texture)
            skNode.position = CGPoint(x: skScene.size.width / 2.0, y: skScene.size.height / 2.0)
            skNode.size = skScene.size
            skNode.yScale = -1.0
            skScene.addChild(skNode)
            
            switch materialType {
            case .box:
                materialNode = SCNNode(geometry: SCNBox())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1 * mediaAspectRatio,1  , 1 * mediaAspectRatio)
                materialNode.worldPosition = frontOfCamera
            case .sphere:
                materialNode = SCNNode(geometry: SCNSphere())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1, 1, 1)
                materialNode.worldPosition = frontOfCamera
            case .text:
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(0.1, 0.1, 0.1)
                materialNode.worldPosition = frontOfCamera
            case .plane:
                materialNode = SCNNode(geometry: SCNBox())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1 * mediaAspectRatio, 1 , 0.01)
                materialNode.worldPosition = frontOfCamera
            case .movingBox:
                materialNode = SCNNode(geometry: SCNBox())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1 * mediaAspectRatio,1  , 1 * mediaAspectRatio)
                materialNode.worldPosition = frontOfCamera
                movingNodes.append(materialNode)
            case .movingSphere:
                materialNode = SCNNode(geometry: SCNSphere())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1, 1, 1)
                materialNode.worldPosition = frontOfCamera
                movingNodes.append(materialNode)
            case .movingPlane:
                materialNode = SCNNode(geometry: SCNBox())
                materialNode.geometry?.firstMaterial?.diffuse.contents = skScene
                sceneView.scene.rootNode.addChildNode(materialNode)
                materialNode.scale = SCNVector3(1 * mediaAspectRatio, 1 , 0.01)
                materialNode.worldPosition = frontOfCamera
                movingNodes.append(materialNode)
            }
        case .occlussion:
            let width = uiImage.size.width
            let height = uiImage.size.height
            let mediaAspectRatio = Double(width / height)
            let cgImage = uiImage.cgImage
            let newUiImage = UIImage(cgImage: cgImage!, scale: 1.0, orientation: .up)
            let skScene = SKScene(size: CGSize(width: 1000  * mediaAspectRatio, height: 1000))
            let texture = SKTexture(image:newUiImage)
            let skNode = SKSpriteNode(texture:texture)
            skNode.position = CGPoint(x: skScene.size.width / 2.0, y: skScene.size.height / 2.0)
            skNode.size = skScene.size
            skNode.yScale = -1.0
            skScene.addChild(skNode)
            guard let reference = SCNReferenceNode(named: "reference").childNode(withName: creatureName, recursively: false) else {return}
            reference.enumerateChildNodes ({ (node:SCNNode, _ _:UnsafeMutablePointer<ObjCBool>) in
                if !(node.name?.contains("1"))!  {
                    node.geometry?.firstMaterial?.diffuse.contents = skScene
                }
            })
            sceneView.scene.rootNode.addChildNode(reference)
            reference.scale = SCNVector3(1, 1, 1)
            reference.worldPosition = SCNVector3(frontOfCamera.x,frontOfCamera.y,frontOfCamera.z - 2)
        }
    }
    
    private var timer:Timer?
    
    private var movingNodes:[SCNNode] = [] {
        didSet {
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { (Timer) in
                    self.updateMovingBox()
                })
                timer?.fire()
            }
            if movingNodes.count == 0,timer != nil {
                timer?.invalidate()
            }
            }
    }
    
    private func updateMovingBox() {
        for movingNode in movingNodes {
            let randomPosition = random(Float(-12)...Float(-2))
            movingNode.runAction(SCNAction.move(to: randomPosition, duration: 5),completionHandler: nil)
        }
    }
    
    private func random(_ range:ClosedRange<Float>)->SCNVector3 {
        let z = Float.random(in: range)
        let defaultX:Float = 0
        let defaultY:Float = 1
        var plus:Float = 0
        switch z {
        case -2 ..< -1 :
            plus = 0
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        case -3 ..< -2:
            plus = 0.3
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        case -4 ..< -3:
            plus = 0.5
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        case -5 ..< -4:
            plus = 1
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        case -6 ..< -5:
            plus = 2
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        case -8 ..< -7:
            plus = 2.5
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        case -9 ..< -8:
            plus = 3
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        case -10 ..< -9:
            plus = 3.5
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        case -11 ..< -10:
            plus = 4
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        case -12 ..< -11:
            plus = 4.5
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        default:
            plus = 0.5
            return SCNVector3(Float.random(in: (defaultX - plus)...(defaultX + plus)),Float.random(in:  (defaultY - plus)...(defaultY + plus)),z)
        }
    }
    
    
    private var speechRecognizer:SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine:AVAudioEngine?
    
    private func speech(){
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
        speechRecognizer?.delegate = self
        audioEngine = AVAudioEngine()
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.suggestAnimation("Say something")
                case .denied:
                    self.suggestAnimation("Please allow access to speech recognition")
                case .restricted:
                    self.suggestAnimation("Speech recognition restricted on this device")
                    
                case .notDetermined:
                    self.suggestAnimation("Please allow access to speech recognition")
                default:
                    break
                }
            }
        }
        do {
            try startRecording()
        } catch {
            suggestAnimation("Could not recording")
        }
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine!.inputNode
        
        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                // Update the text view with the results.
                isFinal = result.isFinal
                print("Text \(result.bestTranscription.formattedString)")
                let recognizedText = result.bestTranscription.formattedString
                self.setText(recognizedText)
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine?.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine?.prepare()
        try audioEngine?.start()
        // Let the user know to start talking.
        
    }
    private var reccentTextCount:Int = 0
    
    private func setText(_ result:String){
        switch speechMode {
        case .horizontal:
            if result.count >= reccentTextCount {
                let index = result.index(result.startIndex, offsetBy: reccentTextCount)
                let cutText = result[index...]
                reccentTextCount = result.count
                let text = SCNText(string: cutText, extrusionDepth: 2)
                text.flatness = 0.3
                text.chamferRadius = 0.3
                let textNode = SCNNode(geometry: text)
                text.firstMaterial?.diffuse.contents = UIColor.randomColor
                self.sceneView.scene.rootNode.addChildNode(textNode)
                let random = Float.random(in: -100...100)
                let random2 = Float.random(in: -100...100)
                let random3 = Float.random(in: -200 ... -50)
                textNode.position = SCNVector3(x: 20, y: random2, z: random3)
                textNode.runAction(SCNAction.move(to: SCNVector3(x: -100, y: random, z: random3), duration: 5),completionHandler: {
                    textNode.removeFromParentNode()
                })
            }
        case .rain:
            if result.count >= reccentTextCount {
                if reccentTextCount  == 0 {
                    reccentTextCount = result.count
                    let text = SCNText(string: result, extrusionDepth: 5)
                    text.flatness = 0.5
                    text.chamferRadius = 0.5
                    let textNode = SCNNode(geometry: text)
                    text.firstMaterial?.diffuse.contents = UIColor.randomColor
                    self.sceneView.scene.rootNode.addChildNode(textNode)
                    let random2 = Float.random(in: -100...100)
                    let random3 = Float.random(in: -200 ... -50)
                    textNode.position = SCNVector3(x: 0, y: 100, z: random3)
                    textNode.runAction(SCNAction.move(to: SCNVector3(x: random2, y: 0, z: random3), duration: 5),completionHandler: {
                        textNode.removeFromParentNode()
                    })
                }else{
                    let randomNumber = Int.random(in: 0...(reccentTextCount - 1))
                    let randomStartIndex = result.index(result.startIndex,offsetBy: randomNumber)
                    let randomEndIndex = result.index(randomStartIndex,offsetBy: Int.random(in: 1...(result.count - randomNumber)) - 1)
                    let cutText = result[randomStartIndex...randomEndIndex]
                    reccentTextCount = result.count
                    let text = SCNText(string: cutText, extrusionDepth: 5)
                    text.flatness = 0.5
                    text.chamferRadius = 0.5
                    let textNode = SCNNode(geometry: text)
                    text.firstMaterial?.diffuse.contents = UIColor.randomColor
                    self.sceneView.scene.rootNode.addChildNode(textNode)
                    let random2 = Float.random(in: -100...100)
                    let random3 = Float.random(in: -500 ... -50)
                    textNode.position = SCNVector3(x: random2, y: 100, z: random3)
                    textNode.runAction(SCNAction.move(to: SCNVector3(x: random2, y: 0, z: random3), duration: 3),completionHandler: {
                        textNode.removeFromParentNode()
                    })
                }
            }
        case .laser:
            if result.count >= reccentTextCount {
                let index = result.index(result.startIndex, offsetBy: reccentTextCount)
                let cutText = result[index...]
                reccentTextCount = result.count
                let text = SCNText(string: cutText, extrusionDepth: 2)
                text.flatness = 0.3
                text.chamferRadius = 0.3
                let textNode = SCNNode(geometry: text)
                text.firstMaterial?.diffuse.contents = UIColor.randomColor
                self.sceneView.scene.rootNode.addChildNode(textNode)
                let random = Float.random(in: -100...100)
                let random2 = Float.random(in: -100...100)
                let random3 = Float.random(in: -200 ... -50)
                textNode.position = SCNVector3(x: 20, y: random2, z: random3)
                textNode.runAction(SCNAction.move(to: SCNVector3(x: -100, y: random, z: random3), duration: 5),completionHandler: {
                    textNode.removeFromParentNode()
                })
            }
        }
    }
    
    var speechMode:SpeechMode = .horizontal
    
    enum SpeechMode {
        case horizontal
        case rain
        case laser
    }
    
    var horizontalAnchor:ARPlaneAnchor?
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let sceneView = renderer as? ARSCNView,
            anchor is ARFaceAnchor else { return nil }
        if ids.firstIndex(of: anchor.identifier) == nil {
            ids.append(anchor.identifier)
            let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!)!
            let material = faceGeometry.firstMaterial!
            material.lightingModel = .physicallyBased
            _ = ids.firstIndex(of: anchor.identifier)
            let contentNode = SCNNode(geometry: faceGeometry)
            contentNode.geometry?.firstMaterial?.transparency = 0
            contentNodes.append(contentNode)
            return contentNode
        }else{
            let node = SCNNode()
            return node
        }
    }
    
    //    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
    //        guard let plane =  anchors.last as? ARPlaneAnchor else {return}
    //        let colum3 = plane.transform.columns.3
    //        let vector = SCNVector3(colum3.x, colum3.y, colum3.z)
    //        print(vector)
    //        horizontalAnchor = plane
    //        let geo = ARSCNPlaneGeometry(device: sceneView.device!)
    //        let box = SCNNode(geometry:geo )
    //        geo?.update(from: plane.geometry)
    //        box.geometry?.firstMaterial?.diffuse.contents = UIColor.red
    //        sceneView.scene.rootNode.addChildNode(box)
    //    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceGeometry = node.geometry as? ARSCNFaceGeometry,
            let faceAnchor = anchor as? ARFaceAnchor
            else { return }
        faceGeometry.update(from: faceAnchor.geometry)
    }
    
    var frontOfCamera = SCNVector3()
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let position = SCNVector3(x: xPan, y: yPan, z: -10.0) // ノードの位置は、左右：0m 上下：0m　奥に50cm
        if let camera = sceneView.pointOfView,backgroundNode != nil {
            backgroundNode!.position = camera.convertPosition(position, to: nil) // カメラ位置からの偏差で求めた位置
            backgroundNode!.eulerAngles = camera.eulerAngles  // カメラのオイラー角と同じにする
        }
        frontOfCamera = sceneView.pointOfView!.convertPosition(SCNVector3(x: 0, y: -0.1, z: -2), to: nil)
        
    }
    //MARK: - Nodes
    
    var backgroundNode:SCNNode?
    var positionFrontOfCamera:SCNVector3?
    
    var contentNodes:[SCNNode] = []
    var materialNode = SCNNode()
    var creatureName = ""
    var ids = [UUID]()
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        textField.endEditing(true)
        if textField.text?.count != 0 {
            let text = SCNText(string: textField.text, extrusionDepth: 3)
            let textNode = SCNNode(geometry: text)
            materialNode = textNode
            self.imagePick()
        }
        self.textField.removeFromSuperview()
        self.textField.isHidden = true
        return true
    }
    
    @objc func didPlayToEnd(notification: NSNotification) {
        let item: AVPlayerItem = notification.object as! AVPlayerItem
        item.seek(to: CMTime.zero, completionHandler: nil)
    }
    
    private func resolutionForLocalVideo(url: URL) -> (CGSize?,CGAffineTransform?) {
        guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first else { return (nil,nil) }
        let size = track.naturalSize.applying(track.preferredTransform)
        print(track.preferredTransform)
        return (CGSize(width: abs(size.width), height: abs(size.height)),track.preferredTransform)
    }
    
    //MARK: - Gesture Controll
    
    var lastGestureScale:Float = 1
    
    @objc func scenePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let logation = recognizer.location(in: sceneView)
            let hitResults = sceneView.hitTest(logation, options: [SCNHitTestOption.ignoreHiddenNodes:true])
            if hitResults.count > 0 {
                guard let node = hitResults.first?.node else {return}
                materialNode = node
            }
            lastGestureScale = 1
        case .changed:
            let newGestureScale: Float = Float(recognizer.scale)
            
            // ここで直前のscaleとのdiffぶんだけ取得しときます
            let diff = newGestureScale - lastGestureScale
            
            let currentScale = materialNode.scale
            
            // diff分だけscaleを変化させる。1は1倍、1.2は1.2倍の大きさになります。
            materialNode.scale = SCNVector3Make(
                currentScale.x * (1 + diff),
                currentScale.y * (1 + diff),
                currentScale.z * (1 + diff)
            )
            // 保存しとく
            lastGestureScale = newGestureScale
        default :break
        }
    }
    
    var lastTranslation = CGPoint(x: 0,y: 0)
    @objc func longTap(_ gestureRecognize: UILongPressGestureRecognizer){
        let p = gestureRecognize.location(in: sceneView)
        let hitResults = sceneView.hitTest(p, options: [SCNHitTestOption.ignoreHiddenNodes:true])
        if hitResults.count > 0 {
            var result = hitResults[0].node
            if contentNodes.contains(result) {
                if result.geometry?.firstMaterial?.transparency == 0 {
                    if hitResults.count > 1 {
                        result = hitResults[1].node
                        result.removeFromParentNode()
                    }
                } else {
                    contentNodes.first(where: {$0 == result})?.geometry?.firstMaterial?.transparency = 0
                }
            } else {
                result.removeFromParentNode()
            }
        }
    }
    
    @objc func doubleTapAction(_ recognizer:UITapGestureRecognizer){
        
        let p = recognizer.location(in: sceneView)
        let hitResults = sceneView.hitTest(p, options:[SCNHitTestOption.ignoreHiddenNodes:true])
        if hitResults.count > 0 {
            var result = hitResults.first!.node
            if hitResults.count > 1, contentNodes.contains(result) {
                result = hitResults[1].node
            }
            let recentPosition = result.worldPosition
            result.worldPosition = SCNVector3(x: 0, y: 0, z: recentPosition.z - 0.5)
        }
    }
    
    @objc func rotateAction(_ recognizer:UIRotationGestureRecognizer){
        let p = recognizer.location(in: sceneView)
        let hitResults = sceneView.hitTest(p, options: [SCNHitTestOption.ignoreHiddenNodes:true])
        if hitResults.count > 0 {
            var result = hitResults.first!.node
            if hitResults.count > 1, contentNodes.contains(result) {
                result = hitResults[1].node
            }
            switch recognizer.state {
            case .changed :
                print(recognizer.rotation)
                result.rotation = SCNVector4(0, 1, 0,  recognizer.rotation)
            default:break
            }
        }
    }
    
    var xPan:Float = 0
    var yPan:Float = 0
    var lastPan = CGPoint.zero
    var materialXPan:Float = 0
    var materialYPan:Float = 0
    
    @objc func scenePanGesture(_ recognizer: UIPanGestureRecognizer){
        switch recognizer.state {
        case .began:
            materialXPan = 0
            materialYPan = 0
            lastTranslation = CGPoint.zero
            let logation = recognizer.location(in: sceneView)
            let hitResults = sceneView.hitTest(logation, options: [SCNHitTestOption.ignoreHiddenNodes:true])
            if hitResults.count > 0 {
                guard let node = hitResults.first?.node else {return}
                materialNode = node
                if node == backgroundNode {
                    recognizer.setTranslation(lastPan, in: sceneView)
                }
            }
        case .changed:
            if materialNode == backgroundNode {
                if backgroundNode != nil {
                    guard let pannedView = recognizer.view as? ARSCNView else { return }
                    let translation = recognizer.translation(in: pannedView)
                    xPan = Float(translation.x * 0.01)
                    yPan = -Float(translation.y * 0.01)
                    lastPan = translation
                }
            } else {
                let newTranslation = recognizer.translation(in: sceneView)
                materialXPan = (Float(newTranslation.x) - Float(lastTranslation.x)) * -0.005
                materialYPan = (Float(newTranslation.y) - Float(lastTranslation.y)) * -0.005
                print(materialYPan)
                let nodePosition = materialNode.worldPosition
                materialNode.worldPosition = (SCNVector3(nodePosition.x - materialXPan,nodePosition.y + materialYPan, nodePosition.z))
                lastTranslation = newTranslation
            }
        default: break
        }
    }
    
    var lastRotation = 0
    @objc func swipeRotateYAxis(_ recognizer:UIPanGestureRecognizer){
        let p = recognizer.location(in: sceneView)
        let hitResults = sceneView.hitTest(p, options: [SCNHitTestOption.ignoreHiddenNodes:true])
        if hitResults.count > 0 {
            var result = hitResults.first!.node
            if hitResults.count > 1, contentNodes.contains(result) {
                result = hitResults[1].node
            }
            materialNode = result
        }
        if abs(recognizer.translation(in: sceneView).x) > abs(recognizer.translation(in: sceneView).y) {
            let newrotation = recognizer.translation(in: sceneView).x
            if recognizer.state == .began{
                lastRotation = 0
            }
            let diff = (Float(newrotation) - Float(lastRotation)) * -0.01
            let eulerY = materialNode.eulerAngles.y
            materialNode.eulerAngles.y = eulerY - diff
            lastRotation = Int(newrotation)
        } else {
            let newrotation = recognizer.translation(in: sceneView).y
            if recognizer.state == .began{
                lastRotation = 0
            }
            let diff = (Float(newrotation) - Float(lastRotation)) * -0.01
            let eulerX = materialNode.eulerAngles.x
            materialNode.eulerAngles.x = eulerX - diff
            lastRotation = Int(newrotation)
        }
    }
    
    @objc func tapSelectNode(_ recognizer:UITapGestureRecognizer){
        let hitResult =  sceneView.hitTest(recognizer.location(in: sceneView), options: [:])
        if hitResult.count > 0 {
            materialNode = hitResult.first!.node
            
        }
        //        let hitResult = sceneView.hitTest(recognizer.location(in: sceneView), types: [.estimatedHorizontalPlane])
        //        let node = SCNReferenceNode(named: "reference").childNode(withName: "dog", recursively: false)
        //        let box = SCNBox()
        //        box.firstMaterial?.diffuse.contents = UIColor.systemPink
        //        node.geometry = box
        //        node!.scale = SCNVector3(0.1, 0.1, 0.1)
        //        guard let column3: simd_float4 = hitResult.first?.worldTransform.columns.3 else { return}
        //        let position = SCNVector3(column3.x, column3.y, column3.z)
        //        node!.position = position
        //        sceneView.scene.rootNode.addChildNode(node!)
    }
    
    private func position()->SCNVector3 {
        let cameraPosition = sceneView.pointOfView?.scale
        let position = SCNVector3(cameraPosition!.x, cameraPosition!.y, cameraPosition!.z - 10)
        print(position)
        return position
    }
    
    private func imagePick(){
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        imagePicker.mediaTypes = ["public.movie","public.image"]
        self.present(imagePicker,animated: true)
    }
    
    @objc func MultiCamSegue(){
        sceneView.session.pause()
        performSegue(withIdentifier: "MultiCam", sender: nil)
    }
    
    @objc func textureButton(){
        if isOcclusion{ sematicsSwitchMode()}
        pressed = .texture
        imagePick()
    }
    
    @objc func materialAdd(){
        if UIDevice.current.userInterfaceIdiom != .pad {
            let alert = UIAlertController(title: NSLocalizedString("マテリアル",value: "えらんでください", comment: ""), message: NSLocalizedString("はりつけるかたち", comment: ""), preferredStyle: .actionSheet)
            alert.addActions(actions: [
                UIAlertAction(title: NSLocalizedString("はこ", comment: "はこ"), style: .default, handler: { _ in
                    self.materialType = .box
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("たま", comment: "たま"), style: .default, handler: { _ in
                    self.materialType = .sphere
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("いた", comment: "いた"), style: .default, handler: { _ in
                    self.materialType = .plane
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("はいけい", comment: "はいけい"), style: .default, handler: { _ in
                    if !self.isOcclusion{ self.sematicsSwitchMode()}
                    self.pressed = .back
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("うごくはこ", comment: "うごくはこ"), style: .default, handler: { _ in
                    self.materialType = .movingBox
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("うごくたま", comment: "うごくたま"), style: .default, handler: { _ in
                    self.materialType = .movingSphere
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("うごくいた", comment: "うごくいた"), style: .default, handler: { _ in
                    self.materialType = .movingPlane
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("もじ", comment: "もじ"), style: .default, handler: { _ in
                    self.materialType = .text
                    self.pressed = .material
                    self.textField = UITextField(frame: CGRect(x: 0, y: self.view.center.y - 100, width: self.view.bounds.width, height: 200))
                    self.textField.delegate = self
                    
                    self.textField.placeholder =  NSLocalizedString("入力してください。", comment: "入力してください。")
                    self.textField.keyboardType = .default
                    self.textField.returnKeyType = .done
                    self.textField.clearButtonMode = .always
                    self.textField.textAlignment = .center
                    self.textField.borderStyle = .roundedRect
                    
                    self.view.addSubview(self.textField)
                    self.view.bringSubviewToFront(self.textField)
                }),
                UIAlertAction(title: NSLocalizedString("スピーチ", comment: "スピーチ"), style: .default, handler: { _ in
                    self.speechMode = .horizontal
                    if self.audioEngine == nil{
                        self.speech()
                    }
                }),
                UIAlertAction(title: NSLocalizedString("スピーチ（たくさん）", comment: "スピーチ"), style: .default, handler: { _ in
                    self.speechMode = .rain
                    if self.audioEngine == nil{
                        self.speech()
                    }
                }),
                UIAlertAction(title: NSLocalizedString("いぬ", comment: "いぬ"), style: .default, handler: { _ in
                    self.creatureName = "dog"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ねこ", comment: "ねこ"), style: .default, handler: { _ in
                    self.creatureName = "cat"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ひよこ", comment: "ひよこ"), style: .default, handler: { _ in
                    self.creatureName = "chick"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("りす", comment: "りす"), style: .default, handler: { _ in
                    self.creatureName = "squirrel"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ペンギン", comment: "ペンギン"), style: .default, handler: { _ in
                    self.creatureName = "penguin"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("うさぎ", comment: "うさぎ"), style: .default, handler: { _ in
                    self.creatureName = "rabbit"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("かわうそ", comment: "かわうそ"), style: .default, handler: { _ in
                    self.creatureName = "otter"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("きつね", comment: "きつね"), style: .default, handler: { _ in
                    self.creatureName = "fox"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ミーアキャット", comment: "ミーアキャット"), style: .default, handler: { _ in
                    self.creatureName = "miacat"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ひと", comment: "ひと"), style: .default, handler: { _ in
                    self.creatureName = "girl"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("キャンセル", comment: "キャンセル"), style: .cancel, handler: nil)
                ]
            )
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = self.view.bounds
            alert.popoverPresentationController?.permittedArrowDirections = []
            self.present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: NSLocalizedString("マテリアル",value: "えらんでください", comment: ""), message: "はりつけるかたち", preferredStyle: .actionSheet)
            alert.addActions(actions: [
                UIAlertAction(title: NSLocalizedString("はこ", comment: "はこ"), style: .default, handler: { _ in
                    self.materialType = .box
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("たま", comment: "たま"), style: .default, handler: { _ in
                    self.materialType = .sphere
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("いた", comment: "いた"), style: .default, handler: { _ in
                    self.materialType = .plane
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("はいけい", comment: "はいけい"), style: .default, handler: { _ in
                    if !self.isOcclusion{ self.sematicsSwitchMode()}
                    self.pressed = .back
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("うごくはこ", comment: "うごくはこ"), style: .default, handler: { _ in
                    self.materialType = .movingBox
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("うごくたま", comment: "うごくたま"), style: .default, handler: { _ in
                    self.materialType = .movingSphere
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("うごくいた", comment: "うごくいた"), style: .default, handler: { _ in
                    self.materialType = .movingPlane
                    self.pressed = .material
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("もじ", comment: "もじ"), style: .default, handler: { _ in
                    self.materialType = .text
                    self.pressed = .material
                    self.textField = UITextField(frame: CGRect(x: 0, y: self.view.center.y - 100, width: self.view.bounds.width, height: 200))
                    self.textField.delegate = self
                    self.textField.placeholder = "入力してください。"
                    self.textField.keyboardType = .default
                    self.textField.returnKeyType = .default
                    self.textField.clearButtonMode = .always
                    self.textField.textAlignment = .center
                    self.textField.borderStyle = .roundedRect
                    self.view.addSubview(self.textField)
                    self.view.bringSubviewToFront(self.textField)
                    
                }),
                UIAlertAction(title: NSLocalizedString("スピーチ", comment: "スピーチ"), style: .default, handler: { _ in
                    self.speechMode = .horizontal
                    if self.audioEngine == nil{
                        self.speech()
                    }
                }),
                UIAlertAction(title: NSLocalizedString("スピーチ（たくさん）", comment: "スピーチ"), style: .default, handler: { _ in
                    self.speechMode = .rain
                    if self.audioEngine == nil{
                        self.speech()
                    }
                }),
                UIAlertAction(title: NSLocalizedString("いぬ", comment: "いぬ"), style: .default, handler: { _ in
                    self.creatureName = "dog"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ねこ", comment: "ねこ"), style: .default, handler: { _ in
                    self.creatureName = "cat"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ひよこ", comment: "ひよこ"), style: .default, handler: { _ in
                    self.creatureName = "chick"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("りす", comment: "りす"), style: .default, handler: { _ in
                    self.creatureName = "squirrel"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ペンギン", comment: "ペンギン"), style: .default, handler: { _ in
                    self.creatureName = "penguin"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("うさぎ", comment: "うさぎ"), style: .default, handler: { _ in
                    self.creatureName = "rabbit"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("かわうそ", comment: "かわうそ"), style: .default, handler: { _ in
                    self.creatureName = "otter"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("きつね", comment: "きつね"), style: .default, handler: { _ in
                    self.creatureName = "fox"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ミーアキャット", comment: "ミーアキャット"), style: .default, handler: { _ in
                    self.creatureName = "miacat"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ひと", comment: "ひと"), style: .default, handler: { _ in
                    self.creatureName = "girl"
                    self.pressed = .occlussion
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("キャンセル", comment: "キャンセル"), style: .cancel, handler: nil)
                
                ]
            )
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = self.view.bounds
            alert.popoverPresentationController?.permittedArrowDirections = []
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    enum MaterialTypes {
        case box
        case sphere
        case text
        case plane
        case movingBox
        case movingSphere
        case movingPlane
    }
    
    var materialType:MaterialTypes = .box
    
    var textField = UITextField()
    
    @objc func resetTracking(){
        for node in sceneView.scene.rootNode.childNodes {
            node.removeFromParentNode()
        }
        if isFront == true {
            //Switch to Front Camera
            
            if ARFaceTrackingConfiguration.isSupported {
                let config = ARFaceTrackingConfiguration()
                
                if isOcclusion {
                    if ARFaceTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
                        config.frameSemantics.insert(.personSegmentation)
                    } else {
                        presentAlert(NSLocalizedString("この端末/OSではピープルオクルージョンを利用できません", comment: ""))
                    }
                } else {
                    if #available(iOS 12.0, *) {
                        config.maximumNumberOfTrackedFaces = 3
                        config.frameSemantics.remove(.personSegmentation)
                    }
                }
                sceneView.session.run(config, options: [.resetTracking])
                isFront = true
            } else {
                presentAlert(NSLocalizedString("Front camera is not available on this device.", comment: ""))
            }
            
        } else {
            // Switch to Back Camera
            let config = ARWorldTrackingConfiguration()
            if isOcclusion {
                if  ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
                    config.frameSemantics = .personSegmentation
                } else {
                    presentAlert(NSLocalizedString("この端末/OSではピープルオクルージョンを利用できません", comment: "") )
                }
            }
            sceneView.session.run(config, options:  [.resetTracking])
            isFront = false
        }
    }
    
    @objc func switchCamera(){
        
        if backgroundNode != nil {
            backgroundNode?.removeFromParentNode()
        }
        
        if contentNodes != [] {
            for contentNode in contentNodes {
                contentNode.removeFromParentNode()
            }
        }
        
        if isFront == false {
            // To Front
            faceTextureButton.isHidden = false
            faceTextureLabel.isHidden = false
            isFront = true
            initializeConfig()
        } else {
            // to Back
            faceTextureButton.isHidden = true
            faceTextureLabel.isHidden = true
            isFront = false
            initializeConfig()
        }
    }
    
    func presentAlert(_ title: String) {
        let alertController = UIAlertController(title: title,
                                                message: NSLocalizedString("", comment: ""),
                                                preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK",
                                     style: .default) { _ in
                                        alertController.dismiss(animated: true, completion: nil)
                                        
        }
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        DispatchQueue.main.async { [unowned previewController] in
            previewController.dismiss(animated: true, completion: nil)
        }
    }
    
    func shutter(){
        BehindLabel.isHidden = true
        BehindButton.isHidden = true
        faceTextureButton.isHidden = true
        faceTextureLabel.isHidden = true
        recordButton.isHidden = true
        AddButton.isHidden = true
        CameraButton.isHidden = true
        HelpButton.isHidden = true
        helpLabel.isHidden = true
        addLabel.isHidden = true
        cameraLabel.isHidden = true
        modeSwitchButton.isHidden = true
        backgroundView.isHidden = true
        materialButton.isHidden = true
        materialLabel.isHidden = true
        semanticsModeSwitchButton.isHidden = true
        AudioServicesPlaySystemSound(1108)
        let saveImage = view.snapshot
        UIImageWriteToSavedPhotosAlbum(saveImage!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        AddButton.isHidden = false
        CameraButton.isHidden = false
        HelpButton.isHidden = false
        recordButton.isHidden = false
        modeSwitchButton.isHidden = false
        addLabel.isHidden = false
        cameraLabel.isHidden = false
        modeSwitchButton.isHidden = false
        backgroundView.isHidden = false
        materialButton.isHidden = false
        materialLabel.isHidden = false
        BehindButton.isHidden = false
        semanticsModeSwitchButton.isHidden = false
        BehindLabel.isHidden = false
        BehindButton.isHidden = false
        helpLabel.isHidden = false
        if isFront {
            faceTextureButton.isHidden = false
            faceTextureLabel.isHidden = false
        }
    }
    
    @objc func helpSegue(){
        performSegue(withIdentifier: "ShowHelp", sender: nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        } else {
            let ac = UIAlertController(title: NSLocalizedString("保存しました!",value: "保存しました!", comment: ""), message: NSLocalizedString("フォトライブラリに保存しました",value: "フォトライブラリに保存しました", comment: ""), preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
    }
    
    func imageRotatedByDegrees(oldImage: UIImage, deg degrees: CGFloat) -> UIImage {
        //Calculate the size of the rotated view's containing box for our drawing space
        if degrees == 90 {
            let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: oldImage.size.height, height: oldImage.size.width))
            let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
            rotatedViewBox.transform = t
            let rotatedSize: CGSize = rotatedViewBox.frame.size
            //Create the bitmap context
            UIGraphicsBeginImageContext(rotatedSize)
            let bitmap: CGContext = UIGraphicsGetCurrentContext()!
            //Move the origin to the middle of the image so we will rotate and scale around the center.
            bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            //Rotate the image context
            bitmap.rotate(by: (degrees * CGFloat.pi / 180))
            //Now, draw the rotated/scaled image into the context
            bitmap.scaleBy(x: 1.0, y: -1.0)
            bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.height / 2, y: -oldImage.size.width / 2, width: oldImage.size.height, height: oldImage.size.width))
            let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return newImage
        } else {
            let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: oldImage.size.width, height: oldImage.size.height))
            let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
            rotatedViewBox.transform = t
            let rotatedSize: CGSize = rotatedViewBox.frame.size
            //Create the bitmap context
            UIGraphicsBeginImageContext(rotatedSize)
            let bitmap: CGContext = UIGraphicsGetCurrentContext()!
            //Move the origin to the middle of the image so we will rotate and scale around the center.
            bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            //Rotate the image context
            bitmap.rotate(by: (degrees * CGFloat.pi / 180))
            //Now, draw the rotated/scaled image into the context
            bitmap.scaleBy(x: 1.0, y: -1.0)
            bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.width / 2, y: -oldImage.size.height / 2, width: oldImage.size.width, height: oldImage.size.height))
            let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return newImage
        }
    }
    
    @objc func switchModeSwipeLeft(){
        if !isPhoto{
            switchMode()
        }
    }
    
    @objc func switchModeSwipeRight(){
        if isPhoto{
            switchMode()
        }
    }
    
    @objc func switchMode(){
        isPhoto.toggle()
        if !isPhoto{
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.2, delay: 0, options: [], animations: {
                let modeSwitchButtonWidth = self.modeSwitchButton.bounds.width * 0.33
                let modeSwitchButtonHeight = self.modeSwitchButton.bounds.height
                
                self.videoModeLabel.frame = CGRect(x: (self.modeSwitchButton.bounds.width * 0.5) - (modeSwitchButtonWidth * 0.5), y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
                self.photoModeLabel.frame = CGRect(x: (self.modeSwitchButton.bounds.width * 0.5) + (modeSwitchButtonWidth * 0.5), y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
            },completion: { comp in
                self.videoModeLabel.textColor = UIColor.white
                self.photoModeLabel.textColor = UIColor.darkGray
                self.recordingAnimationButton.layer.backgroundColor = UIColor.white.cgColor
            })
        } else {
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.2, delay: 0, options: [], animations: {
                let modeSwitchButtonWidth = self.modeSwitchButton.bounds.width * 0.33
                let modeSwitchButtonHeight = self.modeSwitchButton.bounds.height
                
                self.videoModeLabel.frame = CGRect(x: 0, y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
                self.photoModeLabel.frame = CGRect(x: (self.modeSwitchButton.bounds.width * 0.5) - (modeSwitchButtonWidth * 0.5), y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
            },completion: { comp in
                self.videoModeLabel.textColor = UIColor.darkGray
                self.photoModeLabel.textColor = UIColor.white
                self.recordingAnimationButton.layer.backgroundColor = UIColor.darkGray.cgColor
            })
        }
    }
    
    @objc func semanticsSwitchModeSwipeLeft(){
        if !isOcclusion{
            sematicsSwitchMode()
        }
    }
    
    @objc func sematicsSwitchModeSwipeRight(){
        if isOcclusion{
            sematicsSwitchMode()
        }
    }
    
    @objc func sematicsSwitchMode(){
        isOcclusion.toggle()
        initializeConfig()
        if !isOcclusion{
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.2, delay: 0, options: [], animations: {
                let modeSwitchButtonWidth = self.semanticsModeSwitchButton.bounds.width * 0.33
                let modeSwitchButtonHeight = self.semanticsModeSwitchButton.bounds.height
                
                self.frontModeLabel.frame = CGRect(x: (self.semanticsModeSwitchButton.bounds.width * 0.5) - (modeSwitchButtonWidth * 0.5), y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
                self.behindModeLabel.frame = CGRect(x: (self.semanticsModeSwitchButton.bounds.width * 0.5) + (modeSwitchButtonWidth * 0.5), y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
            },completion: { comp in
                self.frontModeLabel.textColor = UIColor.white
                self.behindModeLabel.textColor = UIColor.darkGray
            })
        } else {
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.2, delay: 0, options: [], animations: {
                let modeSwitchButtonWidth = self.modeSwitchButton.bounds.width * 0.33
                let modeSwitchButtonHeight = self.modeSwitchButton.bounds.height
                
                self.frontModeLabel.frame = CGRect(x: 0, y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
                self.behindModeLabel.frame = CGRect(x: (self.semanticsModeSwitchButton.bounds.width * 0.5) - (modeSwitchButtonWidth * 0.5), y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
            },completion: { comp in
                self.frontModeLabel.textColor = UIColor.darkGray
                self.behindModeLabel.textColor = UIColor.white
            })
        }
    }
    
    //MARK: - Buttons
    var AddButton = UIImageView()
    var CameraButton = UIImageView()
    var HelpButton = UIImageView()
    var faceTextureButton = UIImageView()
    var faceTextureLabel = UILabel()
    var materialButton = UIImageView()
    var materialLabel = UILabel()
    var BehindButton = UIImageView()
    var BehindLabel = UILabel()
    
    var recordButton = UILabel()
    var recordingAnimationButton = UILabel()
    var backgroundView = UIView()
    var helpLabel = UILabel()
    var addLabel = UILabel()
    var cameraLabel = UILabel()
    var modeSwitch = [NSLocalizedString("video", comment: ""),NSLocalizedString("photo", comment: "")]
    var modeSwitchButton = UIView()
    var videoModeLabel = UILabel()
    var photoModeLabel = UILabel()
    var isPhoto = false
    var semanticsModeSwitch = [NSLocalizedString("front", comment: ""),NSLocalizedString("behind", comment: "")]
    var semanticsModeSwitchButton = UIView()
    var frontModeLabel = UILabel()
    var behindModeLabel = UILabel()
    var isOcclusion = false
    
    var hasPinchSuggested = false
    
    //    MARK: - Button Settings
    
    private func buttonSetting() {
        if view.bounds.width > view.bounds.height {
            backgroundView.frame = CGRect(x: view.bounds.maxX - (view.bounds.width * 0.25), y: 0, width: view.bounds.width  * 0.25, height: view.bounds.height)
            let buttonHeight = backgroundView.bounds.width * 0.33
            if !isRecording {
                recordButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.8) , y: backgroundView.center.y - (buttonHeight * 0.5), width: buttonHeight, height: buttonHeight)
                recordingAnimationButton.frame = CGRect(x: buttonHeight * 0.05, y: buttonHeight * 0.05, width: buttonHeight * 0.9, height: buttonHeight * 0.9)
                
            } else {
                recordButton.frame = CGRect(x: self.view.bounds.maxX - buttonHeight , y: self.view.bounds.maxY - buttonHeight, width: buttonHeight * 0.75, height: buttonHeight * 0.3)
            }
            
            BehindButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.8) , y: backgroundView.center.y + (buttonHeight * 2), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            helpLabel.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.2), y: backgroundView.center.y + (buttonHeight * 2), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            AddButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.8), y: backgroundView.center.y + (buttonHeight * 1.0), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            faceTextureButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.8), y: backgroundView.center.y - (buttonHeight * 1.5), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            faceTextureLabel.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.2) , y: backgroundView.center.y - (buttonHeight * 1.5), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            CameraButton.frame =  CGRect(x: backgroundView.center.x + (buttonHeight * 0.2), y: backgroundView.center.y - (buttonHeight * 2.5), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            HelpButton.frame =  CGRect(x: backgroundView.center.x + (buttonHeight * 0.2), y: backgroundView.center.y + (buttonHeight * 2.0), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            addLabel.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.2) , y: backgroundView.center.y + (buttonHeight * 1.0), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            materialButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.8) , y: backgroundView.center.y - (buttonHeight * 2.5), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            materialLabel.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.2), y: backgroundView.center.y - (buttonHeight * 2.5), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            
            modeSwitchButton.frame = CGRect(x: backgroundView.frame.origin.x, y: backgroundView.center.y - (buttonHeight * 1.0), width: buttonHeight * 2.5, height: buttonHeight * 0.5)
            semanticsModeSwitchButton.frame = CGRect(x: backgroundView.frame.origin.x, y: backgroundView.center.y + (buttonHeight * 0.5), width: buttonHeight * 2.5, height: buttonHeight * 0.5)
            recordButton.layer.cornerRadius = min(recordButton.frame.width, recordButton.frame.height) * 0.5
            recordingAnimationButton.layer.cornerRadius = min(recordingAnimationButton.frame.width, recordingAnimationButton.frame.height) * 0.5
            
            cameraLabel.isHidden = true
            addLabel.isHidden = true
            faceTextureLabel.isHidden = true
            helpLabel.isHidden = true
            BehindLabel.isHidden = true
            materialLabel.isHidden = true
        } else {
            if !isRecording{
                cameraLabel.isHidden = false
                addLabel.isHidden = false
                if isFront {
                    faceTextureLabel.isHidden = false
                }
                helpLabel.isHidden = false
                BehindLabel.isHidden = false
                materialLabel.isHidden = false
            }
            backgroundView.frame = CGRect(x: 0, y: view.bounds.maxY - (view.bounds.height * 0.25), width: view.bounds.width, height: view.bounds.height * 0.25)
            let buttonHeight = backgroundView.bounds.height * 0.33
            if !isRecording {
                recordButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 0.5), y: backgroundView.center.y - (buttonHeight * 0.8), width: buttonHeight, height: buttonHeight)
                recordingAnimationButton.frame = CGRect(x: buttonHeight * 0.05, y: buttonHeight * 0.05, width: buttonHeight * 0.9, height: buttonHeight * 0.9)
            } else {
                recordButton.frame = CGRect(x: self.view.bounds.maxX - buttonHeight , y: self.view.bounds.maxY - buttonHeight, width: buttonHeight * 0.75, height: buttonHeight * 0.3)
            }
            BehindButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 2.5), y: backgroundView.center.y - (buttonHeight * 0.8), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            BehindLabel.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 2.5), y: backgroundView.center.y - (buttonHeight * 0.3) , width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            AddButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 1.5), y: backgroundView.center.y - (buttonHeight * 0.8), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            faceTextureButton.frame = CGRect(x: backgroundView.center.x + (buttonHeight * 1.0), y: backgroundView.center.y - (buttonHeight * 0.8), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            faceTextureLabel.frame = CGRect(x: backgroundView.center.x + (buttonHeight * 1.0), y: backgroundView.center.y - (buttonHeight * 0.3) , width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            CameraButton.frame = CGRect(x: backgroundView.center.x + (buttonHeight * 2.0), y: backgroundView.center.y + (buttonHeight * 0.3), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            cameraLabel.frame = CGRect(x: backgroundView.center.x + (buttonHeight * 2.0), y: backgroundView.center.y + (buttonHeight * 0.8) , width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            HelpButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 2.5), y: backgroundView.center.y + (buttonHeight * 0.3), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            helpLabel.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 2.5), y: backgroundView.center.y + (buttonHeight * 0.8) , width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            addLabel.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 1.5), y: backgroundView.center.y - (buttonHeight * 0.3) , width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            
            materialButton.frame = CGRect(x: backgroundView.center.x + (buttonHeight * 2), y: backgroundView.center.y - (buttonHeight * 0.8), width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            materialLabel.frame = CGRect(x: backgroundView.center.x + (buttonHeight * 2), y: backgroundView.center.y - (buttonHeight * 0.3) , width: buttonHeight * 0.5, height: buttonHeight * 0.5)
            
            modeSwitchButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 1.5), y: backgroundView.frame.origin.y, width: buttonHeight * 3, height: buttonHeight * 0.5)
            semanticsModeSwitchButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 1.5), y: backgroundView.frame.maxY - buttonHeight , width: buttonHeight * 3, height: buttonHeight * 0.5)
        }
        
        let modeSwitchButtonWidth = modeSwitchButton.bounds.width * 0.33
        let modeSwitchButtonHeight = modeSwitchButton.bounds.height
        let semanticsModeSwitchButtonWidth = modeSwitchButton.bounds.width * 0.33
        let semanticsModeSwitchButtonHeight = modeSwitchButton.bounds.height
        
        videoModeLabel.frame = CGRect(x: (modeSwitchButton.bounds.width * 0.5) - (modeSwitchButtonWidth * 0.5), y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
        photoModeLabel.frame = CGRect(x: (modeSwitchButton.bounds.width * 0.5) + (modeSwitchButtonWidth * 0.5), y: 0, width: modeSwitchButtonWidth, height: modeSwitchButtonHeight)
        frontModeLabel.frame = CGRect(x: (semanticsModeSwitchButton.bounds.width * 0.5) - (semanticsModeSwitchButtonWidth * 0.5), y: 0, width: semanticsModeSwitchButtonWidth, height: semanticsModeSwitchButtonHeight)
        behindModeLabel.frame = CGRect(x: (semanticsModeSwitchButton.bounds.width * 0.5) + (semanticsModeSwitchButtonWidth * 0.5), y: 0, width: semanticsModeSwitchButtonWidth, height: semanticsModeSwitchButtonHeight)
        recordButton.layer.cornerRadius = min(recordButton.frame.width, recordButton.frame.height) * 0.5
        recordingAnimationButton.layer.cornerRadius = min(recordingAnimationButton.frame.width, recordingAnimationButton.frame.height) * 0.5
    }
    
    private func buttonAdding(){
        CameraButton.image = UIImage(systemName: "camera.rotate")
        AddButton.image = UIImage(systemName: "camera.on.rectangle")
        HelpButton.image = UIImage(systemName: "questionmark.circle")
        faceTextureButton.image = UIImage(systemName: "smiley")
        materialButton.image = UIImage(systemName: "cube")
        BehindButton.image = UIImage(systemName: "memories")
        cameraLabel.text = NSLocalizedString("Switch", comment: "")
        addLabel.text = NSLocalizedString("Multi>>", comment: "")
        helpLabel.text = NSLocalizedString("Help", comment: "")
        faceTextureLabel.text =  NSLocalizedString("Texture", comment: "")
        materialLabel.text = NSLocalizedString("Material", comment: "")
        BehindLabel.text = NSLocalizedString("Reset", comment: "")
        
        videoModeLabel.text = NSLocalizedString("Video", comment: "")
        photoModeLabel.text = NSLocalizedString("Photo", comment: "")
        videoModeLabel.textColor = UIColor.white
        photoModeLabel.textColor = UIColor.darkGray
        frontModeLabel.text = NSLocalizedString("Front", comment: "")
        behindModeLabel.text = NSLocalizedString("Behind", comment: "")
        frontModeLabel.textColor = UIColor.white
        behindModeLabel.textColor = UIColor.darkGray
        
        HelpButton.tintColor = UIColor.darkGray
        AddButton.tintColor = UIColor.darkGray
        CameraButton.tintColor = UIColor.darkGray
        faceTextureButton.tintColor = UIColor.darkGray
        materialButton.tintColor = UIColor.darkGray
        BehindButton.tintColor = UIColor.darkGray
        helpLabel.textColor = UIColor.darkGray
        addLabel.textColor = UIColor.darkGray
        cameraLabel.textColor = UIColor.darkGray
        faceTextureLabel.textColor = UIColor.darkGray
        materialLabel.textColor = UIColor.darkGray
        BehindLabel.textColor = UIColor.darkGray
        
        helpLabel.textAlignment = .center
        addLabel.textAlignment = .center
        cameraLabel.textAlignment = .center
        faceTextureLabel.textAlignment = .center
        materialLabel.textAlignment = .center
        BehindLabel.textAlignment = .center
        videoModeLabel.textAlignment = .center
        photoModeLabel.textAlignment = .center
        frontModeLabel.textAlignment = .center
        behindModeLabel.textAlignment = .center
        helpLabel.adjustsFontSizeToFitWidth = true
        addLabel.adjustsFontSizeToFitWidth = true
        cameraLabel.adjustsFontSizeToFitWidth = true
        faceTextureLabel.adjustsFontSizeToFitWidth = true
        materialLabel.adjustsFontSizeToFitWidth = true
        BehindLabel.adjustsFontSizeToFitWidth = true
        videoModeLabel.adjustsFontSizeToFitWidth = true
        photoModeLabel.adjustsFontSizeToFitWidth = true
        frontModeLabel.adjustsFontSizeToFitWidth = true
        behindModeLabel.adjustsFontSizeToFitWidth = true
        recordButton.layer.backgroundColor = UIColor.clear.cgColor
        recordButton.layer.borderColor = UIColor.white.cgColor
        recordButton.layer.borderWidth = 4
        recordButton.clipsToBounds = true
        recordButton.layer.cornerRadius = min(recordButton.frame.width, recordButton.frame.height) * 0.5
        recordingAnimationButton.layer.cornerRadius = min(recordingAnimationButton.frame.width, recordingAnimationButton.frame.height) * 0.5
        
        recordingAnimationButton.layer.backgroundColor = UIColor.white.cgColor
        recordingAnimationButton.clipsToBounds = true
        recordingAnimationButton.layer.cornerRadius = min(recordingAnimationButton.frame.width, recordingAnimationButton.frame.height) * 0.5
        recordingAnimationButton.layer.borderWidth = 2
        recordingAnimationButton.layer.borderColor = UIColor.darkGray.cgColor
        backgroundView.backgroundColor = UIColor.white
        backgroundView.alpha = 0.5
        
        let symbolConfig = UIImage.SymbolConfiguration(weight: .thin)
        
        CameraButton.preferredSymbolConfiguration = symbolConfig
        CameraButton.contentMode = .scaleAspectFill
        HelpButton.preferredSymbolConfiguration = symbolConfig
        HelpButton.contentMode = .scaleAspectFill
        AddButton.preferredSymbolConfiguration = symbolConfig
        AddButton.contentMode = .scaleAspectFill
        faceTextureButton.preferredSymbolConfiguration = symbolConfig
        faceTextureButton.contentMode = .scaleAspectFill
        materialButton.preferredSymbolConfiguration = symbolConfig
        materialButton.contentMode = .scaleAspectFill
        BehindButton.preferredSymbolConfiguration = symbolConfig
        BehindButton.contentMode = .scaleAspectFill
        view.addSubview(backgroundView)
        view.addSubview(AddButton)
        view.addSubview(CameraButton)
        view.addSubview(HelpButton)
        view.addSubview(faceTextureButton)
        view.addSubview(materialButton)
        view.addSubview(faceTextureLabel)
        view.addSubview(BehindButton)
        view.addSubview(BehindLabel)
        view.addSubview(materialLabel)
        view.addSubview(helpLabel)
        view.addSubview(addLabel)
        view.addSubview(cameraLabel)
        
        view.addSubview(modeSwitchButton)
        view.addSubview(semanticsModeSwitchButton)
        
        view.bringSubviewToFront(modeSwitchButton)
        view.bringSubviewToFront(semanticsModeSwitchButton)
        
        view.bringSubviewToFront(HelpButton)
        view.bringSubviewToFront(AddButton)
        view.bringSubviewToFront(CameraButton)
        view.bringSubviewToFront(faceTextureButton)
        view.bringSubviewToFront(helpLabel)
        view.bringSubviewToFront(addLabel)
        view.bringSubviewToFront(cameraLabel)
        view.bringSubviewToFront(faceTextureLabel)
        view.bringSubviewToFront(materialButton)
        view.bringSubviewToFront(materialLabel)
        view.bringSubviewToFront(BehindButton)
        view.bringSubviewToFront(BehindLabel)
        modeSwitchButton.addSubview(videoModeLabel)
        modeSwitchButton.addSubview(photoModeLabel)
        semanticsModeSwitchButton.addSubview(frontModeLabel)
        semanticsModeSwitchButton.addSubview(behindModeLabel)
        view.addSubview(recordButton)
        view.bringSubviewToFront(recordButton)
        recordButton.addSubview(recordingAnimationButton)
        
        recordButton.isUserInteractionEnabled = true
        recordingAnimationButton.isUserInteractionEnabled = true
        AddButton.isUserInteractionEnabled = true
        HelpButton.isUserInteractionEnabled = true
        CameraButton.isUserInteractionEnabled = true
        faceTextureButton.isUserInteractionEnabled = true
        faceTextureLabel.isUserInteractionEnabled = true
        materialButton.isUserInteractionEnabled = true
        materialLabel.isUserInteractionEnabled = true
        helpLabel.isUserInteractionEnabled = true
        addLabel.isUserInteractionEnabled = true
        cameraLabel.isUserInteractionEnabled = true
        modeSwitchButton.isUserInteractionEnabled = true
        semanticsModeSwitchButton.isUserInteractionEnabled = true
        
        BehindLabel.isUserInteractionEnabled = true
        BehindButton.isUserInteractionEnabled = true
        
        let behindAddGesture = UITapGestureRecognizer(target: self, action: #selector(resetTracking))
        let behindAddGesture4Label = UITapGestureRecognizer(target: self, action: #selector(resetTracking))
        BehindButton.addGestureRecognizer(behindAddGesture)
        BehindLabel.addGestureRecognizer(behindAddGesture4Label)
        
        let materialAddGesture = UITapGestureRecognizer(target: self, action: #selector(materialAdd))
        let materialAddGesture4Label = UITapGestureRecognizer(target: self, action: #selector(materialAdd))
        materialButton.addGestureRecognizer(materialAddGesture)
        materialLabel.addGestureRecognizer(materialAddGesture4Label)
        
        let addGesture = UITapGestureRecognizer(target: self, action: #selector(MultiCamSegue))
        let addGesture4Label = UITapGestureRecognizer(target: self, action: #selector(MultiCamSegue))
        AddButton.addGestureRecognizer(addGesture)
        addLabel.addGestureRecognizer(addGesture4Label)
        
        let textureGesture = UITapGestureRecognizer(target: self, action: #selector(textureButton))
        let textureGesture4Label = UITapGestureRecognizer(target: self, action: #selector(textureButton))
        faceTextureButton.addGestureRecognizer(textureGesture)
        faceTextureLabel.addGestureRecognizer(textureGesture4Label)
        
        let helpTap = UITapGestureRecognizer(target: self, action: #selector(helpSegue))
        let helpTap4Label = UITapGestureRecognizer(target: self, action: #selector(helpSegue))
        
        HelpButton.addGestureRecognizer(helpTap)
        helpLabel.addGestureRecognizer(helpTap4Label)
        
        let cameraTap = UITapGestureRecognizer(target: self, action: #selector(switchCamera))
        let cameraTap4Label = UITapGestureRecognizer(target: self, action: #selector(switchCamera))
        
        CameraButton.addGestureRecognizer(cameraTap)
        cameraLabel.addGestureRecognizer(cameraTap4Label)
        
        let modeSwitchTap = UITapGestureRecognizer(target: self, action: #selector(switchMode))
        modeSwitchButton.addGestureRecognizer(modeSwitchTap)
        let sematicsModeSwitchTap = UITapGestureRecognizer(target: self, action: #selector(sematicsSwitchMode))
        semanticsModeSwitchButton.addGestureRecognizer(sematicsModeSwitchTap)
        
        let modeSwitchSwipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(switchModeSwipeLeft))
        modeSwitchSwipeLeft.direction = .left
        let modeSwitchSwipeRight = UISwipeGestureRecognizer(target: self, action: #selector(switchModeSwipeRight))
        modeSwitchSwipeRight.direction = .right
        modeSwitchButton.addGestureRecognizer(modeSwitchSwipeLeft)
        modeSwitchButton.addGestureRecognizer(modeSwitchSwipeRight)
        let sematicsModeSwitchSwipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(semanticsSwitchModeSwipeLeft))
        sematicsModeSwitchSwipeLeft.direction = .left
        let sematicsModeSwitchSwipeRight = UISwipeGestureRecognizer(target: self, action: #selector(sematicsSwitchModeSwipeRight))
        sematicsModeSwitchSwipeRight.direction = .right
        modeSwitchButton.addGestureRecognizer(modeSwitchSwipeLeft)
        modeSwitchButton.addGestureRecognizer(modeSwitchSwipeRight)
        semanticsModeSwitchButton.addGestureRecognizer(sematicsModeSwitchSwipeLeft)
        semanticsModeSwitchButton.addGestureRecognizer(sematicsModeSwitchSwipeRight)
        
        let recordTap = UITapGestureRecognizer(target: self, action: #selector(tapRecordButton))
        recordButton.addGestureRecognizer(recordTap)
        let recordTap4Label = UITapGestureRecognizer(target: self, action: #selector(tapRecordButton))
        recordingAnimationButton.addGestureRecognizer(recordTap4Label)
        
        let longtap = UILongPressGestureRecognizer(target: self, action: #selector(longTap(_:)))
        longtap.minimumPressDuration = 1
        view.addGestureRecognizer(longtap)
        
        
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(type(of: self).scenePinchGesture(_:))
        )
        
        pinch.delegate = self
        sceneView.addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(scenePanGesture))
        pan.delegate = self
        sceneView.addGestureRecognizer(pan)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapAction))
        doubleTap.delegate = self
        doubleTap.numberOfTapsRequired = 2
        sceneView.addGestureRecognizer(doubleTap)
        
        let doubleFingerPan = UIPanGestureRecognizer(target: self, action: #selector(swipeRotateYAxis(_:)))
        doubleFingerPan.minimumNumberOfTouches = 2
        doubleFingerPan.delegate = self
        sceneView.addGestureRecognizer(doubleFingerPan)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapSelectNode(_:)))
        tap.delegate = self
        sceneView.addGestureRecognizer(tap)
    }
    
    //    MARK: - Movie Rec
    
    func recordingButtonStyling(){
        let buttonHeight = recordButton.bounds.height
        var time = 0
        if !isRecording {
            if UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight {
                UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.3, delay: 0, options: [], animations: {
                    self.recordButton.layer.borderColor = UIColor.red.cgColor
                    self.recordButton.backgroundColor = UIColor.red
                    self.recordButton.layer.cornerRadius = 10
                    self.recordButton.alpha = 1
                    self.recordButton.frame = CGRect(x: self.view.bounds.maxX - buttonHeight , y: self.view.bounds.maxY - buttonHeight, width: buttonHeight * 0.75, height: buttonHeight * 0.3)
                    self.recordButton.text = "Rec"
                    self.recordButton.textAlignment = .center
                    self.recordButton.textColor = .white
                    self.recordingAnimationButton.frame = CGRect(x: buttonHeight * 0.25, y: buttonHeight * 0.25, width: buttonHeight * 0.5, height: buttonHeight * 0.5)
                    self.recordingAnimationButton.layer.backgroundColor = UIColor.white.cgColor
                    self.recordingAnimationButton.clipsToBounds = true
                    self.recordingAnimationButton.layer.cornerRadius = min(self.recordingAnimationButton.frame.width, self.recordingAnimationButton.frame.height) * 0.1
                    self.recordingAnimationButton.layer.borderColor = UIColor.red.cgColor
                    self.recordingAnimationButton.alpha = 1
                }, completion: { comp in
                    UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 1.0, delay: 1.0, options: [], animations: {
                        self.recordButton.alpha = 0.5
                        time += 1
                    },completion:  { (comp) in
                        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 1.0, delay: 1.0, options: [], animations: {
                            self.recordButton.alpha = 1
                        })
                    })
                })
            } else {
                UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.3, delay: 0, options: [], animations: {
                    self.recordButton.layer.borderColor = UIColor.red.cgColor
                    self.recordButton.backgroundColor = UIColor.red
                    self.recordButton.layer.cornerRadius = 10
                    self.recordButton.alpha = 1
                    self.recordButton.frame = CGRect(x: self.view.bounds.maxX - buttonHeight , y: self.view.bounds.maxY - buttonHeight, width: buttonHeight * 0.75, height: buttonHeight * 0.3)
                    self.recordButton.text = "Rec"
                    self.recordButton.textAlignment = .center
                    self.recordButton.textColor = .white
                    self.recordingAnimationButton.frame = CGRect(x: buttonHeight * 0.25, y: buttonHeight * 0.25, width: buttonHeight * 0.5, height: buttonHeight * 0.5)
                    self.recordingAnimationButton.layer.backgroundColor = UIColor.white.cgColor
                    self.recordingAnimationButton.clipsToBounds = true
                    self.recordingAnimationButton.layer.cornerRadius = min(self.recordingAnimationButton.frame.width, self.recordingAnimationButton.frame.height) * 0.1
                    self.recordingAnimationButton.layer.borderColor = UIColor.red.cgColor
                    self.recordingAnimationButton.alpha = 1
                }, completion: { comp in
                    UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 1.0, delay: 1.0, options: [], animations: {
                        self.recordButton.alpha = 0.5
                        time += 1
                    },completion:  { (comp) in
                        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 1.0, delay: 1.0, options: [], animations: {
                            self.recordButton.alpha = 1
                        })
                    })
                })
            }
        } else {
            if UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight {
                UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.3, delay: 0, options: [], animations: {
                    let buttonHeight = self.backgroundView.bounds.width * 0.33
                    self.recordButton.frame = CGRect(x: self.backgroundView.center.x - (buttonHeight * 0.8) , y: self.backgroundView.center.y - (buttonHeight * 0.5), width: buttonHeight, height: buttonHeight)
                    self.recordButton.alpha = 1.0
                    self.recordButton.layer.cornerRadius = min(self.recordButton.frame.width, self.recordButton.frame.height) * 0.5
                    self.recordButton.backgroundColor = UIColor.white
                    self.recordButton.layer.borderColor = UIColor.white.cgColor
                    self.recordingAnimationButton.frame = CGRect(x: buttonHeight * 0.05, y: buttonHeight * 0.05, width: buttonHeight * 0.9, height: buttonHeight * 0.9)
                    self.recordingAnimationButton.layer.backgroundColor = UIColor.white.cgColor
                    self.recordingAnimationButton.clipsToBounds = true
                    self.recordingAnimationButton.layer.cornerRadius = min(self.recordingAnimationButton.frame.width, self.recordingAnimationButton.frame.height) * 0.5
                    self.recordingAnimationButton.layer.borderColor = UIColor.darkGray.cgColor
                    self.recordingAnimationButton.alpha = 1.0
                }, completion: nil)
            } else {
                UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.3, delay: 0, options: [], animations: {
                    self.recordButton.layer.borderColor = UIColor.white.cgColor
                    let buttonHeight = self.backgroundView.bounds.height * 0.33
                    self.recordButton.frame = CGRect(x: self.backgroundView.center.x - (buttonHeight * 0.5), y: self.backgroundView.center.y - (buttonHeight * 0.8), width: buttonHeight, height: buttonHeight)
                    self.recordButton.alpha = 1.0
                    self.recordButton.layer.cornerRadius = min(self.recordButton.frame.width, self.recordButton.frame.height) * 0.5
                    self.recordButton.backgroundColor = UIColor.white
                    self.recordingAnimationButton.frame = CGRect(x: buttonHeight * 0.05, y: buttonHeight * 0.05, width: buttonHeight * 0.9, height: buttonHeight * 0.9)
                    self.recordingAnimationButton.layer.backgroundColor = UIColor.white.cgColor
                    self.recordingAnimationButton.clipsToBounds = true
                    self.recordingAnimationButton.layer.cornerRadius = min(self.recordingAnimationButton.frame.width, self.recordingAnimationButton.frame.height) * 0.5
                    self.recordingAnimationButton.layer.borderColor = UIColor.darkGray.cgColor
                    self.recordingAnimationButton.alpha = 1.0
                }, completion: nil)
            }
        }
    }
    
    func pinchSuggestAnimation(){
        
        if !hasPinchSuggested {
            let pinchSuggestLabel = UILabel()
            let pinchLabelLeft = UILabel()
            let pinchLabelRight = UILabel()
            pinchSuggestLabel.frame = CGRect(x: 0, y: view.bounds.height * 0.2, width: view.bounds.width, height: view.bounds.height * 0.1)
            pinchLabelLeft.frame = CGRect(x: view.center.x - (view.bounds.width * 0.2), y: 0, width: view.bounds.width * 0.2, height: view.bounds.height * 0.2)
            pinchLabelRight.frame = CGRect(x: view.center.x, y: 0, width: view.bounds.width * 0.2, height: view.bounds.height * 0.2)
            
            pinchSuggestLabel.textAlignment = .center
            pinchLabelLeft.textAlignment = .center
            pinchLabelRight.textAlignment = .center
            
            pinchSuggestLabel.adjustsFontSizeToFitWidth = true
            pinchLabelLeft.adjustsFontSizeToFitWidth = true
            pinchLabelRight.adjustsFontSizeToFitWidth = true
            
            pinchSuggestLabel.text = NSLocalizedString("Pinch to enlarge\nthe background", comment: "")
            pinchLabelLeft.text = NSLocalizedString("←", comment: "")
            pinchLabelRight.text = NSLocalizedString("→", comment: "")
            pinchSuggestLabel.numberOfLines = 2
            pinchSuggestLabel.textColor = UIColor.white
            pinchLabelLeft.textColor = UIColor.white
            pinchLabelRight.textColor = UIColor.white
            
            pinchSuggestLabel.font = .systemFont(ofSize: 40, weight: .heavy)
            pinchLabelLeft.font = .systemFont(ofSize: 40, weight: .heavy)
            pinchLabelRight.font = .systemFont(ofSize: 40, weight: .heavy)
            
            view.addSubview(pinchSuggestLabel)
            view.bringSubviewToFront(pinchSuggestLabel)
            view.addSubview(pinchLabelLeft)
            view.bringSubviewToFront(pinchLabelLeft)
            view.addSubview(pinchLabelRight)
            view.bringSubviewToFront(pinchLabelRight)
            
            pinchSuggestLabel.alpha = 0
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 2, delay: 0, options: [], animations: {
                pinchLabelLeft.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width * 0.2, height: self.view.bounds.height * 0.2)
                pinchLabelRight.frame = CGRect(x: self.view.bounds.maxX - (self.view.bounds.width * 0.2), y: 0, width: self.view.bounds.width * 0.2, height: self.view.bounds.height * 0.2)
                pinchSuggestLabel.alpha = 1
            },completion: { (comp) in
                UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 2, delay: 0, options: [], animations: {
                    pinchLabelLeft.alpha = 0
                    pinchLabelRight.alpha = 0
                    pinchSuggestLabel.alpha = 0
                },completion:  { (comp) in
                    pinchLabelLeft.frame = CGRect(x: self.view.center.x - (self.view.bounds.width * 0.2), y: 0, width: self.view.bounds.width * 0.2, height: self.view.bounds.height * 0.2)
                    pinchLabelRight.frame = CGRect(x: self.view.center.x, y: 0, width: self.view.bounds.width * 0.2, height: self.view.bounds.height * 0.2)
                    pinchLabelLeft.alpha = 1
                    pinchLabelRight.alpha = 1
                    pinchSuggestLabel.alpha = 1
                    UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 2, delay: 0, options: [], animations: {
                        pinchLabelLeft.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width * 0.2, height: self.view.bounds.height * 0.2)
                        pinchLabelRight.frame = CGRect(x: self.view.bounds.maxX - (self.view.bounds.width * 0.2), y: 0, width: self.view.bounds.width * 0.2, height: self.view.bounds.height * 0.2)
                    },completion:  { (comp) in
                        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 2.0, delay: 0, options: [], animations: {
                            pinchSuggestLabel.alpha = 0
                            pinchLabelLeft.alpha = 0
                            pinchLabelRight.alpha = 0
                        },completion: { comp in
                            pinchSuggestLabel.isHidden = true
                            pinchLabelLeft.isHidden = true
                            pinchLabelRight.isHidden = true
                        })
                    })
                })
            })
        }
        hasPinchSuggested = true
    }
    
    func suggestAnimation(_ text:String){
        let pinchSuggestLabel = UILabel()
        pinchSuggestLabel.frame = CGRect(x: 0, y: view.bounds.height * 0.2, width: view.bounds.width, height: view.bounds.height * 0.1)
        
        pinchSuggestLabel.textAlignment = .center
        
        pinchSuggestLabel.adjustsFontSizeToFitWidth = true
        
        pinchSuggestLabel.text = NSLocalizedString(text, comment: "")
        pinchSuggestLabel.numberOfLines = 3
        pinchSuggestLabel.textColor = UIColor.white
        pinchSuggestLabel.font = .systemFont(ofSize: 40, weight: .heavy)
        
        view.addSubview(pinchSuggestLabel)
        view.bringSubviewToFront(pinchSuggestLabel)
        
        pinchSuggestLabel.alpha = 0
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 2, delay: 0, options: [], animations: {
            pinchSuggestLabel.alpha = 1
        },completion: { (comp) in
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 2, delay: 0, options: [], animations: {
                pinchSuggestLabel.alpha = 0
            },completion:  { (comp) in
                pinchSuggestLabel.alpha = 1
                UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 2, delay: 0, options: [], animations: {
                },completion:  { (comp) in
                    UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 2.0, delay: 0, options: [], animations: {
                        pinchSuggestLabel.alpha = 0
                        
                    },completion: { comp in
                        pinchSuggestLabel.isHidden = true
                    })
                })
            })
        })
    }
    
    func moviewRecord() {
        recordingButtonStyling()
        if !isRecording {
            AudioServicesPlaySystemSound(1117)
            AddButton.isHidden = true
            CameraButton.isHidden = true
            HelpButton.isHidden = true
            modeSwitchButton.isHidden = true
            semanticsModeSwitchButton.isHidden = true
            faceTextureLabel.isHidden = true
            faceTextureButton.isHidden = true
            addLabel.isHidden = true
            helpLabel.isHidden = true
            cameraLabel.isHidden = true
            modeSwitchButton.isHidden = true
            semanticsModeSwitchButton.isHidden = true
            backgroundView.isHidden = true
            materialLabel.isHidden = true
            materialButton.isHidden = true
            behindModeLabel.isHidden = true
            BehindButton.isHidden = true
            BehindLabel.isHidden = true
            isRecording = true
            sharedRecorder.startRecording(handler: { (error) in
                if let error = error {
                    print(error)
                }
            })
        } else {
            AudioServicesPlaySystemSound(1118)
            isRecording = false
            AddButton.isHidden = false
            CameraButton.isHidden = false
            HelpButton.isHidden = false
            if isFront {
                faceTextureLabel.isHidden = false
                faceTextureButton.isHidden = false
            }
            behindModeLabel.isHidden = false
            BehindButton.isHidden = false
            modeSwitchButton.isHidden = false
            semanticsModeSwitchButton.isHidden = false
            addLabel.isHidden = false
            helpLabel.isHidden = false
            cameraLabel.isHidden = false
            modeSwitchButton.isHidden = false
            materialLabel.isHidden = false
            materialButton.isHidden = false
            backgroundView.isHidden = false
            BehindLabel.isHidden = false
            sharedRecorder.stopRecording(handler: { (previewViewController, error) in
                previewViewController?.previewControllerDelegate = self
                self.present(previewViewController!, animated: true, completion: nil)
            })
        }
    }
    
}

extension UIView {
    var snapshot: UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
        drawHierarchy(in: bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

extension SCNReferenceNode {
    convenience init(named resourceName: String, loadImmediately: Bool = true) {
        let url = Bundle.main.url(forResource: resourceName, withExtension: "scn", subdirectory: "art.scnassets")!
        self.init(url: url)!
        if loadImmediately {
            self.load()
        }
    }
}

extension UIAlertController {
    func addActions(actions: [UIAlertAction], preferred: String? = nil) {
        for action in actions {
            self.addAction(action)
            if let preferred = preferred, preferred == action.title {
                self.preferredAction = action
            }
        }
    }
}
