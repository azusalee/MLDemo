//
//  MLScanViewController.swift
//  MLDemo
//
//  Created by lizihong on 2020/8/18.
//  Copyright © 2020 kinshun. All rights reserved.
//

import UIKit
import MLKit
import AVKit
import Vision

class MLScanViewController: UIViewController {
    
    @IBOutlet var previewView: VideoPreviewView!
    var captureSession: AVCaptureSession!
    /// 使用的识别框架: 0:ML, 1:CI, 2:Vision, 3:AV
    var scanType:Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession = AVCaptureSession()
        self.previewView.session = captureSession
        configCapture()
        previewView.updateVideoOrientationForDeviceOrientation()
        self.previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    func configCapture() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("Unable to find capture device")
            return
        }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            print("Unable to obtain video input")
            return
        }
        
        // 视频数据输出
        let captureOutput = AVCaptureVideoDataOutput()
        captureOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA,]
        captureOutput.alwaysDiscardsLateVideoFrames = true
        let outputQueue = DispatchQueue(label: "com.al.scanqueue")
        captureOutput.setSampleBufferDelegate(self, queue: outputQueue)
        
        // 识别数据输出
        let metaOutput = AVCaptureMetadataOutput()
        let metaOutputQueue = DispatchQueue(label: "com.al.scanmetaqueue")
        metaOutput.setMetadataObjectsDelegate(self, queue: metaOutputQueue)
        
        guard captureSession.canAddInput(videoInput) else {
            print("Unable to add input")
            return
        }
        
        guard captureSession.canAddOutput(captureOutput) else {
            print("Unable to add output")
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        captureSession.addInput(videoInput)
        captureSession.addOutput(captureOutput)
        captureSession.addOutput(metaOutput)
        metaOutput.metadataObjectTypes = [.code128, .ean8, .ean13, .qr]
        captureSession.commitConfiguration()
        
    }
    
    private func scanImage(cgImage: CGImage) {
        
        if self.scanType == 0 {
            let viImage = VisionImage(image: UIImage.init(cgImage: cgImage))
            self.processWithML(image: viImage)
        }else if self.scanType == 1 {
            self.processWithCI(image: cgImage)
        }else if self.scanType == 2{
            self.processWithVision(cgImage: cgImage)
        }

    }
    
    private func processWithML(image:VisionImage) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let format = BarcodeFormat.all
        let barcodeOptions = BarcodeScannerOptions(formats: format)
        
        let barcodeScanner = BarcodeScanner.barcodeScanner(options: barcodeOptions)
        var barcodes: [Barcode]
        do {
            barcodes = try barcodeScanner.results(in: image)
        } catch let error {
            print("Failed to scan barcodes with error: \(error.localizedDescription).")
            return
        }
        let endTime = CFAbsoluteTimeGetCurrent()
        if barcodes.count == 0 {
            return
        }
        print("耗时:\(endTime-startTime)")
        var results:[String] = []
        for barcode in barcodes {
            results.append(barcode.rawValue ?? "")
        }
        self.showAlert(results: results)
        
    }
    
    private func processWithCI(image:CGImage) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let detector = CIDetector.init(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])
        let endTime = CFAbsoluteTimeGetCurrent()
        // 获取识别结果
        if let features = detector?.features(in: CIImage.init(cgImage: image)) {
            var results:[String] = []
            for feature in features {
                if let qrFeature:CIQRCodeFeature = feature as? CIQRCodeFeature {
                    results.append(qrFeature.messageString ?? "")
                }
            }
            if results.count > 0 {
                print("耗时:\(endTime-startTime)")
            }
            self.showAlert(results: results)
        }
    }
    
    private func processWithVision(cgImage:CGImage) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let barcodeRequest = VNDetectBarcodesRequest(completionHandler: { request, error in
            let endTime = CFAbsoluteTimeGetCurrent()
            
            var payloads:[String] = []
            for result in request.results ?? [] {
                // Cast the result to a barcode-observation
                if let barcode = result as? VNBarcodeObservation {
                    if let payload = barcode.payloadStringValue {
                        payloads.append(payload)
                    }
                }
            }
            if payloads.count > 0 {
                print("耗时:\(endTime-startTime)")
            }
            self.showAlert(results: payloads)
        })
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [.properties : ""])
        
        guard let _ = try? handler.perform([barcodeRequest]) else {
            return print("Could not perform barcode-request!")
        }
    }
    
    func showAlert(results:[String]) {
        if results.count == 0 {
            return
        }
        DispatchQueue.main.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }else{
                return;
            }
            
            let alertVC = UIAlertController(title: "扫描结果", message: nil, preferredStyle: .actionSheet)
            alertVC.addAction(UIAlertAction.init(title: "取消", style: .cancel, handler: { (action) in
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
            }))
            
            for result in results {
                alertVC.addAction(UIAlertAction.init(title: result, style: .default, handler: { (action) in
                    if !self.captureSession.isRunning {
                        self.captureSession.startRunning()
                    }
                }))
            }
            
            self.present(alertVC, animated: true, completion: nil)
        }
    }


    @IBAction func closeAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func segChange(_ sender: UISegmentedControl) {
        self.scanType = sender.selectedSegmentIndex
    }
    
}

extension MLScanViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if self.scanType == 3 {
            var results:[String] = []
            for metaObject in metadataObjects {
                if let codeObject:AVMetadataMachineReadableCodeObject = metaObject as? AVMetadataMachineReadableCodeObject {
                    results.append(codeObject.stringValue ?? "")
                }
            }
            self.showAlert(results: results)
        }
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension MLScanViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        guard let addressPoint = CVPixelBufferGetBaseAddress(imageBuffer) else {
            return
        }
        
        let dataProvider = CGDataProvider.init(dataInfo: nil, data: addressPoint, size: CVPixelBufferGetDataSize(imageBuffer)) { (mrp, rp, flag) in
            
        }
        
        if let cgImage = CGImage.init(width: Int(imageWidth), height: Int(imageHeight), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: [.byteOrder32Little, CGBitmapInfo.init(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)], provider: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            scanImage(cgImage: cgImage)
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
    }
}
