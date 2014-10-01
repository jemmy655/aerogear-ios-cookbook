/*
* JBoss, Home of Professional Open Source.
* Copyright Red Hat, Inc., and individual contributors
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/


import UIKit
import MobileCoreServices
import AssetsLibrary

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var newMedia: Bool = true
    
    @IBOutlet weak var imageView: UIImageView!
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }


    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK - Toolbar Actions
    
    @IBAction func useCamera(sender: UIBarButtonItem) {
        if (UIImagePickerController.isSourceTypeAvailable(.Camera)) {
            var imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .Camera
            imagePicker.mediaTypes = NSArray(object: kUTTypeImage)
            imagePicker.allowsEditing = false
            self.presentViewController(imagePicker, animated:true, completion:{})
            newMedia = true
        }
    }
    
    @IBAction func useCameraRoll(sender: UIBarButtonItem) {
        if (UIImagePickerController.isSourceTypeAvailable(.SavedPhotosAlbum)) {
            var imagePicker = UIImagePickerController()
            imagePicker.delegate = self;
            imagePicker.sourceType = .PhotoLibrary
            imagePicker.mediaTypes = NSArray(object: kUTTypeImage)
            imagePicker.allowsEditing = false
            self.presentViewController(imagePicker, animated:true, completion:{})
            newMedia = false
        }
    }
    
    @IBAction func share(sender: UIBarButtonItem) {
        let filename = self.imageView.accessibilityIdentifier;
        if (filename == nil) { // nothing was selected
            let alertController = UIAlertController(title: "Error", message: "Please select an image first!", preferredStyle: .Alert)
            presentViewController(alertController, animated: true, completion: nil)
            let ok = UIAlertAction(title: "OK", style: .Default, handler: { (action) in })
            alertController.addAction(ok)
            return;
        }
        
        let alertController = UIAlertController(title: "Share with", message: nil, preferredStyle: .ActionSheet)
        let google = UIAlertAction(title: "Google", style: .Default, handler: { (action) in
            self.shareWithGoogleDrive()
        })
        alertController.addAction(google)
        let facebook = UIAlertAction(title: "Facebook", style: .Default, handler: { (action) in
            self.self.shareWithFacebook()
        })
        alertController.addAction(facebook)
        
        let keycloak = UIAlertAction(title: "Keycloak", style: .Default, handler: { (action) in
            self.self.shareWithKeycloak()
        })
        alertController.addAction(keycloak)
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    func shareWithFacebook() {
        println("Perform photo upload with Facebook")
        let facebookConfig = FacebookConfig(
            clientId: "YYY",
            clientSecret: "XXX",
            scopes:["photo_upload, publish_actions"])
        
        let fbModule =  AccountManager.addFacebookAccount(facebookConfig)
        let http = Http(url: "https://graph.facebook.com/me/photos")
        http.authzModule = fbModule
        
        self.performUpload(http, parameters: self.extractImageAsMultipartParams())
    }
    
    func shareWithGoogleDrive() {
        println("Perform photo upload with Google")
        
        let googleConfig = GoogleConfig(
            clientId: "873670803862-g6pjsgt64gvp7r25edgf4154e8sld5nq.apps.googleusercontent.com",
            scopes:["https://www.googleapis.com/auth/drive"])

        let gdModule = AccountManager.addGoogleAccount(googleConfig)
        let http = Http(url: "https://www.googleapis.com/upload/drive/v2/files")
        http.authzModule = gdModule
    
        self.performUpload(http, parameters: self.extractImageAsMultipartParams())
    }
    
    func shareWithKeycloak() {
        println("Perform photo upload with Keycloak")
        
        var keycloakConfig = Config(base: "http://192.168.1.6:8080/auth",
            authzEndpoint: "realms/keycloak/tokens/login",
            redirectURL: "org.aerogear.KeycloakDemo://oauth2Callback",
            accessTokenEndpoint: "realms/keycloak/tokens/access/codes",
            clientId: "third-party",
            refreshTokenEndpoint: "realms/keycloak/tokens/refresh",
            revokeTokenEndpoint: "realms/keycloak/tokens/logout")

        let gdModule = AccountManager.addAccount(keycloakConfig, moduleClass: KeycloakOAuth2Module.self)
        let http = Http(url: "http://192.168.1.6:8080/keycloak/rest/products")
        http.authzModule = gdModule
        
        // popup dialog for user to enter product name
        let alertController = UIAlertController(title: "Enter name", message: "Enter name of the product:", preferredStyle: .Alert)
        alertController.addTextFieldWithConfigurationHandler(nil)
        
        let okAction = UIAlertAction(title: "OK", style: .Default, handler: { (action) in
            var params = self.extractImageAsMultipartParams()
            params["name"] = (alertController.textFields![0] as UITextField).text
            
            self.performUpload(http, parameters: params)
        })
        alertController.addAction(okAction)
        
        presentViewController(alertController, animated: true, completion: nil)
        
    }

    func performUpload(http: Http, parameters: [String: AnyObject]?) {
        // TODO as part of AGIOS-229
        http.POST(parameters: parameters, completionHandler: {(response, error) in
            if (error != nil) {
                self.presentAlert("Error", message: error!.localizedDescription)
            } else {
                self.presentAlert("Success", message: "Successfully uploaded!")
            }
        })
    }
    
    // MARK - UIImagePickerControllerDelegate
    
    func imagePickerController(picker: UIImagePickerController!, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]!) {
        self.dismissViewControllerAnimated(true, completion:nil)
        var image: UIImage = info[UIImagePickerControllerOriginalImage] as UIImage
        if (newMedia == true) {
            UIImageWriteToSavedPhotosAlbum(image, self, Selector("image:didFinishSavingWithError:contextInfo:"), nil)
        } else {
            var imageURL:NSURL = info[UIImagePickerControllerReferenceURL] as NSURL
            var assetslibrary = ALAssetsLibrary()
            assetslibrary.assetForURL(imageURL, resultBlock: {
                (asset: ALAsset!) in
                if asset != nil {
                    var assetRep: ALAssetRepresentation = asset.defaultRepresentation()
                    self.imageView.accessibilityIdentifier = assetRep.filename()
                    self.imageView.image = image;
                }
            }, failureBlock: {
                (error: NSError!) in
                println("Error \(error)")
            }
            )
        }
    }
    
    func image(image: UIImage, didFinishSavingWithError: NSError?, contextInfo:UnsafePointer<Void>) {
        self.imageView.image = image;
        self.imageView.accessibilityIdentifier = "Untitled.jpg";
        if let error = didFinishSavingWithError {
            let alert = UIAlertView(title: "Save failed", message: "Failed to save image", delegate: nil, cancelButtonTitle:"OK", otherButtonTitles:"")
                alert.show()
        }
   }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        self.dismissViewControllerAnimated(true, completion:nil)
    }
    
    func extractImageAsMultipartParams() -> [String: AnyObject] {
        // extract the image filename
        let filename = self.imageView.accessibilityIdentifier;
        
        let multiPartData = MultiPartData(data: UIImageJPEGRepresentation(self.imageView.image, 0.2),
            name: "image",
            filename: filename,
            mimeType: "image/jpg")
        
        return ["file": multiPartData]
    }
    
    func presentAlert(title: String, message: String) {
        var alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
}
