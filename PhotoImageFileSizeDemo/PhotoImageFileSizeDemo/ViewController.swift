//
//  ViewController.swift
//  PhotoImageFileSizeDemo
//
//  Created by xin on 2018/7/25.
//  Copyright © 2018年 xin. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet var tapGes: UITapGestureRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let imgNameArray = ["IMG_0016.PNG", "IMG_0032.png", "IMG_0020.JPG", "IMG_0021.JPG"];
        
        for imgName in imgNameArray {
            printSomeBundleImageFileSize(imageName: imgName)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

// MARK: -  Actions
private extension ViewController {
    
    @IBAction func tapGestureAction(_ sender: Any) {
        
        PHPhotoLibrary.requestAuthorization { (authorizationStatus) in
            if authorizationStatus == PHAuthorizationStatus.authorized ||
                authorizationStatus == PHAuthorizationStatus.notDetermined {
                
                let imagePickerVC = UIImagePickerController()
                imagePickerVC.delegate = self
                
                self.present(imagePickerVC, animated: true) {
                    print("imagePickerViewController presented")
                }
            }
        }
    }
}


// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        print("pickedMediaInfo:", info)
        /*["UIImagePickerControllerImageURL": file:///private/var/mobile/Containers/Data/Application/90DA3F70-0807-4563-A21A-D1F31282FCB9/tmp/FB7CCC1C-5CA0-4578-A079-21F2AB85B07B.jpeg,
         "UIImagePickerControllerMediaType": public.image,
         "UIImagePickerControllerReferenceURL": assets-library://asset/asset.JPG?id=4F50BF1E-64BB-42F9-A071-B011CA63E8E1&ext=JPG,
         "UIImagePickerControllerOriginalImage": <UIImage: 0x1c40b27e0> size {2448, 3264} orientation 3 scale 1.000000]
         */
        
        self.imageView.image = info[UIImagePickerControllerOriginalImage] as? UIImage
        printSomePhotoImageFileSize(image: (info[UIImagePickerControllerOriginalImage] as? UIImage)!, assetURL: info[UIImagePickerControllerReferenceURL] as! URL)
        
        picker.dismiss(animated: true) {
            print("picker dismissed")
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker .dismiss(animated: true) {
            print("picker dismissed")
        }
    }
}


// MARK: - ImageFileSize
extension ViewController {
    // TODO: 原始大小是按照Mac上该图片显示的大小， iPhone导出到MAC - iFunBox/Mac照片
    // TODO: 
    /* 相册中的图片
     *  PNG: (IMG_0032.png 660183)
     *      1、(PHImageManager) requestImageData大小，与原始相等 (660183)  -------- 原始大小相等
     *      2、其他经过JPEG/PNG压缩等，与项目工程中的测试结果一致
     *
     *  JPG:（例：IMG_0020.JPG 1231310，IMG_0021.JPG 2263281）
     *      1、(PHImageManager) requestImageData大小，与原始相等 ( 1481706, 2263281)  -------- 有些相等，有些偏大 (难道是 照片 从iPhone导出到Mac 改变了图片大小)
     *      2、其他经过JPEG/PNG压缩等，与项目工程中的测试结果一致
     *
     */
    func printSomePhotoImageFileSize(image pickedImg: UIImage, assetURL url: URL) {
        
        let originalImgData = photoImageOriginalData(assetURL: url)
        if let originalImg = UIImage(data: originalImgData!) {
            
            print("\n\n")
            print("original image data   : ", originalImgData?.count as Int? ?? 0)
            print("compressed image(JPEG): ", UIImageJPEGRepresentation(originalImg, 1.0)?.count ?? 0)
            print("compressed image( PNG): ", UIImagePNGRepresentation(originalImg)?.count ?? 0)
            
            print("compressed picked image(JPEG): ", UIImageJPEGRepresentation(pickedImg, 1.0)?.count ?? 0)
            print("compressed picked image( PNG): ", UIImagePNGRepresentation(pickedImg)?.count ?? 0)
        }
        
    }
    
    /* 项目工程中的照片
     * PNG:（例：IMG_0016.PNG 603880，IMG_0032.png 660183）
     *      1、直接读取Data数据，会有偏差，测试结果大一些（682893, 702146）
     *      2、经过JPEG-1.0压缩后变小（418869, 343196）
     *      3、经过PNG压缩后与原始大小相差不大（602946, 659249） ---------- 最接近原始图片大小
     *      4、FileManager获取文件属性大小与第1种结果相同(682893, 702146)
     *
     * JPG:（例：IMG_0020.JPG 1231310，IMG_0021.JPG 2263281）
     *      1、直接读取Data数据，大小相同（1231310, 2263281） ---------- 等于原始图片大小
     *      2、经过JPEG-1.0压缩后,变大（4114067, 5606201）
     *      3、经过PNG压缩后,变的更大（11264923, 13047269）
     *      4、FileManager获取文件属性大小，与第1种结果相同(1231310, 2263281) ---------- 等于原始图片大小（同1）
     */
    func printSomeBundleImageFileSize(imageName imgName: String) {
        
        do {
            let nameArray = imgName.split(separator: ".")
            let imgPath = Bundle.main.path(forResource: String(nameArray[0]), ofType: String(nameArray[1]))
            let imgURL = URL(fileURLWithPath: imgPath!)
            
            // first Data -> Image
            let originalImgData = try Data(contentsOf: imgURL)
            let originalImg = UIImage(data: originalImgData)
            
            // first Image
            let directImg = UIImage(named: imgName)
            
            // attribute by fileManager
            let attributes = try FileManager.default.attributesOfItem(atPath: imgPath!)
            
            print("bundle image name: ", imgName)
            print("original bundle image data   : ", originalImgData.count as Int? ?? 0)
            print("compressed bundle image(JPEG): ", UIImageJPEGRepresentation(originalImg!, 1.0)?.count ?? 0, "-", UIImageJPEGRepresentation(directImg!, 1.0)?.count ?? 0)
            print("compressed bundle image( PNG): ", UIImagePNGRepresentation(originalImg!)?.count ?? 0, "-", UIImagePNGRepresentation(directImg!)?.count ?? 0)
            
            print("fileManager.default.attributeOfItem: ", attributes[FileAttributeKey.size] ?? Int())
            
        } catch _ {
            print("error")
        }
        
    }
    
    func photoImageOriginalData(assetURL url: URL) -> Data? {
        
        let result = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil)
        
        if let asset = result.firstObject {
            
            let reqOptions = PHImageRequestOptions()
            reqOptions.isSynchronous = true
            
            var imgData: Data?
            PHImageManager.default().requestImageData(for: asset, options: reqOptions) { (imageData, dataUTI, orientation, info) in
                imgData = imageData
            }
            
            return imgData
        }
        
        return nil;
    }
    
}

