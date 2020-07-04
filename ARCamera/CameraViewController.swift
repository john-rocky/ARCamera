

import UIKit
import AVFoundation
import Photos
import ReplayKit
import AudioToolbox
//import WebKit
import Speech


class CameraViewController: UIViewController, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, UIGestureRecognizerDelegate, RPPreviewViewControllerDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate , UITextFieldDelegate, SFSpeechRecognizerDelegate  {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true
        sharedRecorder.isMicrophoneEnabled = true
        textField.delegate = self
        
        backCameraVideoPreviewView = PreviewView()
        frontCameraVideoPreviewView = PreviewView()
        view.addSubview(referenceView)
        view.addSubview(backCameraVideoPreviewView)
        view.addSubview(frontCameraVideoPreviewView)
        // Set up the back and front video preview views.
        backCameraVideoPreviewView.videoPreviewLayer.setSessionWithNoConnection(session)
        frontCameraVideoPreviewView.videoPreviewLayer.setSessionWithNoConnection(session)
        
        // Store the back and front video preview layers so we can connect them to their inputs
        backCameraVideoPreviewLayer = backCameraVideoPreviewView.videoPreviewLayer
        frontCameraVideoPreviewLayer = frontCameraVideoPreviewView.videoPreviewLayer
        
        // Store the location of the pip's frame in relation to the full screen video preview
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        /*
         Configure the capture session.
         In general it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't do this on the main queue, because AVCaptureMultiCamSession.startRunning()
         is a blocking call, which can take a long time. Dispatch session setup
         to the sessionQueue so as not to block the main queue, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.configureSession()
        }
        
        // Keep the screen awake
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    
    var fullRect = CGRect()
    var pipRect = CGRect()
    var referenceView = UIImageView()
    var referenceRect = CGRect.zero
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        buttonAdding()
        buttonSetting()
        print(UIDevice.current.orientation.rawValue)
        
        //To do
        AddButton.removeFromSuperview()
        addLabel.removeFromSuperview()
        CameraButton.removeFromSuperview()
        cameraLabel.removeFromSuperview()
        semanticsModeSwitchButton.removeFromSuperview()
        modeSwitchButton.removeFromSuperview()
        //
        faceTextureLabel.isHidden = true
        faceTextureButton.isHidden = true
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "\(Bundle.main.applicationName) doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: Bundle.main.applicationName, message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                                                    UIApplication.shared.open(settingsURL,
                                                                                              options: [:],
                                                                                              completionHandler: nil)
                                                                }
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: Bundle.main.applicationName, message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .multiCamNotSupported:
                DispatchQueue.main.async {
                    let alertMessage = "Alert message when multi cam is not supported"
                    let message = NSLocalizedString("Multi Cam Not Supported", comment: alertMessage)
                    let alertController = UIAlertController(title: Bundle.main.applicationName, message: message, preferredStyle: .alert)
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        print(UIDevice.current.orientation.rawValue)
        pinchSuggestAnimation()
    }
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
                if self.audioEngine?.isRunning ?? false {
                    self.audioEngine?.stop()
                    self.recognitionRequest?.endAudio()
                }
            }
        }
        super.viewWillDisappear(animated)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        print(UITraitCollection.init())
    }
    
    @objc // Expose to Objective-C for use with #selector()
    private func didEnterBackground(notification: NSNotification) {
        // Free up resources.
        dataOutputQueue.async {
        }
    }
    
    @objc // Expose to Objective-C for use with #selector()
    func willEnterForground(notification: NSNotification) {
        dataOutputQueue.async {
        }
    }
    
    // MARK: KVO and Notifications
    
    private var sessionRunningContext = 0
    
    private var keyValueObservations = [NSKeyValueObservation]()
    
    private func addObservers() {
        let keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            
            DispatchQueue.main.async {
                self.recordButton.isUserInteractionEnabled = isSessionRunning
            }
        }
        keyValueObservations.append(keyValueObservation)
        
        let systemPressureStateObservation = observe(\.self.backCameraDeviceInput?.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue as? AVCaptureDevice.SystemPressureState else { return }
            self.setRecommendedFrameRateRangeForPressureState(systemPressureState)
        }
        keyValueObservations.append(systemPressureStateObservation)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willEnterForground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        
        // A session can run only when the app is full screen. It will be interrupted in a multi-app layout.
        // Add observers to handle these session interruptions and inform the user.
        // See AVCaptureSessionWasInterruptedNotification for other interruption reasons.
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: session)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: session)
    }
    
    private func removeObservers() {
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        
        keyValueObservations.removeAll()
    }
    
    // MARK: Video Preview PiP Management
    
    // MARK: Capture Session Management
    
    //    @IBOutlet private var resumeButton: UIButton!
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
        case multiCamNotSupported
    }
    
    private let session = AVCaptureMultiCamSession()
    
    private var isSessionRunning = false
    
    private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    
    private let dataOutputQueue = DispatchQueue(label: "data output queue")
    
    private var setupResult: SessionSetupResult = .success
    
    @objc dynamic private(set) var backCameraDeviceInput: AVCaptureDeviceInput?
    
    private let backCameraVideoDataOutput = AVCaptureVideoDataOutput()
    
    private var backCameraVideoPreviewView: PreviewView!
    
    private weak var backCameraVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    private var frontCameraDeviceInput: AVCaptureDeviceInput?
    
    private let frontCameraVideoDataOutput = AVCaptureVideoDataOutput()
    
    private var frontCameraVideoPreviewView: PreviewView!
    
    private weak var frontCameraVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    private var microphoneDeviceInput: AVCaptureDeviceInput?
    
    // Must be called on the session queue
    private func configureSession() {
        guard setupResult == .success else { return }
        
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("MultiCam not supported on this device")
            setupResult = .multiCamNotSupported
            return
        }
        
        // When using AVCaptureMultiCamSession, it is best to manually add connections from AVCaptureInputs to AVCaptureOutputs
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            if setupResult == .success {
                checkSystemCost()
            }
        }
        
        guard configureBackCamera() else {
            setupResult = .configurationFailed
            return
        }
        
        guard configureFrontCamera() else {
            setupResult = .configurationFailed
            return
        }
        
    }
    
    private func configureBackCamera() -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
        // Find the back camera
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Could not find the back camera")
            return false
        }
        
        // Add the back camera input to the session
        do {
            backCameraDeviceInput = try AVCaptureDeviceInput(device: backCamera)
            
            guard let backCameraDeviceInput = backCameraDeviceInput,
                session.canAddInput(backCameraDeviceInput) else {
                    print("Could not add back camera device input")
                    return false
            }
            session.addInputWithNoConnections(backCameraDeviceInput)
        } catch {
            print("Could not create back camera device input: \(error)")
            return false
        }
        
        // Find the back camera device input's video port
        guard let backCameraDeviceInput = backCameraDeviceInput,
            let backCameraVideoPort = backCameraDeviceInput.ports(for: .video,
                                                                  sourceDeviceType: backCamera.deviceType,
                                                                  sourceDevicePosition: backCamera.position).first else {
                                                                    print("Could not find the back camera device input's video port")
                                                                    return false
        }
        // Connect the back camera device input to the back camera video preview layer
        guard let backCameraVideoPreviewLayer = backCameraVideoPreviewLayer else {
            return false
        }
        let backCameraVideoPreviewLayerConnection = AVCaptureConnection(inputPort: backCameraVideoPort, videoPreviewLayer: backCameraVideoPreviewLayer)
        guard session.canAddConnection(backCameraVideoPreviewLayerConnection) else {
            print("Could not add a connection to the back camera video preview layer")
            return false
        }
        session.addConnection(backCameraVideoPreviewLayerConnection)
        
        return true
    }
    
    private func configureFrontCamera() -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
        // Find the front camera
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Could not find the front camera")
            return false
        }
        
        // Add the front camera input to the session
        do {
            frontCameraDeviceInput = try AVCaptureDeviceInput(device: frontCamera)
            
            guard let frontCameraDeviceInput = frontCameraDeviceInput,
                session.canAddInput(frontCameraDeviceInput) else {
                    print("Could not add front camera device input")
                    return false
            }
            session.addInputWithNoConnections(frontCameraDeviceInput)
        } catch {
            print("Could not create front camera device input: \(error)")
            return false
        }
        
        // Find the front camera device input's video port
        guard let frontCameraDeviceInput = frontCameraDeviceInput,
            let frontCameraVideoPort = frontCameraDeviceInput.ports(for: .video,
                                                                    sourceDeviceType: frontCamera.deviceType,
                                                                    sourceDevicePosition: frontCamera.position).first else {
                                                                        print("Could not find the front camera device input's video port")
                                                                        return false
        }
        
        guard let frontCameraVideoPreviewLayer = frontCameraVideoPreviewLayer else {
            return false
        }
        let frontCameraVideoPreviewLayerConnection = AVCaptureConnection(inputPort: frontCameraVideoPort, videoPreviewLayer: frontCameraVideoPreviewLayer)
        guard session.canAddConnection(frontCameraVideoPreviewLayerConnection) else {
            print("Could not add a connection to the front camera video preview layer")
            return false
        }
        session.addConnection(frontCameraVideoPreviewLayerConnection)
        frontCameraVideoPreviewLayerConnection.automaticallyAdjustsVideoMirroring = false
        frontCameraVideoPreviewLayerConnection.isVideoMirrored = true
        
        return true
    }
    
    @objc // Expose to Objective-C for use with #selector()
    private func sessionWasInterrupted(notification: NSNotification) {
        // In iOS 9 and later, the userInfo dictionary contains information on why the session was interrupted.
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            let reasonIntegerValue = userInfoValue.integerValue,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted (\(reason))")
            
            if reason == .videoDeviceInUseByAnotherClient {
                // Simply fade-in a button to enable the user to try to resume the session running
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
            }
        }
    }
    
    @objc // Expose to Objective-C for use with #selector()
    private func sessionInterruptionEnded(notification: NSNotification) {
        //                if !resumeButton.isHidden {
        //                    UIView.animate(withDuration: 0.25,
        //                                   animations: {
        //                                    self.resumeButton.alpha = 0
        //                    }, completion: { _ in
        //                        self.resumeButton.isHidden = true
        //                    })
        //                }
    }
    
    @objc // Expose to Objective-C for use with #selector()
    private func sessionRuntimeError(notification: NSNotification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }
        
        let error = AVError(_nsError: errorValue)
        print("Capture session runtime error: \(error)")
        
        /*
         Automatically try to restart the session running if media services were
         reset and the last start running succeeded. Otherwise, enable the user
         to try to resume the session running.
         */
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                } else {
                    DispatchQueue.main.async {
                        //                        self.resumeButton.isHidden = false
                    }
                }
            }
        } else {
            //            resumeButton.isHidden = false
        }
    }
    //
    //    @IBAction private func resumeInterruptedSession(_ sender: UIButton) {
    //        sessionQueue.async {
    //            /*
    //             The session might fail to start running. A failure to start the session running will be communicated via
    //             a session runtime error notification. To avoid repeatedly failing to start the session
    //             running, we only try to restart the session running in the session runtime error handler
    //             if we aren't trying to resume the session running.
    //             */
    //            self.session.startRunning()
    //            self.isSessionRunning = self.session.isRunning
    //            if !self.session.isRunning {
    //                DispatchQueue.main.async {
    //                    let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
    //                    let actions = [
    //                        UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
    //                                      style: .cancel,
    //                                      handler: nil)]
    //                    self.alert(title: Bundle.main.applicationName, message: message, actions: actions)
    //                }
    //            } else {
    //                DispatchQueue.main.async {
    //                    self.resumeButton.isHidden = true
    //                }
    //            }
    //        }
    //    }
    
    func alert(title: String, message: String, actions: [UIAlertAction]) {
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        
        actions.forEach {
            alertController.addAction($0)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Session Cost Check
    
    struct ExceededCaptureSessionCosts: OptionSet {
        let rawValue: Int
        
        static let systemPressureCost = ExceededCaptureSessionCosts(rawValue: 1 << 0)
        static let hardwareCost = ExceededCaptureSessionCosts(rawValue: 1 << 1)
    }
    
    func checkSystemCost() {
        var exceededSessionCosts: ExceededCaptureSessionCosts = []
        
        if session.systemPressureCost > 1.0 {
            exceededSessionCosts.insert(.systemPressureCost)
        }
        
        if session.hardwareCost > 1.0 {
            exceededSessionCosts.insert(.hardwareCost)
        }
        
        switch exceededSessionCosts {
            
        case .systemPressureCost:
            // Choice #1: Reduce front camera resolution
            if reduceResolutionForCamera(.front) {
                checkSystemCost()
            }
                
                // Choice 2: Reduce the number of video input ports
            else if reduceVideoInputPorts() {
                checkSystemCost()
            }
                
                // Choice #3: Reduce back camera resolution
            else if reduceResolutionForCamera(.back) {
                checkSystemCost()
            }
                
                // Choice #4: Reduce front camera frame rate
            else if reduceFrameRateForCamera(.front) {
                checkSystemCost()
            }
                
                // Choice #5: Reduce frame rate of back camera
            else if reduceFrameRateForCamera(.back) {
                checkSystemCost()
            } else {
                print("Unable to further reduce session cost.")
            }
            
        case .hardwareCost:
            // Choice #1: Reduce front camera resolution
            if reduceResolutionForCamera(.front) {
                checkSystemCost()
            }
                
                // Choice 2: Reduce back camera resolution
            else if reduceResolutionForCamera(.back) {
                checkSystemCost()
            }
                
                // Choice #3: Reduce front camera frame rate
            else if reduceFrameRateForCamera(.front) {
                checkSystemCost()
            }
                
                // Choice #4: Reduce back camera frame rate
            else if reduceFrameRateForCamera(.back) {
                checkSystemCost()
            } else {
                print("Unable to further reduce session cost.")
            }
            
        case [.systemPressureCost, .hardwareCost]:
            // Choice #1: Reduce front camera resolution
            if reduceResolutionForCamera(.front) {
                checkSystemCost()
            }
                
                // Choice #2: Reduce back camera resolution
            else if reduceResolutionForCamera(.back) {
                checkSystemCost()
            }
                
                // Choice #3: Reduce front camera frame rate
            else if reduceFrameRateForCamera(.front) {
                checkSystemCost()
            }
                
                // Choice #4: Reduce back camera frame rate
            else if reduceFrameRateForCamera(.back) {
                checkSystemCost()
            } else {
                print("Unable to further reduce session cost.")
            }
            
        default:
            break
        }
    }
    
    func reduceResolutionForCamera(_ position: AVCaptureDevice.Position) -> Bool {
        for connection in session.connections {
            for inputPort in connection.inputPorts {
                if inputPort.mediaType == .video && inputPort.sourceDevicePosition == position {
                    guard let videoDeviceInput: AVCaptureDeviceInput = inputPort.input as? AVCaptureDeviceInput else {
                        return false
                    }
                    
                    var dims: CMVideoDimensions
                    
                    var width: Int32
                    var height: Int32
                    var activeWidth: Int32
                    var activeHeight: Int32
                    
                    dims = CMVideoFormatDescriptionGetDimensions(videoDeviceInput.device.activeFormat.formatDescription)
                    activeWidth = dims.width
                    activeHeight = dims.height
                    
                    if ( activeHeight <= 480 ) && ( activeWidth <= 640 ) {
                        return false
                    }
                    
                    let formats = videoDeviceInput.device.formats
                    if let formatIndex = formats.firstIndex(of: videoDeviceInput.device.activeFormat) {
                        
                        for index in (0..<formatIndex).reversed() {
                            let format = videoDeviceInput.device.formats[index]
                            if format.isMultiCamSupported {
                                dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                                width = dims.width
                                height = dims.height
                                
                                if width < activeWidth || height < activeHeight {
                                    do {
                                        try videoDeviceInput.device.lockForConfiguration()
                                        videoDeviceInput.device.activeFormat = format
                                        
                                        videoDeviceInput.device.unlockForConfiguration()
                                        
                                        print("reduced width = \(width), reduced height = \(height)")
                                        
                                        return true
                                    } catch {
                                        print("Could not lock device for configuration: \(error)")
                                        
                                        return false
                                    }
                                    
                                } else {
                                    continue
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    func reduceFrameRateForCamera(_ position: AVCaptureDevice.Position) -> Bool {
        for connection in session.connections {
            for inputPort in connection.inputPorts {
                
                if inputPort.mediaType == .video && inputPort.sourceDevicePosition == position {
                    guard let videoDeviceInput: AVCaptureDeviceInput = inputPort.input as? AVCaptureDeviceInput else {
                        return false
                    }
                    let activeMinFrameDuration = videoDeviceInput.device.activeVideoMinFrameDuration
                    var activeMaxFrameRate: Double = Double(activeMinFrameDuration.timescale) / Double(activeMinFrameDuration.value)
                    activeMaxFrameRate -= 10.0
                    
                    // Cap the device frame rate to this new max, never allowing it to go below 15 fps
                    if activeMaxFrameRate >= 15.0 {
                        do {
                            try videoDeviceInput.device.lockForConfiguration()
                            videoDeviceInput.videoMinFrameDurationOverride = CMTimeMake(value: 1, timescale: Int32(activeMaxFrameRate))
                            
                            videoDeviceInput.device.unlockForConfiguration()
                            
                            print("reduced fps = \(activeMaxFrameRate)")
                            
                            return true
                        } catch {
                            print("Could not lock device for configuration: \(error)")
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }
        }
        
        return false
    }
    
    func reduceVideoInputPorts () -> Bool {
        var newConnection: AVCaptureConnection
        var result = false
        
        for connection in session.connections {
            for inputPort in connection.inputPorts where inputPort.sourceDeviceType == .builtInDualCamera {
                print("Changing input from dual to single camera")
                
                guard let videoDeviceInput: AVCaptureDeviceInput = inputPort.input as? AVCaptureDeviceInput,
                    let wideCameraPort: AVCaptureInput.Port = videoDeviceInput.ports(for: .video,
                                                                                     sourceDeviceType: .builtInWideAngleCamera,
                                                                                     sourceDevicePosition: videoDeviceInput.device.position).first else {
                                                                                        return false
                }
                
                if let previewLayer = connection.videoPreviewLayer {
                    newConnection = AVCaptureConnection(inputPort: wideCameraPort, videoPreviewLayer: previewLayer)
                } else if let savedOutput = connection.output {
                    newConnection = AVCaptureConnection(inputPorts: [wideCameraPort], output: savedOutput)
                } else {
                    continue
                }
                session.beginConfiguration()
                
                session.removeConnection(connection)
                
                if session.canAddConnection(newConnection) {
                    session.addConnection(newConnection)
                    
                    session.commitConfiguration()
                    result = true
                } else {
                    print("Could not add new connection to the session")
                    session.commitConfiguration()
                    return false
                }
            }
        }
        return result
    }
    
    private func setRecommendedFrameRateRangeForPressureState(_ systemPressureState: AVCaptureDevice.SystemPressureState) {
        // The frame rates used here are for demonstrative purposes only for this app.
        // Your frame rate throttling may be different depending on your app's camera configuration.
        let pressureLevel = systemPressureState.level
        if pressureLevel == .serious || pressureLevel == .critical {
            do {
                try self.backCameraDeviceInput?.device.lockForConfiguration()
                
                print("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
                
                self.backCameraDeviceInput?.device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 20 )
                self.backCameraDeviceInput?.device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 15 )
                
                self.backCameraDeviceInput?.device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        } else if pressureLevel == .shutdown {
            print("Session stopped running due to system pressure level.")
        }
    }
    
    private func matchViewAndLayer() {
        backCameraVideoPreviewLayer?.frame = backCameraVideoPreviewView.frame
        frontCameraVideoPreviewLayer?.frame = frontCameraVideoPreviewView.frame
    }
    var currentPreviewScale:(CGFloat,CGFloat,CGFloat,CGFloat) = (0,0,0,0)
    var currentOrientation = UIDeviceOrientation.portrait
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight {
            let newBackCamaraPreviewViewRect = CGRect(x:backCameraVideoPreviewView.frame.minY,y: referenceView.bounds.width - backCameraVideoPreviewView.frame.maxX,width:backCameraVideoPreviewView.frame.height,height:backCameraVideoPreviewView.frame.width )
            let newFrontCamaraPreviewViewRect = CGRect(x:frontCameraVideoPreviewView.frame.minY,y: referenceView.bounds.width - frontCameraVideoPreviewView.frame.maxX,width:frontCameraVideoPreviewView.frame.height,height:frontCameraVideoPreviewView.frame.width)
            backCameraVideoPreviewView.frame = newBackCamaraPreviewViewRect
            frontCameraVideoPreviewView.frame = newFrontCamaraPreviewViewRect
            referenceView.frame = CGRect(x: 0, y: 0, width: size.height * 1.77778, height: size.height)
            
        } else {
            let newBackCamaraPreviewViewRect = CGRect(x:referenceView.frame.height - backCameraVideoPreviewView.frame.maxY ,y:  backCameraVideoPreviewView.frame.minX,width:backCameraVideoPreviewView.frame.height,height:backCameraVideoPreviewView.frame.width )
            let newFrontCamaraPreviewViewRect = CGRect(x:referenceView.frame.height - frontCameraVideoPreviewView.frame.maxY,y:  frontCameraVideoPreviewView.frame.minX,width:frontCameraVideoPreviewView.frame.height,height:frontCameraVideoPreviewView.frame.width )
            referenceView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.width * 1.77778)
            backCameraVideoPreviewView.frame = newBackCamaraPreviewViewRect
            frontCameraVideoPreviewView.frame = newFrontCamaraPreviewViewRect
        }
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let orientation = UIDevice.current.orientation
        if orientation != currentOrientation, orientation != .unknown {
            switch orientation {
            case .portrait:
                frontCameraVideoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                backCameraVideoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                currentOrientation = .portrait
            case .landscapeLeft:
                frontCameraVideoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
                backCameraVideoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
                currentOrientation = .landscapeLeft
            case .landscapeRight:
                frontCameraVideoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
                backCameraVideoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
                currentOrientation = .landscapeRight
            default:
                frontCameraVideoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                backCameraVideoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                currentOrientation = .portrait
            }
            matchViewAndLayer()
            buttonSetting()
        }
    }
    
    //MARK: - Buttons
    var AddButton = UIImageView()
    var CameraButton = UIImageView()
    var HelpButton = UIImageView()
    var recordingLabel = UILabel()
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
            recordingLabel.frame = CGRect(x: view.bounds.maxX - 150, y: view.bounds.maxY - 100, width: 100, height: 100)
            
            modeSwitchButton.frame = CGRect(x: backgroundView.frame.origin.x, y: backgroundView.center.y - (buttonHeight * 1.0), width: buttonHeight * 2.5, height: buttonHeight * 0.5)
            semanticsModeSwitchButton.frame = CGRect(x: backgroundView.frame.origin.x, y: backgroundView.center.y + (buttonHeight * 0.5), width: buttonHeight * 2.5, height: buttonHeight * 0.5)
            recordingLabel.frame = CGRect(x: recordButton.frame.origin.x, y: recordButton.frame.maxY, width: buttonHeight, height: buttonHeight)
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
                materialLabel.isHidden = false
                helpLabel.isHidden = false
                BehindLabel.isHidden = false
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
            recordingLabel.frame = CGRect(x: view.bounds.maxX - 150, y: view.bounds.maxY - 100, width: 100, height: 100)
            
            modeSwitchButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 1.5), y: backgroundView.frame.origin.y, width: buttonHeight * 3, height: buttonHeight * 0.5)
            semanticsModeSwitchButton.frame = CGRect(x: backgroundView.center.x - (buttonHeight * 1.5), y: backgroundView.frame.maxY - buttonHeight , width: buttonHeight * 3, height: buttonHeight * 0.5)
            recordingLabel.frame = CGRect(x: recordButton.frame.origin.x, y: recordButton.frame.maxY, width: buttonHeight, height: buttonHeight)
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
        if view.bounds.width > view.bounds.height {
            referenceRect = CGRect(x: 0, y: 0, width: view.bounds.height * 1.77778, height: view.bounds.height)
            referenceView.frame = view.bounds
            referenceView.isUserInteractionEnabled = true
            referenceView.contentMode = .scaleAspectFill
            let pipHeight = referenceRect.height * 0.5
            let pipWidth = pipHeight * 1.77778
            pipRect = CGRect(x: 0, y: referenceRect.height * 0.5, width: pipWidth, height: pipHeight )
        } else {
            referenceRect = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.width * 1.77778)
            referenceView.frame = view.bounds
            referenceView.isUserInteractionEnabled = true
            referenceView.contentMode = .scaleAspectFill
            let pipWidth = referenceRect.width * 0.5
            let pipHeight = pipWidth * 1.77778
            pipRect = CGRect(x: 0, y: referenceRect.height * 0.5, width: pipWidth, height: pipHeight )
        }
        backCameraVideoPreviewView.frame = referenceRect
        frontCameraVideoPreviewView.frame = pipRect
        view.bringSubviewToFront(backCameraVideoPreviewView)
        view.bringSubviewToFront(frontCameraVideoPreviewView)
        addGesutures(backCameraVideoPreviewView)
        addGesutures(frontCameraVideoPreviewView)
        
        
        CameraButton.image = UIImage(systemName: "camera.rotate")
        AddButton.image = UIImage(systemName: "person.crop.rectangle")
        HelpButton.image = UIImage(systemName: "questionmark.circle")
        faceTextureButton.image = UIImage(systemName: "camera.on.rectangle")
        materialButton.image = UIImage(systemName: "rectangle")
        BehindButton.image = UIImage(systemName: "chevron.left.2")
        cameraLabel.text = NSLocalizedString("Switch", comment: "")
        addLabel.text = NSLocalizedString("Back", comment: "")
        helpLabel.text = NSLocalizedString("Help", comment: "")
        faceTextureLabel.text =  NSLocalizedString("Texture", comment: "")
        materialLabel.text = NSLocalizedString("Material", comment: "")
        BehindLabel.text = NSLocalizedString("AR", comment: "")
        
        videoModeLabel.text = NSLocalizedString("Video", comment: "")
        photoModeLabel.text = NSLocalizedString("Photo", comment: "")
        videoModeLabel.textColor = UIColor.white
        photoModeLabel.textColor = UIColor.darkGray
        frontModeLabel.text = NSLocalizedString("Front", comment: "")
        behindModeLabel.text = NSLocalizedString("Behind", comment: "")
        frontModeLabel.textColor = UIColor.white
        behindModeLabel.textColor = UIColor.darkGray
        
        HelpButton.tintColor = UIColor.white
        AddButton.tintColor = UIColor.white
        CameraButton.tintColor = UIColor.white
        faceTextureButton.tintColor = UIColor.white
        materialButton.tintColor = UIColor.white
        BehindButton.tintColor = UIColor.white
        helpLabel.textColor = UIColor.white
        addLabel.textColor = UIColor.white
        cameraLabel.textColor = UIColor.white
        faceTextureLabel.textColor = UIColor.white
        materialLabel.textColor = UIColor.white
        BehindLabel.textColor = UIColor.white
        
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
        
        recordingLabel.text = NSLocalizedString("Recording", comment: "")
        recordingLabel.textColor = UIColor.red
        recordingLabel.adjustsFontSizeToFitWidth = true
        
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
        backgroundView.backgroundColor = UIColor.black
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
        view.addSubview(recordingLabel)
        view.addSubview(helpLabel)
        view.addSubview(addLabel)
        view.addSubview(cameraLabel)
        view.addSubview(recordingLabel)
        
        view.addSubview(modeSwitchButton)
        view.addSubview(semanticsModeSwitchButton)
        
        view.bringSubviewToFront(modeSwitchButton)
        view.bringSubviewToFront(semanticsModeSwitchButton)
        
        view.bringSubviewToFront(recordingLabel)
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
        recordingLabel.isHidden = true
        
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
        let BackTo = UITapGestureRecognizer(target: self, action: #selector(backToAR))
        let BackTo2 = UITapGestureRecognizer(target: self, action: #selector(backToAR))
        BehindButton.addGestureRecognizer(BackTo)
        BehindLabel.addGestureRecognizer(BackTo2)
        
        let materialAddGesture = UITapGestureRecognizer(target: self, action: #selector(materialAdd))
        let materialAddGesture4Label = UITapGestureRecognizer(target: self, action: #selector(materialAdd))
        materialButton.addGestureRecognizer(materialAddGesture)
        materialLabel.addGestureRecognizer(materialAddGesture4Label)
        let textureGesture = UITapGestureRecognizer(target: self, action: #selector(cameraAdd))
        let textureGesture4Label = UITapGestureRecognizer(target: self, action: #selector(cameraAdd))
        faceTextureButton.addGestureRecognizer(textureGesture)
        faceTextureLabel.addGestureRecognizer(textureGesture4Label)
        let helpTap = UITapGestureRecognizer(target: self, action: #selector(helpSegue))
        let helpTap4Label = UITapGestureRecognizer(target: self, action: #selector(helpSegue))
        HelpButton.addGestureRecognizer(helpTap)
        helpLabel.addGestureRecognizer(helpTap4Label)
        let modeSwitchTap = UITapGestureRecognizer(target: self, action: #selector(switchMode))
        modeSwitchButton.addGestureRecognizer(modeSwitchTap)
        let modeSwitchSwipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(switchModeSwipeLeft))
        modeSwitchSwipeLeft.direction = .left
        let modeSwitchSwipeRight = UISwipeGestureRecognizer(target: self, action: #selector(switchModeSwipeRight))
        modeSwitchSwipeRight.direction = .right
        modeSwitchButton.addGestureRecognizer(modeSwitchSwipeLeft)
        modeSwitchButton.addGestureRecognizer(modeSwitchSwipeRight)
        let recordTap = UITapGestureRecognizer(target: self, action: #selector(toggleMovieRecording))
        recordButton.addGestureRecognizer(recordTap)
        let recordTap4Label = UITapGestureRecognizer(target: self, action: #selector(toggleMovieRecording))
        recordingAnimationButton.addGestureRecognizer(recordTap4Label)
    }
    //    MARK: - Movie Rec
    
    func recordingButtonStyling(){
        print(UIDevice.current.orientation)
        let buttonHeight = recordButton.bounds.height
        var time = 0
        if !isRecording {
            if UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight ||  UIDevice.current.orientation == .unknown {
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
                        self.recordButton.alpha = 0
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
                
            } else {
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
            
            pinchSuggestLabel.text = NSLocalizedString("Pinch to enlarge\n windows", comment: "")
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
    
    
    //MARK:- Recording
    let sharedRecorder = RPScreenRecorder.shared()
    var isRecording = false
    
    @objc func toggleMovieRecording() {
        if !isPhoto {
            recordingButtonStyling()
            if !isRecording {
                AudioServicesPlaySystemSound(1117)
                AddButton.isHidden = true
                CameraButton.isHidden = true
                HelpButton.isHidden = true
                //                recordingLabel.isHidden = false
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
                helpLabel.alpha = 0
                BehindLabel.alpha = 0
                helpLabel.isUserInteractionEnabled = false
                helpLabel.isUserInteractionEnabled = false
                sharedRecorder.startRecording(handler: { (error) in
                    if let error = error {
                        print(error)
                    }
                })
            } else {
                AudioServicesPlaySystemSound(1118)
                isRecording = false
                //                  AddButton.isHidden = false
                CameraButton.isHidden = false
                HelpButton.isHidden = false
                recordingLabel.isHidden = true
                faceTextureLabel.isHidden = false
                faceTextureButton.isHidden = false
                //                  behindModeLabel.isHidden = false
                BehindButton.isHidden = false
                //                  modeSwitchButton.isHidden = false
                //                  semanticsModeSwitchButton.isHidden = false
                //                  addLabel.isHidden = false
                helpLabel.isHidden = false
                cameraLabel.isHidden = false
                //                  modeSwitchButton.isHidden = false
                materialLabel.isHidden = false
                materialButton.isHidden = false
                backgroundView.isHidden = false
                BehindLabel.isHidden = false
                helpLabel.alpha = 1
                BehindLabel.alpha = 1
                helpLabel.isUserInteractionEnabled = true
                helpLabel.isUserInteractionEnabled = true
                sharedRecorder.stopRecording(handler: { (previewViewController, error) in
                    previewViewController?.previewControllerDelegate = self
                    self.present(previewViewController!, animated: true, completion: nil)
                })
            }
        }
        else {
            shutter()
        }
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
        faceTextureButton.isHidden = false
        faceTextureLabel.isHidden = false
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
    
    //MARK:- Contents
    
    private enum MaterialTypes {
        case image
        case video
        case text
        case web
        case back
    }
    private var materialType:MaterialTypes = .image
    
    private func imagePick(){
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        switch materialType {
        case .image:
            imagePicker.mediaTypes = ["public.image"]
        case .video:
            imagePicker.mediaTypes = ["public.movie"]
        case .back :
            imagePicker.mediaTypes = ["public.image","public.movie"]
        default:break
        }
        self.present(imagePicker,animated: true)
    }
    
    @objc func didPlayToEnd(notification: NSNotification) {
        let item: AVPlayerItem = notification.object as! AVPlayerItem
        item.seek(to: CMTime.zero, completionHandler: nil)
    }
    
    private func resolutionForLocalVideo(url: URL) -> CGSize? {
        guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {         if let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String {
        if mediaType == "public.movie" {
            if let videoURL = info[UIImagePickerController.InfoKey.mediaURL]  as? URL {
                let player = AVPlayer(url: videoURL)
                let playerLayer = AVPlayerLayer(player: player)
                var mediaAspectRatio: CGFloat!
                let resolution = resolutionForLocalVideo(url: videoURL)
                let width = resolution?.width
                let height = resolution?.height
                mediaAspectRatio = CGFloat(height! / width!)
                player.actionAtItemEnd = AVPlayer.ActionAtItemEnd.none;
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(ViewController.didPlayToEnd),
                                                       name: NSNotification.Name("AVPlayerItemDidPlayToEndTimeNotification"),
                                                       object: player.currentItem)
                switch materialType {
                case .video :
                    let addView = UIView()
                    addView.frame = CGRect(x: 0, y: 0, width: view.bounds.width * 0.5, height: view.bounds.width * 0.5 * mediaAspectRatio)
                    playerLayer.frame = addView.bounds
                    addView.layer.addSublayer(playerLayer)
                    view.addSubview(addView)
                    view.bringSubviewToFront(addView)
                    player.play()
                    //                    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panPiece(_:)))
                    //                    addView.addGestureRecognizer(panGesture)
                    //                    let pintchGesture = UIPinchGestureRecognizer(target: self, action:  #selector(scalePiece(_:)))
                    //                    addView.addGestureRecognizer(pintchGesture)
                    //                    addView.isUserInteractionEnabled = true
                    addGesutures(addView)
                case .back :
                    playerLayer.frame = referenceView.bounds
                    referenceView.layer.addSublayer(playerLayer)
                    player.play()
                default:
                    break
                }
                picker.dismiss(animated: true, completion: nil)
            }
        }
        if mediaType == "public.image" {
            if let image = info[UIImagePickerController.InfoKey.originalImage]  as? UIImage {
                switch materialType {
                case .image:
                    let imageWidth = image.size.width
                    let imageHeght = image.size.height
                    let mediaAspectRatio = CGFloat(imageHeght / imageWidth)
                    let addView = UIImageView()
                    addView.frame = CGRect(x: 0, y: 0, width: view.bounds.width * 0.5, height: view.bounds.width * 0.5 * mediaAspectRatio)
                    view.addSubview(addView)
                    view.bringSubviewToFront(addView)
                    addView.image = image
                    addGesutures(addView)
                case .back:
                    referenceView.image = image
                default:
                    break
                }
                picker.dismiss(animated: true, completion: nil)
            }
        }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    private var textField = UITextField()
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        textField.endEditing(true)
        if textField.text?.count != 0 {
            let textLabel = UILabel()
            textLabel.text = textField.text
            textLabel.font = .systemFont(ofSize: 40, weight: .black)
            textLabel.adjustsFontSizeToFitWidth = true
            textLabel.textAlignment = .center
            textLabel.textColor = .darkGray
            textLabel.alpha = 0.75
            textLabel.frame = CGRect(x: 0, y: 50, width: view.bounds.width, height: view.bounds.height * 0.1)
            addGesutures(textLabel)
            view.addSubview(textLabel)
            textLabel.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0)
            textLabel.numberOfLines = 10
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(changeColor(_:)))
            doubleTap.numberOfTouchesRequired = 3
            textLabel.addGestureRecognizer(doubleTap)
            addGesutures(textLabel)
            
        }
        self.textField.removeFromSuperview()
        self.textField.isHidden = true
        return true
    }
    
    let textColors:[UIColor] = [.darkGray,.white,.blue,.green,.yellow,.orange,.red,.systemPink,.purple,.black]
    var colorNumber = 0
    var webColorNumber = 0
    
    @objc func changeColor(_ gestureRecognizer:UITapGestureRecognizer){
        if let tappedView = gestureRecognizer.view as? UILabel {
            colorNumber += 1
            if colorNumber < 10 {
                tappedView.textColor = textColors[colorNumber]
            } else {
                colorNumber = 0
                tappedView.textColor = textColors[colorNumber]
            }
        }
        else if let tappedView = gestureRecognizer.view {
            webColorNumber += 1
            if webColorNumber < 10 {
                tappedView.backgroundColor = textColors[webColorNumber]
            } else {
                webColorNumber = 0
                tappedView.backgroundColor = textColors[webColorNumber]
            }
        }
    }
    
    private func addGesutures(_ addView:UIView){
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panPiece(_:)))
        addView.addGestureRecognizer(panGesture)
        let pintchGesture = UIPinchGestureRecognizer(target: self, action:  #selector(scalePiece(_:)))
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(deletePiece(_:)))
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(bringToFront(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        addView.addGestureRecognizer(longPressGesture)
        addView.addGestureRecognizer(pintchGesture)
        addView.addGestureRecognizer(doubleTapGesture)
        addView.isUserInteractionEnabled = true
    }
    
    @objc private func materialAdd(){
        if UIDevice.current.userInterfaceIdiom != .pad {
            let alert = UIAlertController(title: NSLocalizedString("マテリアル",value: "えらんでください", comment: ""), message: NSLocalizedString("ウインドウ", comment: ""), preferredStyle: .actionSheet)
            alert.addActions(actions: [
                UIAlertAction(title: NSLocalizedString("イメージ", comment: "イメージ"), style: .default, handler: { _ in
                    self.materialType = .image
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ビデオ", comment: "ビデオ"), style: .default, handler: { _ in
                    self.materialType = .video
                    self.imagePick()
                }),
                //                UIAlertAction(title: NSLocalizedString("ウェブ", comment: "ウェブ"), style: .default, handler: { _ in
                //                    self.materialType = .web
                //                    let webConfiguration = WKWebViewConfiguration()
                //                    webConfiguration.allowsInlineMediaPlayback = true
                //                    let webView = WKWebView(frame: CGRect(x: 0, y: 50, width: self.view.bounds.width * 0.5, height: self.view.bounds.width * 0.5), configuration: webConfiguration)
                //                    webView.allowsBackForwardNavigationGestures = true
                //                    webView.allowsLinkPreview = true
                //                    webView.uiDelegate = self
                //                    let myURL = URL(string:"https://www.google.com/")
                //                    let myRequest = URLRequest(url: myURL!)
                //                    webView.load(myRequest)
                //                    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.panPiece(_:)))
                //                    let pintchGesture = UIPinchGestureRecognizer(target: self, action:  #selector(self.scalePiece(_:)))
                //                    webView.isUserInteractionEnabled = true
                //                    let dragTabView = UIView(frame: CGRect(x: webView.frame.minX , y: webView.frame.minY - 10, width: webView.frame.width, height: webView.frame.height + 10))
                //                    dragTabView.addSubview(webView)
                //                    dragTabView.addGestureRecognizer(panGesture)
                //                    dragTabView.addGestureRecognizer(pintchGesture)
                //                    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.deletePiece(_:)))
                //                    dragTabView.addGestureRecognizer(longPressGesture)
                //                    dragTabView.isUserInteractionEnabled = true
                //                    dragTabView.backgroundColor = UIColor.lightGray
                //                    self.view.addSubview(dragTabView)
                //                    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(self.changeColor(_:)))
                //                    doubleTap.numberOfTapsRequired = 2
                //                    dragTabView.addGestureRecognizer(doubleTap)
                //                }),
                UIAlertAction(title: NSLocalizedString("もじ", comment: "もじ"), style: .default, handler: { _ in
                    self.materialType = .text
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
                UIAlertAction(title: NSLocalizedString("はいけい", comment: "はいけい"), style: .default, handler: { _ in
                    self.materialType = .back
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("スピーチ", comment: "スピーチ"), style: .default, handler: { _ in
                    self.speech()
                }),
                UIAlertAction(title: NSLocalizedString("キャンセル", comment: "キャンセル"), style: .cancel, handler: nil)
                ]
            )
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = self.view.bounds
            alert.popoverPresentationController?.permittedArrowDirections = []
            self.present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: NSLocalizedString("マテリアル",value: "えらんでください", comment: ""), message: "ウインドウ", preferredStyle: .actionSheet)
            alert.addActions(actions: [
                UIAlertAction(title: NSLocalizedString("イメージ", comment: "イメージ"), style: .default, handler: { _ in
                    self.materialType = .image
                    self.imagePick()
                }),
                UIAlertAction(title: NSLocalizedString("ビデオ", comment: "ビデオ"), style: .default, handler: { _ in
                    self.materialType = .video
                    self.imagePick()
                }),
                //                UIAlertAction(title: NSLocalizedString("ウェブ", comment: "ウェブ"), style: .default, handler: { _ in
                //                    self.materialType = .web
                //                    let webConfiguration = WKWebViewConfiguration()
                //                    webConfiguration.allowsInlineMediaPlayback = true
                //                    let webView = WKWebView(frame: CGRect(x: 0, y: 50, width: self.view.bounds.width * 0.5, height: self.view.bounds.width * 0.5), configuration: webConfiguration)
                //                    webView.allowsBackForwardNavigationGestures = true
                //                    webView.allowsLinkPreview = true
                //                    webView.uiDelegate = self
                //                    let myURL = URL(string:"https://www.google.com/")
                //                    let myRequest = URLRequest(url: myURL!)
                //                    webView.load(myRequest)
                //                    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.panPiece(_:)))
                //                    let pintchGesture = UIPinchGestureRecognizer(target: self, action:  #selector(self.scalePiece(_:)))
                //                    webView.isUserInteractionEnabled = true
                //                    let dragTabView = UIView(frame: CGRect(x: webView.frame.minX , y: webView.frame.minY - 10, width: webView.frame.width, height: webView.frame.height + 10))
                //                    dragTabView.addSubview(webView)
                //                    dragTabView.addGestureRecognizer(panGesture)
                //                    dragTabView.addGestureRecognizer(pintchGesture)
                //                    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.deletePiece(_:)))
                //                    dragTabView.addGestureRecognizer(longPressGesture)
                //                    dragTabView.isUserInteractionEnabled = true
                //                    dragTabView.backgroundColor = UIColor.lightGray
                //                    self.view.addSubview(dragTabView)
                //                    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(self.changeColor(_:)))
                //                    doubleTap.numberOfTapsRequired = 2
                //                    dragTabView.addGestureRecognizer(doubleTap)
                //                }),
                UIAlertAction(title: NSLocalizedString("もじ", comment: "もじ"), style: .default, handler: { _ in
                    self.materialType = .text
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
                UIAlertAction(title: NSLocalizedString("はいけい", comment: "はいけい"), style: .default, handler: { _ in
                    self.materialType = .back
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
    
    @objc private func backTapped(){
        materialType = .back
        imagePick()
    }
    
    func presentAlert(_ title: String, error: Error) {
        // Always present alert on main thread.
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title,
                                                    message: error.localizedDescription,
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK",
                                         style: .default) { _ in
                                            // Do nothing -- simply dismiss alert.
            }
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    var pan = UIPanGestureRecognizer()
    var pinch = UIPinchGestureRecognizer()
    
    @objc func scalePiece(_ gestureRecognizer : UIPinchGestureRecognizer) {
        guard gestureRecognizer.view != nil else { return }
        
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            gestureRecognizer.view?.transform = (gestureRecognizer.view?.transform.scaledBy(x: gestureRecognizer.scale, y: gestureRecognizer.scale))!
            gestureRecognizer.scale = 1.0
            pipRect = gestureRecognizer.view!.frame
        }}
    
    var initialCenter = CGPoint()
    
    @objc func panPiece(_ gestureRecognizer : UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else {return}
        let piece = gestureRecognizer.view!
        let translation = gestureRecognizer.translation(in: piece.superview)
        if gestureRecognizer.state == .began {
            self.initialCenter = piece.center
        }
        if gestureRecognizer.state != .cancelled {
            let newCenter = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
            piece.center = newCenter
            pipRect = piece.frame
        }
        else {
            piece.center = initialCenter
            pipRect = piece.frame
        }
    }
    @objc func scalePiece2(_ gestureRecognizer : UIPinchGestureRecognizer) {
        guard gestureRecognizer.view != nil else { return }
        
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            gestureRecognizer.view?.transform = (gestureRecognizer.view?.transform.scaledBy(x: gestureRecognizer.scale, y: gestureRecognizer.scale))!
            gestureRecognizer.scale = 1.0
            pipRect = gestureRecognizer.view!.frame
        }}
    
    @objc func panPiece2(_ gestureRecognizer : UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else {return}
        let piece = gestureRecognizer.view!
        let translation = gestureRecognizer.translation(in: piece.superview)
        if gestureRecognizer.state == .began {
            self.initialCenter = piece.center
        }
        if gestureRecognizer.state != .cancelled {
            let newCenter = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
            piece.center = newCenter
            pipRect = piece.frame
        }
        else {
            piece.center = initialCenter
            pipRect = piece.frame
        }
    }
    
    @objc func deletePiece(_ gestureRecognizer:UILongPressGestureRecognizer){
        guard let piece = gestureRecognizer.view else {return}
        if piece != referenceView && piece != self.view && piece != backCameraVideoPreviewView && piece != frontCameraVideoPreviewView {
            piece.removeFromSuperview()
        }
        
        if piece == backCameraVideoPreviewView || piece == frontCameraVideoPreviewView {
            piece.isHidden = true
            faceTextureLabel.isHidden = false
            faceTextureButton.isHidden = false
        }
    }
    
    @objc func bringToFront(_ gestureRecognizer:UITapGestureRecognizer){
        guard let piece = gestureRecognizer.view else { return }
        view.bringSubviewToFront(piece)
    }
    
    //MARK:- Speech
    
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
        if result.count >= reccentTextCount {
            let index = result.index(result.startIndex, offsetBy: reccentTextCount)
            let cutText = result[index...]
            reccentTextCount = result.count
            
            let label = UILabel()
            label.text = String(cutText)
            label.sizeToFit()
            label.textColor = UIColor.randomColor
            label.font = .systemFont(ofSize: 40, weight: .black)
            label.backgroundColor = .clear
            view.addSubview(label)
            let random = CGFloat.random(in: view.bounds.minY...view.bounds.maxY - 100)
            let random2 = CGFloat.random(in: view.bounds.minY...view.bounds.maxY - 100)
            label.frame = CGRect(x: view.bounds.maxX, y: random, width: view.bounds.width, height: 100)
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 8, delay: 0, options: [], animations: {
                label.frame.origin = CGPoint(x: -self.view.bounds.width, y: random2)
            }) { (UIViewAnimatingPosition) in
                label.removeFromSuperview()
            }
        }
    }
    
    //MARK: -Button Actions
    
    @objc func cameraAdd(){
        backCameraVideoPreviewView.isHidden = false
        frontCameraVideoPreviewView.isHidden = false
        faceTextureLabel.isHidden = true
        faceTextureButton.isHidden = true
    }
    
    @objc private func helpSegue(){
        performSegue(withIdentifier: "ShowMultiHelp", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowMultiHelp" {
            if let ocvc = segue.destination as? OthersCollectionViewController {
                ocvc.isMulti = true
            }
        }
    }
    
    @objc private func backToAR(){
        self.navigationController?.popViewController(animated: true)
        session.stopRunning()
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
}
