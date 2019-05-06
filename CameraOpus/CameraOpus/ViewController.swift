//
//  ViewController.swift
//  CameraOpus
//
//  Created by Abheek Basu on 4/28/19.
//  Copyright © 2019 CameraOpus. All rights reserved.
//

import UIKit
import AVFoundation
import Photos


class ViewController: UIViewController, UITextFieldDelegate, AVCaptureFileOutputRecordingDelegate {
    
    var session = AVCaptureSession()
    var photoOutput: AVCapturePhotoOutput?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    var error: NSError?
    
    var depthDataMap: CVPixelBuffer?
    var depthData: AVDepthData?
    
    //MARK: Properties
    @IBOutlet weak var textLabel: UILabel!
    
    @IBOutlet weak var textInput: UITextField!
    
    @IBOutlet weak var previewView: PreviewView!
    
    @IBOutlet weak var photoPreviewImageView: UIImageView!
    
    //var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    
    // stackoverflow.com/questions/37869963/how-to-use-avcapturephotooutput
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        print("in file Output")
        let imageData = outputFileURL.dataRepresentation
        print(imageData)
        
        if error != nil {
            print("Movie file finishing error")
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("in file output 2")
    }

    
    /// - Tag: CapturePhoto
    override func viewDidLoad() {
        super.viewDidLoad()
        textInput.delegate = self
        do{
            /*
             this preset line is needed for depth for some reason
             */
            session.sessionPreset = .photo
            //We are trying to set the input device to the session ie the back camera
            guard let backCamera =  try AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) else { print("Default video device is unavailable."); return }
            let DeviceInput = try AVCaptureDeviceInput(device: backCamera)
            if session.canAddInput(DeviceInput) {
                session.addInput(DeviceInput)
                print("was able to add deviceinput")
                //Now that we set input device lets set output files
                photoOutput = AVCapturePhotoOutput()
                if session.canAddOutput(photoOutput!) {
                    session.addOutput(photoOutput!)
                    print("was able to set deviceoutput")
                    if photoOutput!.isDepthDataDeliverySupported {
                        print("we can add depth")
                        photoOutput!.isDepthDataDeliveryEnabled = true
                    }
                    else{
                        print("for some reason we can't add depth")
                    }
                    //photoOutput!.isDepthDataDeliveryEnabled = true
                    //Now we try to connect the preview layer which will eventually be the element in the IB to what the camera sees
                    videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
                    videoPreviewLayer!.videoGravity =    AVLayerVideoGravity.resizeAspect
                    videoPreviewLayer!.connection?.videoOrientation =   AVCaptureVideoOrientation.portrait
                    photoPreviewImageView.layer.addSublayer(videoPreviewLayer!)
                    print("seems like we have added a subLayer")
                    /*
                     *
                     Configuring the depthdata here
                     *
                     */
                    
                    //session.commitConfiguration()
                    session.startRunning()
                    print("session is running?")
                }
            }
        }
        catch{
            print("there must have been an error in vievDidLoad")
            return
        }
    }

    @IBAction func capturePhoto(_ sender: UIButton) {
        
            do{
                print("in capturePhoto")
                let videoPreviewLayerOrientation = try videoPreviewLayer?.connection?.videoOrientation
                if let photoOutputConnection = photoOutput!.connection(with: .video) {
                    photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
                }
                var photoSettings = AVCapturePhotoSettings()
                //photoSettings.isDepthDataDeliveryEnabled = true
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                //JUST ADDED
                photoSettings.isDepthDataDeliveryEnabled =
                    photoOutput!.isDepthDataDeliverySupported

                print("about to set up delegate")

                print("delegate should have been created")
                photoOutput!.capturePhoto(with: photoSettings, delegate: self)
                
                /*
                 This is the main function that is saving the phto
                */
                //photoOutput!.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
                print("capturePhoto should have been called")
                
            }
            catch{
                print("something wrong with capture")
            }
        }
    
    func viewWillAppear(){
        //captureSession = AVCaptureSession()
        //captureSession!.sessionPreset = AVCaptureSession.Preset.photo
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        videoPreviewLayer!.frame = previewView.bounds
    }
        
        // Do any additional setup after loading the view.
    
    //MARK: UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textLabel.text = textField.text
    }
    
    //MARK: Actions
    @IBAction func setDefaultLabelText(_ sender: UIButton) {
        textLabel.text = "Default text"
    }
    /*
     To create a rectilinear image we must begin with an empty destination buffer and iterate through it
     row by row, calling the sample implementation below for each point in the output image, passing the
     lensDistortionLookupTable to find the corresponding value in the distorted image, and write it to your
     output buffer.
     
     ie we know that the lensDistortionLookupTable is correct,
     */
    
    func lensDistortionPoint(for point: CGPoint, lookupTable: Data, distortionOpticalCenter opticalCenter: CGPoint, imageSize: CGSize) -> CGPoint {
        // The lookup table holds the relative radial magnification for n linearly spaced radii.
        // The first position corresponds to radius = 0
        // The last position corresponds to the largest radius found in the image.
        
        // Determine the maximum radius.
        let delta_ocx_max = Float(max(opticalCenter.x, imageSize.width  - opticalCenter.x))
        let delta_ocy_max = Float(max(opticalCenter.y, imageSize.height - opticalCenter.y))
        let r_max = sqrt(delta_ocx_max * delta_ocx_max + delta_ocy_max * delta_ocy_max)
        
        // Determine the vector from the optical center to the given point.
        let v_point_x = Float(point.x - opticalCenter.x)
        let v_point_y = Float(point.y - opticalCenter.y)
        
        // Determine the radius of the given point.
        let r_point = sqrt(v_point_x * v_point_x + v_point_y * v_point_y)
        
        // Look up the relative radial magnification to apply in the provided lookup table
        let magnification: Float = lookupTable.withUnsafeBytes { (lookupTableValues: UnsafePointer<Float>) in
            let lookupTableCount = lookupTable.count / MemoryLayout<Float>.size
            
            if r_point < r_max {
                // Linear interpolation
                let val   = r_point * Float(lookupTableCount - 1) / r_max
                let idx   = Int(val)
                let frac  = val - Float(idx)
                
                let mag_1 = lookupTableValues[idx]
                let mag_2 = lookupTableValues[idx + 1]
                
                return (1.0 - frac) * mag_1 + frac * mag_2
            } else {
                return lookupTableValues[lookupTableCount - 1]
            }
        }
        
        // Apply radial magnification
        let new_v_point_x = v_point_x + magnification * v_point_x
        let new_v_point_y = v_point_y + magnification * v_point_y
        
        // Construct output
        return CGPoint(x: opticalCenter.x + CGFloat(new_v_point_x), y: opticalCenter.y + CGFloat(new_v_point_y))
    }
    
    /*
     For each point (x,y co-ord) (not pixel value, just co-ord ie no RGB) in the rectified image, find each correspondging x,y co-ord in the non rectified image.
     Take the depth value at the x,y co-ord and put into the right co-ord in the rectified image
     */
    
    private func rectifyDepthData(avDepthData: AVDepthData, image: UIImage) -> CVPixelBuffer? {
        guard
            let distortionLookupTable = avDepthData.cameraCalibrationData?.lensDistortionLookupTable,
            let distortionCenter = avDepthData.cameraCalibrationData?.lensDistortionCenter else {
                return nil
        }
        
        let originalDepthDataMap = avDepthData.depthDataMap
        let width = CVPixelBufferGetWidth(originalDepthDataMap)
        let height = CVPixelBufferGetHeight(originalDepthDataMap)
        // Assumption is that the original depth map is not the same size as the rectified depth map, makes
        // this funtion scale invariant.
        let scaledCenter = CGPoint(x: (distortionCenter.x / CGFloat(image.size.height)) * CGFloat(width), y: (distortionCenter.y / CGFloat(image.size.width)) * CGFloat(height))
        CVPixelBufferLockBaseAddress(originalDepthDataMap, CVPixelBufferLockFlags(rawValue: 0))
        
        /*
         TODO
         Why are we creating a new pixel buffer instead of a new depthmap here?
         TODO
         */
        var maybePixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, width, height, avDepthData.depthDataType, nil, &maybePixelBuffer)
        
        assert(status == kCVReturnSuccess && maybePixelBuffer != nil);
        
        guard let rectifiedPixelBuffer = maybePixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(rectifiedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        guard let address = CVPixelBufferGetBaseAddress(originalDepthDataMap) else {
            return nil
        }
        //This is getting the depth values and putting into the new depthmap
        for y in 0 ..< height{
            let rowData = CVPixelBufferGetBaseAddress(rectifiedPixelBuffer)! + y * CVPixelBufferGetBytesPerRow(rectifiedPixelBuffer)
            let data = UnsafeMutableBufferPointer(start: rowData.assumingMemoryBound(to: Float32.self), count: width)
            
            //
            for x in 0 ..< width{
                let rectifiedPoint = CGPoint(x: x, y: y)
                let distortedPoint = lensDistortionPoint(for: rectifiedPoint, lookupTable: distortionLookupTable, distortionOpticalCenter: scaledCenter, imageSize: CGSize(width: width, height: height) )
                
                let distortedRow = address + Int(distortedPoint.y) * CVPixelBufferGetBytesPerRow(originalDepthDataMap)
                let distortedData = UnsafeBufferPointer(start: distortedRow.assumingMemoryBound(to: Float32.self), count: width)
                data[x] = distortedData[Int(distortedPoint.x)]
            }
        }
        CVPixelBufferUnlockBaseAddress(rectifiedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(originalDepthDataMap, CVPixelBufferLockFlags(rawValue: 0))
        return rectifiedPixelBuffer
    }
    
    
    func testRect(image: CGImage){
        
        print("the type of pixel in og pixel is %@", image.pixelFormatInfo)
        print("the type of colourspace in og pixel is %@", image.colorSpace)
        print("the type of bitmapinfo in og pixel is %@", image.bitmapInfo)
        print("the type of alpha in og pixel is %@", image.alphaInfo)

        //NSLog("the type of pixel in og pixel is %@",CVPixelBufferGetPixelFormatType((image.ciImage?.pixelBuffer)!))
        
    }
    
    
//    func createARGBBitmapContext(inImage: CGImage) -> CGContext {
//        var bitmapByteCount = 0
//        var bitmapBytesPerRow = 0
//
//        //Get image width, height
//        let pixelsWide = inImage.width
//        let pixelsHigh = inImage.height
//        print("the width of inImage is ", pixelsWide)
//        print("the height of inImage is ", pixelsHigh)
//
//        // Declare the number of bytes per row. Each pixel in the bitmap in this
//        // example is represented by 4 bytes; 8 bits each of red, green, blue, and
//        // alpha.
//        bitmapBytesPerRow = Int(pixelsWide) * 4
//        bitmapByteCount = bitmapBytesPerRow * Int(pixelsHigh)
//
//        // Use the generic RGB color space.
//        let colorSpace = CGColorSpaceCreateDeviceRGB()
//
//        // Allocate memory for image data. This is the destination in memory
//        // where any drawing to the bitmap context will be rendered.
//        let bitmapData = malloc(bitmapByteCount)
//
//        // Create the bitmap context. We want pre-multiplied ARGB, 8-bits
//        // per component. Regardless of what the source image format is
//        // (CMYK, Grayscale, and so on) it will be converted over to the format
//        // specified here by CGBitmapContextCreate.
//        let context = CGContext(data: bitmapData, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: bitmapBytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
//
//        // Make sure and release colorspace before returning
//        return context!
//    }
//
    
    func testRectDepth(avDepthData: AVDepthData, image: UIImage){
        let originalDepthDataMap = avDepthData.depthDataMap
        let width = CVPixelBufferGetWidth(originalDepthDataMap)
        let height = CVPixelBufferGetHeight(originalDepthDataMap)
        print("the width is %@", width)
        print("the width is %@", height)
    }
    
    func getDistance(at: CGPoint, avPhoto: AVCapturePhoto)->Float?{
        print("in getDistance")
        let depthM = avPhoto.depthData?.depthDataMap
        guard let address = CVPixelBufferGetBaseAddress(depthM!) else {
            print("an error in getDistance")
            return nil
        }
        var maybePixelBuffer: CVPixelBuffer?
        
        let width = CVPixelBufferGetWidth(depthM!)
        let height = CVPixelBufferGetHeight(depthM!)
        print("depthdatamap width is ", width)
        print("depthdatamap height is ", height)
        let status = CVPixelBufferCreate(nil, width, height, avPhoto.depthData!.depthDataType, nil, &maybePixelBuffer)
        
        guard let rectifiedPixelBuffer = maybePixelBuffer else {
            print("weird error")
            return 42.00
        }
        
        let distortedRow =  address + (Int(at.y)  * CVPixelBufferGetBytesPerRow(rectifiedPixelBuffer)) //+ Int(at.x)
        let distortedData = UnsafeBufferPointer(start: distortedRow.assumingMemoryBound(to: Float32.self), count: width)
        
        let valToReturn = distortedData[Int(at.x)]
        print("depth value is ", valToReturn)
        return valToReturn
        
        //return 4.2
    }

//    private func getPoints(avDepthData: AVDepthData,  image: UIImage)->Array<Any>{
//        let depthData = avDepthData. converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
//        guard let intrinsicMatrix = avDepthData.cameraCalibrationData?.intrinsicMatrix, let depthDataMap = rectifyDepthData(avDepthData: depthData, image: image) else {
//                return []
//            }
//
//        CVPixelBufferLockBaseAddress(depthDataMap, CVPixelBufferLockFlags(rawValue: 0))
//
//        let width = CVPixelBufferGetWidth(depthDataMap)
//        let height = CVPixelBufferGetHeight(depthDataMap)
//
//        var points = Array<Any>()
//        let focalX = Float(width) *  ( intrinsicMatrix[0][0] / Float(image.size.width))
//        let focalY = Float(height) * ( intrinsicMatrix[1][1] / Float(image.size.height))
//        let principalPointX = Float(width) * (intrinsicMatrix[2][0] / Float(image.size.width))
//        let principalPointY = Float(height) * (intrinsicMatrix[2][1] / Float (image.size.height))
//        for y in 0 ..< height{
//            for x in 0 ..< width{
//                guard let Z = getDistance(at: CGPoint(x: x, y: y) , depthMap: depthDataMap) else {
//                    continue
//                }
//                let X = (Float(x) - principalPointX) * Z / focalX
//                let Y = (Float(y) - principalPointY) * Z / focalY
//                points.append(RThree(x: X, y: Y, z: Z))
//            }
//        }
//        CVPixelBufferUnlockBaseAddress(depthDataMap, CVPixelBufferLockFlags(rawValue: 0))
//
//        return points
//    }

}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        var photoData: Data?
        
        print("in didFinishProcessingPhoto")
        if let error = error {
            print("Error capturing photo: \(error)")
        } else {
            print("we seem to be error free")
            photoData = photo.fileDataRepresentation()
            
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else { return }
                PHPhotoLibrary.shared().performChanges({
                    // Add the captured photo's file data as the main resource for the Photos asset.
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: photo.fileDataRepresentation()!, options: nil)
                }, completionHandler: { success, error in
                    if success{
                        print("saved image to library")
                        
                        //getting information about pixel format type in cg file
                        let temp = photo.cgImageRepresentation()
                        let cgim = temp!.takeUnretainedValue()//!.takeRetainedValue()
                        print("cg rep")
                        self.testRect(image: cgim)
                        print("finsihed testrect")
                        
                        //getting depthmap info and testing depth functions
                        let avDepthData = photo.depthData?.depthDataMap
                       
                        let cgTestPointOne = CGPoint(x: 3,y: 5)
                        self.getDistance(at: cgTestPointOne, avPhoto: photo)
                        let cgTestPointTwo = CGPoint(x: 14,y: 60)
                        self.getDistance(at: cgTestPointOne, avPhoto: photo)
                        
                    }
                    else {
                        print("Opus couldn't save the photo to your photo library")
                    }
                })
            }
        }
    }
        
}
